import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/item_gasto_model.dart';
import '../../data/datasources/remote/gemini_service.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/models/shopping_item_model.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../../providers/scan_queue_provider.dart';
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
  final stt.SpeechToText? speechToText;

  const ChatScreen({
    Key? key,
    this.showBackButton = false,
    this.onBack,
    this.geminiService,
    this.dbHelper,
    this.speechToText,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final GeminiService _geminiService;
  late final DatabaseHelper _dbHelper;
  late final stt.SpeechToText _speech;
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String? _spanishLocaleId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _geminiService = widget.geminiService ?? GeminiService();
    _dbHelper = widget.dbHelper ?? DatabaseHelper.instance;
    _speech = widget.speechToText ?? stt.SpeechToText();
    _focusNode.addListener(_onFocusChange);
    final now = DateTime.now();
    final mesNombre = DateFormatter.getMonthName(now.month);
    final String initialGreeting;
    if (now.day <= 5) {
      initialGreeting = '¡Nuevo mes! Hoy es un buen día para determinarte a aplicar lo aprendido el mes pasado. Tu presupuesto de $mesNombre ya está listo. ¿Qué deseas consultar o registrar hoy?';
    } else {
      initialGreeting = 'Puedo ayudarte con lo que necesites dentro de Rinde Más: responder preguntas sobre tus gastos del mes o registrar compras directamente. ¿Qué deseas consultar?';
    }
    _messages.add({
      'role': 'assistant',
      'text': initialGreeting,
    });
    _initSpeech();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _isListening) {
      _stopListening();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopListening();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    try {
      _speech.stop();
    } catch (_) {}
    _textCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
  }

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
      await _stopListening();
    } else {
      if (_speechAvailable) {
        _focusNode.unfocus();
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
              content: Text('Reconocimiento de voz no disponible o sin permiso.', style: TextStyle(color: Colors.black)),
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

  GeminiExtractionResult _prepararExtractionResult({
    required Map gastoData,
    required String rawUserText,
    required double tasaChat,
  }) {
    final double totalUsd = (gastoData['total_usd'] as num?)?.toDouble() ?? 0.0;
    final double montoOriginalArg = (gastoData['monto_original'] as num?)?.toDouble() ?? 0.0;
    final String comercio = gastoData['comercio']?.toString().trim().isNotEmpty == true
        ? gastoData['comercio'].toString().trim()
        : 'General';
    final String fecha = gastoData['fecha']?.toString().trim().isNotEmpty == true
        ? gastoData['fecha'].toString().trim()
        : DateTime.now().toIso8601String().substring(0, 10);
    final String categoria = AppConstants.normalizarCategoria(gastoData['categoria']?.toString().trim() ?? 'Otros');
    final String monedaArg = gastoData['moneda']?.toString() ?? '';
    final String monedaGasto = AppConstants.normalizarMoneda(
      monedaArg.isNotEmpty ? monedaArg : null,
      fallback: AppConstants.detectarMonedaDeTexto(rawUserText, fallback: 'USD'),
    );

    double totalOrigVal;
    if (monedaGasto == 'VES') {
      totalOrigVal = montoOriginalArg > 0 ? montoOriginalArg : (totalUsd > 0 && totalUsd != montoOriginalArg ? totalUsd : (totalUsd * tasaChat));
    } else {
      totalOrigVal = montoOriginalArg > 0 ? montoOriginalArg : totalUsd;
    }

    final List itemsList = gastoData['items'] as List? ?? [];
    final List<ItemGastoModel> itemsGasto = itemsList.whereType<Map>().map((item) {
      final double cant = (item['cantidad'] as num?)?.toDouble() ?? 1.0;
      final double precioUnit = (item['precio_unitario'] as num?)?.toDouble() ?? (cant > 0 ? totalOrigVal / cant : totalOrigVal);
      final String catItemRaw = item['categoria']?.toString().trim() ?? categoria;
      return ItemGastoModel(
        descripcion: item['descripcion']?.toString() ?? 'Artículo',
        cantidad: cant,
        precioUnitario: (precioUnit * 100).round(),
        total: (precioUnit * cant * 100).round(),
        categoria: AppConstants.normalizarCategoria(catItemRaw),
      );
    }).toList();

    if (itemsGasto.isEmpty) {
      itemsGasto.add(ItemGastoModel(
        descripcion: 'Compra en $comercio',
        cantidad: 1.0,
        precioUnitario: (totalOrigVal * 100).round(),
        total: (totalOrigVal * 100).round(),
        categoria: categoria,
      ));
    }

    return GeminiExtractionResult(
      comercio: comercio,
      fecha: fecha,
      moneda: monedaGasto,
      totalOriginal: totalOrigVal,
      tasaCambioDetectada: tasaChat > 0 ? tasaChat : null,
      impuestoIva: 0.0,
      items: itemsGasto,
    );
  }

  Future<void> _sendMessage([String? textOverride]) async {
    if (_isListening) {
      await _stopListening();
    }
    final text = (textOverride ?? _textCtrl.text).trim();
    if (text.isEmpty) return;

    if (!mounted) return;
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
      final savingsSnapshot = gastoProvider.savingsSnapshot;
      final contextData = {
        'gastos_mes': gastoProvider.gastos.map((g) => g.toMap()).toList(),
        'total_usd': gastoProvider.totalMesUsd,
        'total_ves': gastoProvider.totalMesVes,
        'presupuesto_general': gastoProvider.presupuestoGeneral,
        'meta_ahorro': gastoProvider.metaAhorro,
        'limite_para_gastar': savingsSnapshot.limiteParaGastar,
        'gasto_proyectado_fin_mes': savingsSnapshot.gastoProyectadoFinDeMes,
        'estado_meta_ahorro': savingsSnapshot.status.name,
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

      if (!mounted) return;

      if (responseMap.containsKey('functionCall')) {
        final call = responseMap['functionCall'] as Map;
        final callName = call['name'];

        if (callName == 'registrar_gasto') {
          final args = call['args'] as Map;
          final List gastosList = args['gastos'] as List? ?? [];
          final settings = Provider.of<SettingsProvider>(context, listen: false);
          final double tasaChat = settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : 1.0;

          final List<GeminiExtractionResult> extractions = [];
          if (gastosList.isNotEmpty) {
            for (final g in gastosList) {
              if (g is Map) {
                extractions.add(_prepararExtractionResult(
                  gastoData: g,
                  rawUserText: text,
                  tasaChat: tasaChat,
                ));
              }
            }
          } else {
            final double totalUsd = (args['total_usd'] as num?)?.toDouble() ?? 0.0;
            final userText = text.toLowerCase();
            final bool hasExplicitNumber = RegExp(r'\d+').hasMatch(userText);
            final bool hasExpenseKeyword = userText.contains('gast') || userText.contains('compr') || userText.contains('pagu') || userText.contains('cost');

            if (totalUsd <= 0 || (!hasExplicitNumber && !hasExpenseKeyword)) {
              if (!mounted) return;
              setState(() {
                _messages.add({
                  'role': 'assistant',
                  'text': '¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?',
                });
              });
              return;
            }

            extractions.add(_prepararExtractionResult(
              gastoData: args,
              rawUserText: text,
              tasaChat: tasaChat,
            ));
          }

          if (extractions.isEmpty) {
            if (!mounted) return;
            setState(() {
              _messages.add({
                'role': 'assistant',
                'text': 'No se pudieron extraer los datos del gasto. Intenta indicando monto y comercio.',
              });
            });
            return;
          }

          int? firstQueueId;
          if (extractions.length > 1) {
            try {
              final queueProvider = Provider.of<ScanQueueProvider>(context, listen: false);
              final insertedIds = await queueProvider.enqueueReadyExtractionResults(extractions);
              if (insertedIds.isNotEmpty) {
                firstQueueId = insertedIds.first;
              }
            } catch (_) {}
          }

          final firstExtraction = extractions.first;
          final montoFormateado = CurrencyFormatter.formatAmount(firstExtraction.totalOriginal, firstExtraction.moneda);
          final count = extractions.length;
          final msgText = count > 1
              ? 'He preparado $count compras para tu revisión: ${extractions.map((e) => '"${e.comercio}" (${CurrencyFormatter.formatAmount(e.totalOriginal, e.moneda)})').join(', ')}. Confírmalas a continuación para guardarlas.'
              : 'He preparado tu compra en "${firstExtraction.comercio}" por $montoFormateado. Revísala y confírmala para guardarla.';

          if (!mounted) return;
          setState(() {
            _messages.add({
              'role': 'assistant',
              'text': msgText,
              'extractionResult': firstExtraction,
              'queueItemId': firstQueueId,
            });
          });
          return;
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
          if (!mounted) return;
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

          if (!mounted) return;
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
          if (!mounted) return;
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
          if (!mounted) return;
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
        if (!mounted) return;
        setState(() {
          _messages.add({'role': 'assistant', 'text': textResponse});
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final cleanError = e.toString().replaceFirst('Exception: ', '').trim();
        _messages.add({'role': 'assistant', 'text': cleanError});
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
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

  void _mostrarDialogoReporteIA(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.flag_outlined, color: AppColors.textPrimary, size: 22),
            SizedBox(width: 8),
            Text('Reportar respuesta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '¿Consideras que esta respuesta generada por la IA es inexacta, inapropiada o contiene información errónea? Tu reporte nos ayuda a mejorar la precisión y calidad del asistente.',
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gracias por tu reporte. Lo tendremos en cuenta para futuras mejoras.', style: TextStyle(color: Colors.black)),
                  backgroundColor: AppColors.primary,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
            ),
            child: const Text('Reportar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente IA'),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _stopListening();
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification || notification is ScrollUpdateNotification) {
                  if (_isListening) {
                    _stopListening();
                  }
                }
                return false;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _focusNode.unfocus();
                  if (_isListening) {
                    _stopListening();
                  }
                },
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
                            if (msg['extractionResult'] != null && msg['extractionResult'] is GeminiExtractionResult) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                key: const Key('chat_review_expense_button'),
                                onPressed: () {
                                  _stopListening();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReviewExpenseScreen(
                                        extractedData: msg['extractionResult'] as GeminiExtractionResult,
                                        queueItemId: msg['queueItemId'] as int?,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.rate_review_outlined, size: 18, color: Colors.black),
                                label: const Text(
                                  'Revisar y Guardar compra',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ] else if (msg['gasto'] != null && msg['gasto'] is GastoModel) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                key: const Key('chat_edit_expense_button'),
                                onPressed: () {
                                  _stopListening();
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
                            if (!isUser) ...[
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: () => _mostrarDialogoReporteIA(context),
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.outlined_flag, size: 12, color: AppColors.textSecondary),
                                        SizedBox(width: 4),
                                        Text(
                                          'Reportar respuesta',
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
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
                    focusNode: _focusNode,
                    onTap: () {
                      if (_isListening) {
                        _stopListening();
                      }
                    },
                    onChanged: (_) {
                      if (_isListening) {
                        _stopListening();
                      }
                    },
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

