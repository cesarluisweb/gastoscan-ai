import '../../core/utils/amount_parser.dart';
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
  final String? metodoLiquidacion;

  GeminiExtractionResult({
    required this.comercio,
    required this.fecha,
    required this.moneda,
    required this.totalOriginal,
    required this.impuestoIva,
    this.tasaCambioDetectada,
    required this.items,
    this.matchedShoppingItemIds = const [],
    this.metodoLiquidacion,
  });

    static double _parseAmount(dynamic value, {bool isPrice = false}) {
      // Lógica centralizada en amount_parser.dart; aquí se conserva la firma
      // y la semántica de fallback (0.0 ante dato ausente/inválido de la IA).
      return tryParseAmount(value, isPrice: isPrice) ?? 0.0;
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

    double totalOriginal = _parseAmount(json['total_original']);
    final impuestoIva = _parseAmount(json['impuesto_iva']);

    // Ítems de la factura
    final itemsList = <ItemGastoModel>[];
    const validCategorias = ['Alimentación', 'Salud', 'Educación', 'Hogar', 'Servicios', 'Transporte', 'Otros'];
    
    if (json['items'] is List) {
      for (final rawItem in (json['items'] as List)) {
        if (rawItem is Map) {
          final itemMap = Map<String, dynamic>.from(rawItem);
          String desc = itemMap['descripcion']?.toString() ?? 'Producto/Servicio';
          final alicuota = itemMap['alicuota_fiscal']?.toString().trim().toUpperCase();
          if (alicuota == 'E' && !desc.toUpperCase().contains('(E)')) {
            desc = '$desc (E)';
          } else if (alicuota == 'G' && !desc.toUpperCase().contains('(G)')) {
            desc = '$desc (G)';
          }
          
          double cant = _parseAmount(itemMap['cantidad'], isPrice: false);
          if (cant <= 0.0) cant = 1.0;
          
          final precio = _parseAmount(itemMap['precio_unitario']);
          // El total del ítem se calcula estrictamente como Cantidad * Precio Unitario
          final totalCalculado = cant * precio;
          final catItemRaw = itemMap['categoria']?.toString() ?? 'Otros';
          final catItem = validCategorias.contains(catItemRaw) ? catItemRaw : 'Otros';

          itemsList.add(ItemGastoModel(
            descripcion: desc,
            cantidad: cant,
            precioUnitario: (precio * 100).round(),
            total: (totalCalculado * 100).round(),
            categoria: catItem,
          ));
        }
      }
    }

    // Agregar impuesto IVA como ítem independiente si aplica y no fue incluido previamente
    if (impuestoIva > 0) {
      final yaTieneIva = itemsList.any((it) =>
          it.descripcion.toLowerCase().contains('iva') ||
          it.descripcion.toLowerCase().contains('impuesto'));
      if (!yaTieneIva) {
        itemsList.add(ItemGastoModel(
          descripcion: 'Impuesto IVA',
          cantidad: 1.0,
          precioUnitario: (impuestoIva * 100).round(),
          total: (impuestoIva * 100).round(),
          categoria: 'Otros',
        ));
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

    // Validación cruzada matemática entre la suma de ítems y el Total Original
    if (itemsList.isNotEmpty && totalOriginal > 0) {
      // 1. Corregir ítems individuales que evidentemente omitieron separador decimal
      // Si un ítem individual supera el total general de la factura, pero dividido entre 100
      // cabe dentro del total, con alta certeza omitió la coma o punto decimal en OCR.
      for (int i = 0; i < itemsList.length; i++) {
        final it = itemsList[i];
        if (it.totalDisplay > totalOriginal * 1.05 && (it.totalDisplay / 100.0) <= totalOriginal * 1.05) {
          final nuevoPrecioInt = (it.precioUnitario / 100).round();
          final nuevoTotalInt = (it.total / 100).round();
          itemsList[i] = it.copyWith(
            precioUnitario: nuevoPrecioInt,
            total: nuevoTotalInt,
          );
        }
      }

      final int sumItemsCentavos = itemsList.fold(0, (sum, item) => sum + item.total);
      final double sumItems = sumItemsCentavos / 100.0;

      if (sumItems > 0) {
        final ratioTotalToSum = totalOriginal / sumItems;
        final ratioSumToTotal = sumItems / totalOriginal;

        if (ratioTotalToSum >= 90.0 && ratioTotalToSum <= 110.0) {
          // Caso A: El totalOriginal omitió los decimales (ej. 5612 extraído vs 56.12 real en ítems).
          // Se corrige el total dividiéndolo entre 100.
          totalOriginal = (totalOriginal / 100.0);
        } else if (ratioSumToTotal >= 90.0 && ratioSumToTotal <= 110.0) {
          // Caso B: Los ítems omitieron los decimales (ej. ítems sumaban 5612 vs 56.12 real en total).
          // Se corrigen los ítems dividiéndolos entre 100.
          for (int i = 0; i < itemsList.length; i++) {
            final old = itemsList[i];
            final nuevoPrecioInt = (old.precioUnitario / 100).round();
            final nuevoTotalInt = (old.total / 100).round();
            itemsList[i] = old.copyWith(
              precioUnitario: nuevoPrecioInt,
              total: nuevoTotalInt,
            );
          }
        }
      }
    } else if (itemsList.isNotEmpty && totalOriginal == 0) {
      final int sumCentavos = itemsList.fold(0, (sum, item) => sum + item.total);
      totalOriginal = sumCentavos / 100.0;
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

    // Método de liquidación opcional (BS_BCV, BS_USDT, DIVISA)
    final rawMetodo = json['metodo_liquidacion']?.toString() ?? json['metodoLiquidacion']?.toString();
    final metodoLiquidacion = (rawMetodo != null && ['BS_BCV', 'BS_USDT', 'DIVISA'].contains(rawMetodo.toUpperCase()))
        ? rawMetodo.toUpperCase()
        : null;

    return GeminiExtractionResult(
      comercio: comercio,
      fecha: fecha,
      moneda: moneda,
      totalOriginal: totalOriginal,
      impuestoIva: impuestoIva,
      tasaCambioDetectada: tasaDetectada,
      items: itemsList,
      matchedShoppingItemIds: matchedIds,
      metodoLiquidacion: metodoLiquidacion,
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
      'metodo_liquidacion': metodoLiquidacion,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}
