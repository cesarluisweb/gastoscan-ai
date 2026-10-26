/// Modelo tipado para normalizar documentos de presupuestos provenientes de Firestore.
class PresupuestoRemotoModel {
  final int anio;
  final int mes;
  final double general;
  final double metaAhorro;
  final String moneda;
  final Map<String, double> categorias;
  final String actualizadoEn;

  const PresupuestoRemotoModel({
    required this.anio,
    required this.mes,
    required this.general,
    required this.metaAhorro,
    required this.moneda,
    required this.categorias,
    required this.actualizadoEn,
  });

  /// Parsea y normaliza un documento de presupuesto de Firestore.
  /// Si el timestamp actualizado_en falta, usa creado_en o la época Unix (nunca DateTime.now()).
  factory PresupuestoRemotoModel.fromFirestore(Map<String, dynamic> data, String docId) {
    int parsedAnio = (data['anio'] as num?)?.toInt() ?? 0;
    int parsedMes = (data['mes'] as num?)?.toInt() ?? 0;

    // Si anio o mes no vienen en el mapa, intentar extraerlos del docId (ej. "2026_10")
    if ((parsedAnio == 0 || parsedMes == 0) && docId.contains('_')) {
      final parts = docId.split('_');
      if (parts.length >= 2) {
        parsedAnio = int.tryParse(parts[0]) ?? parsedAnio;
        parsedMes = int.tryParse(parts[1]) ?? parsedMes;
      }
    }

    final cats = <String, double>{};
    if (data['categorias'] is Map) {
      (data['categorias'] as Map).forEach((k, v) {
        if (v is num && v.toDouble() > 0) {
          cats[k.toString()] = v.toDouble();
        }
      });
    }

    final actEn = data['actualizado_en'] as String? ??
        data['creado_en'] as String? ??
        DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();

    return PresupuestoRemotoModel(
      anio: parsedAnio,
      mes: parsedMes,
      general: (data['presupuesto_general'] as num?)?.toDouble() ?? 0.0,
      metaAhorro: (data['meta_ahorro'] as num?)?.toDouble() ?? 0.0,
      moneda: (data['moneda'] as String?) ?? 'USD',
      categorias: cats,
      actualizadoEn: actEn,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'anio': anio,
      'mes': mes,
      'presupuesto_general': general,
      'meta_ahorro': metaAhorro,
      'moneda': moneda,
      'categorias': categorias,
      'actualizado_en': actualizadoEn,
    };
  }
}
