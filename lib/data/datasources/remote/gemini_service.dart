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
              precioUnitario: precioUnit,
              total: precioUnit * cant,
              categoria: item['categoria'] ?? categoria,
            );
          }).toList();

          if (itemsGasto.isEmpty) {
            itemsGasto = [
              ItemGastoModel(
                descripcion: spokenText,
                cantidad: 1.0,
                precioUnitario: totalUsd,
                total: totalUsd,
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
      montoFallback = double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0.0;
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
          precioUnitario: montoFallback,
          total: montoFallback,
          categoria: 'Alimentación',
        ),
      ],
    );
  }
}
