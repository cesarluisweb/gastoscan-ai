import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

  Future<List<GeminiExtractionResult>> analyzeReceiptImage({
    required Uint8List imageBytes,
    required String apiKey,
    List<ShoppingItemModel>? pendingShoppingItems,
  }) async {
    try {
      final token = await _getAuthToken();
      final base64Image = base64Encode(imageBytes);
      final shoppingListContext = pendingShoppingItems != null && pendingShoppingItems.isNotEmpty
          ? pendingShoppingItems.map((e) => {'id': e.id, 'name': e.name}).toList()
          : [];

      final uri = Uri.parse('$_baseUrl/analyze-receipt');
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
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
      final token = await _getAuthToken();
      final shoppingListContext = pendingShoppingItems != null && pendingShoppingItems.isNotEmpty
          ? pendingShoppingItems.map((e) => {'id': e.id, 'name': e.name}).toList()
          : [];

      final uri = Uri.parse('$_baseUrl/analyze-receipt');
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
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
    } else if (response.statusCode == 429) {
      String msg = 'Límite de solicitudes alcanzado. Espera unos segundos e intenta nuevamente.';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map) {
          final retry = errorBody['retryAfter'];
          if (retry != null && retry.toString().isNotEmpty) {
            msg = 'Límite de solicitudes alcanzado (esperar ${retry}s).';
          } else if (errorBody['error'] != null) {
            msg = errorBody['error'].toString();
          }
        }
      } catch (_) {}
      throw Exception(msg);
    } else if (response.statusCode == 504) {
      throw Exception('Tiempo de espera agotado. El servidor tardó demasiado en procesar.');
    } else if (response.statusCode == 502 || response.statusCode == 503) {
      throw Exception('Servidores de Gemini temporalmente saturados (${response.statusCode}). Intenta nuevamente en unos instantes.');
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
      final token = await _getAuthToken();
      final uri = Uri.parse('$_baseUrl/chat-analyst');

      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messages': messages,
          'contextData': contextData,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('No estás autenticado en Firebase.');
      } else if (response.statusCode == 429) {
        String msg = 'Límite de solicitudes alcanzado. Espera unos segundos e intenta nuevamente.';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map && errorBody['error'] != null) {
            msg = errorBody['error'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      } else if (response.statusCode == 504) {
        throw Exception('Tiempo de espera agotado al conectar con el asistente.');
      } else if (response.statusCode == 502 || response.statusCode == 503) {
        throw Exception('Servidores de Gemini temporalmente saturados (${response.statusCode}). Intenta nuevamente.');
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

  Future<GeminiExtractionResult> parseVoiceExpense(String spokenText) async {
    try {
      final responseMap = await chatWithAnalyst(
        messages: [
          {
            'role': 'user',
            'text': 'Registra este gasto: "$spokenText". Asume que la fecha es hoy si no la menciono. Extrae los productos, precios y la categoría adecuada para cada uno.',
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
          final double totalUsd = (args['total_usd'] as num?)?.toDouble() ?? 0.0;
          final String comercio = args['comercio'] ?? 'Varios';
          final String fecha = args['fecha'] ?? DateTime.now().toIso8601String().substring(0, 10);
          final String categoria = args['categoria'] ?? 'Otros';
          final List itemsList = args['items'] ?? [];

          List<ItemGastoModel> itemsGasto = itemsList.map((item) {
            final double cant = (item['cantidad'] as num?)?.toDouble() ?? 1.0;
            final double precioUnit = (item['precio_unitario'] as num?)?.toDouble() ?? totalUsd;
            return ItemGastoModel(
              descripcion: item['descripcion'] ?? 'Artículo',
              cantidad: cant,
              precioUnitario: (precioUnit * 100).round(),
              total: (precioUnit * cant * 100).round(),
              categoria: item['categoria'] ?? categoria,
            );
          }).toList();

          if (itemsGasto.isEmpty) {
            itemsGasto = [
              ItemGastoModel(
                descripcion: spokenText,
                cantidad: 1.0,
                precioUnitario: (totalUsd * 100).round(),
                total: (totalUsd * 100).round(),
                categoria: categoria,
              ),
            ];
          }

          return GeminiExtractionResult(
            comercio: comercio,
            fecha: fecha,
            moneda: 'USD',
            totalOriginal: totalUsd,
            tasaCambioDetectada: null,
            impuestoIva: 0.0,
            items: itemsGasto,
          );
        }
      }
    } catch (e) {
      // Fallback si falla la llamada de red
    }

    // Fallback básico si la IA no devolvió functionCall o hubo un corte
    double montoFallback = 0.0;
    final regexMonto = RegExp(r'(\d+([.,]\d+)?)');
    final match = regexMonto.firstMatch(spokenText);
    if (match != null) {
      // Misma semántica que antes (isPrice: false): el regex solo captura
      // dígitos con un separador opcional, sin miles.
      montoFallback = tryParseAmount(match.group(1)!, isPrice: false) ?? 0.0;
    }

    if (montoFallback <= 0.0) {
      throw Exception('No se detectó el monto en el dictado. Por favor incluye el precio de la compra.');
    }

    return GeminiExtractionResult(
      comercio: 'Gasto por voz',
      fecha: DateTime.now().toIso8601String().substring(0, 10),
      moneda: 'USD',
      totalOriginal: montoFallback,
      tasaCambioDetectada: null,
      impuestoIva: 0.0,
      items: [
        ItemGastoModel(
          descripcion: spokenText,
          cantidad: 1.0,
          precioUnitario: (montoFallback * 100).round(),
          total: (montoFallback * 100).round(),
          categoria: 'Alimentación',
        ),
      ],
    );
  }
}
