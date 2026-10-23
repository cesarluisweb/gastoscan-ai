import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/amount_parser.dart';
import '../../models/gemini_extraction_result.dart';
import '../../models/item_gasto_model.dart';
import '../../models/shopping_item_model.dart';

class GeminiService {
  final String _baseUrl;
  final http.Client _client;

  GeminiService({
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = (baseUrl ?? AppConstants.defaultGatewayUrl).replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  /// Valida una API key directamente contra el endpoint público de Google Gemini
  static Future<bool> validateGeminiApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.length < 10) return false;
    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$trimmed');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> _getAuthToken() async {
    // Si Firebase no está inicializado (ej. en tests locales de widgets), retornar token dummy
    if (Firebase.apps.isEmpty) {
      return 'test_mock_token';
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
      }
      final token = await user?.getIdToken();
      if (token == null || token.isEmpty) {
        throw Exception('No se pudo obtener el token de autenticación.');
      }
      return token;
    } catch (e) {
      throw Exception('Fallo de autenticación: $e');
    }
  }

  Future<Map<String, String>> _buildHeaders({String? explicitKey}) async {
    final token = await _getAuthToken();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    String? keyToUse = explicitKey;
    if (keyToUse == null || keyToUse.isEmpty || keyToUse == 'proxy') {
      try {
        const secureStorage = FlutterSecureStorage();
        final stored = await secureStorage.read(key: AppConstants.prefApiKey);
        if (stored != null && stored.trim().length > 10) {
          keyToUse = stored.trim();
        }
      } catch (_) {}
    }

    if (keyToUse != null && keyToUse.trim().length > 10 && keyToUse != 'proxy') {
      headers['x-custom-gemini-key'] = keyToUse.trim();
    }

    return headers;
  }

  Future<List<GeminiExtractionResult>> analyzeReceiptImage({
    required Uint8List imageBytes,
    required String apiKey,
    List<ShoppingItemModel>? pendingShoppingItems,
  }) async {
    try {
      final headers = await _buildHeaders(explicitKey: apiKey);
      final base64Image = base64Encode(imageBytes);
      final shoppingListContext = pendingShoppingItems != null && pendingShoppingItems.isNotEmpty
          ? pendingShoppingItems.map((e) => {'id': e.id, 'name': e.name}).toList()
          : [];

      final uri = Uri.parse('$_baseUrl/analyze-receipt');
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'imageBase64': base64Image,
          'forceVision': true,
          'shoppingList': shoppingListContext,
        }),
      ).timeout(const Duration(minutes: 3));

      return _handleExtractionResponse(response);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error interno al analizar imagen: $e');
    }
  }

  /// Analiza el texto estructurado extraído localmente por ML Kit Text Recognition
  /// evitando el envío multimodal de imágenes en base64 y reduciendo drásticamente latencia y tokens.
  Future<List<GeminiExtractionResult>> analyzeReceiptText({
    required String ocrText,
    List<ShoppingItemModel>? pendingShoppingItems,
  }) async {
    try {
      final headers = await _buildHeaders();
      final shoppingListContext = pendingShoppingItems != null && pendingShoppingItems.isNotEmpty
          ? pendingShoppingItems.map((e) => {'id': e.id, 'name': e.name}).toList()
          : [];

      final uri = Uri.parse('$_baseUrl/analyze-receipt');
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'ocrText': ocrText,
          'shoppingList': shoppingListContext,
        }),
      ).timeout(const Duration(seconds: 45));

      return _handleExtractionResponse(response);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error interno al analizar texto OCR: $e');
    }
  }

  List<GeminiExtractionResult> _handleExtractionResponse(http.Response response) {
    if (response.statusCode == 200) {
      final jsonResult = jsonDecode(response.body) as Map<String, dynamic>;
      return GeminiExtractionResult.listFromJson(jsonResult);
    } else if (response.statusCode == 401) {
      throw Exception('No estás autenticado en Firebase o la sesión caducó.');
    }

    try {
      final errorBody = jsonDecode(response.body);
      if (errorBody is Map && errorBody['isCustomKey'] == true) {
        final errText = errorBody['error']?.toString();
        throw Exception(errText?.isNotEmpty == true
            ? errText!
            : 'Tu API Key de Gemini personalizada tiene un error o agotó su cuota.');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('FormatException')) rethrow;
    }

    if (response.statusCode == 429) {
      String msg = 'El servicio de IA no está disponible en este momento. Tu comprobante está seguro y pendiente de procesamiento.';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map) {
          if (errorBody['dailyLimitReached'] == true && errorBody['error'] != null) {
            msg = errorBody['error'].toString();
          } else {
            final retry = errorBody['retryAfter'];
            if (retry != null && retry.toString().isNotEmpty) {
              msg = 'Límite de solicitudes alcanzado (esperar ${retry}s). Tu comprobante está seguro y pendiente de procesamiento.';
            }
          }
        }
      } catch (_) {}
      throw Exception(msg);
    } else if (response.statusCode == 504) {
      throw Exception('El servicio de IA no está disponible en este momento. Tu comprobante está seguro y pendiente de procesamiento.');
    } else if (response.statusCode == 502 || response.statusCode == 503) {
      throw Exception('El servicio de IA no está disponible en este momento. Tu comprobante está seguro y pendiente de procesamiento.');
    } else {
      try {
        final errorBody = jsonDecode(response.body);
        final message = errorBody['error'] ?? errorBody['message'] ?? 'Error al procesar la factura (${response.statusCode})';
        throw Exception(message);
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) rethrow;
        throw Exception('Error en el servidor (${response.statusCode}).');
      }
    }
  }

  Future<Map<String, dynamic>> chatWithAnalyst({
    required List<Map<String, String>> messages,
    required Map<String, dynamic> contextData,
  }) async {
    try {
      final headers = await _buildHeaders();
      final uri = Uri.parse('$_baseUrl/chat-analyst');

      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'messages': messages,
          'contextData': contextData,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('No estás autenticado en Firebase.');
      }

      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody['isCustomKey'] == true) {
          final errText = errorBody['error']?.toString();
          throw Exception(errText?.isNotEmpty == true
              ? errText!
              : 'Tu API Key de Gemini personalizada tiene un error o agotó su cuota.');
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) rethrow;
      }

      if (response.statusCode == 429) {
        String msg = 'El asistente no está disponible en este momento por límites de capacidad. Intenta de nuevo más tarde.';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map && errorBody['error'] != null) {
            if (errorBody['dailyLimitReached'] == true) {
              msg = errorBody['error'].toString();
            }
          }
        } catch (_) {}
        throw Exception(msg);
      } else if (response.statusCode == 504) {
        throw Exception('El asistente no pudo conectarse. Revisa tu conexión a internet e intenta nuevamente.');
      } else if (response.statusCode == 502 || response.statusCode == 503) {
        throw Exception('El asistente está experimentando alta demanda. Intenta nuevamente más tarde.');
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          final message = errorBody['error'] ?? errorBody['message'] ?? 'Error al comunicarse con el asistente.';
          throw Exception(message);
        } catch (_) {
          throw Exception('Error al comunicarse con el asistente (${response.statusCode}).');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Fallo al conectar con el chat: $e');
    }
  }

  /// Normaliza expresiones coloquiales venezolanas de voz para números y decimales
  /// (ej. "11 con 56" -> "11.56", "12 y medio" -> "12.50", "3 coma 20" -> "3.20")
  static String normalizeVoiceText(String text) {
    if (text.isEmpty) return text;
    String normalized = text;
    // 1. "X con Y" para decimales hablados (ej. "11 con 56" -> "11.56", "3 con 50" -> "3.50")
    normalized = normalized.replaceAllMapped(
      RegExp(r'\b(\d+)\s+con\s+(\d{1,2})\b', caseSensitive: false),
      (m) => '${m.group(1)}.${m.group(2)}',
    );
    // 2. "X y medio" / "X y media" -> "X.50"
    normalized = normalized.replaceAllMapped(
      RegExp(r'\b(\d+)\s+y\s+medi[ao]\b', caseSensitive: false),
      (m) => '${m.group(1)}.50',
    );
    // 3. "X coma Y" -> "X.Y"
    normalized = normalized.replaceAllMapped(
      RegExp(r'\b(\d+)\s+coma\s+(\d{1,2})\b', caseSensitive: false),
      (m) => '${m.group(1)}.${m.group(2)}',
    );
    return normalized;
  }

  GeminiExtractionResult _mapArgsToExtractionResult(Map args, String spokenText) {
    final double totalUsd = (args['total_usd'] as num?)?.toDouble() ?? 0.0;
    final double montoOriginalArg = (args['monto_original'] as num?)?.toDouble() ?? totalUsd;
    final String comercio = args['comercio']?.toString().trim().isNotEmpty == true
        ? args['comercio'].toString().trim()
        : 'Varios';
    final String fecha = args['fecha']?.toString().trim().isNotEmpty == true
        ? args['fecha'].toString().trim()
        : DateTime.now().toIso8601String().substring(0, 10);
    final String categoriaRaw = args['categoria']?.toString().trim() ?? 'Otros';
    final String categoria = AppConstants.normalizarCategoria(categoriaRaw);
    final String monedaArg = args['moneda']?.toString() ?? '';
    final String monedaDetectadaTexto = AppConstants.detectarMonedaDeTexto(spokenText, fallback: 'USD');
    String moneda = AppConstants.normalizarMoneda(
      monedaArg.isNotEmpty ? monedaArg : null,
      fallback: monedaDetectadaTexto,
    );

    // Si el usuario mencionó explícitamente un monto en Bolívares (ej. "Pagué 4.000 Bs por gasolina; eran unos 20 dólares")
    // sin tratarse de un pago en USD liquidado en Bs ("en bolívares a BCV"), prevalece VES e inmutabilidad del bolívar.
    final regMontoExplicitoBs = RegExp(r'\d+\s*(?:mil\s+)?(?:bol[ií]vares|bol[ií]var|bs\.?|ves)\b', caseSensitive: false);
    if (regMontoExplicitoBs.hasMatch(spokenText) && montoOriginalArg > totalUsd && totalUsd > 0) {
      moneda = 'VES';
    }
    final double rawTotalOriginal = montoOriginalArg > 0 ? montoOriginalArg : totalUsd;
    final List itemsList = args['items'] as List? ?? [];

    List<ItemGastoModel> itemsGasto = itemsList.whereType<Map>().map((item) {
      final double cant = (item['cantidad'] as num?)?.toDouble() ?? 1.0;
      double precioUnit = (item['precio_unitario'] as num?)?.toDouble() ?? (cant > 0 && rawTotalOriginal > 0 ? rawTotalOriginal / cant : rawTotalOriginal);

      // Trampa del subtotal vs precio unitario en dictado (ej. "3 harinas en 4 dólares"):
      // Si la IA asigna cantidad 3 y precio_unitario 4, el total del renglón daría 12$ en vez de 4$.
      // Si el precio unitario multiplicado supera el total general dictado pero precioUnit == rawTotalOriginal,
      // significa que el usuario dictó el subtotal de la línea y no el precio unitario.
      if (cant > 1 && rawTotalOriginal > 0) {
        if ((precioUnit * cant) > rawTotalOriginal * 1.05 &&
            (precioUnit - rawTotalOriginal).abs() <= rawTotalOriginal * 0.05) {
          precioUnit = rawTotalOriginal / cant;
        }
      }

      final String catItemRaw = item['categoria']?.toString().trim() ?? categoria;
      return ItemGastoModel(
        descripcion: item['descripcion']?.toString() ?? 'Artículo',
        cantidad: cant,
        precioUnitario: (precioUnit * 100).round(),
        total: (precioUnit * cant * 100).round(),
        categoria: AppConstants.normalizarCategoria(catItemRaw),
      );
    }).toList();

    double totalOriginal = rawTotalOriginal;
    // Si se extrajeron ítems pero el total original vino en 0, calcularlo sumando los ítems
    if (totalOriginal <= 0 && itemsGasto.isNotEmpty) {
      final sumItemsCents = itemsGasto.fold(0, (sum, it) => sum + it.total);
      totalOriginal = sumItemsCents / 100.0;
    }

    if (itemsGasto.isEmpty) {
      itemsGasto = [
        ItemGastoModel(
          descripcion: comercio != 'Varios' ? 'Compra en $comercio' : spokenText,
          cantidad: 1.0,
          precioUnitario: (totalOriginal * 100).round(),
          total: (totalOriginal * 100).round(),
          categoria: categoria,
        ),
      ];
    }

    final String? metodoArg = args['metodo_liquidacion']?.toString() ?? args['metodoLiquidacion']?.toString();
    String? metodoLiquidacion = (metodoArg != null && ['BS_BCV', 'BS_USDT', 'DIVISA'].contains(metodoArg.toUpperCase()))
        ? metodoArg.toUpperCase()
        : null;

    if (metodoLiquidacion == null && (moneda == 'USD' || moneda == 'EUR')) {
      final textLower = spokenText.toLowerCase();
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
      } else {
        // Por defecto en Venezuela los precios referenciados en USD sin especificar efectivo/divisa liquidan en Bs a BCV
        metodoLiquidacion = 'BS_BCV';
      }
    }

    return GeminiExtractionResult(
      comercio: comercio,
      fecha: fecha,
      moneda: moneda,
      totalOriginal: totalOriginal,
      tasaCambioDetectada: null,
      impuestoIva: 0.0,
      items: itemsGasto,
      metodoLiquidacion: metodoLiquidacion,
    );
  }

  Future<List<GeminiExtractionResult>> parseVoiceExpense(String spokenText) async {
    final cleanSpokenText = normalizeVoiceText(spokenText);
    try {
      final responseMap = await chatWithAnalyst(
        messages: [
          {
            'role': 'user',
            'text': 'Registra este gasto o compras: "$cleanSpokenText". Asume que la fecha es hoy si no la menciono. Si menciono compras en múltiples lugares o comercios distintos, extrae cada una por separado en la lista "gastos". Extrae los productos, precios y la categoría adecuada para cada uno. REGLA DE PRECIOS Y CANTIDADES: Expresa los precios usando siempre punto decimal (ej. 11.56 y nunca 1156). Si digo "3 harinas en 4 dólares", el precio_unitario es 4 / 3 = 1.33 (el monto es el subtotal del renglón, no unitario). REGLA CRÍTICA DE MONEDA: Si menciono un monto explícito en Bolívares (ej. "Pagué 4.000 Bs por gasolina; eran unos 20 dólares"), el dato original obligatorio e inmutable es 4000 con moneda: "VES" (el monto en dólares es solo contexto y no debe sobreescribir los bolívares). Si el gasto es en USD o EUR: si fue a tasa paralelo/USDT/Binance especifica metodo_liquidacion: "BS_USDT"; si fue en efectivo/Zelle/Zinli/divisa directa especifica "DIVISA"; en cualquier otro caso (pago móvil, punto, BCV o sin especificar tasa) especifica "BS_BCV".',
          }
        ],
        contextData: {
          'fecha_hoy': DateTime.now().toIso8601String().substring(0, 10),
        },
      );

      if (responseMap.containsKey('functionCall')) {
        final call = responseMap['functionCall'] as Map;
        if (call['name'] == 'registrar_gasto') {
          final args = call['args'] as Map;
          final List gastosList = args['gastos'] as List? ?? [];

          if (gastosList.isNotEmpty) {
            final List<GeminiExtractionResult> results = [];
            for (final g in gastosList) {
              if (g is Map) {
                results.add(_mapArgsToExtractionResult(g, cleanSpokenText));
              }
            }
            if (results.isNotEmpty) {
              return results;
            }
          }

          return [_mapArgsToExtractionResult(args, cleanSpokenText)];
        }
      }
    } catch (e) {
      // Fallback si falla la llamada de red
    }

    // Fallback básico si la IA no devolvió functionCall o hubo un corte
    double montoFallback = 0.0;
    final regexMonto = RegExp(r'(\d+([.,]\d+)?)');
    final match = regexMonto.firstMatch(cleanSpokenText);
    if (match != null) {
      montoFallback = tryParseAmount(match.group(1)!, isPrice: false) ?? 0.0;
    }

    if (montoFallback <= 0.0) {
      throw Exception('No se detectó el monto en el dictado. Por favor incluye el precio de la compra.');
    }

    final String monedaFallback = AppConstants.detectarMonedaDeTexto(cleanSpokenText, fallback: 'USD');
    String? metodoFallback;
    if (monedaFallback == 'USD' || monedaFallback == 'EUR') {
      final textLower = cleanSpokenText.toLowerCase();
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
        metodoFallback = 'BS_BCV';
      } else if (textLower.contains('paralelo') ||
          textLower.contains('usdt') ||
          textLower.contains('binance') ||
          textLower.contains('p2p')) {
        metodoFallback = 'BS_USDT';
      } else if (textLower.contains('efectivo') ||
          textLower.contains('billete') ||
          textLower.contains('zelle') ||
          textLower.contains('wally') ||
          textLower.contains('zinli') ||
          textLower.contains('divisa')) {
        metodoFallback = 'DIVISA';
      } else {
        metodoFallback = 'BS_BCV';
      }
    }

    return [
      GeminiExtractionResult(
        comercio: 'Gasto por voz',
        fecha: DateTime.now().toIso8601String().substring(0, 10),
        moneda: monedaFallback,
        totalOriginal: montoFallback,
        tasaCambioDetectada: null,
        impuestoIva: 0.0,
        metodoLiquidacion: metodoFallback,
        items: [
          ItemGastoModel(
            descripcion: spokenText,
            cantidad: 1.0,
            precioUnitario: (montoFallback * 100).round(),
            total: (montoFallback * 100).round(),
            categoria: 'Otros',
          ),
        ],
      ),
    ];
  }
}
