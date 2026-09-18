import 'item_gasto_model.dart';

class GastoModel {
  final int? id;
  final String uuid;
  final String fecha;
  final String comercio;
  final String moneda;
  final int totalOriginal;
  final int totalUsd;
  final double tasaCambio;
  final String? fuenteTasaCambio;
  final String? fechaTasaCambio;
  final String categoria;
  final String? rutaFotoLocal;
  final String creadoEn;
  final String? actualizadoEn;
  final String? eliminadoEn;
  final List<ItemGastoModel> items;
  final String? firestoreId;
  final int synced;

  GastoModel({
    this.id,
    required this.uuid,
    required this.fecha,
    required this.comercio,
    required this.moneda,
    required this.totalOriginal,
    required this.totalUsd,
    this.tasaCambio = 1.0,
    this.fuenteTasaCambio,
    this.fechaTasaCambio,
    required this.categoria,
    this.rutaFotoLocal,
    required this.creadoEn,
    this.actualizadoEn,
    this.eliminadoEn,
    this.items = const [],
    this.firestoreId,
    this.synced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'fecha': fecha,
      'comercio': comercio,
      'moneda': moneda,
      'total_original': totalOriginal,
      'total_usd': totalUsd,
      'tasa_cambio': tasaCambio,
      'fuente_tasa_cambio': fuenteTasaCambio,
      'fecha_tasa_cambio': fechaTasaCambio,
      'categoria': categoria,
      'ruta_foto_local': rutaFotoLocal,
      'creado_en': creadoEn,
      'actualizado_en': actualizadoEn,
      'eliminado_en': eliminadoEn,
      'firestore_id': firestoreId,
      'synced': synced,
    };
  }

  factory GastoModel.fromMap(Map<String, dynamic> map, {List<ItemGastoModel> items = const []}) {
    return GastoModel(
      id: map['id'] as int?,
      uuid: map['uuid'] as String? ?? '',
      fecha: map['fecha'] as String? ?? '',
      comercio: map['comercio'] as String? ?? 'Comercio Desconocido',
      moneda: map['moneda'] as String? ?? 'USD',
      totalOriginal: (map['total_original'] as num?)?.toInt() ?? 0,
      totalUsd: (map['total_usd'] as num?)?.toInt() ?? 0,
      tasaCambio: (map['tasa_cambio'] as num?)?.toDouble() ?? 1.0,
      fuenteTasaCambio: map['fuente_tasa_cambio'] as String?,
      fechaTasaCambio: map['fecha_tasa_cambio'] as String?,
      categoria: map['categoria'] as String? ?? 'Otros',
      rutaFotoLocal: map['ruta_foto_local'] as String?,
      creadoEn: map['creado_en'] as String? ?? DateTime.now().toIso8601String(),
      actualizadoEn: map['actualizado_en'] as String?,
      eliminadoEn: map['eliminado_en'] as String?,
      items: items,
      firestoreId: map['firestore_id'] as String?,
      synced: map['synced'] as int? ?? 0,
    );
  }

  GastoModel copyWith({
    int? id,
    String? uuid,
    String? fecha,
    String? comercio,
    String? moneda,
    int? totalOriginal,
    int? totalUsd,
    double? tasaCambio,
    String? fuenteTasaCambio,
    String? fechaTasaCambio,
    String? categoria,
    String? rutaFotoLocal,
    String? creadoEn,
    String? actualizadoEn,
    String? eliminadoEn,
    List<ItemGastoModel>? items,
    String? firestoreId,
    int? synced,
  }) {
    return GastoModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      fecha: fecha ?? this.fecha,
      comercio: comercio ?? this.comercio,
      moneda: moneda ?? this.moneda,
      totalOriginal: totalOriginal ?? this.totalOriginal,
      totalUsd: totalUsd ?? this.totalUsd,
      tasaCambio: tasaCambio ?? this.tasaCambio,
      fuenteTasaCambio: fuenteTasaCambio ?? this.fuenteTasaCambio,
      fechaTasaCambio: fechaTasaCambio ?? this.fechaTasaCambio,
      categoria: categoria ?? this.categoria,
      rutaFotoLocal: rutaFotoLocal ?? this.rutaFotoLocal,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      eliminadoEn: eliminadoEn ?? this.eliminadoEn,
      items: items ?? this.items,
      firestoreId: firestoreId ?? this.firestoreId,
      synced: synced ?? this.synced,
    );
  }

  double get totalOriginalDisplay => totalOriginal / 100.0;
  double get totalUsdDisplay => totalUsd / 100.0;
}
