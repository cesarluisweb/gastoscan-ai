import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/amount_parser.dart';
import 'item_gasto_model.dart';

/// Representación explícita del tratamiento tributario del IVA en una extracción.
/// Evita confundir ausencia de información con exención fiscal confirmada y permite
/// que `SemanticValidator` contabilice el IVA exactamente una vez.
enum IvaModo {
  /// No se informó IVA ni hay evidencia fiscal (ej. dictado por voz, manual o borrador).
  noInformado,

  /// La factura declaró explícitamente `impuesto_iva == 0` sin renglón de impuesto.
  sinIvaDeclarado,

  /// El IVA figura como renglón independiente en `items` (Opción A / fallback seguro).
  renglonSeparado,

  /// El IVA ya fue repartido e imputado en el precio de los ítems gravados (Opción B).
  imputado,

  /// Los precios impresos en los ítems ya incluían el IVA desde origen.
  yaIncluido,

  /// Extracción ambigua o inconsistente (descuentos, múltiples líneas de IVA, etc.).
  requiereRevision,
}

/// Clasificación semántica de cada renglón crudo recibido desde Gemini antes de
/// aplicar normalización o reglas fiscales.
enum TipoLineaExtraccion {
  producto,
  iva,
  igtf,
  servicio,
  descuento,
  subtotal,
}

class _RawParsedItem {
  final ItemGastoModel item;
  final String? alicuota; // 'E', 'G', 'R' o null

  const _RawParsedItem({
    required this.item,
    required this.alicuota,
  });
}

class _DecimalReconcileResult {
  final List<ItemGastoModel> items;
  final double targetTotal;

  const _DecimalReconcileResult({
    required this.items,
    required this.targetTotal,
  });
}

class GeminiExtractionResult {
  static const int currentSchemaVersion = 2;

  final String comercio;
  final String fecha;
  final String moneda;
  final double totalOriginal;
  final double impuestoIva;
  final double? tasaCambioDetectada;
  final List<ItemGastoModel> items;
  final List<int> matchedShoppingItemIds;
  final String? metodoLiquidacion;
  final IvaModo ivaModo;
  final int schemaVersion;
  final bool hasSpecialLines;

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
    this.ivaModo = IvaModo.noInformado,
    this.schemaVersion = currentSchemaVersion,
    this.hasSpecialLines = false,
  });

  static const double _maxMontoIA = 1000000000.0; // techo de cordura: mil millones
  static const double _maxCantidadIA = 10000.0;

  /// Reparte los centavos exactos del IVA documental (`ivaCents`) entre las líneas
  /// mediante el algoritmo de Mayor Resto (Hamilton / Largest Remainder Method).
  ///
  /// Usa [BigInt] internamente para evitar desbordamiento de enteros de 64 bits ante
  /// montos altos en bolívares (`ivaCents * base * tasa`). Garantiza que
  /// `sum(resultado) == ivaCents` de forma determinista y sin error acumulado.
  static List<int> repartirIvaMayorResto(
    List<int> bases,
    List<int> tasaPct,
    int ivaCents,
  ) {
    if (bases.isEmpty || ivaCents <= 0) {
      return List<int>.filled(bases.length, 0);
    }
    final weights = List<BigInt>.generate(
      bases.length,
      (i) => bases[i] > 0 && tasaPct[i] > 0
          ? BigInt.from(bases[i]) * BigInt.from(tasaPct[i])
          : BigInt.zero,
    );
    final BigInt totalWeight = weights.fold<BigInt>(BigInt.zero, (a, b) => a + b);
    if (totalWeight <= BigInt.zero) {
      return List<int>.filled(bases.length, 0);
    }

    final BigInt ivaBig = BigInt.from(ivaCents);
    final shares = List<int>.filled(bases.length, 0);
    final remainders = List<BigInt>.filled(bases.length, BigInt.zero);
    int assigned = 0;

    for (int i = 0; i < weights.length; i++) {
      final w = weights[i];
      if (w <= BigInt.zero) continue;
      final BigInt numerator = ivaBig * w;
      shares[i] = (numerator ~/ totalWeight).toInt();
      remainders[i] = numerator % totalWeight;
      assigned += shares[i];
    }

    final int remaining = ivaCents - assigned;
    if (remaining > 0) {
      final order = List<int>.generate(weights.length, (i) => i)
        ..sort((a, b) {
          final cmpRem = remainders[b].compareTo(remainders[a]);
          if (cmpRem != 0) return cmpRem;
          final cmpWeight = weights[b].compareTo(weights[a]);
          if (cmpWeight != 0) return cmpWeight;
          return a.compareTo(b);
        });
      for (int k = 0; k < remaining && k < order.length; k++) {
        if (weights[order[k]] > BigInt.zero) {
          shares[order[k]] += 1;
        }
      }
    }

    return shares;
  }

  /// Calcula la tolerancia en centavos para la guardia `|sum - target|` teniendo en
  /// cuenta que `total = round(cant * precio_unitario)` acumula hasta 0.5 centavos
  /// por unidad cuando el precio unitario viene redondeado a 2 decimales.
  static int _guardToleranceCents(List<ItemGastoModel> items) {
    if (items.isEmpty) return 2;
    double sumQty = 0.0;
    for (final it in items) {
      sumQty += it.cantidad > 0 ? it.cantidad : 1.0;
    }
    final int byQty = 1 + (sumQty / 2.0).ceil();
    final int byLines = 1 + (items.length / 2.0).ceil();
    final int raw = byQty > byLines ? byQty : byLines;
    return raw.clamp(2, 25);
  }

  /// Tolerancia fiscal estricta en centavos para validar que el IVA impreso en la
  /// factura corresponde exactamente al 16% (o 8%) de las bases gravadas identificadas.
  static int _fiscalRateToleranceCents(int numTaxedItems) {
    if (numTaxedItems <= 0) return 1;
    return ((numTaxedItems / 2.0).ceil() + 1).clamp(2, 10);
  }

  /// Ejecuta de forma pura los 4 bloques de reconciliación de decimales omitidos
  /// contra un [targetTotal] explícito, sin mutar la lista de entrada.
  static _DecimalReconcileResult _reconcileDecimals(
    List<ItemGastoModel> sourceItems,
    double targetTotal, {
    bool allowScaleTargetTotal = true,
  }) {
    final itemsList = List<ItemGastoModel>.from(sourceItems);
    double resolvedTarget = targetTotal;

    if (itemsList.isEmpty) {
      return _DecimalReconcileResult(items: itemsList, targetTotal: resolvedTarget);
    }

    // 1. Ítem individual que supera el total objetivo pero /100 cabe dentro
    if (resolvedTarget > 0) {
      for (int i = 0; i < itemsList.length; i++) {
        final it = itemsList[i];
        if (it.totalDisplay > resolvedTarget * 1.05 &&
            (it.totalDisplay / 100.0) <= resolvedTarget * 1.05) {
          itemsList[i] = it.copyWith(
            precioUnitario: (it.precioUnitario / 100).round(),
            total: (it.total / 100).round(),
          );
        }
      }
    }

    // 2. Residual Match: si la suma supera el objetivo, probar dividir /100 un ítem >= 10.00
    if (resolvedTarget > 0) {
      int currentSumCents = itemsList.fold(0, (sum, item) => sum + item.total);
      double currentSum = currentSumCents / 100.0;
      if (currentSum > resolvedTarget * 1.05) {
        for (int i = 0; i < itemsList.length; i++) {
          final it = itemsList[i];
          if (it.total >= 1000) {
            final candidateTotalCents = (it.total / 100).round();
            final simulatedSumCents = currentSumCents - it.total + candidateTotalCents;
            final simulatedSum = simulatedSumCents / 100.0;
            final diff = (simulatedSum - resolvedTarget).abs();
            final maxAllowedDiff = (resolvedTarget * 0.05).clamp(0.05, 1.0);
            if (diff <= maxAllowedDiff) {
              itemsList[i] = it.copyWith(
                precioUnitario: (it.precioUnitario / 100).round(),
                total: candidateTotalCents,
              );
              currentSumCents = simulatedSumCents;
              break;
            }
          }
        }
      }
    }

    // 3. Consenso de Decimales y Outlier de Escala
    if (itemsList.length >= 2) {
      final decimalItems = itemsList.where((it) => (it.precioUnitario % 100) != 0).toList();
      if (decimalItems.isNotEmpty && decimalItems.length >= (itemsList.length / 2).floor()) {
        final sortedPrices = decimalItems.map((it) => it.precioUnitarioDisplay).toList()..sort();
        final medianPrice = sortedPrices[sortedPrices.length ~/ 2];

        if (medianPrice > 0) {
          for (int i = 0; i < itemsList.length; i++) {
            final it = itemsList[i];
            if ((it.precioUnitario % 100) == 0 && it.precioUnitarioDisplay >= 10.0) {
              final ratio = it.precioUnitarioDisplay / medianPrice;
              final candidatePrice = it.precioUnitarioDisplay / 100.0;
              final candidateRatio = candidatePrice / medianPrice;

              if (ratio >= 10.0 && candidateRatio >= 0.05 && candidateRatio <= 10.0) {
                final intUnitInt = it.precioUnitarioDisplay.round();
                final endsInNonZeroDigits = (intUnitInt % 100) != 0;
                if (endsInNonZeroDigits || ratio >= 20.0) {
                  final oldTotalCents = it.total;
                  final nuevoPrecioInt = (it.precioUnitario / 100).round();
                  final nuevoTotalInt = (it.total / 100).round();
                  itemsList[i] = it.copyWith(
                    precioUnitario: nuevoPrecioInt,
                    total: nuevoTotalInt,
                  );

                  if (allowScaleTargetTotal && resolvedTarget > 0) {
                    final excess = (oldTotalCents - nuevoTotalInt) / 100.0;
                    if ((resolvedTarget - (oldTotalCents / 100.0)).abs() < resolvedTarget * 0.5) {
                      resolvedTarget = (resolvedTarget - excess).clamp(0.0, double.infinity);
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // 4. Validación general de ratios 90..110 (total x100 o todos los ítems x100)
    final int sumItemsCentavos = itemsList.fold(0, (sum, item) => sum + item.total);
    final double sumItems = sumItemsCentavos / 100.0;

    if (sumItems > 0 && resolvedTarget > 0) {
      final ratioTotalToSum = resolvedTarget / sumItems;
      final ratioSumToTotal = sumItems / resolvedTarget;

      if (allowScaleTargetTotal && ratioTotalToSum >= 90.0 && ratioTotalToSum <= 110.0) {
        resolvedTarget = resolvedTarget / 100.0;
      } else if (ratioSumToTotal >= 90.0 && ratioSumToTotal <= 110.0) {
        for (int i = 0; i < itemsList.length; i++) {
          final old = itemsList[i];
          itemsList[i] = old.copyWith(
            precioUnitario: (old.precioUnitario / 100).round(),
            total: (old.total / 100).round(),
          );
        }
      }
    }

    return _DecimalReconcileResult(items: itemsList, targetTotal: resolvedTarget);
  }

  static String? _extractAlicuota(String? rawAlicuota, String descripcion) {
    final norm = rawAlicuota?.trim().toUpperCase();
    if (norm == 'E' || norm == 'G' || norm == 'R') return norm;
    if (RegExp(r'\(G\)\s*$', caseSensitive: false).hasMatch(descripcion)) return 'G';
    if (RegExp(r'\(E\)\s*$', caseSensitive: false).hasMatch(descripcion)) return 'E';
    if (RegExp(r'\(R\)\s*$', caseSensitive: false).hasMatch(descripcion)) return 'R';
    return null;
  }

  /// Evalúa si un vector de alícuotas `[0, 8, 16]` explica el `ivaCents` documental
  /// dentro de la tolerancia fiscal estricta. Retorna el error en centavos si calza,
  /// o `null` si no cumple el chequeo.
  static int? _matchWeightedVatError(
    List<ItemGastoModel> items,
    List<int> ratesPct,
    int ivaCents,
  ) {
    int taxedCount = 0;
    int weightedBaseSum = 0;
    for (int i = 0; i < items.length; i++) {
      final rate = ratesPct[i];
      if (rate > 0 && items[i].total > 0) {
        taxedCount++;
        weightedBaseSum += items[i].total * rate;
      }
    }
    if (taxedCount == 0 || weightedBaseSum <= 0) return null;
    final int expectedIvaCents = (weightedBaseSum + 50) ~/ 100;
    final int diff = (expectedIvaCents - ivaCents).abs();
    final int tol = _fiscalRateToleranceCents(taxedCount);
    return diff <= tol ? diff : null;
  }

  static double _parseAmount(dynamic value, {bool isPrice = false}) {
    // Defensa contra datos de la IA: nada negativo, infinito ni fuera de rango.
    final parsed = tryParseAmount(value, isPrice: isPrice) ?? 0.0;
    if (!parsed.isFinite || parsed < 0) return 0.0;
    if (parsed > _maxMontoIA) return _maxMontoIA;
    return parsed;
  }

  /// Parsea el monto preservando el signo original antes de cualquier clamp,
  /// para detectar descuentos o ajustes negativos reales enviados por el LLM.
  static double? _parseRawSignedAmount(dynamic value, {bool isPrice = false}) {
    final parsed = tryParseAmount(value, isPrice: isPrice);
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  /// Clasifica una línea cruda del JSON de Gemini usando la descripción y el monto
  /// con signo original antes de cualquier saneamiento.
  static TipoLineaExtraccion classifyRawLine({
    required String descripcion,
    double? rawUnitPrice,
    double? rawTotal,
  }) {
    if (ItemGastoModel.isSummaryLineDescription(descripcion)) {
      return TipoLineaExtraccion.subtotal;
    }
    if (ItemGastoModel.isIgtfDescription(descripcion)) {
      return TipoLineaExtraccion.igtf;
    }
    if (ItemGastoModel.isIvaOnlyDescription(descripcion)) {
      return TipoLineaExtraccion.iva;
    }
    if (ItemGastoModel.isServiceOrTipDescription(descripcion)) {
      return TipoLineaExtraccion.servicio;
    }
    final bool isNegative =
        (rawUnitPrice != null && rawUnitPrice < 0) ||
        (rawTotal != null && rawTotal < 0);
    if (isNegative || ItemGastoModel.isDiscountDescription(descripcion)) {
      return TipoLineaExtraccion.descuento;
    }
    return TipoLineaExtraccion.producto;
  }

  static IvaModo? _parseIvaModo(dynamic raw) {
    if (raw == null) return null;
    final key = raw.toString().trim();
    for (final mode in IvaModo.values) {
      if (mode.name == key) return mode;
    }
    return null;
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

  /// Deserializa de forma defensiva el campo `extracted_data` almacenado en `scan_queue`.
  /// Acepta un `Map`, un `String` JSON válido que decodifique a `Map`, y degrada
  /// limpiamente a `fromQueueMap(const {})` ante `null`, cadena vacía, JSON corrupto
  /// o estructuras no-`Map` (sin lanzar `TypeError` ni `FormatException`).
  static GeminiExtractionResult fromQueueJson(dynamic raw) {
    if (raw == null) {
      return GeminiExtractionResult.fromQueueMap(const {});
    }
    if (raw is Map) {
      return GeminiExtractionResult.fromQueueMap(Map<String, dynamic>.from(raw));
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return GeminiExtractionResult.fromQueueMap(const {});
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return GeminiExtractionResult.fromQueueMap(Map<String, dynamic>.from(decoded));
        }
        debugPrint('GeminiExtractionResult.fromQueueJson: JSON decodificado no es Map (${decoded.runtimeType}).');
      } catch (e) {
        debugPrint('GeminiExtractionResult.fromQueueJson: JSON inválido en scan_queue: $e');
      }
      return GeminiExtractionResult.fromQueueMap(const {});
    }
    debugPrint('GeminiExtractionResult.fromQueueJson: tipo inesperado (${raw.runtimeType}).');
    return GeminiExtractionResult.fromQueueMap(const {});
  }

  /// Restaura un resultado previamente serializado en `scan_queue` (SQLite) sin volver
  /// a ejecutar heurísticas de extracción, normalización de decimales ni inyección de IVA.
  ///
  /// Soporta tanto registros nuevos (`schema_v: 2`, con centavos exactos y `iva_modo`)
  /// como registros legados (`schema_v` ausente o `< 2`, escritos antes de AI-06),
  /// preservando intactos los montos, descripciones y sufijos originales.
  factory GeminiExtractionResult.fromQueueMap(Map<String, dynamic> json) {
    final comercioRaw = json['comercio'];
    final comercio = (comercioRaw != null && comercioRaw.toString().trim().isNotEmpty)
        ? comercioRaw.toString().trim()
        : 'Comercio no especificado';

    final fecha = parseExtractionDate(json['fecha']);
    final moneda = AppConstants.normalizarMoneda(json['moneda']?.toString(), fallback: 'USD');
    final double totalOriginal = _parseAmount(json['total_original']);
    final double impuestoIva = _parseAmount(json['impuesto_iva']);

    final rawSchemaV = json['schema_v'];
    final int schemaVersion = rawSchemaV is num ? rawSchemaV.toInt() : 1;

    final int maxMontoCentavos = (_maxMontoIA * 100).round();
    final itemsList = <ItemGastoModel>[];
    const validCategorias = AppConstants.categorias;

    if (json['items'] is List) {
      for (final rawItem in (json['items'] as List)) {
        if (rawItem is Map) {
          final itemMap = Map<String, dynamic>.from(rawItem);
          final desc = itemMap['descripcion']?.toString() ?? 'Producto/Servicio';

          double cant = _parseAmount(itemMap['cantidad'], isPrice: false);
          if (cant <= 0.0) cant = 1.0;
          if (cant > _maxCantidadIA) cant = _maxCantidadIA;

          int precioCentavos;
          if (itemMap['precio_unitario_cents'] is num) {
            precioCentavos = (itemMap['precio_unitario_cents'] as num).toInt().clamp(0, maxMontoCentavos);
          } else {
            final precio = _parseAmount(itemMap['precio_unitario']);
            precioCentavos = (precio * 100).round().clamp(0, maxMontoCentavos);
          }

          int totalCentavos;
          if (itemMap['total_cents'] is num) {
            totalCentavos = (itemMap['total_cents'] as num).toInt().clamp(0, maxMontoCentavos);
          } else if (itemMap['total'] != null) {
            final totalVal = _parseAmount(itemMap['total']);
            totalCentavos = (totalVal * 100).round().clamp(0, maxMontoCentavos);
          } else {
            totalCentavos = (cant * precioCentavos).round().clamp(0, maxMontoCentavos);
          }

          final catItemRaw = itemMap['categoria']?.toString() ?? 'Otros';
          final normCat = AppConstants.normalizarCategoria(catItemRaw);
          final catItem = validCategorias.contains(normCat) ? normCat : 'Otros';

          final rawId = itemMap['id'];
          final rawGastoId = itemMap['gasto_id'];
          final rawBaseCents = itemMap['base_imponible_original_cents'];
          final int? baseImponibleOriginal = rawBaseCents is num
              ? rawBaseCents.toInt().clamp(0, maxMontoCentavos)
              : null;
          final rawTasaIva = itemMap['tasa_iva_pct'];
          final int tasaIvaPct = rawTasaIva is num
              ? rawTasaIva.toInt().clamp(0, 100)
              : (baseImponibleOriginal != null ? 16 : 0);

          itemsList.add(ItemGastoModel(
            id: rawId is num ? rawId.toInt() : null,
            gastoId: rawGastoId is num ? rawGastoId.toInt() : null,
            descripcion: desc,
            cantidad: cant,
            precioUnitario: precioCentavos,
            total: totalCentavos,
            categoria: catItem,
            origenCategoria: catItem != 'Otros' ? OrigenCategoria.ia : OrigenCategoria.predeterminada,
            baseImponibleOriginal: baseImponibleOriginal,
            tasaIvaPct: tasaIvaPct,
          ));
        }
      }
    }

    final rawTasa = _parseAmount(json['tasa_cambio']);
    final tasaDetectada = rawTasa > 0 ? rawTasa : null;

    final matchedIds = <int>[];
    if (json['items_comprados_ids'] is List) {
      for (final id in (json['items_comprados_ids'] as List)) {
        if (id is num) {
          matchedIds.add(id.toInt());
        }
      }
    }

    final rawMetodo = json['metodo_liquidacion']?.toString() ?? json['metodoLiquidacion']?.toString();
    final metodoLiquidacion = (rawMetodo != null && ['BS_BCV', 'BS_USDT', 'DIVISA'].contains(rawMetodo.toUpperCase()))
        ? rawMetodo.toUpperCase()
        : null;

    final bool hasSpecialLines = json['has_special_lines'] == true;

    IvaModo? parsedModo = _parseIvaModo(json['iva_modo']);
    if (parsedModo == null) {
      // Compatibilidad con registros legados (schema_v < 2) guardados en scan_queue
      final hasIvaItem = itemsList.any((it) => ItemGastoModel.isIvaOnlyDescription(it.descripcion));
      if (hasIvaItem) {
        parsedModo = IvaModo.renglonSeparado;
      } else if (impuestoIva > 0) {
        parsedModo = IvaModo.yaIncluido;
      } else if (json.containsKey('impuesto_iva') && json['impuesto_iva'] != null) {
        parsedModo = IvaModo.sinIvaDeclarado;
      } else {
        parsedModo = IvaModo.noInformado;
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
      metodoLiquidacion: metodoLiquidacion,
      ivaModo: parsedModo,
      schemaVersion: schemaVersion,
      hasSpecialLines: hasSpecialLines,
    );
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
    final bool hasDeclaredIvaField = json.containsKey('impuesto_iva') && json['impuesto_iva'] != null;
    double impuestoIva = _parseAmount(json['impuesto_iva']);

    // Paso 0: Clasificación estricta de líneas crudas (antes de cualquier clamp o normalización)
    final rawProducts = <_RawParsedItem>[];
    const validCategorias = AppConstants.categorias;
    final ivaLinesFromJson = <ItemGastoModel>[];
    bool hasSpecialLines = false;

    if (json['items'] is List) {
      for (final rawItem in (json['items'] as List)) {
        if (rawItem is Map) {
          final itemMap = Map<String, dynamic>.from(rawItem);
          String desc = itemMap['descripcion']?.toString().trim() ?? 'Producto/Servicio';
          if (desc.isEmpty) desc = 'Producto/Servicio';

          final rawUnitSigned = _parseRawSignedAmount(itemMap['precio_unitario']);
          final rawTotalSigned = _parseRawSignedAmount(itemMap['total']);
          final lineType = classifyRawLine(
            descripcion: desc,
            rawUnitPrice: rawUnitSigned,
            rawTotal: rawTotalSigned,
          );

          // Descartar líneas resumen coladas por el LLM (SUBTOTAL, BASE IMPONIBLE, etc.)
          if (lineType == TipoLineaExtraccion.subtotal) {
            continue;
          }

          if (lineType == TipoLineaExtraccion.igtf ||
              lineType == TipoLineaExtraccion.servicio ||
              lineType == TipoLineaExtraccion.descuento) {
            hasSpecialLines = true;
          }

          final alicuota = lineType == TipoLineaExtraccion.producto
              ? _extractAlicuota(itemMap['alicuota_fiscal']?.toString(), desc)
              : null;

          // Conservamos sufijos temporalmente; si se imputa IVA en Paso 3, los limpiamos.
          if (lineType == TipoLineaExtraccion.producto) {
            if (alicuota == 'E' && !desc.toUpperCase().contains('(E)')) {
              desc = '$desc (E)';
            } else if (alicuota == 'G' && !desc.toUpperCase().contains('(G)')) {
              desc = '$desc (G)';
            } else if (alicuota == 'R' && !desc.toUpperCase().contains('(R)')) {
              desc = '$desc (R)';
            }
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

          final parsedItem = ItemGastoModel(
            descripcion: desc,
            cantidad: cant,
            precioUnitario: (precio * 100).round(),
            total: (totalCalculado * 100).round(),
            categoria: catItem,
            origenCategoria: catItem != 'Otros' ? OrigenCategoria.ia : OrigenCategoria.predeterminada,
          );

          if (lineType == TipoLineaExtraccion.iva) {
            ivaLinesFromJson.add(parsedItem);
          } else {
            rawProducts.add(_RawParsedItem(item: parsedItem, alicuota: alicuota));
          }
        }
      }
    }

    // Consolidar IVA documental (cabecera vs renglones explícitos en `items`)
    bool hasMultipleConflictingIvaLines = false;
    if (ivaLinesFromJson.isNotEmpty) {
      final int sumIvaLinesCents = ivaLinesFromJson.fold(0, (acc, it) => acc + it.total);
      final int headerIvaCents = (impuestoIva * 100).round();

      if (ivaLinesFromJson.length > 1) {
        hasMultipleConflictingIvaLines = true;
      } else if (headerIvaCents > 0 && (sumIvaLinesCents - headerIvaCents).abs() > 1) {
        hasMultipleConflictingIvaLines = true;
      }

      if (impuestoIva <= 0 && sumIvaLinesCents > 0) {
        impuestoIva = sumIvaLinesCents / 100.0;
      }
    }

    // Si no detectó items pero hay monto total, agrega al menos una línea
    List<ItemGastoModel> productItems = rawProducts.map((e) => e.item).toList();
    List<String?> productAlicuotas = rawProducts.map((e) => e.alicuota).toList();

    // Paso 1: Reconciliación pura de decimales omitidos por candidatos [T - iva, T]
    if (productItems.isNotEmpty) {
      if (impuestoIva > 0 && totalOriginal > 0 && !hasMultipleConflictingIvaLines) {
        final int totalCents = (totalOriginal * 100).round();
        final int ivaCents = (impuestoIva * 100).round();
        final int tol = _guardToleranceCents(productItems);
        final int rawSumCents = productItems.fold(0, (s, it) => s + it.total);

        final bool alreadyFitsBase = (rawSumCents + ivaCents - totalCents).abs() <= tol;
        final bool alreadyFitsIncluded = (rawSumCents - totalCents).abs() <= tol;

        if (!alreadyFitsBase && !alreadyFitsIncluded) {
          // Comprobar primero si total_original omitió el separador decimal (x100) respecto a (bases + IVA)
          final double sumWithIva = (rawSumCents + ivaCents) / 100.0;
          final double? scaledTotalFromBase = (sumWithIva > 0 &&
                  (totalOriginal / sumWithIva) >= 90.0 &&
                  (totalOriginal / sumWithIva) <= 110.0)
              ? (totalOriginal / 100.0)
              : null;

          final double baseAnchorTotal = scaledTotalFromBase ?? totalOriginal;
          final int baseAnchorTotalCents = (baseAnchorTotal * 100).round();
          final double targetBase = (baseAnchorTotal - impuestoIva) > 0
              ? (baseAnchorTotal - impuestoIva)
              : baseAnchorTotal;
          final candBase = _reconcileDecimals(
            productItems,
            targetBase,
            allowScaleTargetTotal: false,
          );
          final int sumCandBase = candBase.items.fold(0, (s, it) => s + it.total);
          final int diffCandBase = (sumCandBase + ivaCents - baseAnchorTotalCents).abs();

          final candIncluded = _reconcileDecimals(
            productItems,
            totalOriginal,
            allowScaleTargetTotal: true,
          );
          final int sumCandInc = candIncluded.items.fold(0, (s, it) => s + it.total);
          final int candIncTotalCents = (candIncluded.targetTotal * 100).round();
          final int diffCandInc = (sumCandInc - candIncTotalCents).abs();

          if (diffCandBase <= tol) {
            productItems = candBase.items;
            if (scaledTotalFromBase != null) {
              totalOriginal = scaledTotalFromBase;
            }
          } else if (diffCandInc <= tol) {
            productItems = candIncluded.items;
            totalOriginal = candIncluded.targetTotal;
          } else if (diffCandBase <= diffCandInc) {
            productItems = candBase.items;
            if (scaledTotalFromBase != null) {
              totalOriginal = scaledTotalFromBase;
            }
          } else {
            productItems = candIncluded.items;
            totalOriginal = candIncluded.targetTotal;
          }
        }
      } else if (totalOriginal > 0) {
        final rec = _reconcileDecimals(productItems, totalOriginal, allowScaleTargetTotal: true);
        productItems = rec.items;
        totalOriginal = rec.targetTotal;
      } else {
        // Sin totalOriginal: aplicar solo consenso de decimales y derivar total
        final rec = _reconcileDecimals(productItems, 0.0, allowScaleTargetTotal: false);
        productItems = rec.items;
      }
    }

    // Paso 2 & 3: Guardia absoluta, chequeo estricto de tasa ponderada e imputación por Mayor Resto
    final List<ItemGastoModel> itemsList = [];
    final IvaModo ivaModo;
    final String dominantCat = ItemGastoModel.calcularCategoriaDominante(productItems);

    if (productItems.isEmpty && ivaLinesFromJson.isEmpty && totalOriginal > 0) {
      itemsList.add(ItemGastoModel(
        descripcion: 'Consumo general / Pago',
        cantidad: 1.0,
        precioUnitario: (totalOriginal * 100).round(),
        total: (totalOriginal * 100).round(),
        origenCategoria: OrigenCategoria.predeterminada,
      ));
      ivaModo = hasDeclaredIvaField && impuestoIva == 0.0
          ? IvaModo.sinIvaDeclarado
          : IvaModo.noInformado;
    } else if (hasMultipleConflictingIvaLines) {
      // Conflicto entre líneas de IVA y cabecera -> mantener renglones y marcar requiereRevision
      itemsList.addAll(productItems);
      for (final ivaItem in ivaLinesFromJson) {
        itemsList.add(
          ivaItem.categoria == 'Otros' ? ivaItem.copyWith(categoria: dominantCat) : ivaItem,
        );
      }
      ivaModo = IvaModo.requiereRevision;
    } else if (impuestoIva <= 0) {
      itemsList.addAll(productItems);
      ivaModo = hasDeclaredIvaField ? IvaModo.sinIvaDeclarado : IvaModo.noInformado;
    } else {
      final int ivaCents = (impuestoIva * 100).round();
      final int totalCents = (totalOriginal * 100).round();
      final int sumProductsCents = productItems.fold(0, (s, it) => s + it.total);
      final int guardTol = _guardToleranceCents(productItems);

      final bool linesAlreadyIncludeVat =
          !hasSpecialLines &&
          ivaLinesFromJson.isEmpty &&
          totalCents > 0 &&
          (sumProductsCents - totalCents).abs() <= guardTol &&
          (sumProductsCents + ivaCents - totalCents).abs() > guardTol;

      final bool linesAreBases =
          !hasSpecialLines &&
          totalCents > 0 &&
          (sumProductsCents + ivaCents - totalCents).abs() <= guardTol;

      if (linesAlreadyIncludeVat) {
        // Los ítems impresos ya contienen el IVA: no sumar nada ni agregar renglón Impuesto IVA
        // y limpiar sufijos fiscales (no generar baseImponibleOriginal).
        for (final it in productItems) {
          final cleanDesc = ItemGastoModel.stripFiscalSuffix(it.descripcion);
          itemsList.add(it.copyWith(
            descripcion: cleanDesc.isNotEmpty ? cleanDesc : it.descripcion,
          ));
        }
        ivaModo = IvaModo.yaIncluido;
      } else if (linesAreBases && productItems.isNotEmpty) {
        // Intentar determinar alícuotas exactas (G=16%, R=8%, E=0%) y probar hipótesis para `null`
        final bool hasAnyNull = productAlicuotas.any((a) => a == null);
        List<int>? winningRates;

        if (!hasAnyNull) {
          final rates = productAlicuotas.map((a) {
            if (a == 'G') return 16;
            if (a == 'R') return 8;
            return 0;
          }).toList();
          if (_matchWeightedVatError(productItems, rates, ivaCents) != null) {
            winningRates = rates;
          }
        } else {
          // Hipótesis 1: todos los `null` son exentos (0%)
          final ratesNullExempt = productAlicuotas.map((a) {
            if (a == 'G') return 16;
            if (a == 'R') return 8;
            return 0;
          }).toList();
          // Hipótesis 2: todos los `null` son gravados al 16%
          final ratesNullGravado = productAlicuotas.map((a) {
            if (a == 'E') return 0;
            if (a == 'R') return 8;
            return 16;
          }).toList();

          final int? errExempt = _matchWeightedVatError(productItems, ratesNullExempt, ivaCents);
          final int? errGravado = _matchWeightedVatError(productItems, ratesNullGravado, ivaCents);

          if (errExempt != null && errGravado == null) {
            winningRates = ratesNullExempt;
          } else if (errGravado != null && errExempt == null) {
            winningRates = ratesNullGravado;
          } else if (errExempt != null && errGravado != null) {
            // Ambas hipótesis cuadran -> ambiguo: no adivinar, caer a fallback seguro (Rama 3)
            winningRates = null;
          }
        }

        if (winningRates != null) {
          final bases = productItems.map((it) => it.total).toList();
          final shares = repartirIvaMayorResto(bases, winningRates, ivaCents);

          for (int i = 0; i < productItems.length; i++) {
            final it = productItems[i];
            final rate = winningRates[i];
            final cleanDesc = ItemGastoModel.stripFiscalSuffix(it.descripcion);
            final finalDesc = cleanDesc.isNotEmpty ? cleanDesc : it.descripcion;

            if (rate > 0 && it.total > 0) {
              final int baseUnitCents = it.precioUnitario;
              final int unitWithVatCents = (baseUnitCents * (100 + rate) + 50) ~/ 100;
              final int totalWithVatCents = it.total + shares[i];
              itemsList.add(it.copyWith(
                descripcion: finalDesc,
                precioUnitario: unitWithVatCents,
                total: totalWithVatCents,
                baseImponibleOriginal: baseUnitCents,
                tasaIvaPct: rate,
              ));
            } else {
              itemsList.add(it.copyWith(
                descripcion: finalDesc,
                clearBaseImponibleOriginal: true,
              ));
            }
          }
          ivaModo = IvaModo.imputado;
        } else {
          // Rama 3 (Fallback conservador a Opción A): preservar precios base y sufijos + 1 renglón IVA
          itemsList.addAll(productItems);
          if (ivaLinesFromJson.isNotEmpty) {
            final ivaItem = ivaLinesFromJson.first;
            itemsList.add(
              ivaItem.categoria == 'Otros' ? ivaItem.copyWith(categoria: dominantCat) : ivaItem,
            );
          } else {
            itemsList.add(ItemGastoModel(
              descripcion: 'Impuesto IVA',
              cantidad: 1.0,
              precioUnitario: ivaCents,
              total: ivaCents,
              categoria: dominantCat,
              origenCategoria: dominantCat != 'Otros' ? OrigenCategoria.ia : OrigenCategoria.predeterminada,
            ));
          }
          ivaModo = IvaModo.renglonSeparado;
        }
      } else {
        // Fallback conservador (hay líneas especiales, o la suma no calza con totalOriginal)
        itemsList.addAll(productItems);
        if (ivaLinesFromJson.isNotEmpty) {
          final ivaItem = ivaLinesFromJson.first;
          itemsList.add(
            ivaItem.categoria == 'Otros' ? ivaItem.copyWith(categoria: dominantCat) : ivaItem,
          );
        } else {
          itemsList.add(ItemGastoModel(
            descripcion: 'Impuesto IVA',
            cantidad: 1.0,
            precioUnitario: ivaCents,
            total: ivaCents,
            categoria: dominantCat,
            origenCategoria: dominantCat != 'Otros' ? OrigenCategoria.ia : OrigenCategoria.predeterminada,
          ));
        }
        ivaModo = IvaModo.renglonSeparado;
      }
    }

    // Si quedó otro ítem fiscal (ej. IGTF) con categoría 'Otros', asignarle la categoría dominante
    for (int i = 0; i < itemsList.length; i++) {
      if (ItemGastoModel.isTaxDescription(itemsList[i].descripcion) && itemsList[i].categoria == 'Otros') {
        itemsList[i] = itemsList[i].copyWith(categoria: dominantCat);
      }
    }

    if (itemsList.isNotEmpty && totalOriginal == 0) {
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
      ivaModo: ivaModo,
      schemaVersion: currentSchemaVersion,
      hasSpecialLines: hasSpecialLines,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schema_v': schemaVersion,
      'iva_modo': ivaModo.name,
      if (hasSpecialLines) 'has_special_lines': true,
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
        'precio_unitario_cents': i.precioUnitario,
        'total': i.totalDisplay,
        'total_cents': i.total,
        'categoria': i.categoria,
        if (i.baseImponibleOriginal != null)
          'base_imponible_original_cents': i.baseImponibleOriginal,
        if (i.tasaIvaPct > 0) 'tasa_iva_pct': i.tasaIvaPct,
      }).toList(),
      'items_comprados_ids': matchedShoppingItemIds,
      'metodo_liquidacion': metodoLiquidacion,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}
