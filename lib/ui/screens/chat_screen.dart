import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/item_gasto_model.dart';
import '../../data/datasources/remote/gemini_service.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/models/shopping_item_model.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../../providers/scan_queue_provider.dart';
import '../../providers/chat_provider.dart';
import 'review_expense_screen.dart';

class ChatSuggestion {
  final String label;
  final IconData icon;
  const ChatSuggestion({required this.label, required this.icon});
}

const List<ChatSuggestion> kDefaultChatSuggestions = [
  ChatSuggestion(
    label: '¿Qué gastos pequeños están sumando más de lo que parece?',
    icon: Icons.search_rounded,
  ),
  ChatSuggestion(
    label: '¿Qué gastos podría reducir sin afectar lo esencial?',
    icon: Icons.content_cut_rounded,
  ),
  ChatSuggestion(
    label: '¿Qué productos o gastos me han subido de precio?',
    icon: Icons.trending_up_rounded,
  ),
  ChatSuggestion(
    label: '¿En qué días o momentos del mes suelo gastar más?',
    icon: Icons.calendar_month_rounded,
  ),
  ChatSuggestion(
    label: '¿Qué suelo comprar cada mes que aún no he comprado?',
    icon: Icons.checklist_rounded,
  ),
];

class ChatScreen extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBack;
  final GeminiService? geminiService;
  final DatabaseHelper? dbHelper;
  final stt.SpeechToText? speechToText;
  final ChatProvider? chatProvider;

  const ChatScreen({
    Key? key,
    this.showBackButton = false,
    this.onBack,
    this.geminiService,
    this.dbHelper,
    this.speechToText,
    this.chatProvider,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  ChatProvider? _localChatProvider;
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final GeminiService _geminiService;
  late final DatabaseHelper _dbHelper;
  late final stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  String? _spanishLocaleId;

  ChatProvider _getChatProvider(BuildContext context) {
    if (widget.chatProvider != null) return widget.chatProvider!;
    try {
      return Provider.of<ChatProvider>(context, listen: false);
    } catch (_) {
      return _localChatProvider ??= ChatProvider();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _geminiService = widget.geminiService ?? GeminiService();
    _dbHelper = widget.dbHelper ?? DatabaseHelper.instance;
    _speech = widget.speechToText ?? stt.SpeechToText();
    _focusNode.addListener(_onFocusChange);
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToBottom();
      }
    });
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

  Future<void> _stopListening({bool cancel = false}) async {
    _isListening = false;
    if (mounted) {
      setState(() {});
    }
    try {
      if (cancel) {
        await _speech.cancel();
      } else {
        await _speech.stop();
      }
    } catch (_) {}
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
            if (mounted && _isListening) {
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

    final String? metodoArg = gastoData['metodo_liquidacion']?.toString() ?? gastoData['metodoLiquidacion']?.toString();
    String? metodoLiquidacion = (metodoArg != null && ['BS_BCV', 'BS_USDT', 'DIVISA'].contains(metodoArg.toUpperCase()))
        ? metodoArg.toUpperCase()
        : null;

    if (metodoLiquidacion == null && (monedaGasto == 'USD' || monedaGasto == 'EUR')) {
      final textLower = rawUserText.toLowerCase();
      if (textLower.contains('bcv') ||
          textLower.contains('banco central') ||
          textLower.contains('oficial') ||
          textLower.contains('pago movil') ||
          textLower.contains('pago móvil') ||
          textLower.contains('punto') ||
          textLower.contains('debito') ||
          textLower.contains('débito') ||
          textLower.contains('biopago') ||
          textLower.contains('en bolivares') ||
          textLower.contains('en bolívares') ||
          textLower.contains('en bs')) {
        metodoLiquidacion = 'BS_BCV';
      } else if (textLower.contains('paralelo') ||
          textLower.contains('usdt') ||
          textLower.contains('binance') ||
          textLower.contains('p2p')) {
        metodoLiquidacion = 'BS_USDT';
      } else if (textLower.contains('efectivo') ||
          textLower.contains('billete') ||
          textLower.contains('zelle') ||
          textLower.contains('wally') ||
          textLower.contains('zinli') ||
          textLower.contains('divisa')) {
        metodoLiquidacion = 'DIVISA';
      }
    }

    return GeminiExtractionResult(
      comercio: comercio,
      fecha: fecha,
      moneda: monedaGasto,
      totalOriginal: totalOrigVal,
      tasaCambioDetectada: tasaChat > 0 ? tasaChat : null,
      impuestoIva: 0.0,
      items: itemsGasto,
      metodoLiquidacion: metodoLiquidacion,
    );
  }

  Map<String, dynamic> _buildSemanticChatContext({
    required GastoProvider gastoProvider,
    required SettingsProvider settings,
    required List<ShoppingItemModel> shoppingItems,
  }) {
    final savingsSnapshot = gastoProvider.savingsSnapshot;

    // 1. Totales acumulados por categoría en USD
    final Map<String, double> totalesCategoria = {};
    for (final g in gastoProvider.gastos) {
      final cat = g.categoria;
      final usd = g.totalUsd / 100.0;
      totalesCategoria[cat] = (totalesCategoria[cat] ?? 0.0) + usd;
    }

    // 2. Top 10 productos más comprados del mes (cantidad y total USD)
    final Map<String, Map<String, dynamic>> productMap = {};
    for (final g in gastoProvider.gastos) {
      for (final item in g.items) {
        final name = item.descripcion.trim();
        if (name.isEmpty) continue;
        if (DatabaseHelper.isTaxItem(name)) continue;
        final key = name.toLowerCase();
        final existing = productMap[key] ?? {
          'producto': name,
          'cantidad': 0.0,
          'total_usd': 0.0,
          'veces_comprado': 0,
        };
        existing['cantidad'] = (existing['cantidad'] as double) + item.cantidad;
        final double itemUsd = (g.totalOriginal > 0)
            ? (item.total / g.totalOriginal) * (g.totalUsd / 100.0)
            : (item.total / 100.0);
        existing['total_usd'] = (existing['total_usd'] as double) + itemUsd;
        existing['veces_comprado'] = (existing['veces_comprado'] as int) + 1;
        productMap[key] = existing;
      }
    }
    final sortedProducts = productMap.values.toList()
      ..sort((a, b) => (b['cantidad'] as double).compareTo(a['cantidad'] as double));
    final top10Productos = sortedProducts.take(10).map((p) => {
      'producto': p['producto'],
      'cantidad': double.parse((p['cantidad'] as double).toStringAsFixed(1)),
      'total_usd': double.parse((p['total_usd'] as double).toStringAsFixed(2)),
      'veces_comprado': p['veces_comprado'],
    }).toList();

    // 3. Últimas 5 compras del mes para contexto temporal
    final sortedGastos = List<GastoModel>.from(gastoProvider.gastos)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final ultimasCompras = sortedGastos.take(5).map((g) => {
      'fecha': g.fecha,
      'comercio': g.comercio,
      'categoria': g.categoria,
      'moneda': g.moneda,
      'monto_original': double.parse((g.totalOriginal / 100.0).toStringAsFixed(2)),
      'total_usd': double.parse((g.totalUsd / 100.0).toStringAsFixed(2)),
      'total_usdt': double.parse(((g.totalUsdt ?? g.totalUsd) / 100.0).toStringAsFixed(2)),
    }).toList();

    final brechaCapturada = double.parse(
      (gastoProvider.totalMesUsd - gastoProvider.totalMesUsdt).toStringAsFixed(2),
    );

    final double totalEurBcv = (settings.tasaCambioVesEur > 0 && gastoProvider.totalMesVes > 0)
        ? double.parse((gastoProvider.totalMesVes / settings.tasaCambioVesEur).toStringAsFixed(2))
        : (settings.tasaCambioVesEur > 0
            ? double.parse((gastoProvider.totalMesUsd * settings.tasaCambioVesUsd / settings.tasaCambioVesEur).toStringAsFixed(2))
            : gastoProvider.totalMesUsd);

    return {
      'tasa_bcv_usd': settings.tasaCambioVesUsd,
      'tasa_bcv_eur': settings.tasaCambioVesEur,
      'tasa_usdt': settings.tasaCambioVesUsdt,
      'totales_categoria': totalesCategoria.map((k, v) => MapEntry(k, double.parse(v.toStringAsFixed(2)))),
      'top_productos_mes': top10Productos,
      'ultimas_compras': ultimasCompras,
      'total_usd': gastoProvider.totalMesUsd,
      'total_usd_bcv': gastoProvider.totalMesUsd,
      'total_usdt_p2p': gastoProvider.totalMesUsdt,
      'total_eur_bcv': totalEurBcv,
      'total_ves': gastoProvider.totalMesVes,
      'brecha_capturada': brechaCapturada,
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
  }

  Future<void> _sendMessage([String? textOverride]) async {
    final text = (textOverride ?? _textCtrl.text).trim();
    if (text.isEmpty) return;

    if (_isListening || _speech.isListening) {
      await _stopListening(cancel: true);
    }

    final chatProvider = _getChatProvider(context);
    chatProvider.addMessage({'role': 'user', 'text': text});
    if (textOverride == null) {
      _textCtrl.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isListening && _textCtrl.text.isNotEmpty) {
          _textCtrl.clear();
        }
      });
    }
    chatProvider.setLoading(true);
    _scrollToBottom();

    try {
      final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final shoppingItems = await _dbHelper.getAllShoppingItems();
      final contextData = _buildSemanticChatContext(
        gastoProvider: gastoProvider,
        settings: settings,
        shoppingItems: shoppingItems,
      );

      // Ventana deslizante: enviar a la API solo los últimos 5 mensajes para proteger tokens
      final allMsgs = chatProvider.messages;
      final recentMessages = allMsgs.length > 5
          ? allMsgs.sublist(allMsgs.length - 5)
          : allMsgs;
      final chatMessages = recentMessages.map((m) => {
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
              if (hasExpenseKeyword) {
                final String comercio = args['comercio']?.toString().trim() ?? '';
                final List items = args['items'] as List? ?? [];
                final String itemDesc = items.isNotEmpty && items.first is Map && items.first['descripcion'] != null
                    ? items.first['descripcion'].toString().trim()
                    : 'tu compra';
                final String comStr = (comercio.isNotEmpty && comercio != 'Varios' && comercio != 'Compra general')
                    ? ' en $comercio'
                    : '';
                chatProvider.addMessage({
                  'role': 'assistant',
                  'text': 'Entendido, antes de registrar $itemDesc$comStr, dime: ¿cuánto te costó en total?',
                });
              } else {
                chatProvider.addMessage({
                  'role': 'assistant',
                  'text': '¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?',
                });
              }
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
            chatProvider.addMessage({
              'role': 'assistant',
              'text': 'No se pudieron extraer los datos del gasto. Intenta indicando monto y comercio.',
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
          chatProvider.addMessage({
            'role': 'assistant',
            'text': msgText,
            'extractionResult': firstExtraction,
            'queueItemId': firstQueueId,
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
          if (agregados.isNotEmpty) {
            final plural = agregados.length == 1 ? 'producto' : 'productos';
            chatProvider.addMessage({
              'role': 'assistant',
              'text': 'Anoté $plural en tu lista de compras: ${agregados.join(", ")}.',
            });
          } else {
            chatProvider.addMessage({
              'role': 'assistant',
              'text': 'No se especificaron productos para agregar a la lista.',
            });
          }
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
          if (match != null && match.id != null && nuevoNombre.isNotEmpty) {
            _dbHelper.updateShoppingItemName(match.id!, nuevoNombre);
            chatProvider.addMessage({
              'role': 'assistant',
              'text': 'Cambié "${match.name}" por "$nuevoNombre" en tu lista de compras.',
            });
          } else {
            chatProvider.addMessage({
              'role': 'assistant',
              'text': 'No encontré ningún producto que coincida con "$nombreActual" en tu lista de compras.',
            });
          }
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
          if (eliminados.isNotEmpty) {
            chatProvider.addMessage({
              'role': 'assistant',
              'text': 'Eliminé de tu lista de compras: ${eliminados.join(", ")}.',
            });
          } else {
            chatProvider.addMessage({
              'role': 'assistant',
              'text': 'No encontré los productos solicitados en tu lista de compras.',
            });
          }
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
          final estado = comprado ? 'comprado(s)' : 'pendiente(s)';
          if (modificados.isNotEmpty) {
            chatProvider.addMessage({
              'role': 'assistant',
              'text': 'Marqué como $estado: ${modificados.join(", ")}.',
            });
          } else {
            chatProvider.addMessage({
              'role': 'assistant',
              'text': 'No encontré los productos solicitados en tu lista de compras.',
            });
          }
        }
      } else {
        final String textResponse = responseMap['text'] ?? '';
        if (!mounted) return;
        chatProvider.addMessage({'role': 'assistant', 'text': textResponse});
      }
    } catch (e) {
      if (!mounted) return;
      final cleanError = e.toString().replaceFirst('Exception: ', '').trim();
      chatProvider.addMessage({'role': 'assistant', 'text': cleanError});
    } finally {
      chatProvider.setLoading(false);
      if (mounted) {
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

  void _mostrarDialogoReiniciar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: AppColors.textPrimary, size: 22),
            SizedBox(width: 8),
            Text('¿Reiniciar conversación?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Se borrará el historial actual del chat y no podrás recuperar la conversación anterior. ¿Deseas empezar de nuevo?',
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            key: const Key('chat_confirm_reset_button'),
            onPressed: () {
              Navigator.pop(ctx);
              _getChatProvider(context).clearConversation();
              _scrollToBottom();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
            ),
            child: const Text('Reiniciar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = widget.chatProvider ?? () {
      try {
        return Provider.of<ChatProvider>(context);
      } catch (_) {
        return _localChatProvider ??= ChatProvider();
      }
    }();

    return AnimatedBuilder(
      animation: chatProvider,
      builder: (context, _) {
        final messages = chatProvider.messages;
        final isLoading = chatProvider.isLoading;

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
            actions: [
              IconButton(
                key: const Key('chat_reset_conversation_button'),
                icon: const Icon(Icons.restart_alt, size: 24),
                tooltip: 'Reiniciar conversación',
                onPressed: () => _mostrarDialogoReiniciar(context),
              ),
            ],
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
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
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
          if (isLoading)
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
                    color: isLoading ? AppColors.textMuted : AppColors.secondary,
                  ),
                  label: Text(
                    suggestion.label,
                    style: TextStyle(
                      color: isLoading ? AppColors.textMuted : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                    color: isLoading ? AppColors.divider : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: isLoading ? null : () => _sendMessage(suggestion.label),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12,
            ),
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
                  onPressed: isLoading ? null : _toggleListening,
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primaryDark),
                  onPressed: isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

