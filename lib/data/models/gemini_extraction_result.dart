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

  static double _parseAmount(dynamic value, {bool isPrice = true}) {
    if (value == null) return 0.0;
    
    String s = value.toString().trim();
    if (s.isEmpty) return 0.0;
    
    // Si la cadena ya contiene un punto o coma (ej. "12.50", "12,50", "1.250"),
    // asumimos que los decimales o separadores de miles ya están explícitos.
    if (s.contains('.') || s.contains(',')) {
      s = s.replaceAll(RegExp(r'[^\d.,]'), '');
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
    } else {
      // No tiene punto ni coma (ej. "1250" o "1").
      s = s.replaceAll(RegExp(r'[^\d]'), '');
      if (s.isEmpty) return 0.0;
      
      if (isPrice) {
        // Regla: añadir el punto decimal siempre después del segundo número de derecha a izquierda.
        if (s.length <= 2) {
          s = s.padLeft(3, '0'); // "5" -> "005" -> "0.05"
        }
        final length = s.length;
        final integerPart = s.substring(0, length - 2);
        final decimalPart = s.substring(length - 2);
        
        final parsedStr = '$integerPart.$decimalPart';
        return double.tryParse(parsedStr) ?? 0.0;
      } else {
        // Es una cantidad u otro valor que no requiere forzar 2 decimales
        return double.tryParse(s) ?? 0.0;
      }
    }
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
    final totalOriginal = _parseAmount(json['total_original']);
    final impuestoIva = _parseAmount(json['impuesto_iva']);

    // Ítems de la factura
    final itemsList = <ItemGastoModel>[];
    const validCategorias = ['Alimentación', 'Salud', 'Educación', 'Hogar', 'Servicios', 'Transporte', 'Otros'];
    
    if (json['items'] is List) {
      for (final rawItem in (json['items'] as List)) {
        if (rawItem is Map) {
          final itemMap = Map<String, dynamic>.from(rawItem);
          final desc = itemMap['descripcion']?.toString() ?? 'Producto/Servicio';
          
          double cant = _parseAmount(itemMap['cantidad'], isPrice: false);
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
      ));
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
