import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants/app_colors.dart';
import '../../data/datasources/remote/gemini_service.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../../data/models/item_gasto_model.dart';
import '../../providers/scan_queue_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/connectivity_service.dart';
import '../screens/review_expense_screen.dart';

class VoiceExpenseSheet extends StatefulWidget {
  final GeminiService? geminiService;
  final stt.SpeechToText? speechToText;
  final ConnectivityService? connectivityService;
  final VoidCallback? onOpenManualExpense;

  const VoiceExpenseSheet({
    Key? key,
    this.geminiService,
    this.speechToText,
    this.connectivityService,
    this.onOpenManualExpense,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    GeminiService? geminiService,
    stt.SpeechToText? speechToText,
    ConnectivityService? connectivityService,
    VoidCallback? onOpenManualExpense,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceExpenseSheet(
        geminiService: geminiService,
        speechToText: speechToText,
        connectivityService: connectivityService,
        onOpenManualExpense: onOpenManualExpense,
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
  late final bool _ownsGeminiService;
  late final ConnectivityService _connectivity;
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  StreamSubscription<bool>? _connectivitySub;
  bool _isOffline = false;
  bool _hasInitializedSpeech = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isProcessing = false;
  String? _serviceErrorMessage;
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
    _ownsGeminiService = widget.geminiService == null;
    _geminiService = widget.geminiService ??
        GeminiService(
          enableLocalVoiceFallback: false,
          voiceRequestTimeout: const Duration(seconds: 15),
        );
    _connectivity = widget.connectivityService ?? ConnectivityService.instance;
    _initConnectivityListener();
    _checkConnectivityAndStart();
  }

  void _initConnectivityListener() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((hasConnection) {
      if (!mounted) return;
      if (!hasConnection) {
        if (_isProcessing) return;
        _manualStopRequested = true;
        final wasListening = _isListening;
        _isListening = false;
        if (wasListening || _speechAvailable) {
          unawaited(_speech.cancel());
        }
        setState(() {
          _isOffline = true;
          _serviceErrorMessage = null;
        });
      } else if (_isOffline) {
        setState(() {
          _isOffline = false;
          _serviceErrorMessage = null;
          _statusMessage = 'Preparando micrófono...';
        });
        if (!_hasInitializedSpeech) {
          _initAndStartListening();
        } else if (_speechAvailable) {
          _startListening();
        } else {
          setState(() {
            _statusMessage = 'Toca el micrófono para hablar o escribe';
          });
        }
      }
    });
  }

  Future<void> _checkConnectivityAndStart() async {
    final hasConnection = await _connectivity.isConnected();
    if (!mounted) return;
    if (!hasConnection) {
      setState(() {
        _isOffline = true;
        _isListening = false;
      });
      return;
    }
    await _initAndStartListening();
  }

  @override
  void dispose() {
    _manualStopRequested = true;
    _isListening = false;
    _connectivitySub?.cancel();
    if (_speechAvailable) {
      unawaited(_speech.cancel());
    }
    if (_ownsGeminiService) {
      _geminiService.close();
    }
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initAndStartListening() async {
    if (_isOffline) return;
    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) {
          if (!mounted) return;
          final errMsg = val.errorMsg.toLowerCase();
          if (errMsg == 'error_network' || errMsg == 'error_network_timeout') {
            _manualStopRequested = true;
            _isListening = false;
            if (_speechAvailable) {
              unawaited(_speech.cancel());
            }
            setState(() {
              _isOffline = true;
              _serviceErrorMessage = null;
            });
            return;
          }
          setState(() {
            _isListening = false;
            _statusMessage = 'Toca el micrófono para hablar o escribe abajo';
          });
        },
        onStatus: (status) {
          if (!mounted || _isOffline) return;
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

      if (!mounted || _manualStopRequested || _isOffline) {
        _hasInitializedSpeech = false;
        return;
      }
      _hasInitializedSpeech = _speechAvailable;

      if (_speechAvailable) {
        final locales = await _speech.locales();
        if (!mounted || _manualStopRequested || _isOffline) return;
        for (final loc in locales) {
          if (loc.localeId.toLowerCase().startsWith('es')) {
            _spanishLocaleId = loc.localeId;
            break;
          }
        }
        _spanishLocaleId ??= 'es_ES';

        await _startListening();
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = 'Micrófono no disponible o sin permiso';
          });
        }
      }
    } catch (e) {
      _hasInitializedSpeech = false;
      debugPrint('VoiceExpenseSheet: Error al iniciar micrófono: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusMessage = 'No pudimos activar el micrófono. Puedes escribir abajo.';
        });
      }
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable || _isOffline) return;

    _focusNode.unfocus();
    _manualStopRequested = false;
    _committedText = _textCtrl.text.trim();
    _currentSegmentText = '';
    _segmentFinalized = false;
    _lastResultAt = null;

    setState(() {
      _isListening = true;
      _serviceErrorMessage = null;
      _statusMessage = 'Escuchando... toca el micrófono para pausar';
    });

    try {
      await _speech.listen(
        localeId: _spanishLocaleId,
        onResult: (val) {
          if (!mounted || _manualStopRequested || _isProcessing || !_isListening || _isOffline) return;

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
    } catch (e) {
      debugPrint('VoiceExpenseSheet: Error al escuchar con micrófono: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusMessage = 'Toca el micrófono para hablar o escribe abajo';
        });
      }
    }
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

    if (_speechAvailable) {
      await _speech.stop();
    }
  }

  void _openManualExpense(BuildContext context) {
    final onOpenManual = widget.onOpenManualExpense;
    if (onOpenManual != null) {
      Navigator.pop(context);
      onOpenManual();
      return;
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ReviewExpenseScreen(
          extractedData: GeminiExtractionResult(
            comercio: '',
            fecha: DateTime.now().toIso8601String().substring(0, 10),
            moneda: settings.monedaPrincipal,
            totalOriginal: 0.0,
            tasaCambioDetectada: null,
            impuestoIva: 0.0,
            items: [
              ItemGastoModel(
                descripcion: '',
                cantidad: 1.0,
                precioUnitario: 0,
                total: 0,
                categoria: 'Otros',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processExpense() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    _manualStopRequested = true;
    _isListening = false;
    if (_speechAvailable) {
      await _speech.cancel();
    }
    if (!mounted) return;

    final hasConnection = await _connectivity.isConnected();
    if (!mounted) return;
    if (!hasConnection) {
      setState(() {
        _isProcessing = false;
        _isOffline = true;
        _serviceErrorMessage = null;
      });
      return;
    }

    _focusNode.unfocus();
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _serviceErrorMessage = null;
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
    } on VoiceOfflineException catch (e) {
      debugPrint('VoiceExpenseSheet: Corte de red al procesar dictado: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isOffline = true;
          _serviceErrorMessage = null;
        });
      }
    } on VoiceServiceException catch (e) {
      debugPrint('VoiceExpenseSheet: Error de servicio al procesar dictado: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _serviceErrorMessage = e.message;
          _statusMessage = 'No se pudo procesar en este momento.';
        });
      }
    } catch (e) {
      debugPrint('VoiceExpenseSheet: Error inesperado al procesar dictado: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _serviceErrorMessage =
              'No pudimos procesar tu dictado en este momento. Intenta de nuevo o regístralo manualmente.';
          _statusMessage = 'No se pudo procesar en este momento.';
        });
      }
    }
  }

  Widget _buildOfflineView(BuildContext context) {
    return Column(
      key: const ValueKey('voice_offline_column'),
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
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardLighter,
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.wifi_off_rounded,
            size: 26,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Dictar gasto necesita internet',
          key: Key('voice_offline_title'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Regístralo manualmente ahora o vuelve a intentar cuando tengas conexión.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('voice_offline_close_button'),
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text(
                  'Cerrar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                key: const Key('voice_offline_manual_button'),
                onPressed: () => _openManualExpense(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, size: 17, color: AppColors.textPrimary),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Escribir gasto',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _textCtrl.text.trim().isNotEmpty;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final serviceError = _serviceErrorMessage;

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
            child: _isOffline
                ? _buildOfflineView(context)
                : Column(
                    key: const ValueKey('voice_online_column'),
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
                      if (serviceError != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          key: const Key('voice_service_error_banner'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.warning),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  serviceError,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF92400E),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else ...[
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
                      ],
                      Container(
                        key: const Key('voice_expense_input_container'),
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
                          textCapitalization: TextCapitalization.sentences,
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
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
                      else if (serviceError != null)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('voice_error_manual_button'),
                                onPressed: () => _openManualExpense(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                                child: const Text(
                                  'Escribir gasto',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: ElevatedButton(
                                key: const Key('voice_expense_process_button'),
                                onPressed: hasText ? _processExpense : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.textPrimary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Reintentar',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
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
