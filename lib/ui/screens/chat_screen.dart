import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants/app_colors.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/item_gasto_model.dart';
import '../../data/datasources/remote/gemini_service.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/models/shopping_item_model.dart';
import '../../core/utils/uuid_generator.dart';
import 'review_expense_screen.dart';

class ChatSuggestion {
  final String label;
  final IconData icon;
  const ChatSuggestion({required this.label, required this.icon});
}

const List<ChatSuggestion> kDefaultChatSuggestions = [
  ChatSuggestion(
    label: '¿Cuánto he gastado este mes?',
    icon: Icons.account_balance_wallet_outlined,
  ),
  ChatSuggestion(
    label: '¿En qué categoría he gastado más?',
    icon: Icons.pie_chart_outline,
  ),
  ChatSuggestion(
    label: '¿Qué tengo en mi lista de compras?',
    icon: Icons.checklist_rounded,
  ),
  ChatSuggestion(
    label: '¿Cómo voy con mi presupuesto?',
    icon: Icons.savings_outlined,
  ),
  ChatSuggestion(
    label: 'Dame un resumen de mis gastos',
    icon: Icons.analytics_outlined,
  ),
];

class ChatScreen extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBack;
  final GeminiService? geminiService;
  final DatabaseHelper? dbHelper;

  const ChatScreen({
    Key? key,
    this.showBackButton = false,
    this.onBack,
    this.geminiService,
    this.dbHelper,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final GeminiService _geminiService;
  late final DatabaseHelper _dbHelper;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _geminiService = widget.geminiService ?? GeminiService();
    _dbHelper = widget.dbHelper ?? DatabaseHelper.instance;
    _messages.add({
      'role': 'assistant',
      'text': 'Puedo ayudarte con lo que necesites dentro de Rinde Más: responder preguntas sobre tus gastos del mes o registrar compras directamente. ¿Qué deseas consultar?',
    });
    _initSpeech();
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .trim();
  }

  @override
  void dispose() {
    try {
      _speech.stop();
    } catch (_) {}
    _textCtrl.dispose();
    _scrollController.dispose();
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
        String previousText = _textCtrl.text;
        if (previousText.isNotEmpty && !previousText.endsWith(' ')) {
          previousText += ' ';
        }
        if (mounted) setState(() => _isListening = true);
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? textOverride]) async {
    final text = (textOverride ?? _textCtrl.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      if (textOverride == null) {
        _textCtrl.clear();
      }
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
      final shoppingItems = await _dbHelper.getAllShoppingItems();
      final contextData = {
        'gastos_mes': gastoProvider.gastos.map((g) => g.toMap()).toList(),
        'total_usd': gastoProvider.totalMesUsd,
        'total_ves': gastoProvider.totalMesVes,
        'presupuesto_general': gastoProvider.presupuestoGeneral,
        'moneda_presupuesto': gastoProvider.monedaPresupuesto,
        'presupuestos_categoria': gastoProvider.presupuestosPorCategoria,
        'lista_compras': shoppingItems.map((e) => {
          'id': e.id,
          'nombre': e.name,
          'comprado': e.isPurchased == 1,
        }).toList(),
      };

      final chatMessages = _messages.map((m) => {
        'role': m['role']?.toString() ?? 'user',
        'text': m['text']?.toString() ?? '',
      }).toList();

      final responseMap = await _geminiService.chatWithAnalyst(
        messages: chatMessages,
        contextData: contextData,
      );

      if (responseMap.containsKey('functionCall')) {
        final call = responseMap['functionCall'] as Map;
        final callName = call['name'];

        if (callName == 'registrar_gasto') {
          final args = call['args'] as Map;
          final double totalUsd = (args['total_usd'] as num?)?.toDouble() ?? 0.0;

          // Red de seguridad de desambiguación en cliente
          final userText = text.toLowerCase();
          final bool hasExplicitNumber = RegExp(r'\d+').hasMatch(userText);
          final bool hasExpenseKeyword = userText.contains('gast') || userText.contains('compr') || userText.contains('pagu') || userText.contains('cost');

          if (totalUsd <= 0 || (!hasExplicitNumber && !hasExpenseKeyword)) {
            setState(() {
              _messages.add({
                'role': 'assistant',
                'text': '¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?',
              });
            });
            return;
          }

          final String comercio = args['comercio'] ?? 'General';
          final String fecha = args['fecha'] ?? DateTime.now().toIso8601String().substring(0, 10);
          final String categoria = args['categoria'] ?? 'Otros';
          
          final List itemsList = args['items'] ?? [];
          final List<ItemGastoModel> itemsGasto = itemsList.map((item) {
            final double precioUnit = (item['precio_unitario'] as num?)?.toDouble() ?? totalUsd;
            final double cant = (item['cantidad'] as num?)?.toDouble() ?? 1.0;
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
            moneda: 'USD',
            totalOriginal: (totalUsd * 100).round(),
            totalUsd: (totalUsd * 100).round(),
            categoria: categoria,
            creadoEn: DateTime.now().toIso8601String(),
          );

          // Auto-detectar coincidencias con la lista de compras pendiente
          final List<int> matchedShoppingIds = [];
          try {
            final pendingShopping = await _dbHelper.getPendingShoppingItems();
            for (final item in itemsGasto) {
              final descNorm = _normalizeText(item.descripcion);
              if (descNorm.length >= 2) {
                for (final shopItem in pendingShopping) {
                  final shopNorm = _normalizeText(shopItem.name);
                  if (shopNorm.isNotEmpty && (descNorm == shopNorm || descNorm.contains(shopNorm) || shopNorm.contains(descNorm))) {
                    if (shopItem.id != null && !matchedShoppingIds.contains(shopItem.id!)) {
                      matchedShoppingIds.add(shopItem.id!);
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error al cotejar compras en chat: $e');
          }

          final success = await gastoProvider.agregarGasto(nuevoGasto, itemsGasto, shoppingItemIds: matchedShoppingIds);

          setState(() {
            if (success) {
              String msg = '¡Listo! He registrado tu compra en "$comercio" por \$${totalUsd.toStringAsFixed(2)}.';
              if (matchedShoppingIds.isNotEmpty) {
                msg += ' Se tacharon ${matchedShoppingIds.length} producto(s) de tu lista de compras.';
              }
              GastoModel gastoGuardado = nuevoGasto;
              try {
                gastoGuardado = gastoProvider.gastos.firstWhere(
                  (g) => g.uuid == nuevoGasto.uuid,
                  orElse: () => nuevoGasto,
                );
              } catch (_) {}

              _messages.add({
                'role': 'assistant',
                'text': msg,
                'gasto': gastoGuardado,
              });
            } else {
              _messages.add({'role': 'assistant', 'text': 'Hubo un error al intentar guardar el gasto.'});
            }
          });
        } else if (callName == 'agregar_items_lista_compras') {
          final args = call['args'] as Map;
          final List nombres = args['nombres'] ?? (args['nombre'] != null ? [args['nombre']] : []);
          final List<String> agregados = [];
          for (final n in nombres) {
            final nombreStr = n.toString().trim();
            if (nombreStr.isNotEmpty) {
              await _dbHelper.insertShoppingItem(
                ShoppingItemModel(
                  name: nombreStr,
                  createdAt: DateTime.now().toIso8601String(),
                ),
              );
              agregados.add(nombreStr);
            }
          }
          setState(() {
            if (agregados.isNotEmpty) {
              final plural = agregados.length == 1 ? 'producto' : 'productos';
              _messages.add({
                'role': 'assistant',
                'text': 'Anoté $plural en tu lista de compras: ${agregados.join(", ")}.',
              });
            } else {
              _messages.add({
                'role': 'assistant',
                'text': 'No se especificaron productos para agregar a la lista.',
              });
            }
          });
        } else if (callName == 'modificar_item_lista_compras') {
          final args = call['args'] as Map;
          final String nombreActual = (args['nombre_actual'] ?? args['nombre'] ?? '').toString().trim().toLowerCase();
          final String nuevoNombre = (args['nuevo_nombre'] ?? '').toString().trim();
          final allItems = await _dbHelper.getAllShoppingItems();
          ShoppingItemModel? match;
          for (final item in allItems) {
            final iname = item.name.toLowerCase();
            if (iname == nombreActual || iname.contains(nombreActual) || nombreActual.contains(iname)) {
              match = item;
              break;
            }
          }

          setState(() {
            if (match != null && match.id != null && nuevoNombre.isNotEmpty) {
              _dbHelper.updateShoppingItemName(match.id!, nuevoNombre);
              _messages.add({
                'role': 'assistant',
                'text': 'Cambié "${match.name}" por "$nuevoNombre" en tu lista de compras.',
              });
            } else {
              _messages.add({
                'role': 'assistant',
                'text': 'No encontré ningún producto que coincida con "$nombreActual" en tu lista de compras.',
              });
            }
          });
        } else if (callName == 'eliminar_items_lista_compras') {
          final args = call['args'] as Map;
          final List nombres = args['nombres'] ?? (args['nombre'] != null ? [args['nombre']] : []);
          final allItems = await _dbHelper.getAllShoppingItems();
          final List<String> eliminados = [];
          for (final n in nombres) {
            final target = n.toString().trim().toLowerCase();
            for (final item in allItems) {
              final iname = item.name.toLowerCase();
              if (iname == target || iname.contains(target) || target.contains(iname)) {
                if (item.id != null && !eliminados.contains(item.name)) {
                  await _dbHelper.deleteShoppingItem(item.id!);
                  eliminados.add(item.name);
                  break;
                }
              }
            }
          }
          setState(() {
            if (eliminados.isNotEmpty) {
              _messages.add({
                'role': 'assistant',
                'text': 'Eliminé de tu lista de compras: ${eliminados.join(", ")}.',
              });
            } else {
              _messages.add({
                'role': 'assistant',
                'text': 'No encontré los productos solicitados en tu lista de compras.',
              });
            }
          });
        } else if (callName == 'marcar_items_lista_compras') {
          final args = call['args'] as Map;
          final List nombres = args['nombres'] ?? (args['nombre'] != null ? [args['nombre']] : []);
          final bool comprado = args['comprado'] ?? true;
          final allItems = await _dbHelper.getAllShoppingItems();
          final List<String> modificados = [];
          for (final n in nombres) {
            final target = n.toString().trim().toLowerCase();
            for (final item in allItems) {
              final iname = item.name.toLowerCase();
              if (iname == target || iname.contains(target) || target.contains(iname)) {
                if (item.id != null && !modificados.contains(item.name)) {
                  await _dbHelper.updateShoppingItemStatus(item.id!, comprado);
                  modificados.add(item.name);
                  break;
                }
              }
            }
          }
          setState(() {
            final estado = comprado ? 'comprado(s)' : 'pendiente(s)';
            if (modificados.isNotEmpty) {
              _messages.add({
                'role': 'assistant',
                'text': 'Marqué como $estado: ${modificados.join(", ")}.',
              });
            } else {
              _messages.add({
                'role': 'assistant',
                'text': 'No encontré los productos solicitados en tu lista de compras.',
              });
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
      _scrollToBottom();
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
        automaticallyImplyLeading: widget.showBackButton && widget.onBack == null,
        leading: (widget.showBackButton && widget.onBack != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormattedMessage(
                          msg['text'] ?? '',
                          AppColors.textPrimary,
                        ),
                        if (msg['gasto'] != null && msg['gasto'] is GastoModel) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            key: const Key('chat_edit_expense_button'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReviewExpenseScreen(
                                    existingGasto: msg['gasto'] as GastoModel,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_note, size: 18, color: AppColors.textPrimary),
                            label: const Text(
                              'Ver / Editar gasto',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ],
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
            height: 40,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kDefaultChatSuggestions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final suggestion = kDefaultChatSuggestions[index];
                return ActionChip(
                  key: Key('chat_suggestion_chip_$index'),
                  avatar: Icon(
                    suggestion.icon,
                    size: 16,
                    color: _isLoading ? AppColors.textMuted : AppColors.secondary,
                  ),
                  label: Text(
                    suggestion.label,
                    style: TextStyle(
                      color: _isLoading ? AppColors.textMuted : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                    color: _isLoading ? AppColors.divider : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: _isLoading ? null : () => _sendMessage(suggestion.label),
                );
              },
            ),
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
                      hintText: _isListening ? 'Escuchando... habla ahora' : 'Pregunta o pídeme algo...',
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

