import 'item_gasto_model.dart';

class GastoModel {
  final int? id;
  final String fecha;
  final String comercio;
  final String moneda;
  final double totalOriginal;
  final double totalUsd;
  final String categoria;
  final String? rutaFotoLocal;
  final String creadoEn;
  final List<ItemGastoModel> items;
  final String? firestoreId;
  final int synced;

  GastoModel({
    this.id,
    required this.fecha,
    required this.comercio,
    required this.moneda,
    required this.totalOriginal,
    required this.totalUsd,
    required this.categoria,
    this.rutaFotoLocal,
    required this.creadoEn,
    this.items = const [],
    this.firestoreId,
    this.synced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha,
      'comercio': comercio,
      'moneda': moneda,
      'total_original': totalOriginal,
      'total_usd': totalUsd,
      'categoria': categoria,
      'ruta_foto_local': rutaFotoLocal,
      'creado_en': creadoEn,
      'firestore_id': firestoreId,
      'synced': synced,
    };
  }

  factory GastoModel.fromMap(Map<String, dynamic> map, {List<ItemGastoModel> items = const []}) {
    return GastoModel(
      id: map['id'] as int?,
      fecha: map['fecha'] as String? ?? '',
      comercio: map['comercio'] as String? ?? 'Comercio Desconocido',
      moneda: map['moneda'] as String? ?? 'USD',
      totalOriginal: (map['total_original'] as num?)?.toDouble() ?? 0.0,
      totalUsd: (map['total_usd'] as num?)?.toDouble() ?? 0.0,
      categoria: map['categoria'] as String? ?? 'Otros',
      rutaFotoLocal: map['ruta_foto_local'] as String?,
      creadoEn: map['creado_en'] as String? ?? DateTime.now().toIso8601String(),
      items: items,
      firestoreId: map['firestore_id'] as String?,
      synced: map['synced'] as int? ?? 0,
    );
  }

  GastoModel copyWith({
    int? id,
    String? fecha,
    String? comercio,
    String? moneda,
    double? totalOriginal,
    double? totalUsd,
    String? categoria,
    String? rutaFotoLocal,
    String? creadoEn,
    List<ItemGastoModel>? items,
    String? firestoreId,
    int? synced,
  }) {
    return GastoModel(
      id: id ?? this.id,
      fecha: fecha ?? this.fecha,
      comercio: comercio ?? this.comercio,
      moneda: moneda ?? this.moneda,
      totalOriginal: totalOriginal ?? this.totalOriginal,
      totalUsd: totalUsd ?? this.totalUsd,
      categoria: categoria ?? this.categoria,
      rutaFotoLocal: rutaFotoLocal ?? this.rutaFotoLocal,
      creadoEn: creadoEn ?? this.creadoEn,
      items: items ?? this.items,
      firestoreId: firestoreId ?? this.firestoreId,
      synced: synced ?? this.synced,
    );
  }
}
