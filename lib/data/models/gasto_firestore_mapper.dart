import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import 'gasto_model.dart';
import 'item_gasto_model.dart';

/// Mapper estático puro para transformar entre [GastoModel] y los documentos de Firestore.
/// - Excluye campos locales de SQLite: id, synced, firestore_id, ruta_foto_local.
/// - Limpia los items: elimina id y gasto_id para evitar colisiones en la base local.
/// - Normaliza categorías canónicas usando [AppConstants.normalizarCategoria].
/// - Omite 'eliminado_en' cuando sea null para no sobreescribir soft-deletes remotos.
/// - Garantiza 'actualizado_en' (nunca null, usando actualizadoEn ?? creadoEn).
class GastoFirestoreMapper {
  /// Convierte un [GastoModel] al mapa canónico para guardar en Firestore.
  static Map<String, dynamic> toPayload(GastoModel gasto) {
    final payload = <String, dynamic>{
      'uuid': gasto.uuid,
      'fecha': gasto.fecha,
      'comercio': gasto.comercio,
      'moneda': gasto.moneda,
      'total_original': gasto.totalOriginal,
      'total_usd': gasto.totalUsd,
      'total_usdt': gasto.totalUsdt,
      'total_eur': gasto.totalEur,
      'tasa_cambio': gasto.tasaCambio,
      'tasa_usdt': gasto.tasaUsdt,
      'tasa_eur': gasto.tasaEur,
      'fuente_tasa_cambio': gasto.fuenteTasaCambio,
      'fecha_tasa_cambio': gasto.fechaTasaCambio,
      'categoria': AppConstants.normalizarCategoria(gasto.categoria),
      'creado_en': gasto.creadoEn,
      'actualizado_en': gasto.actualizadoEn ?? gasto.creadoEn,
      'ocr_text': gasto.ocrText,
      'items': gasto.items.map((item) {
        return <String, dynamic>{
          'descripcion': item.descripcion,
          'cantidad': item.cantidad,
          'precio_unitario': item.precioUnitario,
          'total': item.total,
          'categoria': AppConstants.normalizarCategoria(item.categoria),
        };
      }).toList(),
    };

    if (gasto.eliminadoEn != null) {
      payload['eliminado_en'] = gasto.eliminadoEn;
    }

    return payload;
  }

  /// Reconstruye un [GastoModel] a partir de los datos de Firestore.
  /// Los ítems quedan con id y gastoId en null para que SQLite asigne los autoincrementales.
  static GastoModel fromPayload(Map<String, dynamic> data, String docId) {
    final itemsRaw = data['items'] as List<dynamic>? ?? [];
    final items = itemsRaw.map((m) {
      final map = Map<String, dynamic>.from(m as Map);
      return ItemGastoModel(
        id: null,
        gastoId: null,
        descripcion: map['descripcion'] as String? ?? '',
        cantidad: (map['cantidad'] as num?)?.toDouble() ?? 1.0,
        precioUnitario: (map['precio_unitario'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt() ?? 0,
        categoria: AppConstants.normalizarCategoria(map['categoria'] as String?),
      );
    }).toList();

    return GastoModel.fromMap(data, items: items).copyWith(
      id: null,
      uuid: docId,
      firestoreId: docId,
      synced: 1,
      categoria: AppConstants.normalizarCategoria(data['categoria'] as String?),
    );
  }
}
