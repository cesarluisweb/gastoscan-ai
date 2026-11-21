import '../../core/constants/app_constants.dart';

enum OrigenCategoria { predeterminada, ia, automatica, manual }

class ItemGastoModel {
  static int _clientKeySeq = 0;

  final int? id;
  final int? gastoId;
  final String descripcion;
  final double cantidad;
  final int precioUnitario;
  final int total;
  final String categoria;
  final OrigenCategoria origenCategoria;
  final String clientKey;

  /// Base imponible unitaria original en centavos (sin IVA), conservada solo en
  /// memoria y en el JSON temporal de `scan_queue` mientras el usuario revisa una
  /// factura con IVA imputado (`IvaModo.imputado`). Nunca se persiste en SQLite `items_gasto`.
  final int? baseImponibleOriginal;

  /// Porcentaje entero de alícuota aplicada al imputar IVA (`16`, `8` o `0`).
  /// Solo en memoria y en `scan_queue`; nunca se persiste en SQLite `items_gasto`.
  final int tasaIvaPct;

  ItemGastoModel({
    this.id,
    this.gastoId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.total,
    this.categoria = 'Otros',
    this.origenCategoria = OrigenCategoria.predeterminada,
    String? clientKey,
    this.baseImponibleOriginal,
    this.tasaIvaPct = 0,
  }) : clientKey = clientKey ?? 'it_${++_clientKeySeq}';

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
      origenCategoria: OrigenCategoria.manual,
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
    OrigenCategoria? origenCategoria,
    String? clientKey,
    int? baseImponibleOriginal,
    bool clearBaseImponibleOriginal = false,
    int? tasaIvaPct,
  }) {
    return ItemGastoModel(
      id: id ?? this.id,
      gastoId: gastoId ?? this.gastoId,
      descripcion: descripcion ?? this.descripcion,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      total: total ?? this.total,
      categoria: categoria ?? this.categoria,
      origenCategoria: origenCategoria ?? this.origenCategoria,
      clientKey: clientKey ?? this.clientKey,
      baseImponibleOriginal: clearBaseImponibleOriginal
          ? null
          : (baseImponibleOriginal ?? this.baseImponibleOriginal),
      tasaIvaPct: clearBaseImponibleOriginal
          ? 0
          : (tasaIvaPct ?? this.tasaIvaPct),
    );
  }

  double get precioUnitarioDisplay => precioUnitario / 100.0;
  double get totalDisplay => total / 100.0;
  double? get baseImponibleOriginalDisplay =>
      baseImponibleOriginal != null ? baseImponibleOriginal! / 100.0 : null;

  /// Elimina los sufijos fiscales `(G)`, `(E)`, `(R)` al final de la descripción
  /// cuando el precio ya se presenta limpio como precio de anaquel con IVA imputado.
  static String stripFiscalSuffix(String descripcion) {
    return descripcion
        .replaceAll(RegExp(r'\s*\([GERger]\)\s*$'), '')
        .trim();
  }

  /// Determina si una descripción conservó el marcador fiscal `(G)` de producto gravado
  /// (usado en registros históricos o fallback `renglonSeparado`).
  static bool hasGravadoSuffix(String descripcion) {
    return RegExp(r'\(G\)\s*$', caseSensitive: false).hasMatch(descripcion.trim());
  }

  /// Determina si una descripción conservó el marcador fiscal `(R)` de alícuota reducida (8%).
  static bool hasReducidoSuffix(String descripcion) {
    return RegExp(r'\(R\)\s*$', caseSensitive: false).hasMatch(descripcion.trim());
  }

  /// Determina si la descripción de un ítem corresponde estrictamente a un renglón
  /// fiscal de impuesto (IVA / IGTF), evitando falsos positivos como "Aceite de oliva"
  /// o "Leche Nativa".
  static bool isTaxDescription(String descripcion) {
    return isIvaOnlyDescription(descripcion) || isIgtfDescription(descripcion);
  }

  /// Determina si la descripción corresponde únicamente a un renglón de IVA
  /// (excluyendo IGTF u otros tributos distintos al IVA, y sin atrapar productos
  /// compuestos como "Combo con IVA 16%" o palabras como "Aceite de oliva").
  static bool isIvaOnlyDescription(String descripcion) {
    final lower = descripcion.trim().toLowerCase();
    if (lower.isEmpty) return false;
    final clean = lower.replaceAll(RegExp(r'\s+'), ' ');
    if (clean.contains('igtf')) return false;
    if (clean == 'impuesto iva' ||
        clean == 'iva' ||
        clean == 'i.v.a' ||
        clean == 'i.v.a.' ||
        clean == 'impuesto' ||
        clean == 'impuestos') {
      return true;
    }
    return RegExp(
      r'^(?:(?:total|monto|impuestos?(?:\s+(?:al|de|del))?)\s+)?\(?i\.?v\.?a\.?\)?(?:[\s:/\-(\d%]|$)',
      caseSensitive: false,
    ).hasMatch(clean) ||
        RegExp(
          r'^(?:total\s+)?impuesto\s+al\s+valor\s+agregado(?:\s|[:(\d%]|$)',
          caseSensitive: false,
        ).hasMatch(clean);
  }

  /// Determina si la descripción corresponde a un renglón de IGTF (3%).
  static bool isIgtfDescription(String descripcion) {
    final lower = descripcion.trim().toLowerCase();
    if (lower.isEmpty) return false;
    return RegExp(r'\bigtf\b', caseSensitive: false).hasMatch(lower);
  }

  /// Determina si la descripción corresponde a un subtotal o línea resumen
  /// que el LLM haya colado erróneamente como ítem (ej. "SUBTOTAL", "BASE IMPONIBLE").
  static bool isSummaryLineDescription(String descripcion) {
    final clean = descripcion.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return false;
    return RegExp(
      r'^(?:sub\s*-?\s*total|base\s+imponible|bi\s+[gr]|total\s+exento|exento|monto\s+exento|total\s+general|total\s+a\s+pagar|total\s+factura)(?:\s|:|$)',
      caseSensitive: false,
    ).hasMatch(clean);
  }

  /// Determina si la descripción corresponde explícitamente a una línea de descuento,
  /// rebaja o bonificación (sin atrapar productos reales como "Pack Ahorro Pañales"
  /// o "Combo Promo 2x1").
  static bool isDiscountDescription(String descripcion) {
    final clean = descripcion.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return false;
    return RegExp(
      r'^(?:descuento|desct?o?\.?|dto\.?|bonificaci[oó]n|bonif\.?|rebaja|cup[oó]n(?:\s+de\s+descuento)?)(?:[\s:\-/%(\d]|$)',
      caseSensitive: false,
    ).hasMatch(clean);
  }

  /// Determina si la descripción corresponde a servicio de restaurante o propina
  /// (sin atrapar conceptos como "Servicio técnico", "Servicio de internet",
  /// "Cubierto de plástico" o "Tip Top Galletas").
  static bool isServiceOrTipDescription(String descripcion) {
    final clean = descripcion.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return false;
    return RegExp(
      r'^(?:servicio(?:\s*[:\-]?\s*\(?\d{1,2}\s*%\)?|\s+de\s+mesa)?|\d{1,2}\s*%\s*servicio|cargo\s+por\s+servicio(?:\s*[:\-]?\s*\(?\d{1,2}\s*%\)?)?|propina(?:\s*[:\-]?\s*\(?\d{1,2}\s*%\)?|\s+sugerida)?|tip(?:\s*[:\-]?\s*\(?\d{1,2}\s*%\)?)?|cubiertos?(?:\s*[:\-]?\s*\d+|\s+de\s+mesa)?)$',
      caseSensitive: false,
    ).hasMatch(clean);
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
