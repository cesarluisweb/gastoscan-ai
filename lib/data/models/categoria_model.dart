class CategoríaModel {
  final int? id;
  final String nombre;
  final double presupuestoMensual;

  CategoríaModel({
    this.id,
    required this.nombre,
    this.presupuestoMensual = 0.0,
  });

  /// Alias getters for flexibility
  String get name => nombre;
  double get presupuesto => presupuestoMensual;
  double get budget => presupuestoMensual;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'presupuesto_mensual': presupuestoMensual,
    };
  }

  factory Categoríap) {
    return CategoríaModel(
      id: map['id'] as int?,
      nombre: (map['nombre'] ?? map['name'] ?? map['categoria'] ?? '') as String,
      presupuestoMensual: (map['presupuesto_mensual'] ??
              map['presupuesto'] ??
              map['budget'] ??
              0.0 as num)
          .toDouble(),
    );
  }

  CategoríaModel copyWith({
    int? id,
    String? nombre,
    double? presupuestoMensual,
  }) {
    return CategoríaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      presupuestoMensual: presupuestoMensual ?? this.presupuestoMensual,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoríaModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre &&
          presupuestoMensual == other.presupuestoMensual;

  @override
  int get hashCode =>
      id.hashCode ^ nombre.hashCode ^ presupuestoMensual.hashCode;

  @override
  String toString() =>
      'Categoríal)';
}

/// Convenience alias
typedef CategoríaModel;
