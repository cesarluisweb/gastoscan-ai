class ItemGastoModel {
  final int? id;
  final int? gastoId;
  final String descripcion;
  final double cantidad;
  final int precioUnitario;
  final int total;
  final String categoria;

  ItemGastoModel({
    this.id,
    this.gastoId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.total,
    this.categoria = 'Otros',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gasto_id': gastoId,
      'descripcion': descripcion,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'total': total,
      'categoria': categoria,
    };
  }

  factory ItemGastoModel.fromMap(Map<String, dynamic> map) {
    return ItemGastoModel(
      id: map['id'] as int?,
      gastoId: map['gasto_id'] as int?,
      descripcion: map['descripcion'] as String? ?? 'Sin descripción',
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 1.0,
      precioUnitario: (map['precio_unitario'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      categoria: map['categoria'] as String? ?? 'Otros',
    );
  }

  ItemGastoModel copyWith({
    int? id,
    int? gastoId,
    String? descripcion,
    double? cantidad,
    int? precioUnitario,
    int? total,
    String? categoria,
  }) {
    return ItemGastoModel(
      id: id ?? this.id,
      gastoId: gastoId ?? this.gastoId,
      descripcion: descripcion ?? this.descripcion,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      total: total ?? this.total,
      categoria: categoria ?? this.categoria,
    );
  }

  double get precioUnitarioDisplay => precioUnitario / 100.0;
  double get totalDisplay => total / 100.0;
}
