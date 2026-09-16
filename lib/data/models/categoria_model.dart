class CategoriaModel {
  final int? id;
  final String nombre;
  final double presupuestoMensual;

  CategoriaModel({
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

  factory CategoriaModel.fromMap(Map<String, dynamic> map) {
    return CategoriaModel(
      id: map['id'] as int?,
      nombre: (map['nombre'] ?? map['name'] ?? map['categoria'] ?? '') as String,
      presupuestoMensual: (map['presupuesto_mensual'] ??
              map['presupuesto'] ??
              map['budget'] ??
              0.0 as num)
          .toDouble(),
    );
  }

  CategoriaModel copyWith({
    int? id,
    String? nombre,
    double? presupuestoMensual,
  }) {
    return CategoriaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      presupuestoMensual: presupuestoMensual ?? this.presupuestoMensual,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoriaModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre &&
          presupuestoMensual == other.presupuestoMensual;

  @override
  int get hashCode =>
      id.hashCode ^ nombre.hashCode ^ presupuestoMensual.hashCode;

  @override
  String toString() =>
      'CategoriaModel(id: $id, nombre: $nombre, presupuestoMensual: $presupuestoMensual)';
}

/// Convenience alias
typedef CategoryModel = CategoriaModel;
