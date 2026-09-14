import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExchangeRateService {
  static const String _dolarApiOficial = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const String _dolarApiParalelo = 'https://ve.dolarapi.com/v1/dolares/paralelo';

  /// Obtiene la tasa de cambio para una fecha específica (formato YYYY-MM-DD)
  /// Si la fecha es hoy, consulta la tasa en tiempo real de BCV oficial.
  /// Si es una fecha anterior, consulta el registro histórico de esa fecha.
  static Future<double> getRateForDate(String isoDate, {String tipo = 'oficial'}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Si la fecha es hoy o vacía, consulta en vivo
    if (isoDate.isEmpty || isoDate == today) {
      return await getTodayRate(tipo: tipo);
    }

    // 1. Revisar si ya tenemos la tasa de esa fecha en la memoria local
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_rate_$isoDate';
    final cachedRate = prefs.getDouble(cacheKey);
    if (cachedRate != null && cachedRate > 0) {
      return cachedRate;
    }

    // 2. Consultar histórico por fecha
    try {
      final url = Uri.parse('https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@$isoDate/v1/currencies/usd.json');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final vesRate = (data['usd']?['ves'] as num?)?.toDouble();
        if (vesRate != null && vesRate > 0) {
          await prefs.setDouble(cacheKey, vesRate);
          return vesRate;
        }
      }
    } catch (_) {}

    try {
      // Fallback a CDN alternativa
      final urlFallback = Uri.parse('https://$isoDate.currency-api.pages.dev/v1/currencies/usd.json');
      final responseFallback = await http.get(urlFallback).timeout(const Duration(seconds: 5));

      if (responseFallback.statusCode == 200) {
        final data = jsonDecode(responseFallback.body);
        final vesRate = (data['usd']?['ves'] as num?)?.toDouble();
        if (vesRate != null && vesRate > 0) {
          await prefs.setDouble(cacheKey, vesRate);
          return vesRate;
        }
      }
    } catch (_) {}

    // 3. Fallback a la tasa general guardada si no hay registro histórico disponible
    return await getTodayRate(tipo: tipo);
  }

  /// Obtiene la tasa de cambio de hoy en tiempo real
  static Future<double> getTodayRate({String tipo = 'oficial'}) async {
    try {
      final url = Uri.parse(tipo == 'paralelo' ? _dolarApiParalelo : _dolarApiOficial);
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final promedio = (data['promedio'] as num?)?.toDouble();
        if (promedio != null && promedio > 0) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('cached_exchange_rate', promedio);
          await prefs.setString('cached_exchange_rate_date', DateTime.now().toIso8601String());
          return promedio;
        }
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('cached_exchange_rate') ?? 40.0;
  }
}
