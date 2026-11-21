import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gemini_extraction_result.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/domain/finance/fiscal_reconciliation_helper.dart';

void main() {
  group('ItemGastoModel contrato SQLite y sufijos fiscales', () {
    test('toMap conserva exactamente las 7 columnas SQLite sin metadatos fiscales en memoria', () {
      final item = ItemGastoModel(
        id: 1,
        gastoId: 10,
        descripcion: 'Detergente Líquido',
        cantidad: 0.31,
        precioUnitario: 30000,
        total: 9301,
        categoria: 'Hogar',
        baseImponibleOriginal: 25862,
        baseTotalOriginal: 8017,
        tasaIvaPct: 16,
        origenAlicuota: OrigenAlicuota.manual,
      );

      final map = item.toMap();
      expect(
        map.keys.toSet(),
        equals({'id', 'gasto_id', 'descripcion', 'cantidad', 'precio_unitario', 'total', 'categoria'}),
      );
      expect(map.containsKey('base_imponible_original'), isFalse);
      expect(map.containsKey('base_total_original'), isFalse);
      expect(map.containsKey('tasa_iva_pct'), isFalse);
      expect(map.containsKey('origen_alicuota'), isFalse);
    });

    test('withFiscalSuffix aplica (G)/(R)/(E) sin duplicar sufijos previos', () {
      expect(ItemGastoModel.withFiscalSuffix('Detergente (E)', 16), equals('Detergente (G)'));
      expect(ItemGastoModel.withFiscalSuffix('Panadería', 8), equals('Panadería (R)'));
      expect(ItemGastoModel.withFiscalSuffix('Harina PAN (G)', 0), equals('Harina PAN (E)'));
    });
  });

  group('FiscalReconciliationHelper.prepararSesionFiscal', () {
    test('No activa modo fiscal B-2 en facturas sin IVA, yaIncluido o con líneas especiales', () {
      final sinIva = GeminiExtractionResult(
        comercio: 'Abasto',
        fecha: '2026-11-20',
        moneda: 'VES',
        totalOriginal: 110.0,
        impuestoIva: 0.0,
        ivaModo: IvaModo.sinIvaDeclarado,
        items: [
          ItemGastoModel(descripcion: 'Harina', cantidad: 1, precioUnitario: 11000, total: 11000),
        ],
      );
      expect(FiscalReconciliationHelper.prepararSesionFiscal(sinIva).activa, isFalse);

      final yaIncluido = GeminiExtractionResult(
        comercio: 'Restaurante',
        fecha: '2026-11-20',
        moneda: 'VES',
        totalOriginal: 300.0,
        impuestoIva: 41.38,
        ivaModo: IvaModo.yaIncluido,
        items: [
          ItemGastoModel(descripcion: 'Almuerzo', cantidad: 1, precioUnitario: 30000, total: 30000),
        ],
      );
      expect(FiscalReconciliationHelper.prepararSesionFiscal(yaIncluido).activa, isFalse);

      final conIgtf = GeminiExtractionResult(
        comercio: 'Ferretería',
        fecha: '2026-11-20',
        moneda: 'USD',
        totalOriginal: 119.0,
        impuestoIva: 16.0,
        ivaModo: IvaModo.renglonSeparado,
        hasSpecialLines: true,
        items: [
          ItemGastoModel(descripcion: 'Taladro (G)', cantidad: 1, precioUnitario: 10000, total: 10000),
          ItemGastoModel(descripcion: 'Impuesto IVA', cantidad: 1, precioUnitario: 1600, total: 1600),
          ItemGastoModel(descripcion: 'IGTF 3%', cantidad: 1, precioUnitario: 300, total: 300),
        ],
      );
      expect(FiscalReconciliationHelper.prepararSesionFiscal(conIgtf).activa, isFalse);
    });

    test('Activa B-2 con badges visibles en factura mixta y badges ocultos en factura homogénea 100% gravada', () {
      final mixta = GeminiExtractionResult.fromJson({
        'comercio': 'Supermercado',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 410.0,
        'impuesto_iva': 41.38,
        'items': [
          {'descripcion': 'Detergente', 'cantidad': 1, 'precio_unitario': 258.62, 'alicuota_fiscal': 'G', 'categoria': 'Hogar'},
          {'descripcion': 'Harina PAN', 'cantidad': 1, 'precio_unitario': 110.0, 'alicuota_fiscal': 'E', 'categoria': 'Alimentación'},
        ],
      });
      final sesionMixta = FiscalReconciliationHelper.prepararSesionFiscal(mixta);
      expect(sesionMixta.activa, isTrue);
      expect(sesionMixta.mostrarBadgesEnTarjetas, isTrue);
      expect(sesionMixta.ivaDocumentalCents, equals(4138));

      final homogenea = GeminiExtractionResult.fromJson({
        'comercio': 'Farmacia',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 348.0,
        'impuesto_iva': 48.0,
        'items': [
          {'descripcion': 'Shampoo', 'cantidad': 1, 'precio_unitario': 180.0, 'alicuota_fiscal': 'G', 'categoria': 'Cuidado Personal'},
          {'descripcion': 'Desodorante', 'cantidad': 1, 'precio_unitario': 120.0, 'alicuota_fiscal': 'G', 'categoria': 'Cuidado Personal'},
        ],
      });
      final sesionHomo = FiscalReconciliationHelper.prepararSesionFiscal(homogenea);
      expect(sesionHomo.activa, isTrue);
      expect(sesionHomo.mostrarBadgesEnTarjetas, isFalse);
    });

    test('Recupera renglonSeparado limpio con error OCR de 1 artículo y sugiere corrección única', () {
      final conErrorOcr = GeminiExtractionResult.fromJson({
        'comercio': 'Automercado Plaza',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 410.0,
        'impuesto_iva': 41.38,
        'items': [
          // Error OCR: Detergente marcado como E cuando realmente es G
          {'descripcion': 'Detergente Líquido', 'cantidad': 1, 'precio_unitario': 258.62, 'alicuota_fiscal': 'E', 'categoria': 'Hogar'},
          {'descripcion': 'Harina PAN', 'cantidad': 1, 'precio_unitario': 110.0, 'alicuota_fiscal': 'E', 'categoria': 'Alimentación'},
        ],
      });
      expect(conErrorOcr.ivaModo, equals(IvaModo.renglonSeparado));

      final sesion = FiscalReconciliationHelper.prepararSesionFiscal(conErrorOcr);
      expect(sesion.activa, isTrue);
      expect(sesion.items.length, equals(2));
      expect(sesion.items.any((i) => ItemGastoModel.isIvaOnlyDescription(i.descripcion)), isFalse);

      final estado = FiscalReconciliationHelper.reconciliar(
        items: sesion.items,
        ivaDocumentalCents: sesion.ivaDocumentalCents,
        montoTotalCents: 41000,
        anclaFiscalActiva: true,
      );
      expect(estado.ivaCuadra, isFalse);
      expect(estado.puedeGuardarImputado, isFalse);
      expect(estado.sugerenciaUnica, isNotNull);
      expect(estado.sugerenciaUnica!.itemIndex, equals(0));
      expect(estado.sugerenciaUnica!.tasaSugeridaPct, equals(16));
    });
  });

  group('FiscalReconciliationHelper.reconciliar (3 verificaciones y ancla)', () {
    test('No reporta cuadraConFactura si el IVA coincide pero un precio exento descuadra el total', () {
      final items = [
        ItemGastoModel(
          descripcion: 'Detergente',
          cantidad: 1,
          precioUnitario: 30000,
          total: 30000,
          baseImponibleOriginal: 25862,
          baseTotalOriginal: 25862,
          tasaIvaPct: 16,
        ),
        // Usuario editó Harina de 110 a 150 sin tocar Monto total (410)
        ItemGastoModel(
          descripcion: 'Harina PAN',
          cantidad: 1,
          precioUnitario: 15000,
          total: 15000,
        ),
      ];

      final estado = FiscalReconciliationHelper.reconciliar(
        items: items,
        ivaDocumentalCents: 4138,
        montoTotalCents: 41000,
        anclaFiscalActiva: true,
      );

      expect(estado.ivaCuadra, isTrue);
      expect(estado.totalCuadra, isFalse);
      expect(estado.cuadraConFactura, isFalse);
      expect(estado.puedeGuardarImputado, isFalse);
      // No sugiere cambio G/E cuando el problema es el precio total
      expect(estado.sugerenciaUnica, isNull);
    });

    test('Invalidar el ancla cambia a IVA calculado y nunca reporta cuadraConFactura', () {
      final items = [
        ItemGastoModel(
          descripcion: 'Detergente',
          cantidad: 1,
          precioUnitario: 30000,
          total: 30000,
          baseImponibleOriginal: 25862,
          baseTotalOriginal: 25862,
          tasaIvaPct: 16,
          origenAlicuota: OrigenAlicuota.manual,
        ),
        ItemGastoModel(
          descripcion: 'Harina PAN',
          cantidad: 1,
          precioUnitario: 15000,
          total: 15000,
        ),
      ];

      final estadoCuadrado = FiscalReconciliationHelper.reconciliar(
        items: items,
        ivaDocumentalCents: 4138,
        montoTotalCents: 45000,
        anclaFiscalActiva: false,
      );
      expect(estadoCuadrado.anclaFiscalActiva, isFalse);
      expect(estadoCuadrado.cuadraConFactura, isFalse);
      expect(estadoCuadrado.totalCuadra, isTrue);
      expect(estadoCuadrado.puedeGuardarImputado, isTrue);
      expect(estadoCuadrado.itemsRecalculados[0].origenAlicuota, equals(OrigenAlicuota.manual));

      final estadoDescuadrado = FiscalReconciliationHelper.reconciliar(
        items: items,
        ivaDocumentalCents: 4138,
        montoTotalCents: 50000,
        anclaFiscalActiva: false,
      );
      expect(estadoDescuadrado.totalCuadra, isFalse);
      expect(estadoDescuadrado.puedeGuardarImputado, isFalse);
    });

    test('Mayor Resto distribuye exacto al centavo con cantidad fraccionaria 0.31 kg', () {
      final items = [
        ItemGastoModel(
          descripcion: 'Detergente a granel',
          cantidad: 0.31,
          precioUnitario: 25862,
          total: 8017,
          baseImponibleOriginal: 25862,
          baseTotalOriginal: 8017,
          tasaIvaPct: 16,
        ),
        ItemGastoModel(
          descripcion: 'Harina PAN',
          cantidad: 1,
          precioUnitario: 11000,
          total: 11000,
        ),
      ];
      // 8017 * 16% = 1282.72 -> 1283 centavos; total = 8017 + 11000 + 1283 = 20300
      final estado = FiscalReconciliationHelper.reconciliar(
        items: items,
        ivaDocumentalCents: 1283,
        montoTotalCents: 20300,
        anclaFiscalActiva: true,
      );

      expect(estado.cuadraConFactura, isTrue);
      expect(estado.sumBrutoCents, equals(20300));
      expect(estado.itemsRecalculados[0].total, equals(9300));
      expect(estado.itemsRecalculados[0].baseTotalCents, equals(8017));
      expect(estado.itemsRecalculados[1].total, equals(11000));
    });
  });

  group('FiscalReconciliationHelper.sugerirCorreccionUnica y test de propiedades', () {
    test('Detecta flip G->E con cantidad > 1 usando base total de línea', () {
      final items = [
        ItemGastoModel(
          descripcion: 'Refresco',
          cantidad: 3,
          precioUnitario: 10000,
          total: 30000,
          baseImponibleOriginal: 10000,
          baseTotalOriginal: 30000,
          tasaIvaPct: 16,
        ),
        ItemGastoModel(
          descripcion: 'Jabón',
          cantidad: 2,
          precioUnitario: 5000,
          total: 10000,
          baseImponibleOriginal: 5000,
          baseTotalOriginal: 10000,
          tasaIvaPct: 16,
        ),
      ];
      // IVA documental solo corresponde a Jabón (100 * 16% = 16.00 = 1600 cents)
      final sug = FiscalReconciliationHelper.sugerirCorreccionUnica(
        items: items,
        ivaDocumentalCents: 1600,
        montoTotalCents: 41600,
        anclaFiscalActiva: true,
      );
      expect(sug, isNotNull);
      expect(sug!.itemIndex, equals(0));
      expect(sug.tasaActualPct, equals(16));
      expect(sug.tasaSugeridaPct, equals(0));
    });

    test('Empate: dos artículos con la misma base dejan sugerirCorreccionUnica en null', () {
      final items = [
        ItemGastoModel(descripcion: 'Producto A', cantidad: 1, precioUnitario: 10000, total: 10000),
        ItemGastoModel(descripcion: 'Producto B', cantidad: 1, precioUnitario: 10000, total: 10000),
      ];
      final cands = FiscalReconciliationHelper.buscarCandidatosCorreccion(
        items: items,
        ivaDocumentalCents: 1600,
        montoTotalCents: 21600,
        anclaFiscalActiva: true,
      );
      expect(cands.length, equals(2));
      final sug = FiscalReconciliationHelper.sugerirCorreccionUnica(
        items: items,
        ivaDocumentalCents: 1600,
        montoTotalCents: 21600,
        anclaFiscalActiva: true,
      );
      expect(sug, isNull);
    });

    test('Errores que se compensan (G->E y E->G con igual base): chequeo pasa y detector no sugiere', () {
      final items = [
        // Realmente era G, marcado E
        ItemGastoModel(descripcion: 'Jabón', cantidad: 1, precioUnitario: 10000, total: 10000),
        // Realmente era E, marcado G
        ItemGastoModel(
          descripcion: 'Arroz',
          cantidad: 1,
          precioUnitario: 11600,
          total: 11600,
          baseImponibleOriginal: 10000,
          baseTotalOriginal: 10000,
          tasaIvaPct: 16,
        ),
      ];
      final estado = FiscalReconciliationHelper.reconciliar(
        items: items,
        ivaDocumentalCents: 1600,
        montoTotalCents: 21600,
        anclaFiscalActiva: true,
      );
      expect(estado.cuadraConFactura, isTrue);
      expect(estado.sugerenciaUnica, isNull);
    });

    test('Propiedad: en 120 facturas sintéticas con 1 etiqueta invertida, el culpable siempre aparece entre los candidatos', () {
      final rng = Random(20261121);
      int totalEvaluadas = 0;
      int sugerenciasUnicas = 0;
      int empatesSilenciados = 0;

      for (int trial = 0; trial < 120; trial++) {
        final int n = 3 + rng.nextInt(10); // 3 a 12 artículos
        final trueRates = <int>[];
        final itemsOriginales = <ItemGastoModel>[];

        for (int i = 0; i < n; i++) {
          final int baseUnit = (25 + rng.nextInt(950)) * 100 + rng.nextInt(100);
          final double qty = rng.nextInt(4) == 0 ? (25 + rng.nextInt(175)) / 100.0 : (1 + rng.nextInt(3)).toDouble();
          final int baseTotal = (baseUnit * qty).round();
          final int rate = rng.nextBool() ? 16 : 0;
          trueRates.add(rate);
          itemsOriginales.add(ItemGastoModel(
            descripcion: 'Item $i',
            cantidad: qty,
            precioUnitario: baseUnit,
            total: baseTotal,
            baseImponibleOriginal: rate > 0 ? baseUnit : null,
            baseTotalOriginal: rate > 0 ? baseTotal : null,
            tasaIvaPct: rate,
          ));
        }

        // Asegurar al menos 1 gravado real para que exista IVA documental > 0
        if (!trueRates.contains(16)) {
          trueRates[0] = 16;
          final it0 = itemsOriginales[0];
          itemsOriginales[0] = it0.copyWith(
            baseImponibleOriginal: it0.precioUnitario,
            baseTotalOriginal: it0.total,
            tasaIvaPct: 16,
          );
        }

        final bases = itemsOriginales.map((it) => it.baseTotalCents).toList();
        final int subtotal = bases.fold<int>(0, (a, b) => a + b);
        final int ivaDoc = FiscalReconciliationHelper.calcularIvaEsperadoCents(bases, trueRates);
        if (ivaDoc <= 0) continue;
        final int totalDoc = subtotal + ivaDoc;

        // Invertir aleatoriamente la etiqueta de un único artículo
        final int flipIdx = rng.nextInt(n);
        final int flippedRate = trueRates[flipIdx] == 16 ? 0 : 16;
        final itemsCorrompidos = List<ItemGastoModel>.from(itemsOriginales);
        final target = itemsCorrompidos[flipIdx];
        itemsCorrompidos[flipIdx] = flippedRate > 0
            ? target.copyWith(
                baseImponibleOriginal: target.baseUnitCents,
                baseTotalOriginal: target.baseTotalCents,
                tasaIvaPct: 16,
              )
            : target.copyWith(
                precioUnitario: target.baseUnitCents,
                total: target.baseTotalCents,
                clearBaseImponibleOriginal: true,
              );

        final estado = FiscalReconciliationHelper.reconciliar(
          items: itemsCorrompidos,
          ivaDocumentalCents: ivaDoc,
          montoTotalCents: totalDoc,
          anclaFiscalActiva: true,
        );
        if (estado.ivaCuadra) {
          // Base tan pequeña que cayó dentro de la tolerancia fiscal
          continue;
        }

        totalEvaluadas++;
        final cands = FiscalReconciliationHelper.buscarCandidatosCorreccion(
          items: itemsCorrompidos,
          ivaDocumentalCents: ivaDoc,
          montoTotalCents: totalDoc,
          anclaFiscalActiva: true,
        );

        // Propiedad fundamental: el ítem invertido SIEMPRE está entre los candidatos
        expect(
          cands.any((c) => c.itemIndex == flipIdx && c.tasaSugeridaPct == trueRates[flipIdx]),
          isTrue,
          reason: 'Trial $trial: el ítem $flipIdx no apareció en candidatos',
        );

        if (cands.length == 1) {
          sugerenciasUnicas++;
          expect(estado.sugerenciaUnica, isNotNull);
          expect(estado.sugerenciaUnica!.itemIndex, equals(flipIdx));
          expect(estado.sugerenciaUnica!.tasaSugeridaPct, equals(trueRates[flipIdx]));
        } else {
          empatesSilenciados++;
          expect(estado.sugerenciaUnica, isNull);
        }
      }

      expect(totalEvaluadas, greaterThan(100));
      expect(sugerenciasUnicas, greaterThan(0));
      expect(sugerenciasUnicas + empatesSilenciados, equals(totalEvaluadas));
    });
  });

  group('FiscalReconciliationHelper.construirItemsFallback', () {
    test('Restaura sufijos (G)/(R)/(E) según estado actual, devuelve bases y asigna dominante al IVA', () {
      final items = [
        ItemGastoModel(
          descripcion: 'Detergente',
          cantidad: 1,
          precioUnitario: 30000,
          total: 30000,
          categoria: 'Hogar',
          baseImponibleOriginal: 25862,
          baseTotalOriginal: 25862,
          tasaIvaPct: 16,
          origenAlicuota: OrigenAlicuota.manual,
        ),
        ItemGastoModel(
          descripcion: 'Panadería',
          cantidad: 1,
          precioUnitario: 10800,
          total: 10800,
          categoria: 'Alimentación',
          baseImponibleOriginal: 10000,
          baseTotalOriginal: 10000,
          tasaIvaPct: 8,
        ),
        ItemGastoModel(
          descripcion: 'Harina PAN',
          cantidad: 2,
          precioUnitario: 11000,
          total: 22000,
          categoria: 'Alimentación',
        ),
      ];

      final fallback = FiscalReconciliationHelper.construirItemsFallback(
        items: items,
        ivaCents: 4938,
      );

      expect(fallback.length, equals(4));
      expect(fallback[0].descripcion, equals('Detergente (G)'));
      expect(fallback[0].precioUnitario, equals(25862));
      expect(fallback[0].total, equals(25862));
      expect(fallback[0].baseImponibleOriginal, isNull);
      expect(fallback[1].descripcion, equals('Panadería (R)'));
      expect(fallback[1].total, equals(10000));
      expect(fallback[2].descripcion, equals('Harina PAN (E)'));
      expect(fallback[2].total, equals(22000));
      // Categoría dominante excluyendo renglón fiscal: Alimentación (32000) > Hogar (25862)
      expect(fallback[3].descripcion, equals('Impuesto IVA'));
      expect(fallback[3].total, equals(4938));
      expect(fallback[3].categoria, equals('Alimentación'));
    });
  });
}
