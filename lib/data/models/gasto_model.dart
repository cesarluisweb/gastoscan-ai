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
    );
  }
}
