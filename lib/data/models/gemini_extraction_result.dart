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
    final validCategorias = AppConstants.categorias;

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

          itemsList.add(ItemGastoModel(
            id: rawId is num ? rawId.toInt() : null,
            gastoId: rawGastoId is num ? rawGastoId.toInt() : null,
            descripcion: desc,
            cantidad: cant,
            precioUnitario: precioCentavos,
            total: totalCentavos,
            categoria: catItem,
            origenCategoria: catItem != 'Otros' ? OrigenCategoria.ia : OrigenCategoria.predeterminada,
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
    final itemsList = <ItemGastoModel>[];
    final validCategorias = AppConstants.categorias;
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

          final alicuota = itemMap['alicuota_fiscal']?.toString().trim().toUpperCase();
          if (lineType == TipoLineaExtraccion.producto) {
            if (alicuota == 'E' && !desc.toUpperCase().contains('(E)')) {
              desc = '$desc (E)';
            } else if (alicuota == 'G' && !desc.toUpperCase().contains('(G)')) {
              desc = '$desc (G)';
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
            itemsList.add(parsedItem);
          }
        }
      }
    }

    // Categoría dominante de la factura para asignar al renglón de IVA (evitando inflar 'Otros')
    final String dominantCat = ItemGastoModel.calcularCategoriaDominante(itemsList);

    // Consolidar renglones de IVA explícitos de `items` con el campo `impuesto_iva`
    // garantizando que el IVA se contabilice una sola vez y nunca se confunda con
    // productos como "Aceite de oliva" o "Leche Nativa".
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

      for (final ivaItem in ivaLinesFromJson) {
        final normalizedIvaItem = ivaItem.categoria == 'Otros'
            ? ivaItem.copyWith(categoria: dominantCat)
            : ivaItem;
        itemsList.add(normalizedIvaItem);
      }
    } else if (impuestoIva > 0) {
      itemsList.add(ItemGastoModel(
        descripcion: 'Impuesto IVA',
        cantidad: 1.0,
        precioUnitario: (impuestoIva * 100).round(),
        total: (impuestoIva * 100).round(),
        categoria: dominantCat,
        origenCategoria: dominantCat != 'Otros' ? OrigenCategoria.ia : OrigenCategoria.predeterminada,
      ));
    }

    // Si la IA devolvió otro ítem fiscal (ej. IGTF) con categoría 'Otros', asignarle la dominante
    for (int i = 0; i < itemsList.length; i++) {
      if (ItemGastoModel.isTaxDescription(itemsList[i].descripcion) && itemsList[i].categoria == 'Otros') {
        itemsList[i] = itemsList[i].copyWith(categoria: dominantCat);
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

    // Determinar IvaModo explícito de esta extracción
    final bool hasIvaItemInList = itemsList.any((it) => ItemGastoModel.isIvaOnlyDescription(it.descripcion));
    final IvaModo ivaModo;
    if (hasMultipleConflictingIvaLines) {
      ivaModo = IvaModo.requiereRevision;
    } else if (hasIvaItemInList) {
      ivaModo = IvaModo.renglonSeparado;
    } else if (hasDeclaredIvaField && impuestoIva == 0.0) {
      ivaModo = IvaModo.sinIvaDeclarado;
    } else {
      ivaModo = IvaModo.noInformado;
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
      }).toList(),
      'items_comprados_ids': matchedShoppingItemIds,
      'metodo_liquidacion': metodoLiquidacion,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}
