import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExchangeRatesData {
  final double usd;
  final double eur;
  final double usdt;
  final DateTime fecha;

  const ExchangeRatesData({
    required this.usd,
    required this.eur,
    required this.usdt,
    required this.fecha,
  });

  Map<String, dynamic> toJson() => {
    'usd': usd,
    'eur': eur,
    'usdt': usdt,
    'fecha': fecha.toIso8601String(),
  };

  factory ExchangeRatesData.fromJson(Map<String, dynamic> json) => ExchangeRatesData(
    usd: (json['usd'] as num?)?.toDouble() ?? 40.0,
    eur: (json['eur'] as num?)?.toDouble() ?? 43.0,
    usdt: (json['usdt'] as num?)?.toDouble() ?? 40.0,
    fecha: DateTime.tryParse(json['fecha'] ?? '') ?? DateTime.now(),
  );
}

class ExchangeRateService {
  static const String _dolarApiOficial = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const String _euroApiOficial = 'https://ve.dolarapi.com/v1/euros/oficial';
  static const String _dolarApiParalelo = 'https://ve.dolarapi.com/v1/dolares/paralelo';

  /// Obtiene las 3 tasas del día (USD BCV, EUR BCV, USDT Binance / Paralelo) en paralelo.
  static Future<ExchangeRatesData> getAllTodayRates() async {
    final prefs = await SharedPreferences.getInstance();

    double usdRate = prefs.getDouble('cached_rate_usd') ?? prefs.getDouble('cached_exchange_rate') ?? 40.0;
    double eurRate = prefs.getDouble('cached_rate_eur') ?? (usdRate * 1.08);
    double usdtRate = prefs.getDouble('cached_rate_usdt') ?? usdRate;

    final results = await Future.wait([
      _fetchUrlDouble(_dolarApiOficial, 'promedio'),
      _fetchUrlDouble(_euroApiOficial, 'promedio'),
      _fetchUsdtLiveRate(),
    ]);

    if (results[0] != null && results[0]! > 0) {
      usdRate = results[0]!;
      await prefs.setDouble('cached_rate_usd', usdRate);
      await prefs.setDouble('cached_exchange_rate', usdRate);
    }

    if (results[1] != null && results[1]! > 0) {
      eurRate = results[1]!;
      await prefs.setDouble('cached_rate_eur', eurRate);
    } else if (usdRate > 0) {
      eurRate = usdRate * 1.08;
    }

    if (results[2] != null && results[2]! > 0) {
      usdtRate = results[2]!;
      await prefs.setDouble('cached_rate_usdt', usdtRate);
    } else {
      usdtRate = usdRate;
    }

    final now = DateTime.now();
    await prefs.setString('cached_exchange_rates_timestamp', now.toIso8601String());

    return ExchangeRatesData(
      usd: usdRate,
      eur: eurRate,
      usdt: usdtRate,
      fecha: now,
    );
  }

  static Future<double?> _fetchUrlDouble(String urlString, String fieldKey) async {
    try {
      final url = Uri.parse(urlString);
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final val = (data[fieldKey] as num?)?.toDouble();
        if (val != null && val > 0) return val;
      }
    } catch (_) {}
    return null;
  }

  /// Intenta consultar Yadio P2P / DolarAPI paralelo para USDT
  static Future<double?> _fetchUsdtLiveRate() async {
    try {
      final yadioUrl = Uri.parse('https://api.yadio.io/json');
      final resp = await http.get(yadioUrl).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final p2pUsdt = (data['USD']?['other']?['p2p_usdt']?['rate'] as num?)?.toDouble();
        if (p2pUsdt != null && p2pUsdt > 0) return p2pUsdt;
        final usdRate = (data['USD']?['rate'] as num?)?.toDouble();
        if (usdRate != null && usdRate > 0) return usdRate;
      }
    } catch (_) {}

    // Fallback directo a DolarAPI paralelo
    return await _fetchUrlDouble(_dolarApiParalelo, 'promedio');
  }

  /// Obtiene la tasa de cambio para una fecha específica (formato YYYY-MM-DD) y moneda.
  /// Si la fecha es hoy o no hay histórico, consulta en vivo.
  static Future<double> getRateForDate(
    String isoDate, {
    String moneda = 'USD',
    String tipo = 'oficial',
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final monedaClean = moneda.toUpperCase();

    // Si es hoy, consultar en vivo
    if (isoDate.isEmpty || isoDate == today) {
      final allRates = await getAllTodayRates();
      if (monedaClean == 'EUR') return allRates.eur;
      if (monedaClean == 'USDT') return allRates.usdt;
      return allRates.usd;
    }

    // 1. Revisar caché local por fecha y moneda
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_rate_${monedaClean}_$isoDate';
    final cachedRate = prefs.getDouble(cacheKey);
    if (cachedRate != null && cachedRate > 0) {
      return cachedRate;
    }

    // 2. Consultar históricos oficiales en DolarAPI
    try {
      String endpoint = '';
      if (monedaClean == 'EUR') {
        endpoint = 'https://ve.dolarapi.com/v1/historicos/euros/oficial';
      } else if (monedaClean == 'USDT' || tipo == 'paralelo') {
        endpoint = 'https://ve.dolarapi.com/v1/historicos/dolares/paralelo';
      } else {
        endpoint = 'https://ve.dolarapi.com/v1/historicos/dolares/oficial';
      }

      final url = Uri.parse(endpoint);
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        
        // Buscar coincidencia exacta
        for (final item in list) {
          if (item['fecha'] == isoDate) {
            final rate = (item['promedio'] as num?)?.toDouble();
            if (rate != null && rate > 0) {
              await prefs.setDouble(cacheKey, rate);
              return rate;
            }
          }
        }

        // Si no hay fecha exacta (ej. fin de semana o feriado), buscar el último día hábil anterior a isoDate
        double? lastValidRate;
        for (final item in list) {
          final itemFecha = item['fecha']?.toString() ?? '';
          if (itemFecha.isNotEmpty && itemFecha.compareTo(isoDate) <= 0) {
            final rate = (item['promedio'] as num?)?.toDouble();
            if (rate != null && rate > 0) {
              lastValidRate = rate;
            }
          }
        }

        if (lastValidRate != null && lastValidRate > 0) {
          await prefs.setDouble(cacheKey, lastValidRate);
          return lastValidRate;
        }
      }
    } catch (_) {}

    // 3. Fallback retrocediendo día a día en Fawaz Ahmed Currency API para USD
    if (monedaClean == 'USD') {
      try {
        DateTime parsedDate = DateTime.tryParse(isoDate) ?? DateTime.now();
        for (int i = 0; i < 5; i++) {
          final targetIso = parsedDate.subtract(Duration(days: i)).toIso8601String().substring(0, 10);
          final url = Uri.parse('https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@$targetIso/v1/currencies/usd.json');
          final response = await http.get(url).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final vesRate = (data['usd']?['ves'] as num?)?.toDouble();
            if (vesRate != null && vesRate > 0) {
              await prefs.setDouble(cacheKey, vesRate);
              return vesRate;
            }
          }
        }
      } catch (_) {}
    }

    // 4. Fallback final a tasa del día
    final allRates = await getAllTodayRates();
    if (monedaClean == 'EUR') return allRates.eur;
    if (monedaClean == 'USDT') return allRates.usdt;
    return allRates.usd;
  }

  /// Obtiene la tasa de cambio de hoy en tiempo real (retrocompatibilidad)
  static Future<double> getTodayRate({String tipo = 'oficial'}) async {
    final allRates = await getAllTodayRates();
    if (tipo == 'paralelo') return allRates.usdt;
    return allRates.usd;
  }
}
