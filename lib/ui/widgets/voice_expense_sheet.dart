import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants/app_colors.dart';
import '../../data/datasources/remote/gemini_service.dart';
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

  @override
  void initState() {
    super.initState();
    _speech = widget.speechToText ?? stt.SpeechToText();
    _geminiService = widget.geminiService ?? GeminiService();
    _initAndStartListening();
  }

  @override
  void dispose() {
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
          if (mounted) {
            if (status == 'done' || status == 'notListening') {
              setState(() {
                _isListening = false;
                if (_textCtrl.text.trim().isNotEmpty) {
                  _statusMessage = 'Pausado. Puedes editar el texto o procesar.';
                } else {
                  _statusMessage = 'Toca el micrófono para hablar o escribe';
                }
              });
            }
          }
        },
      );

      if (_speechAvailable) {
        final locales = await _speech.locales();
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

    String previousText = _textCtrl.text.trim();
    if (previousText.isNotEmpty) {
      previousText += ' ';
    }

    setState(() {
      _isListening = true;
      _statusMessage = 'Escuchando... toca el micrófono para pausar';
    });

    await _speech.listen(
      localeId: _spanishLocaleId,
      onResult: (val) {
        if (mounted) {
          setState(() {
            _textCtrl.text = previousText + val.recognizedWords;
            _textCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _textCtrl.text.length),
            );
          });
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 10),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        if (_textCtrl.text.trim().isNotEmpty) {
          _statusMessage = 'Pausado. Puedes editar el texto o procesar.';
        } else {
          _statusMessage = 'Toca el micrófono para hablar o escribe';
        }
      });
    }
  }

  Future<void> _processExpense() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    await _speech.stop();
    _focusNode.unfocus();
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _statusMessage = 'Analizando compra con IA...';
    });

    try {
      final extractionResult = await _geminiService.parseVoiceExpense(text);

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewExpenseScreen(
              extractedData: extractionResult,
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
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
                            .withOpacity(0.35),
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
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) {
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
                  Text(
                    'Puedes editar el texto antes de procesarlo',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
    );
  }
}
