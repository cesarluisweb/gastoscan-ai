import '../../core/constants/app_constants.dart';

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
      categoria: AppConstants.normalizarCategoria(map['categoria'] as String?),
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

  /// Determina si la descripción de un ítem corresponde a un renglón fiscal de impuesto (IVA / IGTF).
  static bool isTaxDescription(String descripcion) {
    final lower = descripcion.trim().toLowerCase();
    return lower == 'impuesto iva' ||
        lower == 'iva' ||
        lower.startsWith('iva ') ||
        lower.startsWith('iva(') ||
        lower.contains('impuesto iva') ||
        lower.contains('iva 16%') ||
        lower == 'igtf' ||
        lower.startsWith('igtf ');
  }

  /// Calcula la categoría dominante de una factura sumando `precio * cantidad` (`total`)
  /// de los ítems no impositivos agrupados por categoría canónica, eligiendo la de mayor
  /// monto acumulado y usando `'Otros'` solo como fallback si no hay ítems previos.
  static String calcularCategoriaDominante(List<ItemGastoModel> items) {
    if (items.isEmpty) return 'Otros';

    final Map<String, int> catTotals = {};
    String? firstNonTaxCat;

    for (final item in items) {
      if (isTaxDescription(item.descripcion)) continue;
      final cat = AppConstants.normalizarCategoria(item.categoria);
      firstNonTaxCat ??= cat;
      final int itemMonto = item.total > 0
          ? item.total
          : (item.precioUnitario * item.cantidad).round();
      catTotals[cat] = (catTotals[cat] ?? 0) + itemMonto;
    }

    if (catTotals.isEmpty) {
      return 'Otros';
    }

    String dominant = firstNonTaxCat ?? 'Otros';
    int maxMonto = -1;
    for (final entry in catTotals.entries) {
      if (entry.value > maxMonto) {
        maxMonto = entry.value;
        dominant = entry.key;
      }
    }

    return maxMonto > 0 ? dominant : (firstNonTaxCat ?? 'Otros');
  }
}
