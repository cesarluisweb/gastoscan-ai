import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../models/gemini_extraction_result.dart';

class GeminiService {
  static const List<String> _preferredModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-2.5-flash-lite',
    'gemini-1.5-flash',
    'gemini-1.5-flash-latest',
  ];

  static String? _cachedDiscoveredModel;

  static const String _systemPrompt = '''
Analiza la imagen de este recibo o factura comercial. Extrae con precisión quirúrgica todos los datos legibles. 
Devuelve EXCLUSIVAMENTE un objeto JSON válido con la siguiente estructura, sin texto adicional ni bloques markdown:
{
  "comercio": "Nombre del establecimiento o persona receptora",
  "fecha": "YYYY-MM-DD",
  "moneda": "VES" | "USD" | "EUR",
  "total_original": 0.00,
  "tasa_cambio": 0.00,
  "impuesto_iva": 0.00,
  "categoria_sugerida": "Alimentación" | "Salud" | "Educación" | "Hogar" | "Servicios" | "Transporte" | "Otros",
  "items": [
    {
      "descripcion": "Nombre del producto o servicio",
      "cantidad": 1.0,
      "precio_unitario": 0.00,
      "total": 0.00
    }
  ]
}
Si un dato no es legible o no aplica (ej. tasa de cambio no impresa), coloca null. Si es un comprobante de Pago Móvil o transferencia bancaria, coloca en "comercio" el beneficiario y en "items" una sola línea con el concepto.
''';

  /// Resuelve dinámicamente el modelo Flash compatible para la API Key
  Future<String> _resolveBestModel(String apiKey) async {
    if (_cachedDiscoveredModel != null) {
      return _cachedDiscoveredModel!;
    }

    try {
      final listUrl = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey.trim()}');
      final response = await http.get(listUrl).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final modelsList = data['models'] as List?;
        if (modelsList != null && modelsList.isNotEmpty) {
          final List<String> supportedModels = [];
          for (final m in modelsList) {
            final methods = (m['supportedGenerationMethods'] as List?)?.map((e) => e.toString()).toList() ?? [];
            if (methods.contains('generateContent')) {
              final rawName = m['name']?.toString() ?? '';
              final cleanName = rawName.replaceFirst('models/', '');
              supportedModels.add(cleanName);
            }
          }

          // 1. Buscar coincidencia con la lista de modelos preferidos
          for (final candidate in _preferredModels) {
            if (supportedModels.contains(candidate)) {
              _cachedDiscoveredModel = candidate;
              return candidate;
            }
          }

          // 2. Buscar cualquier modelo que contenga "flash"
          final anyFlash = supportedModels.firstWhere(
            (m) => m.toLowerCase().contains('flash'),
            orElse: () => '',
          );
          if (anyFlash.isNotEmpty) {
            _cachedDiscoveredModel = anyFlash;
            return anyFlash;
          }

          // 3. Buscar cualquier modelo que contenga "gemini"
          final anyGemini = supportedModels.firstWhere(
            (m) => m.toLowerCase().contains('gemini'),
            orElse: () => '',
          );
          if (anyGemini.isNotEmpty) {
            _cachedDiscoveredModel = anyGemini;
            return anyGemini;
          }
        }
      }
    } catch (_) {
      // Si la consulta de modelos falla por red o permisos, se usa el orden preferido
    }

    return _preferredModels.first;
  }

  /// Procesa los bytes de la imagen del recibo utilizando el modelo Gemini disponible
  Future<GeminiExtractionResult> analyzeReceiptImage({
    required Uint8List imageBytes,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Debes configurar tu API Key de Google AI Studio en Ajustes.');
    }

    final key = apiKey.trim();
    final base64Image = base64Encode(imageBytes);

    final payload = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Image,
              }
            },
            {
              "text": _systemPrompt,
            }
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.1,
        "responseMimeType": "application/json",
      }
    };

    final resolvedModel = await _resolveBestModel(key);
    final modelsToTry = <String>[
      resolvedModel,
      ..._preferredModels.where((m) => m != resolvedModel),
    ];

    String? lastErrorBody;
    int lastStatusCode = 0;

    for (final candidateModel in modelsToTry) {
      for (final apiVersion in ['v1beta', 'v1']) {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/$apiVersion/models/$candidateModel:generateContent?key=$key',
        );

        try {
          final response = await http
              .post(
                url,
                headers: {"Content-Type": "application/json"},
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 45));

          if (response.statusCode == 200) {
            _cachedDiscoveredModel = candidateModel;
            return _parseGeminiResponse(response.body);
          }

          if (response.statusCode == 404) {
            lastStatusCode = 404;
            lastErrorBody = response.body;
            continue;
          }

          _handleHttpError(response.statusCode, response.body);
        } catch (e) {
          if (e is Exception && !e.toString().contains('404')) {
            rethrow;
          }
        }
      }
    }

    if (lastStatusCode != 0 && lastErrorBody != null) {
      _handleHttpError(lastStatusCode, lastErrorBody);
    }

    throw Exception('No se pudo conectar con ningún modelo de Gemini disponible.');
  }

  GeminiExtractionResult _parseGeminiResponse(String responseBody) {
    try {
      final decodedResponse = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = decodedResponse['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('El modelo no generó ninguna respuesta para esta imagen.');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw Exception('Respuesta vacía recibida desde la API de Gemini.');
      }

      String rawText = parts[0]['text'] as String? ?? '';

      // Sanitiza bloques markdown si estuviesen presentes
      rawText = rawText.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
      rawText = rawText.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
      rawText = rawText.trim();

      // Extrae únicamente el bloque JSON {...}
      final firstBrace = rawText.indexOf('{');
      final lastBrace = rawText.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        rawText = rawText.substring(firstBrace, lastBrace + 1);
      }

      final jsonResult = jsonDecode(rawText) as Map<String, dynamic>;
      return GeminiExtractionResult.fromJson(jsonResult);
    } catch (e) {
      if (e is FormatException) {
        throw Exception('No se pudo convertir la respuesta del modelo en JSON válido.');
      }
      rethrow;
    }
  }

  void _handleHttpError(int statusCode, String responseBody) {
    if (statusCode == 400) {
      throw Exception('Petición incorrecta: la imagen enviada no es válida o está dañada.');
    } else if (statusCode == 401 || statusCode == 403) {
      throw Exception('API Key inválida o sin permisos. Verifica tu clave en Ajustes.');
    } else if (statusCode == 404) {
      throw Exception('Modelo de Gemini no disponible para tu clave de API. Verifica tu clave en Ajustes.');
    } else if (statusCode == 429) {
      throw Exception('Límite de cuota excedido en Google AI Studio. Espera unos segundos y reintenta.');
    } else if (statusCode >= 500) {
      throw Exception('Los servidores de Google AI están experimentando problemas. Intenta más tarde.');
    } else {
      throw Exception('Error en API ($statusCode): $responseBody');
    }
  }
}
