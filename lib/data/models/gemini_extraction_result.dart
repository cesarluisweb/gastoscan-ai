import 'item_gasto_model.dart';

class GeminiExtractionResult {
  final String comercio;
  final String fecha;
  final String moneda;
  final double totalOriginal;
  final double impuestoIva;
  final double? tasaCambioDetectada;
  final List<ItemGastoModel> items;
  final List<int> matchedShoppingItemIds;

  GeminiExtractionResult({
    required this.comercio,
    required this.fecha,
    required this.moneda,
    required this.totalOriginal,
    required this.impuestoIva,
    this.tasaCambioDetectada,
    required this.items,
    this.matchedShoppingItemIds = const [],
  });

  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      String s = value.replaceAll(RegExp(r'[^\d.,]'), '').trim();
      if (s.contains(',') && s.contains('.')) {
        if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
          s = s.replaceAll('.', '').replaceAll(',', '.');
        } else {
          s = s.replaceAll(',', '');
        }
      } else {
        s = s.replaceAll(',', '.');
      }
      return double.tryParse(s) ?? 0.0;
    }
    return 0.0;
  }

  static List<GeminiExtractionResult> listFromJson(Map<String, dynamic> json) {
    if (json.containsKey('facturas') && json['facturas'] is List) {
      final list = json['facturas'] as List;
      if (list.isNotEmpty) {
        return list
            .whereType<Map>()
            .map((item) => GeminiExtractionResult.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    }
    return [GeminiExtractionResult.fromJson(json)];
  }

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
    double totalOriginal = _parseAmount(json['total_original']);
    final impuestoIva = _parseAmount(json['impuesto_iva']);

    // Ítems de la factura
    final itemsList = <ItemGastoModel>[];
    const validCategorias = ['Alimentación', 'Salud', 'Educación', 'Hogar', 'Servicios', 'Transporte', 'Otros'];
    
    if (json['items'] is List) {
      for (final rawItem in (json['items'] as List)) {
        if (rawItem is Map) {
          final itemMap = Map<String, dynamic>.from(rawItem);
          final desc = itemMap['descripcion']?.toString() ?? 'Producto/Servicio';
          
          double cant = _parseAmount(itemMap['cantidad']);
          if (cant == 0.0) cant = 1.0;
          
          final precio = _parseAmount(itemMap['precio_unitario']);
          double total = _parseAmount(itemMap['total']);
          if (total == 0.0) total = cant * precio;
          final catItemRaw = itemMap['categoria']?.toString() ?? 'Otros';
          final catItem = validCategorias.contains(catItemRaw) ? catItemRaw : 'Otros';

          itemsList.add(ItemGastoModel(
            descripcion: desc,
            cantidad: cant,
            precioUnitario: (precio * 100).round(),
            total: (total * 100).round(),
            categoria: catItem,
          ));
        }
      }
    }

    // Si no detectó items pero hay monto total, agrega al menos una línea
    if (itemsList.isEmpty && totalOriginal > 0) {
      itemsList.add(ItemGastoModel(
        descripcion: 'Consumo general / Pago',
        cantidad: 1.0,
        precioUnitario: (totalOriginal * 100).round(),
        total: (totalOriginal * 100).round(),
        categoria: 'Otros',
      ));
    }

    // --- VERIFICACIÓN MATEMÁTICA Y CORRECCIÓN DE DECIMALES ---
    if (itemsList.isNotEmpty && totalOriginal > 0) {
      double sumItems = 0;
      for (final item in itemsList) {
        sumItems += item.totalDisplay;
      }
      
      // Margen de error tolerado (por redondeos o discrepancias menores)
      if ((sumItems - totalOriginal).abs() > 2.0) {
        // Caso 1: La IA extrajo los ítems omitiendo el decimal (sumItems es ~100x mayor al total)
        final ratioItemsToTotal = sumItems / totalOriginal;
        if (ratioItemsToTotal >= 95.0 && ratioItemsToTotal <= 105.0) {
          for (int i = 0; i < itemsList.length; i++) {
            final old = itemsList[i];
            itemsList[i] = ItemGastoModel(
              descripcion: old.descripcion,
              cantidad: old.cantidad,
              precioUnitario: (old.precioUnitario / 100).round(),
              total: (old.total / 100).round(),
              categoria: old.categoria,
            );
          }
        } 
        // Caso 2: La IA extrajo el total_original omitiendo el decimal (~100x mayor a los ítems)
        else {
          final ratioTotalToItems = totalOriginal / sumItems;
          if (ratioTotalToItems >= 95.0 && ratioTotalToItems <= 105.0) {
            totalOriginal = totalOriginal / 100;
          }
        }
      }
    }

    // Tasa de cambio detectada (si está impresa en la factura)
    final rawTasa = _parseAmount(json['tasa_cambio']);
    final tasaDetectada = rawTasa > 0 ? rawTasa : null;

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
      'tasa_cambio': tasaCambioDetectada,
      'items': items.map((i) => i.toMap()).toList(),
      'items_comprados_ids': matchedShoppingItemIds,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}
