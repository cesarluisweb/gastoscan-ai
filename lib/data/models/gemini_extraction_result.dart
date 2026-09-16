import 'item_gasto_model.dart';

class GeminiExtractionResult {
  final String comercio;
  final String fecha;
  final String moneda;
  final double totalOriginal;
  final double impuestoIva;
  final String categoriaSugerida;
  final double? tasaCambioDetectada;
  final List<ItemGastoModel> items;
  final List<int> matchedShoppingItemIds;

  GeminiExtractionResult({
    required this.comercio,
    required this.fecha,
    required this.moneda,
    required this.totalOriginal,
    required this.impuestoIva,
    required this.categoriaSugerida,
    this.tasaCambioDetectada,
    required this.items,
    this.matchedShoppingItemIds = const [],
  });

  factory GeminiExtractionResult.fromJson(Map<String, dynamic> json) {
    // Comercio / Beneficiario
    final comercioRaw = json['comercio'];
    final comercio = (comercioRaw != null && comercioRaw.toString().trim().isNotEmpty)
        ? comercioRaw.toString().trim()
        : 'Comercio Desconocido';

    // Fecha con fallback a hoy si es null o inválida
    final fechaRaw = json['fecha']?.toString();
    String fecha = DateTime.now().toIso8601String().substring(0, 10);
    if (fechaRaw != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fechaRaw)) {
      fecha = fechaRaw;
    }

    // Moneda
    final monedaRaw = json['moneda']?.toString().toUpperCase() ?? 'USD';
    final moneda = ['USD', 'VES', 'EUR'].contains(monedaRaw) ? monedaRaw : 'USD';

    // Montos numéricos
    final totalOriginal = (json['total_original'] as num?)?.toDouble() ?? 0.0;
    final impuestoIva = (json['impuesto_iva'] as num?)?.toDouble() ?? 0.0;

    // Categoría
    final categoriaRaw = json['categoria_sugerida']?.toString() ?? 'Otros';
    const validCategoríaciónsporte', 'Otros'];
    final categoria = validCategoríaw : 'Otros';

    // Ítems de la factura
    final itemsList = <ItemGastoModel>[];
    if (json['items'] is List) {
      for (final rawItem in (json['items'] as List)) {
        if (rawItem is Map) {
          final itemMap = Map<String, dynamic>.from(rawItem);
          final desc = itemMap['descripcion']?.toString() ?? 'Producto/Servicio';
          final cant = (itemMap['cantidad'] as num?)?.toDouble() ?? 1.0;
          final precio = (itemMap['precio_unitario'] as num?)?.toDouble() ?? 0.0;
          final total = (itemMap['total'] as num?)?.toDouble() ?? (cant * precio);

          itemsList.add(ItemGastoModel(
            descripcion: desc,
            cantidad: cant,
            precioUnitario: precio,
            total: total,
          ));
        }
      }
    }

    // Si no detectó items pero hay monto total, agrega al menos una línea
    if (itemsList.isEmpty && totalOriginal > 0) {
      itemsList.add(ItemGastoModel(
        descripcion: 'Consumo general / Pago',
        cantidad: 1.0,
        precioUnitario: totalOriginal,
        total: totalOriginal,
      ));
    }

    // Tasa de cambio detectada (si está impresa en la factura)
    final tasaDetectada = (json['tasa_cambio'] as num?)?.toDouble();

    // IDs de lista de compras vinculados
    final matchedIds = <int>[];
    if (json['items_comprados_ids'] is List) {
      for (final id in (json['items_comprados_ids'] as List)) {
        if (id is num) {
          matchedIds.add(id.toInt());
        }
      }
    }

    return GeminiExtractionResult(
      comercio: comercio,
      fecha: fecha,
      moneda: moneda,
      totalOriginal: totalOriginal,
      impuestoIva: impuestoIva,
      categoriaSugerida: categoria,
      tasaCambioDetectada: tasaDetectada,
      items: itemsList,
      matchedShoppingItemIds: matchedIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'comercio': comercio,
      'fecha': fecha,
      'moneda': moneda,
      'total_original': totalOriginal,
      'impuesto_iva': impuestoIva,
      'categoria_sugerida': categoriaSugerida,
      'tasa_cambio': tasaCambioDetectada,
      'items': items.map((i) => i.toMap()).toList(),
      'items_comprados_ids': matchedShoppingItemIds,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}
