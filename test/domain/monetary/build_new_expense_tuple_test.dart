import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/domain/monetary/expense_tuple.dart';
import 'package:gastoscan_ai/domain/monetary/metodo_liquidacion.dart';
import 'package:gastoscan_ai/domain/monetary/rate_market.dart';
import 'package:gastoscan_ai/domain/monetary/rate_quote_input.dart';

void main() {
  group('buildNewExpenseTuple (T-63 y Casos Normativos RM-03 v1.2)', () {
    const validFecha = '2026-10-31';

    final qUsd = RateQuoteInput(
      mercado: RateMarket.usdOficial,
      sourceId: RateSourceId.gatewayUsdOficial,
      endpointOrField: 'worker:/rates#usd',
      valor: 40.0,
      fechaSolicitada: validFecha,
      fechaEfectiva: validFecha,
      esExacta: true,
      esReferencia: false,
    );

    final qEur = RateQuoteInput(
      mercado: RateMarket.eurOficial,
      sourceId: RateSourceId.gatewayEurOficial,
      endpointOrField: 'worker:/rates#eur',
      valor: 44.0,
      fechaSolicitada: validFecha,
      fechaEfectiva: validFecha,
      esExacta: true,
      esReferencia: false,
    );

    final qUsdt = RateQuoteInput(
      mercado: RateMarket.usdtP2p,
      sourceId: RateSourceId.gatewayUsdtP2p,
      endpointOrField: 'worker:/rates#usdt',
      valor: 50.0,
      fechaSolicitada: validFecha,
      fechaEfectiva: validFecha,
      esExacta: true,
      esReferencia: false,
    );

    test('T-63: Bloqueo normativo en Fase 0A de EUR + BS_USDT', () {
      final result = buildNewExpenseTuple(
        monedaOriginal: 'EUR',
        montoOriginalCentavos: 1000, // 10.00 EUR
        metodo: MetodoLiquidacion.bsUsdt,
        fechaGasto: validFecha,
        cotizacionUsd: qUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
      );

      expect(result, isA<TupleBuildFailure>());
      final failure = result as TupleBuildFailure;
      expect(
        failure.code,
        equals(TupleFailureCode.combinacionMonedaLiquidacionNoSoportada),
      );
      expect(
        failure.userMessage,
        contains('El pago en Bs. indexado a USDT solo aplica a precios en USD/USDT'),
      );
    });

    test('Rechaza si cotización USD es inválida', () {
      final invalidUsd = RateQuoteInput(
        mercado: RateMarket.usdOficial,
        sourceId: RateSourceId.gatewayUsdOficial,
        endpointOrField: 'worker:/rates#usd',
        valor: 0.5, // Fuera de dominio
        fechaSolicitada: validFecha,
        fechaEfectiva: validFecha,
        esExacta: true,
        esReferencia: false,
      );

      final result = buildNewExpenseTuple(
        monedaOriginal: 'USD',
        montoOriginalCentavos: 1000,
        metodo: MetodoLiquidacion.divisa,
        fechaGasto: validFecha,
        cotizacionUsd: invalidUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
      );

      expect(result, isA<TupleBuildFailure>());
      final failure = result as TupleBuildFailure;
      expect(failure.code, equals(TupleFailureCode.cotizacionInvalida));
      expect(failure.failedMarket, equals(RateMarket.usdOficial));
    });

    test('Rechaza si monto original es <= 0', () {
      final result = buildNewExpenseTuple(
        monedaOriginal: 'USD',
        montoOriginalCentavos: 0,
        metodo: MetodoLiquidacion.divisa,
        fechaGasto: validFecha,
        cotizacionUsd: qUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
      );

      expect(result, isA<TupleBuildFailure>());
      final failure = result as TupleBuildFailure;
      expect(failure.code, equals(TupleFailureCode.montoInvalido));
    });

    test('Caso 1: Registro en VES directo', () {
      // 400.00 Bs. -> USD (rUsd=40): 10.00 USD, EUR (rEur=44): 9.09 EUR, USDT (rUsdt=50): 8.00 USDT
      final result = buildNewExpenseTuple(
        monedaOriginal: 'VES',
        montoOriginalCentavos: 40000,
        metodo: MetodoLiquidacion.divisa,
        fechaGasto: validFecha,
        cotizacionUsd: qUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
      );

      expect(result, isA<TupleBuildSuccess>());
      final tuple = (result as TupleBuildSuccess).tuple;
      expect(tuple.monedaOriginal, equals('VES'));
      expect(tuple.monedaPersistida, equals('VES'));
      expect(tuple.totalOriginalCentavos, equals(40000));
      expect(tuple.totalUsdCentavos, equals(1000)); // 40000 / 40
      expect(tuple.totalEurCentavos, equals(909));  // 40000 / 44 = 909.09 -> 909
      expect(tuple.totalUsdtCentavos, equals(800)); // 40000 / 50 = 800
      expect(tuple.fuenteTasaCambio, equals('VES_DIRECTO'));
    });

    test('Caso 2: Registro en USD directo (DIVISA) - Paridad directa 1:1 USD/USDT', () {
      final result = buildNewExpenseTuple(
        monedaOriginal: 'USD',
        montoOriginalCentavos: 2500, // 25.00 USD
        metodo: MetodoLiquidacion.divisa,
        fechaGasto: validFecha,
        cotizacionUsd: qUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
      );

      expect(result, isA<TupleBuildSuccess>());
      final tuple = (result as TupleBuildSuccess).tuple;
      expect(tuple.monedaOriginal, equals('USD'));
      expect(tuple.monedaPersistida, equals('USD'));
      expect(tuple.totalOriginalCentavos, equals(2500));
      expect(tuple.totalUsdCentavos, equals(2500));
      expect(tuple.totalUsdtCentavos, equals(2500)); // Paridad 1:1 directa
      // EUR = round(2500 * 40 / 44) = round(2272.72) = 2273
      expect(tuple.totalEurCentavos, equals(2273));
      expect(tuple.fuenteTasaCambio, equals('DIVISA_DIRECTA'));
    });

    test('Caso 3: Registro en USDT directo (DIVISA) - Paridad directa 1:1 USD/USDT', () {
      final result = buildNewExpenseTuple(
        monedaOriginal: 'USDT',
        montoOriginalCentavos: 5000, // 50.00 USDT
        metodo: MetodoLiquidacion.divisa,
        fechaGasto: validFecha,
        cotizacionUsd: qUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
      );

      expect(result, isA<TupleBuildSuccess>());
      final tuple = (result as TupleBuildSuccess).tuple;
      expect(tuple.monedaOriginal, equals('USDT'));
      expect(tuple.monedaPersistida, equals('USDT'));
      expect(tuple.totalOriginalCentavos, equals(5000));
      expect(tuple.totalUsdtCentavos, equals(5000));
      expect(tuple.totalUsdCentavos, equals(5000)); // Paridad 1:1 directa
      // EUR = round(5000 * 40 / 44) = round(4545.45) = 4545
      expect(tuple.totalEurCentavos, equals(4545));
      expect(tuple.fuenteTasaCambio, equals('USDT_DIRECTO'));
    });

    test('Caso 4: Registro en USD indexado a BCV (BS_BCV) con y sin monto manual', () {
      // Sin monto manual: 10.00 USD * 40.0 = 400.00 Bs.
      final resultAuto = buildNewExpenseTuple(
        monedaOriginal: 'USD',
        montoOriginalCentavos: 1000,
        metodo: MetodoLiquidacion.bsBcv,
        fechaGasto: validFecha,
        cotizacionUsd: qUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
      );

      expect(resultAuto, isA<TupleBuildSuccess>());
      final tAuto = (resultAuto as TupleBuildSuccess).tuple;
      expect(tAuto.monedaOriginal, equals('USD'));
      expect(tAuto.monedaPersistida, equals('VES'));
      expect(tAuto.totalOriginalCentavos, equals(40000));
      expect(tAuto.totalUsdCentavos, equals(1000)); // Preservación exacta USD
      expect(tAuto.totalEurCentavos, equals(909));   // 40000 / 44
      expect(tAuto.totalUsdtCentavos, equals(800));  // 40000 / 50
      expect(tAuto.fuenteTasaCambio, equals('USD_BCV_INDEXADO'));

      // Con monto manual en bolívares por redondeo comercial
      final resultManual = buildNewExpenseTuple(
        monedaOriginal: 'USD',
        montoOriginalCentavos: 1000,
        metodo: MetodoLiquidacion.bsBcv,
        fechaGasto: validFecha,
        cotizacionUsd: qUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
        montoVesManualCentavos: 40500, // 405.00 Bs.
      );

      final tManual = (resultManual as TupleBuildSuccess).tuple;
      expect(tManual.totalOriginalCentavos, equals(40500));
      expect(tManual.totalUsdCentavos, equals(1000)); // Preserva USD de referencia
    });

    test('Caso 5: Registro en EUR indexado a BCV (BS_BCV)', () {
      // 10.00 EUR * 44.0 = 440.00 Bs.
      final result = buildNewExpenseTuple(
        monedaOriginal: 'EUR',
        montoOriginalCentavos: 1000, // 10.00 EUR
        metodo: MetodoLiquidacion.bsBcv,
        fechaGasto: validFecha,
        cotizacionUsd: qUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
      );

      expect(result, isA<TupleBuildSuccess>());
      final tuple = (result as TupleBuildSuccess).tuple;
      expect(tuple.monedaOriginal, equals('EUR'));
      expect(tuple.monedaPersistida, equals('VES'));
      expect(tuple.totalOriginalCentavos, equals(44000));
      expect(tuple.totalEurCentavos, equals(1000));  // Preservación exacta EUR
      expect(tuple.totalUsdCentavos, equals(1100));  // 44000 / 40 = 11.00 USD
      expect(tuple.totalUsdtCentavos, equals(880));  // 44000 / 50 = 8.80 USDT
      expect(tuple.fuenteTasaCambio, equals('EUR_BCV_INDEXADO'));
    });

    test('Caso 6: Registro en USD indexado a USDT P2P (BS_USDT)', () {
      // 10.00 USD * 50.0 (rUsdt) = 500.00 Bs.
      final result = buildNewExpenseTuple(
        monedaOriginal: 'USD',
        montoOriginalCentavos: 1000, // 10.00 USD
        metodo: MetodoLiquidacion.bsUsdt,
        fechaGasto: validFecha,
        cotizacionUsd: qUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
      );

      expect(result, isA<TupleBuildSuccess>());
      final tuple = (result as TupleBuildSuccess).tuple;
      expect(tuple.monedaOriginal, equals('USD'));
      expect(tuple.monedaPersistida, equals('VES'));
      expect(tuple.totalOriginalCentavos, equals(50000));
      expect(tuple.totalUsdtCentavos, equals(1000)); // Preservación exacta referencia P2P
      expect(tuple.totalUsdCentavos, equals(1250));  // 50000 / 40 = 12.50 USD
      expect(tuple.totalEurCentavos, equals(1136));  // 50000 / 44 = 11.36 EUR
      expect(tuple.fuenteTasaCambio, equals('USDT_INDEXADO'));
    });

    test('Caso 7: Registro en EUR en Divisa directa', () {
      // 10.00 EUR -> equivVes = 1000 * 44 = 44000
      final result = buildNewExpenseTuple(
        monedaOriginal: 'EUR',
        montoOriginalCentavos: 1000,
        metodo: MetodoLiquidacion.divisa,
        fechaGasto: validFecha,
        cotizacionUsd: qUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
      );

      expect(result, isA<TupleBuildSuccess>());
      final tuple = (result as TupleBuildSuccess).tuple;
      expect(tuple.monedaOriginal, equals('EUR'));
      expect(tuple.monedaPersistida, equals('EUR'));
      expect(tuple.totalOriginalCentavos, equals(1000));
      expect(tuple.totalEurCentavos, equals(1000));
      expect(tuple.totalUsdCentavos, equals(1100)); // 44000 / 40
      expect(tuple.totalUsdtCentavos, equals(880)); // 44000 / 50
      expect(tuple.fuenteTasaCambio, equals('DIVISA_DIRECTA'));
    });

    test('Caso 8: Registro en USDT indexado a USDT P2P (BS_USDT)', () {
      final result = buildNewExpenseTuple(
        monedaOriginal: 'USDT',
        montoOriginalCentavos: 2000,
        metodo: MetodoLiquidacion.bsUsdt,
        fechaGasto: validFecha,
        cotizacionUsd: qUsd,
        cotizacionEur: qEur,
        cotizacionUsdt: qUsdt,
      );

      expect(result, isA<TupleBuildSuccess>());
      final tuple = (result as TupleBuildSuccess).tuple;
      expect(tuple.monedaOriginal, equals('USDT'));
      expect(tuple.monedaPersistida, equals('VES'));
      expect(tuple.totalOriginalCentavos, equals(100000)); // 2000 * 50
      expect(tuple.totalUsdtCentavos, equals(2000));
      expect(tuple.totalUsdCentavos, equals(2500)); // 100000 / 40
      expect(tuple.totalEurCentavos, equals(2273)); // 100000 / 44
      expect(tuple.fuenteTasaCambio, equals('USDT_INDEXADO'));
    });
  });
}
