import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/gemini_extraction_result.dart';
import '../../models/item_gasto_model.dart';
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
      final callable = FirebaseFunctions.instance.httpsCallable(
        'analyzeReceipt',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 3)),
      );
      
      final shoppingListContext = pendingShoppingItems != null && pendingShoppingItems.isNotEmpty
          ? pendingShoppingItems.map((e) => {'id': e.id, 'name': e.name}).toList()
          : [];

      final response = await callable.call({
        'imageBase64': base64Image,
        'shoppingList': shoppingListContext,
      });

      final data = response.data;
      if (data == null) {
        throw Exception('Respuesta vacía del servidor.');
      }

      final jsonResult = Map<String, dynamic>.from(data as Map);
      return GeminiExtractionResult.fromJson(jsonResult);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        throw Exception('No estás autenticado en Firebase.');
      } else if (e.code == 'deadline-exceeded') {
        throw Exception('Tiempo de espera agotado. El servidor tardó demasiado en procesar.');
      } else if (e.code == 'resource-exhausted') {
        throw Exception('Límite de solicitudes alcanzado. Espera unos segundos e intenta nuevamente.');
      } else if (e.code == 'unavailable') {
        throw Exception('Servicio no disponible temporalmente. Intenta nuevamente.');
      } else {
        final message = (e.message != null && e.message!.isNotEmpty)
            ? e.message!
            : 'Error al procesar la factura en el servidor. Intenta nuevamente.';
        throw Exception(message);
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
      if (e.code == 'unauthenticated') {
        throw Exception('No estás autenticado en Firebase.');
      } else if (e.code == 'deadline-exceeded') {
        throw Exception('Tiempo de espera agotado al conectar con el chat.');
      } else if (e.code == 'resource-exhausted') {
        throw Exception('Límite de solicitudes alcanzado. Espera unos segundos e intenta nuevamente.');
      } else if (e.code == 'unavailable') {
        throw Exception('Servicio no disponible temporalmente. Intenta nuevamente.');
      } else {
        final message = (e.message != null && e.message!.isNotEmpty)
            ? e.message!
            : 'Error al comunicarse con el asistente.';
        throw Exception(message);
      }
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
