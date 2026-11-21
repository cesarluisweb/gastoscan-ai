import '../../data/models/gemini_extraction_result.dart';
import '../../data/models/item_gasto_model.dart';

/// Resultado de preparar la sesión de revisión fiscal (B-2) al abrir
/// `ReviewExpenseScreen` desde una extracción escaneada o un borrador.
class SesionFiscalInicial {
  final bool activa;
  final int ivaDocumentalCents;
  final List<ItemGastoModel> items;

  /// Determina al cargar la pantalla si las tarjetas gravadas muestran el badge
  /// compacto (`G · 16%` / `R · 8%`). Se fija una sola vez al abrir para evitar
  /// saltos visuales al editar; se oculta en facturas homogéneas (100% gravadas).
  final bool mostrarBadgesEnTarjetas;

  const SesionFiscalInicial({
    required this.activa,
    required this.ivaDocumentalCents,
    required this.items,
    required this.mostrarBadgesEnTarjetas,
  });
}

/// Sugerencia puntual de corrección de alícuota para un único artículo sospechoso.
/// Nunca se aplica automáticamente: requiere confirmación explícita del usuario.
class SugerenciaCorreccionFiscal {
  final int itemIndex;
  final String descripcion;
  final int tasaActualPct;
  final int tasaSugeridaPct;
  final int ivaCalculadoNuevoCents;

  const SugerenciaCorreccionFiscal({
    required this.itemIndex,
    required this.descripcion,
    required this.tasaActualPct,
    required this.tasaSugeridaPct,
    required this.ivaCalculadoNuevoCents,
  });
}

/// Fotografía completa de la reconciliación fiscal en 3 pasos:
/// 1) IVA calculado vs IVA de la factura (con tolerancia de redondeo fiscal),
/// 2) Subtotal base + IVA vs Monto total de la factura,
/// 3) Suma bruta distribuida por Mayor Resto vs Monto total.
class EstadoReconciliacionFiscal {
  final int subtotalBaseCents;
  final int ivaCalculadoCents;
  final int ivaDocumentalCents;
  final int montoTotalCents;
  final bool anclaFiscalActiva;

  /// Cantidad de artículos marcados con `tasaIvaPct > 0` (para etiquetas UI).
  final int cantidadMarcadosGravados;

  /// Cantidad de artículos gravados con base > 0 (para tolerancia fiscal).
  final int cantidadGravadosConBase;
  final int cantidadExentos;
  final int toleranciaIvaCents;
  final int toleranciaTotalCents;

  final bool ivaCuadra;
  final bool totalCuadra;
  final bool sumaBrutaCuadra;
  final bool puedeGuardarImputado;

  final int ivaEfectivoDistribuidoCents;
  final int sumBrutoCents;
  final List<ItemGastoModel> itemsRecalculados;
  final SugerenciaCorreccionFiscal? sugerenciaUnica;

  const EstadoReconciliacionFiscal({
    required this.subtotalBaseCents,
    required this.ivaCalculadoCents,
    required this.ivaDocumentalCents,
    required this.montoTotalCents,
    required this.anclaFiscalActiva,
    required this.cantidadMarcadosGravados,
    required this.cantidadGravadosConBase,
    required this.cantidadExentos,
    required this.toleranciaIvaCents,
    required this.toleranciaTotalCents,
    required this.ivaCuadra,
    required this.totalCuadra,
    required this.sumaBrutaCuadra,
    required this.puedeGuardarImputado,
    required this.ivaEfectivoDistribuidoCents,
    required this.sumBrutoCents,
    required this.itemsRecalculados,
    required this.sugerenciaUnica,
  });

  /// Verdadero solo cuando el ancla del ticket está activa y pasan las 3 verificaciones.
  bool get cuadraConFactura => anclaFiscalActiva && ivaCuadra && totalCuadra && sumaBrutaCuadra;
}

/// Motor puro de reconciliación fiscal B-2 para `ReviewExpenseScreen`.
///
/// No modifica SQLite, Firestore ni el comparador: trabaja únicamente con los
/// campos en memoria de [ItemGastoModel] (`baseImponibleOriginal`, `baseTotalOriginal`,
/// `tasaIvaPct` y `origenAlicuota`).
class FiscalReconciliationHelper {
  FiscalReconciliationHelper._();

  static final RegExp _explicitFiscalSuffixRegex =
      RegExp(r'\([GERger]\)\s*$', caseSensitive: false);

  /// Evalúa si una extracción escaneada debe abrirse en modo de revisión fiscal B-2.
  ///
  /// - Activa B-2 para `IvaModo.imputado` con `impuestoIva > 0`.
  /// - También recupera facturas limpias en `IvaModo.renglonSeparado` (sin líneas
  ///   especiales ni IGTF, con un único renglón de IVA y `subtotal + IVA == total`)
  ///   cuando existen marcadores fiscales o un único artículo culpable detectable,
  ///   para permitir corregir errores puntuales `(G)/(E)` del OCR en 1 toque.
  static SesionFiscalInicial prepararSesionFiscal(GeminiExtractionResult? data) {
    if (data == null || data.items.isEmpty) {
      return SesionFiscalInicial(
        activa: false,
        ivaDocumentalCents: 0,
        items: List<ItemGastoModel>.from(data?.items ?? const []),
        mostrarBadgesEnTarjetas: false,
      );
    }

    final int ivaCents = (data.impuestoIva * 100).round();
    if (ivaCents <= 0) {
      return SesionFiscalInicial(
        activa: false,
        ivaDocumentalCents: 0,
        items: List<ItemGastoModel>.from(data.items),
        mostrarBadgesEnTarjetas: false,
      );
    }

    if (data.ivaModo == IvaModo.imputado) {
      final normalized = data.items.map((it) {
        if (it.tasaIvaPct > 0) {
          final baseUnit = it.baseUnitCents;
          final baseTotal = it.baseTotalCents;
          return it.copyWith(
            baseImponibleOriginal: baseUnit,
            baseTotalOriginal: baseTotal,
            tasaIvaPct: it.tasaIvaPct,
          );
        }
        return it;
      }).toList();

      final int totalCents = (data.totalOriginal * 100).round();
      final estado = reconciliar(
        items: normalized,
        ivaDocumentalCents: ivaCents,
        montoTotalCents: totalCents,
        anclaFiscalActiva: true,
      );
      final bool hasExempt = estado.itemsRecalculados.any((it) => it.tasaIvaPct == 0);
      return SesionFiscalInicial(
        activa: true,
        ivaDocumentalCents: ivaCents,
        items: estado.itemsRecalculados,
        mostrarBadgesEnTarjetas: hasExempt,
      );
    }

    if (data.ivaModo == IvaModo.renglonSeparado && !data.hasSpecialLines) {
      final ivaRows = <ItemGastoModel>[];
      final productRows = <ItemGastoModel>[];
      for (final it in data.items) {
        if (ItemGastoModel.isIvaOnlyDescription(it.descripcion)) {
          ivaRows.add(it);
        } else if (ItemGastoModel.isTaxDescription(it.descripcion)) {
          // Otro impuesto (ej. IGTF): no activar B-2 automático.
          return SesionFiscalInicial(
            activa: false,
            ivaDocumentalCents: 0,
            items: List<ItemGastoModel>.from(data.items),
            mostrarBadgesEnTarjetas: false,
          );
        } else {
          productRows.add(it);
        }
      }

      if (ivaRows.length == 1 && productRows.isNotEmpty) {
        final int ivaRowCents = ivaRows.first.total > 0 ? ivaRows.first.total : ivaCents;
        final int totalCents = (data.totalOriginal * 100).round();
        final int sumBases = productRows.fold<int>(0, (s, it) => s + it.total);
        final int guardTol = GeminiExtractionResult.guardToleranceCents(productRows);

        if (ivaRowCents > 0 &&
            totalCents > 0 &&
            ((sumBases + ivaRowCents) - totalCents).abs() <= guardTol) {
          bool hasAnyFiscalHint = false;
          final lifted = <ItemGastoModel>[];
          for (final it in productRows) {
            final bool hasSuffix = _explicitFiscalSuffixRegex.hasMatch(it.descripcion);
            int rate = it.tasaIvaPct;
            if (rate <= 0) {
              if (ItemGastoModel.hasGravadoSuffix(it.descripcion)) {
                rate = 16;
              } else if (ItemGastoModel.hasReducidoSuffix(it.descripcion)) {
                rate = 8;
              }
            }
            if (hasSuffix || rate > 0) {
              hasAnyFiscalHint = true;
            }
            final cleanDesc = ItemGastoModel.stripFiscalSuffix(it.descripcion);
            final finalDesc = cleanDesc.isNotEmpty ? cleanDesc : it.descripcion;
            if (rate > 0) {
              lifted.add(it.copyWith(
                descripcion: finalDesc,
                baseImponibleOriginal: it.precioUnitario,
                baseTotalOriginal: it.total,
                tasaIvaPct: rate,
                origenAlicuota: OrigenAlicuota.ia,
              ));
            } else {
              lifted.add(it.copyWith(
                descripcion: finalDesc,
                clearBaseImponibleOriginal: true,
                origenAlicuota: OrigenAlicuota.ia,
              ));
            }
          }

          final estado = reconciliar(
            items: lifted,
            ivaDocumentalCents: ivaRowCents,
            montoTotalCents: totalCents,
            anclaFiscalActiva: true,
          );

          if (hasAnyFiscalHint || estado.sugerenciaUnica != null) {
            final bool hasExempt = estado.itemsRecalculados.any((it) => it.tasaIvaPct == 0);
            return SesionFiscalInicial(
              activa: true,
              ivaDocumentalCents: ivaRowCents,
              items: estado.itemsRecalculados,
              mostrarBadgesEnTarjetas: hasExempt,
            );
          }
        }
      }
    }

    return SesionFiscalInicial(
      activa: false,
      ivaDocumentalCents: 0,
      items: List<ItemGastoModel>.from(data.items),
      mostrarBadgesEnTarjetas: false,
    );
  }

  /// Calcula el IVA esperado en centavos a partir de bases de línea y tasas porcentuales
  /// usando aritmética [BigInt] sin desbordamiento (redondeo half-up).
  static int calcularIvaEsperadoCents(List<int> baseTotals, List<int> tasasPct) {
    BigInt weightedSum = BigInt.zero;
    for (int i = 0; i < baseTotals.length; i++) {
      final int b = baseTotals[i];
      final int r = i < tasasPct.length ? tasasPct[i] : 0;
      if (b > 0 && r > 0) {
        weightedSum += BigInt.from(b) * BigInt.from(r);
      }
    }
    if (weightedSum <= BigInt.zero) return 0;
    return ((weightedSum + BigInt.from(50)) ~/ BigInt.from(100)).toInt();
  }

  /// Ejecuta la reconciliación fiscal global de toda la factura:
  /// - Recalcula IVA esperado y verifica tolerancia fiscal estricta.
  /// - Verifica el cuadre con [montoTotalCents].
  /// - Distribuye los centavos de IVA por Mayor Resto (`BigInt`) sin perder
  ///   [ItemGastoModel.origenAlicuota] ni la marca fiscal de ítems en edición.
  /// - Busca si existe un único artículo candidato que reconcilie un descuadre de IVA.
  static EstadoReconciliacionFiscal reconciliar({
    required List<ItemGastoModel> items,
    required int ivaDocumentalCents,
    required int montoTotalCents,
    required bool anclaFiscalActiva,
    bool habilitarSugerencia = true,
  }) {
    final baseUnits = <int>[];
    final baseTotals = <int>[];
    final tasasPct = <int>[];

    int subtotalBaseCents = 0;
    int cantidadMarcadosGravados = 0;
    int cantidadGravadosConBase = 0;
    int cantidadExentos = 0;

    for (final it in items) {
      final int bUnit = it.baseUnitCents.clamp(0, 100000000000);
      final int bTotal = it.baseTotalCents.clamp(0, 100000000000);
      final int rate = it.tasaIvaPct.clamp(0, 100);
      baseUnits.add(bUnit);
      baseTotals.add(bTotal);
      tasasPct.add(rate);
      subtotalBaseCents += bTotal;
      if (rate > 0) {
        cantidadMarcadosGravados++;
        if (bTotal > 0) cantidadGravadosConBase++;
      } else {
        cantidadExentos++;
      }
    }

    final int ivaCalculadoCents = calcularIvaEsperadoCents(baseTotals, tasasPct);
    final int tolIva = GeminiExtractionResult.fiscalRateToleranceCents(cantidadGravadosConBase);
    final int tolTotal = GeminiExtractionResult.guardToleranceCents(items);

    final bool hasAnchor = anclaFiscalActiva && ivaDocumentalCents > 0;
    final bool ivaCuadra = hasAnchor
        ? (cantidadGravadosConBase > 0 &&
            (ivaCalculadoCents - ivaDocumentalCents).abs() <= tolIva)
        : true;

    final int ivaEfectivoDistribuidoCents =
        (hasAnchor && ivaCuadra) ? ivaDocumentalCents : ivaCalculadoCents;

    final List<int> shares = GeminiExtractionResult.repartirIvaMayorResto(
      baseTotals,
      tasasPct,
      ivaEfectivoDistribuidoCents,
    );

    final recalculated = <ItemGastoModel>[];
    int sumBrutoCents = 0;
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      final int rate = tasasPct[i];
      final int bUnit = baseUnits[i];
      final int bTotal = baseTotals[i];
      if (rate > 0) {
        final int grossTotal = bTotal + shares[i];
        final int grossUnit = bUnit > 0 ? ((bUnit * (100 + rate) + 50) ~/ 100) : 0;
        sumBrutoCents += grossTotal;
        recalculated.add(it.copyWith(
          precioUnitario: grossUnit,
          total: grossTotal,
          baseImponibleOriginal: bUnit,
          baseTotalOriginal: bTotal,
          tasaIvaPct: rate,
        ));
      } else {
        sumBrutoCents += bTotal;
        recalculated.add(it.copyWith(
          precioUnitario: bUnit,
          total: bTotal,
          clearBaseImponibleOriginal: true,
        ));
      }
    }

    final bool totalCuadra = hasAnchor
        ? (montoTotalCents > 0 &&
            ((subtotalBaseCents + ivaDocumentalCents) - montoTotalCents).abs() <= tolTotal)
        : (montoTotalCents > 0 && (sumBrutoCents - montoTotalCents).abs() <= tolTotal);

    final bool sumaBrutaCuadra =
        montoTotalCents > 0 && (sumBrutoCents - montoTotalCents).abs() <= tolTotal;

    final bool puedeGuardarImputado = hasAnchor
        ? (ivaCuadra && totalCuadra && sumaBrutaCuadra)
        : (totalCuadra && sumaBrutaCuadra);

    SugerenciaCorreccionFiscal? sugerencia;
    if (habilitarSugerencia && hasAnchor && !ivaCuadra && totalCuadra) {
      sugerencia = sugerirCorreccionUnica(
        items: recalculated,
        ivaDocumentalCents: ivaDocumentalCents,
        montoTotalCents: montoTotalCents,
        anclaFiscalActiva: anclaFiscalActiva,
      );
    }

    return EstadoReconciliacionFiscal(
      subtotalBaseCents: subtotalBaseCents,
      ivaCalculadoCents: ivaCalculadoCents,
      ivaDocumentalCents: ivaDocumentalCents,
      montoTotalCents: montoTotalCents,
      anclaFiscalActiva: hasAnchor,
      cantidadMarcadosGravados: cantidadMarcadosGravados,
      cantidadGravadosConBase: cantidadGravadosConBase,
      cantidadExentos: cantidadExentos,
      toleranciaIvaCents: tolIva,
      toleranciaTotalCents: tolTotal,
      ivaCuadra: ivaCuadra,
      totalCuadra: totalCuadra,
      sumaBrutaCuadra: sumaBrutaCuadra,
      puedeGuardarImputado: puedeGuardarImputado,
      ivaEfectivoDistribuidoCents: ivaEfectivoDistribuidoCents,
      sumBrutoCents: sumBrutoCents,
      itemsRecalculados: recalculated,
      sugerenciaUnica: sugerencia,
    );
  }

  /// Devuelve todos los cambios de un solo artículo que reconcilian el IVA
  /// documental dentro de [GeminiExtractionResult.fiscalRateToleranceCents].
  ///
  /// Expuesto como función pura para auditoría y pruebas de propiedades.
  static List<SugerenciaCorreccionFiscal> buscarCandidatosCorreccion({
    required List<ItemGastoModel> items,
    required int ivaDocumentalCents,
    required int montoTotalCents,
    required bool anclaFiscalActiva,
    bool incluirTasaReducida = false,
  }) {
    if (!anclaFiscalActiva || ivaDocumentalCents <= 0 || items.isEmpty) {
      return const [];
    }

    final baseTotals = items.map((it) => it.baseTotalCents.clamp(0, 100000000000)).toList();
    final tasasActuales = items.map((it) => it.tasaIvaPct.clamp(0, 100)).toList();
    final int subtotalBaseCents = baseTotals.fold<int>(0, (a, b) => a + b);
    final int tolTotal = GeminiExtractionResult.guardToleranceCents(items);

    if (montoTotalCents > 0 &&
        ((subtotalBaseCents + ivaDocumentalCents) - montoTotalCents).abs() > tolTotal) {
      return const [];
    }

    int taxedActual = 0;
    for (int i = 0; i < items.length; i++) {
      if (tasasActuales[i] > 0 && baseTotals[i] > 0) taxedActual++;
    }
    final int ivaActual = calcularIvaEsperadoCents(baseTotals, tasasActuales);
    final int tolActual = GeminiExtractionResult.fiscalRateToleranceCents(taxedActual);
    if (taxedActual > 0 && (ivaActual - ivaDocumentalCents).abs() <= tolActual) {
      return const [];
    }

    final bool evaluarTasa8 = incluirTasaReducida || tasasActuales.contains(8);
    final List<int> tasasObjetivo = evaluarTasa8 ? const [0, 16, 8] : const [0, 16];

    final candidatos = <SugerenciaCorreccionFiscal>[];
    for (int i = 0; i < items.length; i++) {
      if (baseTotals[i] <= 0) continue;
      final int currentRate = tasasActuales[i];
      for (final int candidateRate in tasasObjetivo) {
        if (candidateRate == currentRate) continue;
        final simRates = List<int>.from(tasasActuales);
        simRates[i] = candidateRate;
        int simTaxed = 0;
        for (int j = 0; j < simRates.length; j++) {
          if (simRates[j] > 0 && baseTotals[j] > 0) simTaxed++;
        }
        if (simTaxed == 0) continue;
        final int simIva = calcularIvaEsperadoCents(baseTotals, simRates);
        final int tol = GeminiExtractionResult.fiscalRateToleranceCents(simTaxed);
        if ((simIva - ivaDocumentalCents).abs() <= tol) {
          candidatos.add(SugerenciaCorreccionFiscal(
            itemIndex: i,
            descripcion: items[i].descripcion,
            tasaActualPct: currentRate,
            tasaSugeridaPct: candidateRate,
            ivaCalculadoNuevoCents: simIva,
          ));
        }
      }
    }

    return candidatos;
  }

  /// Devuelve una sugerencia únicamente cuando existe **exactamente un** candidato
  /// matemático que reconcilia el IVA. Si hay 0 o más de 1 (empate), retorna `null`.
  static SugerenciaCorreccionFiscal? sugerirCorreccionUnica({
    required List<ItemGastoModel> items,
    required int ivaDocumentalCents,
    required int montoTotalCents,
    required bool anclaFiscalActiva,
    bool incluirTasaReducida = false,
  }) {
    final candidatos = buscarCandidatosCorreccion(
      items: items,
      ivaDocumentalCents: ivaDocumentalCents,
      montoTotalCents: montoTotalCents,
      anclaFiscalActiva: anclaFiscalActiva,
      incluirTasaReducida: incluirTasaReducida,
    );
    return candidatos.length == 1 ? candidatos.first : null;
  }

  /// Construye la lista de ítems del fallback seguro (`renglonSeparado`) cuando
  /// el usuario confirma guardar una factura cuyo IVA no cuadra:
  /// - Cada producto queda en precio base (sin IVA) y con sufijo `(G)`/`(R)`/`(E)`
  ///   reflejando su estado actual de clasificación (incluidas correcciones manuales).
  /// - El renglón `Impuesto IVA` recibe la categoría dominante calculada excluyendo
  ///   renglones fiscales (`ItemGastoModel.calcularCategoriaDominante`).
  static List<ItemGastoModel> construirItemsFallback({
    required List<ItemGastoModel> items,
    required int ivaCents,
    bool fillEmptyNames = true,
  }) {
    int unnamedCounter = 1;
    final productFallbacks = <ItemGastoModel>[];
    for (final it in items) {
      if (ItemGastoModel.isIvaOnlyDescription(it.descripcion)) continue;
      final trimmed = it.descripcion.trim();
      final String taggedDesc;
      if (trimmed.isEmpty) {
        taggedDesc = fillEmptyNames
            ? ItemGastoModel.withFiscalSuffix('Artículo ${unnamedCounter++}', it.tasaIvaPct)
            : '';
      } else {
        taggedDesc = ItemGastoModel.withFiscalSuffix(trimmed, it.tasaIvaPct);
      }
      final baseFallback = it.copyWith(
        descripcion: taggedDesc,
        precioUnitario: it.baseUnitCents,
        total: it.baseTotalCents,
        clearBaseImponibleOriginal: true,
      );
      productFallbacks.add(
        (trimmed.isEmpty && !fillEmptyNames && it.tasaIvaPct > 0)
            ? baseFallback.copyWith(tasaIvaPct: it.tasaIvaPct)
            : baseFallback,
      );
    }

    if (ivaCents > 0) {
      final String dominantCat = ItemGastoModel.calcularCategoriaDominante(productFallbacks);
      productFallbacks.add(ItemGastoModel(
        descripcion: 'Impuesto IVA',
        cantidad: 1.0,
        precioUnitario: ivaCents,
        total: ivaCents,
        categoria: dominantCat,
        origenCategoria:
            dominantCat != 'Otros' ? OrigenCategoria.ia : OrigenCategoria.predeterminada,
      ));
    }

    return productFallbacks;
  }
}
