import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants/app_colors.dart';
import '../../data/datasources/remote/gemini_service.dart';
import '../../providers/scan_queue_provider.dart';
import '../../providers/settings_provider.dart';
import '../screens/review_expense_screen.dart';

class VoiceExpenseSheet extends StatefulWidget {
  final GeminiService? geminiService;
  final stt.SpeechToText? speechToText;

  const VoiceExpenseSheet({
    Key? key,
    this.geminiService,
    this.speechToText,
  }) : super(key: key);

  static Future<void> show(BuildContext context, {GeminiService? geminiService, stt.SpeechToText? speechToText}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceExpenseSheet(
        geminiService: geminiService,
        speechToText: speechToText,
      ),
    );
  }

  static String joinSpeechParts(String committed, String current) {
    final c = committed.trim();
    final cur = current.trim();
    if (c.isEmpty) return cur;
    if (cur.isEmpty) return c;
    return '$c $cur';
  }

  static String _normalizeSpeechForComparison(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Determina si el motor nativo de voz inició un nuevo segmento (por pausa breve)
  /// en lugar de seguir expandiendo o corrigiendo la frase en curso.
  static bool shouldCommitPreviousSpeechSegment(
    String previousSegment,
    String incomingSegment, {
    required bool wasFinalized,
    Duration? gap,
  }) {
    final prevNorm = _normalizeSpeechForComparison(previousSegment);
    final incNorm = _normalizeSpeechForComparison(incomingSegment);
    if (prevNorm.isEmpty || incNorm.isEmpty) return false;
    if (incNorm == prevNorm || incNorm.startsWith(prevNorm)) return false;
    if (wasFinalized) return true;

    final prevWords = prevNorm.split(' ');
    final incWords = incNorm.split(' ');
    if (prevNorm.startsWith(incNorm) && prevWords.length >= 2 && incWords.length < prevWords.length) {
      return true;
    }

    if (prevWords.first != incWords.first) {
      if (prevWords.length >= 2) return true;
      if (gap != null && gap.inMilliseconds >= 500) return true;
      if (prevWords.first.length < 2 ||
          incWords.first.length < 2 ||
          prevWords.first.substring(0, 2) != incWords.first.substring(0, 2)) {
        return true;
      }
      return false;
    }

    if (prevWords.length >= 3 && incWords.length <= prevWords.length - 2) {
      return true;
    }
    if (gap != null &&
        gap.inMilliseconds >= 700 &&
        incWords.length <= 2 &&
        incWords.length < prevWords.length) {
      return true;
    }

    return false;
  }

  @override
  State<VoiceExpenseSheet> createState() => _VoiceExpenseSheetState();
}

class _VoiceExpenseSheetState extends State<VoiceExpenseSheet> {
  late final stt.SpeechToText _speech;
  late final GeminiService _geminiService;
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isProcessing = false;
  String? _spanishLocaleId;
  String _statusMessage = 'Preparando micrófono...';
  String _committedText = '';
  String _currentSegmentText = '';
  bool _segmentFinalized = false;
  bool _manualStopRequested = false;
  DateTime? _lastResultAt;

  @override
  void initState() {
    super.initState();
    _speech = widget.speechToText ?? stt.SpeechToText();
    _geminiService = widget.geminiService ?? GeminiService();
    _initAndStartListening();
  }

  @override
  void dispose() {
    _manualStopRequested = true;
    _speech.stop();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initAndStartListening() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusMessage = 'Toca el micrófono para hablar o escribe abajo';
            });
          }
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'listening' && !_manualStopRequested && !_isProcessing) {
            setState(() {
              _isListening = true;
              _statusMessage = 'Escuchando... toca el micrófono para pausar';
            });
          } else if (status == 'done' || status == 'notListening') {
            if (_currentSegmentText.isNotEmpty) {
              _committedText = VoiceExpenseSheet.joinSpeechParts(_committedText, _currentSegmentText);
              _currentSegmentText = '';
              _segmentFinalized = false;
            }
            setState(() {
              _isListening = false;
              if (!_isProcessing) {
                if (_textCtrl.text.trim().isNotEmpty) {
                  _statusMessage = 'Pausado. Puedes editar el texto o procesar.';
                } else {
                  _statusMessage = 'Toca el micrófono para hablar o escribe';
                }
              }
            });
          }
        },
      );

      if (!mounted || _manualStopRequested) return;

      if (_speechAvailable) {
        final locales = await _speech.locales();
        if (!mounted || _manualStopRequested) return;
        for (final loc in locales) {
          if (loc.localeId.toLowerCase().startsWith('es')) {
            _spanishLocaleId = loc.localeId;
            break;
          }
        }
        _spanishLocaleId ??= 'es_ES';

        _startListening();
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = 'Micrófono no disponible o sin permiso';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error al iniciar micrófono: $e';
        });
      }
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;

    _focusNode.unfocus();
    _manualStopRequested = false;
    _committedText = _textCtrl.text.trim();
    _currentSegmentText = '';
    _segmentFinalized = false;
    _lastResultAt = null;

    setState(() {
      _isListening = true;
      _statusMessage = 'Escuchando... toca el micrófono para pausar';
    });

    await _speech.listen(
      localeId: _spanishLocaleId,
      onResult: (val) {
        if (!mounted || _manualStopRequested || _isProcessing) return;

        final incoming = val.recognizedWords.trim();
        final now = DateTime.now();

        if (incoming.isEmpty) {
          if (val.finalResult && _currentSegmentText.isNotEmpty) {
            _segmentFinalized = true;
          }
          return;
        }

        final gap = _lastResultAt != null ? now.difference(_lastResultAt!) : null;
        if (_currentSegmentText.isNotEmpty &&
            VoiceExpenseSheet.shouldCommitPreviousSpeechSegment(
              _currentSegmentText,
              incoming,
              wasFinalized: _segmentFinalized,
              gap: gap,
            )) {
          _committedText = VoiceExpenseSheet.joinSpeechParts(_committedText, _currentSegmentText);
          _currentSegmentText = incoming;
          _segmentFinalized = val.finalResult;
        } else {
          _currentSegmentText = incoming;
          if (val.finalResult) {
            _segmentFinalized = true;
          }
        }

        _lastResultAt = now;
        final combined = VoiceExpenseSheet.joinSpeechParts(_committedText, _currentSegmentText);

        setState(() {
          _textCtrl.text = combined;
          _textCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _textCtrl.text.length),
          );
        });
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 10),
    );
  }

  Future<void> _stopListening() async {
    _manualStopRequested = true;
    _isListening = false;
    _committedText = _textCtrl.text.trim();
    _currentSegmentText = '';
    _segmentFinalized = false;

    if (mounted) {
      setState(() {
        if (_textCtrl.text.trim().isNotEmpty) {
          _statusMessage = 'Pausado. Puedes editar el texto o procesar.';
        } else {
          _statusMessage = 'Toca el micrófono para hablar o escribe';
        }
      });
    }

    await _speech.stop();
  }

  Future<void> _processExpense() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    _manualStopRequested = true;
    await _speech.stop();
    if (!mounted) return;
    _focusNode.unfocus();
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _statusMessage = 'Analizando compra con IA...';
    });

    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final extractionResults = await _geminiService.parseVoiceExpense(
        text,
        monedaPrincipal: settings.monedaPrincipal,
      );

      if (!mounted) return;
      if (extractionResults.length > 1) {
        final queueProvider = Provider.of<ScanQueueProvider>(context, listen: false);
        final insertedIds = await queueProvider.enqueueReadyExtractionResults(extractionResults);
        if (!mounted) return;

        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ReviewExpenseScreen(
              extractedData: extractionResults.first,
              queueItemId: insertedIds.first,
            ),
          ),
        );
      } else if (extractionResults.isNotEmpty) {
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ReviewExpenseScreen(
              extractedData: extractionResults.first,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Error al procesar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _textCtrl.text.trim().isNotEmpty;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        key: const Key('sheet_surface_voice'),
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Dictar Gasto',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _isListening ? AppColors.error : AppColors.textSecondary,
                  fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _isProcessing
                    ? null
                    : () {
                        if (_isListening) {
                          _stopListening();
                        } else {
                          _startListening();
                        }
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? AppColors.error : AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? AppColors.error : AppColors.primary)
                            .withValues(alpha: 0.35),
                        blurRadius: _isListening ? 24 : 12,
                        spreadRadius: _isListening ? 6 : 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 38,
                    color: _isListening ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.cardLighter,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _focusNode.hasFocus ? AppColors.primaryDark : AppColors.border,
                    width: _focusNode.hasFocus ? 1.5 : 1.0,
                  ),
                ),
                child: TextField(
                  key: const Key('voice_expense_input_field'),
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.normal,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ej: "Compré víveres por 30 dólares en el automercado"',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    suffixIcon: hasText
                        ? IconButton(
                            key: const Key('voice_expense_clear_button'),
                            icon: const Icon(Icons.clear, size: 20, color: AppColors.textSecondary),
                            tooltip: 'Borrar texto',
                            onPressed: () {
                              setState(() {
                                _textCtrl.clear();
                                _committedText = '';
                                _currentSegmentText = '';
                                _segmentFinalized = false;
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    _committedText = value.trim();
                    _currentSegmentText = '';
                    _segmentFinalized = false;
                    setState(() {});
                  },
                  onTap: () {
                    if (_isListening) {
                      _stopListening();
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.edit_note, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Puedes editar el texto antes de procesarlo',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isProcessing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        key: const Key('voice_expense_process_button'),
                        onPressed: hasText ? _processExpense : null,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Procesar Gasto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
