import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants/app_colors.dart';
import '../../data/datasources/remote/gemini_service.dart';
import '../screens/review_expense_screen.dart';

class VoiceExpenseSheet extends StatefulWidget {
  const VoiceExpenseSheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceExpenseSheet(),
    );
  }

  @override
  State<VoiceExpenseSheet> createState() => _VoiceExpenseSheetState();
}

class _VoiceExpenseSheetState extends State<VoiceExpenseSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final GeminiService _geminiService = GeminiService();

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isProcessing = false;
  String _transcribedText = '';
  String? _spanishLocaleId;
  String _statusMessage = 'Preparando micrófono...';

  @override
  void initState() {
    super.initState();
    _initAndStartListening();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _initAndStartListening() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusMessage = 'Toca el micrófono para hablar';
            });
          }
        },
        onStatus: (status) {
          if (mounted) {
            if (status == 'done' || status == 'notListening') {
              setState(() {
                _isListening = false;
                if (_transcribedText.isNotEmpty) {
                  _statusMessage = 'Dictado listo. Toca "Procesar Gasto"';
                } else {
                  _statusMessage = 'Toca el micrófono para hablar';
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

    setState(() {
      _isListening = true;
      _statusMessage = 'Escuchando... habla ahora';
    });

    await _speech.listen(
      localeId: _spanishLocaleId,
      onResult: (val) {
        if (mounted) {
          setState(() {
            _transcribedText = val.recognizedWords;
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        if (_transcribedText.isNotEmpty) {
          _statusMessage = 'Dictado completado';
        } else {
          _statusMessage = 'Toca el micrófono para hablar';
        }
      });
    }
  }

  Future<void> _processExpense() async {
    if (_transcribedText.trim().isEmpty) return;

    await _speech.stop();
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _statusMessage = 'Analizando compra con IA...';
    });

    try {
      final extractionResult = await _geminiService.parseVoiceExpense(_transcribedText.trim());

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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
            style: TextStyle(
              fontSize: 14,
              color: _isListening ? AppColors.error : AppColors.textSecondary,
              fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 24),
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
              width: 88,
              height: 88,
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
                size: 42,
                color: _isListening ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 70, maxHeight: 120),
            decoration: BoxDecoration(
              color: AppColors.cardLighter,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              child: Text(
                _transcribedText.isNotEmpty
                    ? _transcribedText
                    : 'Ej: "Compré víveres por 30 dólares en el automercado"',
                style: TextStyle(
                  fontSize: 15,
                  color: _transcribedText.isNotEmpty
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontStyle: _transcribedText.isNotEmpty
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 24),
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
                    onPressed: _transcribedText.trim().isNotEmpty ? _processExpense : null,
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
    );
  }
}
