import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/domain/monetary/rate_market.dart';
import 'package:gastoscan_ai/domain/monetary/rate_quote_input.dart';

void main() {
  group('RateQuoteInput - Validaciones y Contratos (T-64, T-65, T-66)', () {
    const validFecha = '2026-10-31';

    RateQuoteInput buildQuote({
      RateMarket mercado = RateMarket.usdOficial,
      RateSourceId sourceId = RateSourceId.gatewayUsdOficial,
      String endpointOrField = 'worker:/rates#usd',
      double valor = 40.0,
      String fechaSolicitada = validFecha,
      String fechaEfectiva = validFecha,
      bool esExacta = true,
      bool esReferencia = false,
      bool confirmadaPorUsuario = false,
    }) {
      return RateQuoteInput(
        mercado: mercado,
        sourceId: sourceId,
        endpointOrField: endpointOrField,
        valor: valor,
        fechaSolicitada: fechaSolicitada,
        fechaEfectiva: fechaEfectiva,
        esExacta: esExacta,
        esReferencia: esReferencia,
        confirmadaPorUsuario: confirmadaPorUsuario,
      );
    }

    test('Cotización válida exacta pasa la validación sin errores', () {
      final quote = buildQuote();
      final err = quote.validateFor(
        expectedMarket: RateMarket.usdOficial,
        fechaGasto: validFecha,
      );
      expect(err, isNull);
    });

    test('T-64: Rechaza fuente USD presentada como USDT (mercado o fuente incompatible)', () {
      // Caso 1: mercado usdtP2p pero sourceId dolarApiUsdOficial
      final quote1 = buildQuote(
        mercado: RateMarket.usdtP2p,
        sourceId: RateSourceId.dolarApiUsdOficial,
        endpointOrField: 'dolarapi:/v1/dolares/oficial#promedio',
      );
      expect(
        quote1.validateFor(expectedMarket: RateMarket.usdtP2p, fechaGasto: validFecha),
        equals(QuoteValidationError.fuenteNoAutorizadaParaMercado),
      );

      // Caso 2: mercado usdOficial en slot usdtP2p
      final quote2 = buildQuote(
        mercado: RateMarket.usdOficial,
        sourceId: RateSourceId.gatewayUsdOficial,
        endpointOrField: 'worker:/rates#usd',
      );
      expect(
        quote2.validateFor(expectedMarket: RateMarket.usdtP2p, fechaGasto: validFecha),
        equals(QuoteValidationError.mercadoIncorrecto),
      );
    });

    test('T-65: Rechaza tasa P2P presentada como USD oficial', () {
      final quote1 = buildQuote(
        mercado: RateMarket.usdOficial,
        sourceId: RateSourceId.yadioUsdtP2p,
        endpointOrField: 'yadio:/json#p2p_usdt',
      );
      expect(
        quote1.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: validFecha),
        equals(QuoteValidationError.fuenteNoAutorizadaParaMercado),
      );

      final quote2 = buildQuote(
        mercado: RateMarket.usdOficial,
        sourceId: RateSourceId.dolarApiParalelo,
        endpointOrField: 'dolarapi:/v1/dolares/paralelo#promedio',
      );
      expect(
        quote2.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: validFecha),
        equals(QuoteValidationError.fuenteNoAutorizadaParaMercado),
      );
    });

    group('T-66: Pruebas negativas de fecha y confirmación de usuario', () {
      test('a) fechaSolicitada no coincide con fechaGasto', () {
        final quote = buildQuote(
          fechaSolicitada: '2026-03-10',
          fechaEfectiva: '2026-03-10',
        );
        expect(
          quote.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: '2026-03-09'),
          equals(QuoteValidationError.fechaSolicitadaNoCoincideConGasto),
        );
      });

      test('b) fechaEfectiva futura respecto a fechaSolicitada', () {
        final quote = buildQuote(
          fechaSolicitada: '2026-03-09',
          fechaEfectiva: '2026-03-10',
        );
        expect(
          quote.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: '2026-03-09'),
          equals(QuoteValidationError.fechaEfectivaFutura),
        );
      });

      test('c) esExacta: false, esReferencia: true, confirmadaPorUsuario: false', () {
        final quote = buildQuote(
          fechaSolicitada: '2026-03-09',
          fechaEfectiva: '2026-03-09',
          esExacta: false,
          esReferencia: true,
          confirmadaPorUsuario: false,
        );
        expect(
          quote.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: '2026-03-09'),
          equals(QuoteValidationError.referenciaSinConfirmacionUsuario),
        );
      });

      test('d) manualUsuario sin confirmación de usuario', () {
        final quote = buildQuote(
          sourceId: RateSourceId.manualUsuario,
          endpointOrField: 'manual:input_tasa',
          esExacta: false,
          confirmadaPorUsuario: false,
        );
        expect(
          quote.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: validFecha),
          equals(QuoteValidationError.manualSinConfirmacionUsuario),
        );
      });

      test('d) manualUsuario clasificada erróneamente como exacta', () {
        final quote = buildQuote(
          sourceId: RateSourceId.manualUsuario,
          endpointOrField: 'manual:input_tasa',
          esExacta: true,
          confirmadaPorUsuario: true,
        );
        expect(
          quote.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: validFecha),
          equals(QuoteValidationError.inconsistenciaExactitudFecha),
        );
      });
    });

    test('Rechaza endpoint vacío o compuesto solo por espacios', () {
      final quoteVacia = buildQuote(endpointOrField: '');
      expect(
        quoteVacia.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: validFecha),
        equals(QuoteValidationError.endpointCampoVacio),
      );

      final quoteEspacios = buildQuote(endpointOrField: '   ');
      expect(
        quoteEspacios.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: validFecha),
        equals(QuoteValidationError.endpointCampoVacio),
      );
    });

    test('Rechaza valor numérico fuera de dominio (<= 1.0 o no finito)', () {
      final quoteUno = buildQuote(valor: 1.0);
      expect(
        quoteUno.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: validFecha),
        equals(QuoteValidationError.valorFueraDeDominio),
      );

      final quoteCero = buildQuote(valor: 0.0);
      expect(
        quoteCero.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: validFecha),
        equals(QuoteValidationError.valorFueraDeDominio),
      );

      final quoteInf = buildQuote(valor: double.infinity);
      expect(
        quoteInf.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: validFecha),
        equals(QuoteValidationError.valorFueraDeDominio),
      );
    });

    test('Rechaza formatos de fecha inválidos (no calendario)', () {
      final quote = buildQuote(
        fechaSolicitada: '2026-02-30', // Fecha no existente en el calendario
        fechaEfectiva: '2026-02-30',
      );
      expect(
        quote.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: '2026-02-30'),
        equals(QuoteValidationError.formatoFechaInvalido),
      );
    });

    test('Rechaza fecha anterior a mínima (2023-01-03) para fuentes automáticas', () {
      final quote = buildQuote(
        fechaSolicitada: '2022-12-31',
        fechaEfectiva: '2022-12-31',
      );
      expect(
        quote.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: '2022-12-31'),
        equals(QuoteValidationError.fechaEfectivaAnteriorMinima),
      );
    });

    test('Acepta tasa de referencia o anterior si el usuario la confirmó', () {
      final quote = buildQuote(
        fechaSolicitada: '2026-10-31',
        fechaEfectiva: '2026-10-30',
        esExacta: false,
        esReferencia: true,
        confirmadaPorUsuario: true,
      );
      expect(
        quote.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: '2026-10-31'),
        isNull,
      );
    });

    test('Acepta tasa manual válida confirmada por el usuario', () {
      final quote = buildQuote(
        sourceId: RateSourceId.manualUsuario,
        endpointOrField: 'manual:input_tasa',
        esExacta: false,
        esReferencia: false,
        confirmadaPorUsuario: true,
      );
      expect(
        quote.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: validFecha),
        isNull,
      );
    });
  });
}
