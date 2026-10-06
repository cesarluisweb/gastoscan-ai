import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/services/exchange_rate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExchangeRateService - getRateForDate Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // Históricos enlatados: sin depender de red. El sábado 2026-10-03 no
    // tiene dato exacto y debe resolver al viernes 2026-10-02.
    http.Client historicosMock() {
      return MockClient((request) async {
        if (request.url.toString().contains('/historicos/')) {
          return http.Response(
            '[{"fecha":"2026-10-01","promedio":148.0},{"fecha":"2026-10-02","promedio":150.0}]',
            200,
          );
        }
        return http.Response('error', 500);
      });
    }

    test('retorna tasa exacta cuando la fecha existe en el histórico', () async {
      final rate = await ExchangeRateService.getRateForDate('2026-10-02', client: historicosMock());
      expect(rate, equals(150.0));
    });

    test('encuentra el último día hábil anterior si la fecha es fin de semana', () async {
      // 2026-10-03 es sábado: sin dato exacto, usa el viernes 2026-10-02.
      final rateSabado = await ExchangeRateService.getRateForDate('2026-10-03', client: historicosMock());
      final rateViernes = await ExchangeRateService.getRateForDate('2026-10-02', client: historicosMock());

      expect(rateSabado, equals(150.0));
      expect(rateViernes, equals(150.0));
      expect(rateSabado, equals(rateViernes));
    });

    test('ExchangeRatesData serializa y deserializa correctamente', () {
      final data = ExchangeRatesData(
        usd: 871.36,
        eur: 940.20,
        usdt: 875.00,
        fecha: DateTime.parse('2026-10-05T12:00:00Z'),
      );

      final json = data.toJson();
      final fromJson = ExchangeRatesData.fromJson(json);

      expect(fromJson.usd, equals(871.36));
      expect(fromJson.eur, equals(940.20));
      expect(fromJson.usdt, equals(875.00));
      expect(fromJson.esReferencia, isFalse);
    });
  });

  group('ExchangeRateService - esReferencia Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('sin red ni caché: marca referencia y NO avanza el timestamp', () async {
      final failing = MockClient((_) async => http.Response('error', 500));
      final rates = await ExchangeRateService.getAllTodayRates(client: failing);

      expect(rates.esReferencia, isTrue);
      expect(rates.usd, equals(0.0));
      expect(rates.eur, equals(0.0));
      expect(rates.usdt, equals(0.0));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cached_exchange_rates_timestamp'), isNull);
    });

    test('con fetch USD en vivo: no es referencia y el timestamp avanza', () async {
      final mock = MockClient((request) async {
        if (request.url.toString().contains('/dolares/oficial')) {
          return http.Response('{"promedio": 100.0}', 200);
        }
        return http.Response('error', 500);
      });
      final rates = await ExchangeRateService.getAllTodayRates(client: mock);

      expect(rates.esReferencia, isFalse);
      expect(rates.usd, equals(100.0));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cached_exchange_rates_timestamp'), isNotNull);
      expect(prefs.getDouble('cached_rate_usd'), equals(100.0));
    });

    test('con caché y sin red: conserva caché marcada como referencia', () async {
      SharedPreferences.setMockInitialValues({
        'cached_rate_usd': 95.5,
        'cached_exchange_rates_timestamp': '2026-10-05T12:00:00.000',
      });
      final failing = MockClient((_) async => http.Response('error', 500));
      final rates = await ExchangeRateService.getAllTodayRates(client: failing);

      expect(rates.esReferencia, isTrue);
      expect(rates.usd, equals(95.5));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('cached_exchange_rates_timestamp'),
        equals('2026-10-05T12:00:00.000'),
      );
    });
  });
}
