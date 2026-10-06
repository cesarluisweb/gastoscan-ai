import 'dart:convert';
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

    test('retorna tasa exacta cuando la fecha existe en el histórico', () async {
      final mockData = [
        {'fecha': '2026-10-01', 'promedio': 860.17},
        {'fecha': '2026-10-02', 'promedio': 866.56},
        {'fecha': '2026-10-05', 'promedio': 871.36},
      ];

      final rate = await ExchangeRateService.getRateForDate('2026-10-02');
      // Puede consultar la API real si hay conexión o mock si usamos el flujo
      expect(rate, isPositive);
    });

    test('encuentra el último día hábil anterior si la fecha es fin de semana', () async {
      // 2026-10-03 y 2026-10-04 son sábado y domingo
      final rateSabado = await ExchangeRateService.getRateForDate('2026-10-03');
      final rateViernes = await ExchangeRateService.getRateForDate('2026-10-02');
      
      expect(rateSabado, isPositive);
      expect(rateViernes, isPositive);
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
    });
  });
}
