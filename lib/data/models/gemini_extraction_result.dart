import '../../core/constants/app_constants.dart';
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

  static const double _maxMontoIA = 1000000000.0; // techo de cordura: mil millones
  static const double _maxCantidadIA = 10000.0;

  static double _parseAmount(dynamic value, {bool isPrice = false}) {
    // Defensa contra datos de la IA: nada negativo, infinito ni fuera de rango.
    final parsed = tryParseAmount(value, isPrice: isPrice) ?? 0.0;
    if (!parsed.isFinite || parsed < 0) return 0.0;
    if (parsed > _maxMontoIA) return _maxMontoIA;
    return parsed;
  }

  /// Normaliza defensivamente la fecha extraída por la IA a formato ISO (YYYY-MM-DD).
  /// Soporta ISO ('2026-11-03'), formato venezolano/latinoamericano ('03/11/2026', '03-11-2026', '03.11.2026')
  /// y años de dos dígitos ('03/11/26'), con fallback seguro a la fecha de hoy.
  static String parseExtractionDate(dynamic raw) {
    if (raw == null) {
      return DateTime.now().toIso8601String().substring(0, 10);
    }
    final str = raw.toString().trim();
    if (str.isEmpty) {
      return DateTime.now().toIso8601String().substring(0, 10);
    }

    // 1. Formato ISO YYYY-MM-DD (ej: "2026-11-03" o "2026-11-03T...")
    final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(str);
    if (isoMatch != null) {
      final y = int.tryParse(isoMatch.group(1)!) ?? 0;
      final m = int.tryParse(isoMatch.group(2)!) ?? 0;
      final d = int.tryParse(isoMatch.group(3)!) ?? 0;
      if (y >= 2000 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return '${isoMatch.group(1)}-${isoMatch.group(2)}-${isoMatch.group(3)}';
      }
    }

    // 2. Formato venezolano / latinoamericano DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
    final dmyMatch = RegExp(r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})').firstMatch(str);
    if (dmyMatch != null) {
      final d = int.tryParse(dmyMatch.group(1)!) ?? 0;
      final m = int.tryParse(dmyMatch.group(2)!) ?? 0;
      var y = int.tryParse(dmyMatch.group(3)!) ?? 0;
      if (y < 100) y += 2000;

      if (y >= 2000 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        final dStr = d.toString().padLeft(2, '0');
        final mStr = m.toString().padLeft(2, '0');
        return '$y-$mStr-$dStr';
      }
    }

    // 3. Fallback tolerante con DateTime.tryParse (por si viniera un formato ISO completo con offset)
    final parsed = DateTime.tryParse(str);
    if (parsed != null && parsed.year >= 2000) {
      final dStr = parsed.day.toString().padLeft(2, '0');
      final mStr = parsed.month.toString().padLeft(2, '0');
      return '${parsed.year}-$mStr-$dStr';
    }

    return DateTime.now().toIso8601String().substring(0, 10);
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
        : 'Comercio no especificado';

    // Fecha defensiva: tolera ISO YYYY-MM-DD y formato venezolano DD/MM/YYYY
    final fecha = parseExtractionDate(json['fecha']);

    // Moneda (USD, VES, USDT, EUR)
    final moneda = AppConstants.normalizarMoneda(json['moneda']?.toString(), fallback: 'USD');

    double totalOriginal = _parseAmount(json['total_original']);
    final impuestoIva = _parseAmount(json['impuesto_iva']);

    // Ítems de la factura
    final itemsList = <ItemGastoModel>[];
    final validCategorias = AppConstants.categorias;
    
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
          if (cant > _maxCantidadIA) cant = _maxCantidadIA;
          
          final precio = _parseAmount(itemMap['precio_unitario']);
          // El total del ítem se calcula estrictamente como Cantidad * Precio Unitario
          double totalCalculado = cant * precio;
          if (!totalCalculado.isFinite || totalCalculado < 0) totalCalculado = 0.0;
          if (totalCalculado > _maxMontoIA) totalCalculado = _maxMontoIA;
          final catItemRaw = itemMap['categoria']?.toString() ?? 'Otros';
          final normCat = AppConstants.normalizarCategoria(catItemRaw);
          final catItem = validCategorias.contains(normCat) ? normCat : 'Otros';

          itemsList.add(ItemGastoModel(
            descripcion: desc,
            cantidad: cant,
            precioUnitario: (precio * 100).round(),
            total: (totalCalculado * 100).round(),
            categoria: catItem,
            origenCategoria: catItem != 'Otros' ? OrigenCategoria.ia : OrigenCategoria.predeterminada,
          ));
        }
      }
    }

    // Categoría dominante de la factura para asignar al renglón de IVA (evitando inflar 'Otros')
    final String dominantCat = ItemGastoModel.calcularCategoriaDominante(itemsList);

    // Si la IA ya devolvió un ítem fiscal de IVA con categoría 'Otros', asignarle la categoría dominante
    for (int i = 0; i < itemsList.length; i++) {
      if (ItemGastoModel.isTaxDescription(itemsList[i].descripcion) && itemsList[i].categoria == 'Otros') {
        itemsList[i] = itemsList[i].copyWith(categoria: dominantCat);
      }
    }

    // Agregar impuesto IVA como ítem independiente con la categoría dominante si aplica y no fue incluido previamente
    if (impuestoIva > 0) {
      final yaTieneIva = itemsList.any((it) =>
          ItemGastoModel.isTaxDescription(it.descripcion) ||
          it.descripcion.toLowerCase().contains('iva') ||
          it.descripcion.toLowerCase().contains('impuesto'));
      if (!yaTieneIva) {
        itemsList.add(ItemGastoModel(
          descripcion: 'Impuesto IVA',
          cantidad: 1.0,
          precioUnitario: (impuestoIva * 100).round(),
          total: (impuestoIva * 100).round(),
          categoria: dominantCat,
          origenCategoria: dominantCat != 'Otros' ? OrigenCategoria.ia : OrigenCategoria.predeterminada,
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
        origenCategoria: OrigenCategoria.predeterminada,
      ));
    }

    // Validación cruzada matemática entre la suma de ítems y el Total Original
    if (itemsList.isNotEmpty) {
      // 1. Corregir ítems individuales que evidentemente omitieron separador decimal
      // Si un ítem individual supera el total general de la factura, pero dividido entre 100
      // cabe dentro del total, con alta certeza omitió la coma o punto decimal en OCR.
      if (totalOriginal > 0) {
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
      }

      // 2. Calce por diferencia contra el Total Impreso (Residual Match)
      // Si la suma de los ítems supera al totalOriginal impreso (incluso cuando el ítem individual
      // no superaba el total general), probar si al dividir un ítem de >= 3 cifras entre 100
      // la suma total calza con el totalOriginal dentro de un margen estrecho.
      if (totalOriginal > 0) {
        int currentSumCents = itemsList.fold(0, (sum, item) => sum + item.total);
        double currentSum = currentSumCents / 100.0;
        if (currentSum > totalOriginal * 1.05) {
          for (int i = 0; i < itemsList.length; i++) {
            final it = itemsList[i];
            // Evaluar ítems de al menos 10.00 en escala actual (>= 1000 centavos)
            if (it.total >= 1000) {
              final candidateTotalCents = (it.total / 100).round();
              final simulatedSumCents = currentSumCents - it.total + candidateTotalCents;
              final simulatedSum = simulatedSumCents / 100.0;
              final diff = (simulatedSum - totalOriginal).abs();
              final maxAllowedDiff = (totalOriginal * 0.05).clamp(0.05, 1.0);
              if (diff <= maxAllowedDiff) {
                final nuevoPrecioInt = (it.precioUnitario / 100).round();
                itemsList[i] = it.copyWith(
                  precioUnitario: nuevoPrecioInt,
                  total: candidateTotalCents,
                );
                currentSumCents = simulatedSumCents;
                break;
              }
            }
          }
        }
      }

      // 3. Consenso de Decimales y Detección de Outlier de Escala
      // Si la mayoría de los ítems tienen decimales explícitos (ej. .25, .50) y un ítem aparece
      // sin decimales (entero) con una magnitud desproporcionada (ej. 1156 vs ítems de 3 a 15),
      // o la IA infló total_original con esa misma suma errónea.
      if (itemsList.length >= 2) {
        final decimalItems = itemsList.where((it) => (it.precioUnitario % 100) != 0).toList();
        if (decimalItems.isNotEmpty && decimalItems.length >= (itemsList.length / 2).floor()) {
          final sortedPrices = decimalItems.map((it) => it.precioUnitarioDisplay).toList()..sort();
          final medianPrice = sortedPrices[sortedPrices.length ~/ 2];

          if (medianPrice > 0) {
            for (int i = 0; i < itemsList.length; i++) {
              final it = itemsList[i];
              // El ítem es un entero sin decimales (precioUnitario % 100 == 0) y con valor >= 10.0
              if ((it.precioUnitario % 100) == 0 && it.precioUnitarioDisplay >= 10.0) {
                final ratio = it.precioUnitarioDisplay / medianPrice;
                final candidatePrice = it.precioUnitarioDisplay / 100.0;
                final candidateRatio = candidatePrice / medianPrice;

                // Es outlier: ratio >= 10x respecto a la mediana de los decimales,
                // y al dividirlo entre 100 queda dentro de una escala razonable (0.05x a 10x de la mediana)
                if (ratio >= 10.0 && candidateRatio >= 0.05 && candidateRatio <= 10.0) {
                  final intUnitInt = it.precioUnitarioDisplay.round();
                  final endsInNonZeroDigits = (intUnitInt % 100) != 0; // ej. 1156 termina en 56, no en 00
                  if (endsInNonZeroDigits || ratio >= 20.0) {
                    final oldTotalCents = it.total;
                    final nuevoPrecioInt = (it.precioUnitario / 100).round();
                    final nuevoTotalInt = (it.total / 100).round();
                    itemsList[i] = it.copyWith(
                      precioUnitario: nuevoPrecioInt,
                      total: nuevoTotalInt,
                    );

                    // Si totalOriginal estaba inflado por la suma de la IA, reajustarlo
                    if (totalOriginal > 0) {
                      final excess = (oldTotalCents - nuevoTotalInt) / 100.0;
                      if ((totalOriginal - (oldTotalCents / 100.0)).abs() < totalOriginal * 0.5) {
                        totalOriginal = (totalOriginal - excess).clamp(0.0, double.infinity);
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // 4. Validación general de ratios 90..110 (Caso A: total x100, Caso B: todos los ítems x100)
      final int sumItemsCentavos = itemsList.fold(0, (sum, item) => sum + item.total);
      final double sumItems = sumItemsCentavos / 100.0;

      if (sumItems > 0 && totalOriginal > 0) {
        final ratioTotalToSum = totalOriginal / sumItems;
        final ratioSumToTotal = sumItems / totalOriginal;

        if (ratioTotalToSum >= 90.0 && ratioTotalToSum <= 110.0) {
          // Caso A: El totalOriginal omitió los decimales (ej. 5612 extraído vs 56.12 real en ítems).
          totalOriginal = (totalOriginal / 100.0);
        } else if (ratioSumToTotal >= 90.0 && ratioSumToTotal <= 110.0) {
          // Caso B: Los ítems omitieron los decimales (ej. ítems sumaban 5612 vs 56.12 real en total).
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
      } else if (itemsList.isNotEmpty && totalOriginal == 0) {
        final int sumCentavos = itemsList.fold(0, (sum, item) => sum + item.total);
        totalOriginal = sumCentavos / 100.0;
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
      'items': items.map((i) => {
        if (i.id != null) 'id': i.id,
        if (i.gastoId != null) 'gasto_id': i.gastoId,
        'descripcion': i.descripcion,
        'cantidad': i.cantidad,
        'precio_unitario': i.precioUnitarioDisplay,
        'total': i.totalDisplay,
        'categoria': i.categoria,
      }).toList(),
      'items_comprados_ids': matchedShoppingItemIds,
      'metodo_liquidacion': metodoLiquidacion,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}
