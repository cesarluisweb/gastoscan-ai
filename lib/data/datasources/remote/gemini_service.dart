import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/gemini_extraction_result.dart';
import '../../models/shopping_item_model.dart';

class GeminiService {
  Future<GeminiExtractionResult> analyzeReceiptImage({
    required Uint8List imageBytes,
    required String apiKey,
    List<ShoppingItemModel>? pendingShoppingItems,
  }) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final base64Image = base64Encode(imageBytes);
      final callable = FirebaseFunctions.instance.httpsCallable('analyzeReceipt');
      
      final shoppingListContext = pendingShoppingItems != null && pendingShoppingItems.isNotEmpty
          ? pendingShoppingItems.map((e) => {'id': e.id, 'name': e.name}).toList()
          : [];

      // Client-side retry logic for intermittent network or server issues
      dynamic responseData;
      int retries = 3;
      int delayMs = 2000;
      for (int i = 0; i < retries; i++) {
        try {
          final response = await callable.call({
            'imageBase64': base64Image,
            'shoppingList': shoppingListContext,
          });
          responseData = response.data;
          break; // Success
        } on FirebaseFunctionsException catch (e) {
          if (e.code == 'unauthenticated' || e.code == 'invalid-argument') {
            rethrow; // Do not retry unrecoverable errors
          }
          if (i == retries - 1) rethrow;
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2; // Exponential backoff
        } catch (e) {
          if (i == retries - 1) rethrow;
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2;
        }
      }

      final data = responseData;
      if (data == null) {
        throw Exception('Respuesta vacía del servidor.');
      }

      final jsonResult = Map<String, dynamic>.from(data as Map);
      return GeminiExtractionResult.fromJson(jsonResult);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        throw Exception('No estas autenticado en Firebase. Revisa que el login anónimo esté activo en la consola.');
      } else {
        throw Exception('Error del servidor (${e.code}): ${e.message}');
      }
    } catch (e) {
      throw Exception('Error interno: $e');
    }
  }

  Future<Map<String, dynamic>> chatWithAnalyst({
    required List<Map<String, String>> messages,
    required Map<String, dynamic> contextData,
  }) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final callable = FirebaseFunctions.instance.httpsCallable('chatWithAnalyst');

      final response = await callable.call({
        'messages': messages,
        'contextData': contextData,
      });

      // La Cloud Function ahora puede devolver { text: "..." } o { functionCall: { ... } }
      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error del servidor (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Fallo al conectar con el chat: $e');
    }
  }
}
