import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
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
  static Future<bool> validateGeminiApiKey(String apiKey, {http.Client? client}) async {
    final trimmed = apiKey.trim();
    if (trimmed.length < 10) return false;
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models');
      final res = await httpClient
          .get(uri, headers: {'x-goog-api-key': trimmed})
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (client == null) {
        httpClient.close();
      }
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
    String? modo,
  }) async {
    try {
      final headers = await _buildHeaders();
      final uri = Uri.parse('$_baseUrl/chat-analyst');

      final bodyMap = <String, dynamic>{
        'messages': messages,
        'contextData': contextData,
      };
      if (modo != null) {
        bodyMap['modo'] = modo;
      }

      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(bodyMap),
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
  /// (ej. "11 con 56" -> "11.56", "3 coma 20" -> "3.20")
  /// Preserva intactas las unidades de peso ("500 gramos", "medio kilo", "2 litros") para Gemini.
  static String normalizeVoiceText(String text) {
    if (text.isEmpty) return text;
    String normalized = text;
    // 1. "X con Y" para decimales hablados (ej. "11 con 56" -> "11.56", "3 con 50" -> "3.50")
    normalized = normalized.replaceAllMapped(
      RegExp(r'\b(\d+)\s+con\s+(\d{1,2})\b', caseSensitive: false),
      (m) => '${m.group(1)}.${m.group(2)}',
    );
    // 2. "X y medio" / "X y media" -> "X.50" (solo si NO va seguido de kilo/gramo/litro)
    normalized = normalized.replaceAllMapped(
      RegExp(r'\b(\d+)\s+y\s+medi[ao]\b(?!\s*(?:kilo|kg|gramo|gr|litro|lt))', caseSensitive: false),
      (m) => '${m.group(1)}.50',
    );
    // 3. "X coma Y" -> "X.Y"
    normalized = normalized.replaceAllMapped(
      RegExp(r'\b(\d+)\s+coma\s+(\d{1,2})\b', caseSensitive: false),
      (m) => '${m.group(1)}.${m.group(2)}',
    );
    return normalized;
  }

  GeminiExtractionResult _mapArgsToExtractionResult(
    Map args,
    String spokenText, {
    String fallbackMoneda = 'USD',
  }) {
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
    final String monedaDetectadaTexto = AppConstants.detectarMonedaDeTexto(spokenText, fallback: fallbackMoneda);
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
      double precioUnit = (item['precio_unitario'] as num?)?.toDouble() ?? 0.0;

      // Si no trajo precio_unitario pero sí un total original general y es el único ítem
      if (precioUnit <= 0 && itemsList.length == 1 && rawTotalOriginal > 0 && cant > 0) {
        precioUnit = rawTotalOriginal / cant;
      }

      // Trampa del subtotal vs precio unitario en dictado (ej. "3 harinas en 4 dólares" o "medio kilo de jamón en 4$"):
      if (cant > 0 && cant != 1.0 && rawTotalOriginal > 0) {
        if (cant > 1.0 &&
            (precioUnit * cant) > rawTotalOriginal * 1.05 &&
            (precioUnit - rawTotalOriginal).abs() <= rawTotalOriginal * 0.05) {
          precioUnit = rawTotalOriginal / cant;
        } else if (cant < 1.0 && (precioUnit - rawTotalOriginal).abs() <= 0.05) {
          precioUnit = rawTotalOriginal / cant;
        }
      }

      // Limpieza de descripción para asegurar que no contenga verbos residuales ni comercios
      String desc = item['descripcion']?.toString().trim() ?? 'Artículo';
      desc = desc.replaceAll(RegExp(r'^(?:compr[eé]|gast[eé]|pagu[eé]|traje)\s+', caseSensitive: false), '').trim();
      if (desc.isEmpty) desc = 'Artículo';

      final String catItemRaw = item['categoria']?.toString().trim() ?? categoria;
      return ItemGastoModel(
        descripcion: desc,
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
          descripcion: comercio != 'Varios' ? 'Compra en $comercio' : 'Gasto general',
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

  Future<List<GeminiExtractionResult>> parseVoiceExpense(
    String spokenText, {
    String monedaPrincipal = 'USD',
  }) async {
    final cleanSpokenText = normalizeVoiceText(spokenText);
    try {
      final responseMap = await chatWithAnalyst(
        messages: [
          {
            'role': 'user',
            'text': cleanSpokenText,
          }
        ],
        contextData: {
          'fecha_hoy': DateTime.now().toIso8601String().substring(0, 10),
          'moneda_principal': monedaPrincipal,
        },
        modo: 'dictado_gasto',
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
                results.add(_mapArgsToExtractionResult(g, cleanSpokenText, fallbackMoneda: monedaPrincipal));
              }
            }
            if (results.isNotEmpty) {
              return results;
            }
          }

          return [_mapArgsToExtractionResult(args, cleanSpokenText, fallbackMoneda: monedaPrincipal)];
        }
      }
    } catch (e) {
      // Fallback si falla la llamada de red
    }

    // Fallback inteligente local si la IA no devolvió functionCall o hubo un corte de red
    return _parseVoiceExpenseLocalFallback(cleanSpokenText, fallbackMoneda: monedaPrincipal);
  }

  static List<GeminiExtractionResult> _parseVoiceExpenseLocalFallback(
    String text, {
    String fallbackMoneda = 'USD',
  }) {
    String comercio = 'Varios';
    // 1. Detección de comercio tras "en ..."
    final matchEn = RegExp(r'\ben\s+([A-Za-z0-9ÁÉÍÓÚáéíóúñÑ\s]+)$', caseSensitive: false).firstMatch(text);
    if (matchEn != null) {
      String possibleComercio = matchEn.group(1)!.trim();
      possibleComercio = possibleComercio.replaceFirst(RegExp(r'^(?:el|la|los|las|un|una)\s+', caseSensitive: false), '').trim();
      if (possibleComercio.isNotEmpty &&
          !possibleComercio.toLowerCase().startsWith('dolar') &&
          !possibleComercio.toLowerCase().startsWith('bolivar') &&
          !possibleComercio.toLowerCase().startsWith('bs')) {
        comercio = possibleComercio[0].toUpperCase() + possibleComercio.substring(1);
      }
    }

    // 2. Detección de cantidad y fracciones de peso (gramos/kilos)
    double cantidad = 1.0;
    final lower = text.toLowerCase();
    if (lower.contains('medio kilo') || lower.contains('media docena')) {
      cantidad = 0.5;
    } else if (lower.contains('un cuarto de kilo') || lower.contains('un cuarto')) {
      cantidad = 0.25;
    } else if (lower.contains('tres cuartos de kilo') || lower.contains('tres cuartos')) {
      cantidad = 0.75;
    } else if (lower.contains('kilo y medio')) {
      cantidad = 1.5;
    } else {
      final matchGramos = RegExp(r'(\d+)\s*(?:gramos|gr|g)\b', caseSensitive: false).firstMatch(lower);
      if (matchGramos != null) {
        final g = double.tryParse(matchGramos.group(1)!) ?? 0.0;
        if (g > 0) cantidad = g / 1000.0;
      } else {
        final matchKg = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:kilos?|kg|litros?|lts?|paquetes?|latas?|unidades?)\b', caseSensitive: false).firstMatch(lower);
        if (matchKg != null) {
          cantidad = double.tryParse(matchKg.group(1)!.replaceAll(',', '.')) ?? 1.0;
        }
      }
    }

    // 3. Detección de monto/precio explícito (asociado a moneda o palabra precio)
    double monto = 0.0;
    final matchPrecio = RegExp(
      r'(?:por|en|de|\$)\s*(\d+(?:[.,]\d+)?)\s*(?:\$|d[oó]lares|bol[ií]vares|bs\.?|ves|euros?|€|usdt)?\b',
      caseSensitive: false,
    ).firstMatch(text);

    if (matchPrecio != null) {
      final parsed = double.tryParse(matchPrecio.group(1)!.replaceAll(',', '.')) ?? 0.0;
      final matchCantNum = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:gramos|gr|g|kilos?|kg|litros?|paquetes?)\b', caseSensitive: false).firstMatch(lower);
      if (matchCantNum == null || matchPrecio.group(1) != matchCantNum.group(1)) {
        monto = parsed;
      }
    }

    double precioUnit = (cantidad > 0 && monto > 0) ? (monto / cantidad) : 0.0;

    // 4. Limpieza del nombre del producto
    String producto = text;
    producto = producto.replaceAll(RegExp(r'^(?:compr[eé]|gast[eé]|pagu[eé]|traje|anota|pon)\s+', caseSensitive: false), '');
    if (comercio != 'Varios') {
      producto = producto.replaceAll(RegExp(r'\s+en\s+' + RegExp.escape(comercio) + r'\b', caseSensitive: false), '');
    }
    producto = producto.replaceAll(RegExp(r'\b(?:medio kilo|un cuarto de kilo|tres cuartos de kilo|kilo y medio)\s*(?:de\s+)?', caseSensitive: false), '');
    producto = producto.replaceAll(RegExp(r'\b\d+(?:[.,]\d+)?\s*(?:gramos|gr|g|kilos?|kg|litros?|lts?|paquetes?|latas?|unidades?)\b\s*(?:de\s+)?', caseSensitive: false), '');
    producto = producto.replaceAll(RegExp(r'\s*(?:por|en|de)?\s*\$?\s*\d+(?:[.,]\d+)?\s*(?:\$|d[oó]lares|bol[ií]vares|bs\.?|ves|euros?|€|usdt)?', caseSensitive: false), '');
    producto = producto.trim();
    if (producto.isEmpty) {
      producto = 'Artículo';
    } else {
      producto = producto[0].toUpperCase() + producto.substring(1);
    }

    // 5. Inferencia de categoría
    String categoria = 'Otros';
    final pLower = producto.toLowerCase();
    if (RegExp(r'\b(queso|carne|pollo|pan|leche|huevos|cafe|café|arroz|harina|comida|verduras|frutas|pasta|jamon|jamón|charcuteria|charcutería|mercado)\b').hasMatch(pLower)) {
      categoria = 'Alimentación';
    } else if (RegExp(r'\b(medicina|pastillas?|jarabe|dolor|farmacia|remedio|salud)\b').hasMatch(pLower)) {
      categoria = 'Salud';
    } else if (RegExp(r'\b(jabon|jabón|champu|champú|desodorante|papel|aseo|higiene)\b').hasMatch(pLower)) {
      categoria = 'Higiene';
    } else if (RegExp(r'\b(gasolina|pasaje|taxi|transporte|camioneta|metro)\b').hasMatch(pLower)) {
      categoria = 'Transporte';
    } else if (RegExp(r'\b(luz|agua|cantv|internet|servicio|saldo|recarga)\b').hasMatch(pLower)) {
      categoria = 'Servicios';
    } else if (RegExp(r'\b(ropa|pantalon|pantalón|camisa|zapatos|medias|franela)\b').hasMatch(pLower)) {
      categoria = 'Ropa';
    } else if (RegExp(r'\b(cuaderno|utiles|útiles|libro|colegio|escuela|educacion|educación)\b').hasMatch(pLower)) {
      categoria = 'Educación';
    } else if (RegExp(r'\b(bombillo|detergente|cloro|reparacion|reparación|hogar)\b').hasMatch(pLower)) {
      categoria = 'Hogar';
    } else if (RegExp(r'\b(cine|salida|restaurante|chucheria|chuchería|snack|fiesta)\b').hasMatch(pLower)) {
      categoria = 'Entretenimiento';
    }

    // 6. Moneda y liquidación
    final String moneda = AppConstants.detectarMonedaDeTexto(text, fallback: fallbackMoneda);
    String? metodoLiquidacion;
    if (moneda == 'USD' || moneda == 'EUR') {
      if (lower.contains('efectivo') || lower.contains('billete') || lower.contains('zelle') || lower.contains('divisa')) {
        metodoLiquidacion = 'DIVISA';
      } else if (lower.contains('paralelo') || lower.contains('usdt') || lower.contains('binance') || lower.contains('p2p')) {
        metodoLiquidacion = 'BS_USDT';
      } else {
        metodoLiquidacion = 'BS_BCV';
      }
    }

    return [
      GeminiExtractionResult(
        comercio: comercio,
        fecha: DateTime.now().toIso8601String().substring(0, 10),
        moneda: moneda,
        totalOriginal: monto,
        tasaCambioDetectada: null,
        impuestoIva: 0.0,
        metodoLiquidacion: metodoLiquidacion,
        items: [
          ItemGastoModel(
            descripcion: producto,
            cantidad: cantidad,
            precioUnitario: (precioUnit * 100).round(),
            total: (monto * 100).round(),
            categoria: categoria,
          ),
        ],
      ),
    ];
  }
}
