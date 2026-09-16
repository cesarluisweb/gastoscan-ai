import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/item_gasto_model.dart';
import '../../data/datasources/remote/gemini_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _textCtrl = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'text': 'Puedo ayudarte con lo que necesites dentro de Rinde Más: responder preguntas sobre tus gastos del mes o registrar compras directamente. ¿Qué deseas consultar?',
    });
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
              precioUnitario: precioUnit,
              total: precioUnit * cant,
            );
          }).toList();

          final nuevoGasto = GastoModel(
            fecha: fecha,
            comercio: comercio,
            moneda: 'USD', // Por simplicidad de la IA
            totalOriginal: totalUsd,
            totalUsd: totalUsd,
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
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary),
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
                    decoration: const InputDecoration(
                      hintText: 'Pregunta algo...',
                      border: InputBorder.none,
                      filled: true,
                      fillColor: AppColors.card,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
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

