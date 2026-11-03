import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/domain/monetary/rate_market.dart';

void main() {
  group('isValidMonetaryRate - Predicado Canónico de Validez Numérica (D-08)', () {
    test('Valores numéricos dentro de dominio (> 1.0 y finitos) son válidos', () {
      expect(isValidMonetaryRate(1.0001), isTrue);
      expect(isValidMonetaryRate(45.0), isTrue);
      expect(isValidMonetaryRate(380.0), isTrue);
      expect(isValidMonetaryRate(1000.0), isTrue);
      // enteros num
      expect(isValidMonetaryRate(45), isTrue);
      expect(isValidMonetaryRate(380), isTrue);
      expect(isValidMonetaryRate(2), isTrue);
    });

    test('Valores en el límite y por debajo de 1.0 son inválidos', () {
      expect(isValidMonetaryRate(1.0), isFalse);
      expect(isValidMonetaryRate(1), isFalse);
      expect(isValidMonetaryRate(0.5), isFalse);
      expect(isValidMonetaryRate(0.9999), isFalse);
      expect(isValidMonetaryRate(0), isFalse);
      expect(isValidMonetaryRate(0.0), isFalse);
    });

    test('Valores negativos son inválidos', () {
      expect(isValidMonetaryRate(-0.01), isFalse);
      expect(isValidMonetaryRate(-1.0), isFalse);
      expect(isValidMonetaryRate(-5.0), isFalse);
      expect(isValidMonetaryRate(-380.0), isFalse);
    });

    test('Valores especiales no finitos (NaN, Infinity, -Infinity) son inválidos', () {
      expect(isValidMonetaryRate(double.nan), isFalse);
      expect(isValidMonetaryRate(double.infinity), isFalse);
      expect(isValidMonetaryRate(double.negativeInfinity), isFalse);
    });

    test('Valores de tipo no numérico o nulos son inválidos sin lanzar excepción', () {
      expect(isValidMonetaryRate(null), isFalse);
      expect(isValidMonetaryRate('45.0'), isFalse);
      expect(isValidMonetaryRate(''), isFalse);
      expect(isValidMonetaryRate(true), isFalse);
      expect(isValidMonetaryRate(false), isFalse);
      expect(isValidMonetaryRate({'rate': 45.0}), isFalse);
      expect(isValidMonetaryRate([45.0]), isFalse);
    });
  });

  group('allowedSourcesForMarket - Cobertura de fuentes por mercado', () {
    test('usdOficial contiene gateway, dolarapi, yadio, jsdelivr y manual', () {
      final sources = allowedSourcesForMarket(RateMarket.usdOficial);
      expect(sources.contains(RateSourceId.gatewayUsdOficial), isTrue);
      expect(sources.contains(RateSourceId.dolarApiUsdOficial), isTrue);
      expect(sources.contains(RateSourceId.yadioUsdOficial), isTrue);
      expect(sources.contains(RateSourceId.jsdelivrUsd), isTrue);
      expect(sources.contains(RateSourceId.manualUsuario), isTrue);
      expect(sources.contains(RateSourceId.gatewayEurOficial), isFalse);
    });

    test('eurOficial contiene gateway, dolarapi, jsdelivr, yadio y manual', () {
      final sources = allowedSourcesForMarket(RateMarket.eurOficial);
      expect(sources.contains(RateSourceId.gatewayEurOficial), isTrue);
      expect(sources.contains(RateSourceId.dolarApiEurOficial), isTrue);
      expect(sources.contains(RateSourceId.jsdelivrEur), isTrue);
      expect(sources.contains(RateSourceId.yadioEurRatio), isTrue);
      expect(sources.contains(RateSourceId.manualUsuario), isTrue);
      expect(sources.contains(RateSourceId.gatewayUsdOficial), isFalse);
    });

    test('usdtP2p contiene gateway, yadio, dolarapi paralelo y manual', () {
      final sources = allowedSourcesForMarket(RateMarket.usdtP2p);
      expect(sources.contains(RateSourceId.gatewayUsdtP2p), isTrue);
      expect(sources.contains(RateSourceId.yadioUsdtP2p), isTrue);
      expect(sources.contains(RateSourceId.dolarApiParalelo), isTrue);
      expect(sources.contains(RateSourceId.manualUsuario), isTrue);
      expect(sources.contains(RateSourceId.gatewayEurOficial), isFalse);
    });
  });
}
