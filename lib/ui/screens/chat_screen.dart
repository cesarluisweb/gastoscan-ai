import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants/app_colors.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/item_gasto_model.dart';
import '../../data/datasources/remote/gemini_service.dart';
import '../../core/utils/uuid_generator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _textCtrl = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'text': 'Puedo ayudarte con lo que necesites dentro de Rinde Más: responder preguntas sobre tus gastos del mes o registrar compras directamente. ¿Qué deseas consultar?',
    });
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _textCtrl.dispose();
    super.dispose();
  }

  String? _spanishLocaleId;

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => _isListening = false);
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
      }
    } catch (e) {
      _speechAvailable = false;
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      await _initSpeech();
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    } else {
      if (_speechAvailable) {
        if (mounted) setState(() => _isListening = true);
        await _speech.listen(
          localeId: _spanishLocaleId,
          onResult: (val) {
            if (mounted) {
              setState(() {
                _textCtrl.text = val.recognizedWords;
                _textCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textCtrl.text.length),
                );
              });
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reconocimiento de voz no disponible o sin permiso.'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _textCtrl.clear();
      _isLoading = true;
    });

    try {
      final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
      final contextData = {
        'gastos_mes': gastoProvider.gastos.map((g) => g.toMap()).toList(),
        'total_usd': gastoProvider.totalMesUsd,
        'total_ves': gastoProvider.totalMesVes,
      };

      final responseMap = await _geminiService.chatWithAnalyst(
        messages: _messages,
        contextData: contextData,
      );

      if (responseMap.containsKey('functionCall')) {
        final call = responseMap['functionCall'] as Map;
        if (call['name'] == 'registrar_gasto') {
          final args = call['args'] as Map;
          
          // Construir el gasto
          final settings = Provider.of<SettingsProvider>(context, listen: false);
          final double totalUsd = (args['total_usd'] as num).toDouble();
          final String comercio = args['comercio'] ?? 'General';
          final String fecha = args['fecha'] ?? DateTime.now().toIso8601String().substring(0, 10);
          final String categoria = args['categoria'] ?? 'Otros';
          
          final List itemsList = args['items'] ?? [];
          final List<ItemGastoModel> itemsGasto = itemsList.map((item) {
            final double precioUnit = (item['precio_unitario'] as num).toDouble();
            final double cant = (item['cantidad'] as num).toDouble();
            return ItemGastoModel(
              descripcion: item['descripcion'] ?? 'Artículo',
              cantidad: cant,
              precioUnitario: (precioUnit * 100).round(),
              total: (precioUnit * cant * 100).round(),
            );
          }).toList();

          final nuevoGasto = GastoModel(
            uuid: UuidGenerator.generate(),
            fecha: fecha,
            comercio: comercio,
            moneda: 'USD', // Por simplicidad de la IA
            totalOriginal: (totalUsd * 100).round(),
            totalUsd: (totalUsd * 100).round(),
            categoria: categoria,
            creadoEn: DateTime.now().toIso8601String(),
          );

          final success = await gastoProvider.agregarGasto(nuevoGasto, itemsGasto);

          setState(() {
            if (success) {
              _messages.add({
                'role': 'assistant',
                'text': '¡Listo! He registrado tu compra en "$comercio" por \$${totalUsd.toStringAsFixed(2)}.'
              });
            } else {
              _messages.add({'role': 'assistant', 'text': 'Hubo un error al intentar guardar el gasto.'});
            }
          });
        }
      } else {
        final String textResponse = responseMap['text'] ?? '';
        setState(() {
          _messages.add({'role': 'assistant', 'text': textResponse});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': 'Error: $e'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildFormattedMessage(String text, Color textColor) {
    final List<TextSpan> spans = [];
    final RegExp regex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final Match match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(color: textColor, fontSize: 14),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(color: textColor, fontSize: 14),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente IA'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.85,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: isUser ? null : Border.all(color: AppColors.border),
                    ),
                    child: _buildFormattedMessage(
                      msg['text'] ?? '',
                      AppColors.textPrimary,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 40),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: InputDecoration(
                      hintText: _isListening ? 'Escuchando... habla ahora' : 'Pregunta algo...',
                      border: InputBorder.none,
                      filled: true,
                      fillColor: AppColors.card,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? AppColors.error : AppColors.primaryDark,
                  ),
                  tooltip: _isListening ? 'Detener micrófono' : 'Hablar por micrófono',
                  onPressed: _isLoading ? null : _toggleListening,
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primaryDark),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

