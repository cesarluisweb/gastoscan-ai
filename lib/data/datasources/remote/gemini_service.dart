import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../models/gemini_extraction_result.dart';

class GeminiService {
  static const String _model = 'gemini-1.5-flash';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

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

  /// Procesa los bytes de la imagen del recibo utilizando Gemini 1.5 Flash
  Future<GeminiExtractionResult> analyzeReceiptImage({
    required Uint8List imageBytes,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Debes configurar tu API Key de Google AI Studio en Ajustes.');
    }

    final url = Uri.parse('$_baseUrl/$_model:generateContent?key=${apiKey.trim()}');
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

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return _parseGeminiResponse(response.body);
    } else {
      _handleHttpError(response.statusCode, response.body);
      throw Exception('Error desconocido al contactar con la API de Gemini.');
    }
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

      // Sanitiza bloques markdown de código si estuviesen presentes
      rawText = rawText.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
      rawText = rawText.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
      rawText = rawText.trim();

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
    } else if (statusCode == 429) {
      throw Exception('Límite de cuota excedido en Google AI Studio. Espera unos segundos y reintenta.');
    } else if (statusCode >= 500) {
      throw Exception('Los servidores de Google AI están experimentando problemas. Intenta más tarde.');
    } else {
      throw Exception('Error en API ($statusCode): $responseBody');
    }
  }
}
