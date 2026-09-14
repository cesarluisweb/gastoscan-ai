import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/gemini_extraction_result.dart';

class GeminiService {
  Future<GeminiExtractionResult> analyzeReceiptImage({
    required Uint8List imageBytes,
    required String apiKey,
  }) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final callable = FirebaseFunctions.instance.httpsCallable('analyzeReceipt');

      final response = await callable.call({
        'imageBase64': base64Image,
      });

      final data = response.data;
      if (data == null) {
        throw Exception('Respuesta vacia del servidor.');
      }

      final jsonResult = Map<String, dynamic>.from(data as Map);
      return GeminiExtractionResult.fromJson(jsonResult);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        throw Exception('No estas autenticado para procesar la imagen.');
      } else {
        throw Exception('Error del servidor (${e.code}): ${e.message}');
      }
    } catch (e) {
      throw Exception('Fallo al conectar con el servidor: $e');
    }
  }
}
