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

    test('retorna tasa exacta cuando la fecha existe en el historico', () async {
      final rate = await ExchangeRateService.getRateForDate('2026-10-02', client: historicosMock());
      expect(rate, equals(150.0));
    });

    test('encuentra el ultimo dia habil anterior si la fecha es fin de semana', () async {
      // 2026-10-03 es sabado: sin dato exacto, usa el viernes 2026-10-02.
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

    test('sin red ni cache: marca referencia y NO avanza el timestamp', () async {
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

    test('con cache y sin red: conserva cache marcada como referencia', () async {
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

    test('retorna tasa de EUR y USDT para fechas historicas', () async {
      final mock = MockClient((request) async {
        if (request.url.toString().contains('/euros/oficial')) {
          return http.Response('[{"fecha":"2026-10-02","promedio":162.5}]', 200);
        }
        if (request.url.toString().contains('/dolares/paralelo')) {
          return http.Response('[{"fecha":"2026-10-02","promedio":155.0}]', 200);
        }
        return http.Response('error', 500);
      });

      final eurRate = await ExchangeRateService.getRateForDate('2026-10-02', moneda: 'EUR', client: mock);
      final usdtRate = await ExchangeRateService.getRateForDate('2026-10-02', moneda: 'USDT', client: mock);

      expect(eurRate, equals(162.5));
      expect(usdtRate, equals(155.0));
    });
  });

  group('ExchangeRateService - Cascada Multifuente y Regresion 40', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ExchangeRateService.limpiarCache();
    });

    test('solo Yadio responde: USD queda marcado como referencia (regresion de 40 Bs)', () async {
      // Escenario exacto del bug reportado: DolarAPI caido en el telefono,
      // Yadio vivo entregando USDT. Antes esto devolvia esReferencia:false
      // con usd:0.0, y la app presentaba la semilla (40) con "Actualizada hoy".
      final mock = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('api.yadio.io')) {
          return http.Response(
            '{"USD":{"other":{"p2p_usdt":{"rate":1005.67}}}}',
            200,
          );
        }
        return http.Response('error', 500);
      });

      final rates = await ExchangeRateService.getAllTodayRates(client: mock);

      expect(rates.usd, equals(0.0));
      expect(rates.usdEsReferencia, isTrue, reason: 'el USD no vino en vivo');
      expect(rates.usdtEsReferencia, isFalse, reason: 'el USDT vino de Yadio');
      expect(rates.usdt, equals(1005.67));
      expect(rates.fuentes['usdt'], equals('yadio-p2p'));
    });

    test('DolarAPI caido: USD se recupera via jsDelivr (espejo BCV)', () async {
      final mock = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('jsdelivr.net') && url.contains('/usd.json')) {
          return http.Response('{"date":"2026-10-17","usd":{"ves":877.92}}', 200);
        }
        return http.Response('error', 500);
      });

      final rates = await ExchangeRateService.getAllTodayRates(client: mock);

      expect(rates.usd, equals(877.92));
      expect(rates.usdEsReferencia, isFalse);
      expect(rates.fuentes['usd'], equals('jsdelivr'));
    });

    test('DolarAPI caido: USD se recupera via Yadio official', () async {
      final mock = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('api.yadio.io')) {
          return http.Response(
            '{"USD":{"other":{"official":{"rate":878.92},"p2p_usdt":{"rate":1005.67}}}}',
            200,
          );
        }
        return http.Response('error', 500);
      });

      final rates = await ExchangeRateService.getAllTodayRates(client: mock);

      expect(rates.usd, equals(878.92));
      expect(rates.usdEsReferencia, isFalse);
      expect(rates.fuentes['usd'], equals('yadio-oficial'));
    });

    test('gateway propio resuelve las 3 divisas en una sola peticion', () async {
      final pedidos = <String>[];
      final mock = MockClient((request) async {
        final url = request.url.toString();
        pedidos.add(url);
        if (url.endsWith('/tasas')) {
          return http.Response(
            '{"usd":880.12,"eur":985.73,"usdt":1006.0,"fecha":"2026-10-17T00:00:00Z"}',
            200,
          );
        }
        return http.Response('error', 500);
      });

      final rates = await ExchangeRateService.getAllTodayRates(client: mock);

      expect(rates.usd, equals(880.12));
      expect(rates.eur, equals(985.73));
      expect(rates.usdt, equals(1006.0));
      expect(rates.usdEsReferencia, isFalse);
      expect(rates.eurEsReferencia, isFalse);
      expect(rates.usdtEsReferencia, isFalse);
      expect(rates.fuentes['usd'], equals('gateway'));
      // No debe llamar a las cascadas individuales si el gateway respondio
      expect(pedidos.where((u) => u.contains('dolarapi')).length, equals(0));
      expect(pedidos.where((u) => u.contains('jsdelivr')).length, equals(0));
    });

    test('semilla de 40 persistida en cache previa se purga como inverosimil', () async {
      SharedPreferences.setMockInitialValues({
        'cached_rate_usd': 40.0,
      });
      final failing = MockClient((_) async => http.Response('error', 500));
      final rates = await ExchangeRateService.getAllTodayRates(client: failing);

      expect(rates.usd, equals(0.0), reason: '40.0 no puede aceptarse como tasa real');
      expect(rates.usdEsReferencia, isTrue);
    });
  });
}
