import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class ExchangeRatesData {
  final double usd;
  final double eur;
  final double usdt;
  final DateTime fecha;
  /// true cuando NO se obtuvo dato en vivo: los valores vienen de caché
  /// previa (o cero si nunca hubo) y `fecha` es la última actualización
  /// real conocida, no "ahora".
  final bool esReferencia;

  const ExchangeRatesData({
    required this.usd,
    required this.eur,
    required this.usdt,
    required this.fecha,
    this.esReferencia = false,
  });

  Map<String, dynamic> toJson() => {
    'usd': usd,
    'eur': eur,
    'usdt': usdt,
    'fecha': fecha.toIso8601String(),
    'esReferencia': esReferencia,
  };

  factory ExchangeRatesData.fromJson(Map<String, dynamic> json) => ExchangeRatesData(
    usd: (json['usd'] as num?)?.toDouble() ?? 0.0,
    eur: (json['eur'] as num?)?.toDouble() ?? 0.0,
    usdt: (json['usdt'] as num?)?.toDouble() ?? 0.0,
    fecha: DateTime.tryParse(json['fecha'] ?? '') ?? DateTime.now(),
    esReferencia: json['esReferencia'] as bool? ?? true,
  );
}

class ExchangeRateService {
  static const String _dolarApiOficial = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const String _euroApiOficial = 'https://ve.dolarapi.com/v1/euros/oficial';
  static const String _dolarApiParalelo = 'https://ve.dolarapi.com/v1/dolares/paralelo';

  static const Map<String, String> _requestHeaders = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 RindeMas/1.0',
    'Accept': 'application/json, text/plain, */*',
  };

  /// Obtiene las 3 tasas del día (USD BCV, EUR BCV, USDT Binance / Paralelo) en cascada multifuente.
  /// Fuertes mecanismos de contingencia ante bloqueos de ISP venezolanos (CANTV/Digitel):
  /// 1. DolarAPI oficial (USD/EUR)
  /// 2. Yadio API oficial y P2P (USD Oficial, EUR, USDT)
  /// 3. jsDelivr CDN de divisas (USD/EUR)
  /// 4. Gateway Cloudflare Worker (/tasas)
  static Future<ExchangeRatesData> getAllTodayRates({http.Client? client}) async {
    final prefs = await SharedPreferences.getInstance();
    final httpClient = client ?? http.Client();

    // Semillas: solo caché real existente.
    double? usdRate = prefs.getDouble('cached_rate_usd') ?? prefs.getDouble('cached_exchange_rate');
    double? eurRate = prefs.getDouble('cached_rate_eur');
    double? usdtRate = prefs.getDouble('cached_rate_usdt');

    final results = await Future.wait([
      _fetchUrlDouble(_dolarApiOficial, 'promedio', client: httpClient),
      _fetchUrlDouble(_euroApiOficial, 'promedio', client: httpClient),
      _fetchYadioAllRates(client: httpClient),
    ]);

    bool fetchedAny = false;
    final dUsd = results[0] as double?;
    final dEur = results[1] as double?;
    final yadioRates = results[2] as Map<String, double>?;

    // 1. Dólar BCV: DolarAPI -> Yadio Oficial -> jsDelivr -> Gateway
    if (dUsd != null && dUsd > 0) {
      usdRate = dUsd;
      fetchedAny = true;
    } else if (yadioRates != null && (yadioRates['usd'] ?? 0) > 0) {
      usdRate = yadioRates['usd']!;
      fetchedAny = true;
    } else {
      final jUsd = await _fetchJsDelivrRate('usd', client: httpClient);
      if (jUsd != null && jUsd > 0) {
        usdRate = jUsd;
        fetchedAny = true;
      }
    }

    // 2. Euro BCV: DolarAPI -> Yadio -> jsDelivr -> Gateway
    if (dEur != null && dEur > 0) {
      eurRate = dEur;
      fetchedAny = true;
    } else if (yadioRates != null && (yadioRates['eur'] ?? 0) > 0) {
      eurRate = yadioRates['eur']!;
      fetchedAny = true;
    } else {
      final jEur = await _fetchJsDelivrRate('eur', client: httpClient);
      if (jEur != null && jEur > 0) {
        eurRate = jEur;
        fetchedAny = true;
      }
    }

    // 3. USDT Binance P2P: Yadio -> DolarAPI paralelo -> Par USD
    if (yadioRates != null && (yadioRates['usdt'] ?? 0) > 0) {
      usdtRate = yadioRates['usdt']!;
      fetchedAny = true;
    } else {
      final dParalelo = await _fetchUrlDouble(_dolarApiParalelo, 'promedio', client: httpClient);
      if (dParalelo != null && dParalelo > 0) {
        usdtRate = dParalelo;
        fetchedAny = true;
      } else if ((usdtRate == null || usdtRate <= 0) && (usdRate != null && usdRate > 0)) {
        usdtRate = usdRate;
      }
    }

    // 4. Último recurso en vivo si DolarAPI y Yadio fallaron por completo: Gateway Cloudflare Worker
    if (usdRate == null || usdRate <= 0) {
      final gwRates = await _fetchGatewayRates(client: httpClient);
      if (gwRates != null) {
        if ((gwRates['usd'] ?? 0) > 0) {
          usdRate = gwRates['usd']!;
          fetchedAny = true;
        }
        if ((eurRate == null || eurRate <= 0) && (gwRates['eur'] ?? 0) > 0) {
          eurRate = gwRates['eur']!;
          fetchedAny = true;
        }
        if ((usdtRate == null || usdtRate <= 0) && (gwRates['usdt'] ?? 0) > 0) {
          usdtRate = gwRates['usdt']!;
          fetchedAny = true;
        }
      }
    }

    if (fetchedAny) {
      final now = DateTime.now();
      if (usdRate != null && usdRate > 0) {
        await prefs.setDouble('cached_rate_usd', usdRate);
        await prefs.setDouble('cached_exchange_rate', usdRate);
      }
      if (eurRate != null && eurRate > 0) {
        await prefs.setDouble('cached_rate_eur', eurRate);
      }
      if (usdtRate != null && usdtRate > 0) {
        await prefs.setDouble('cached_rate_usdt', usdtRate);
      }
      await prefs.setString('cached_exchange_rates_timestamp', now.toIso8601String());
      return ExchangeRatesData(
        usd: usdRate ?? 0.0,
        eur: eurRate ?? 0.0,
        usdt: usdtRate ?? 0.0,
        fecha: now,
        esReferencia: false,
      );
    }

    // Sin dato en vivo: NO se escribe el timestamp. `fecha` es la última
    // actualización real conocida, no "ahora".
    final prevTimestampStr = prefs.getString('cached_exchange_rates_timestamp');
    final prevTimestamp = prevTimestampStr == null ? null : DateTime.tryParse(prevTimestampStr);
    return ExchangeRatesData(
      usd: usdRate ?? 0.0,
      eur: eurRate ?? 0.0,
      usdt: usdtRate ?? 0.0,
      fecha: prevTimestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
      esReferencia: true,
    );
  }

  static Future<double?> _fetchUrlDouble(String urlString, String fieldKey, {http.Client? client}) async {
    try {
      final url = Uri.parse(urlString);
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(url, headers: _requestHeaders).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final val = (data[fieldKey] as num?)?.toDouble();
          if (val != null && val > 0) return val;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Consulta Yadio API que ofrece simultáneamente USD BCV Oficial, EUR y USDT P2P
  static Future<Map<String, double>?> _fetchYadioAllRates({http.Client? client}) async {
    try {
      final httpClient = client ?? http.Client();
      final yadioUrl = Uri.parse('https://api.yadio.io/json');
      final resp = await httpClient.get(yadioUrl, headers: _requestHeaders).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final Map<String, double> result = {};

        // P2P USDT
        final p2pUsdt = (data['USD']?['other']?['p2p_usdt']?['rate'] as num?)?.toDouble() ??
            (data['USD']?['rate'] as num?)?.toDouble();
        if (p2pUsdt != null && p2pUsdt > 0) result['usdt'] = p2pUsdt;

        // Dólar Oficial BCV
        final bcvUsd = (data['USD']?['other']?['official']?['rate'] as num?)?.toDouble();
        if (bcvUsd != null && bcvUsd > 0) result['usd'] = bcvUsd;

        // Euro Oficial
        final eur = (data['EUR']?['rate'] as num?)?.toDouble();
        if (eur != null && eur > 0) result['eur'] = eur;

        if (result.isNotEmpty) return result;
      }
    } catch (_) {}
    return null;
  }

  /// Consulta jsDelivr CDN de monedas (proveedor estático inmune a bloqueos de ISP en Venezuela)
  static Future<double?> _fetchJsDelivrRate(String currency, {http.Client? client}) async {
    try {
      final httpClient = client ?? http.Client();
      final url = Uri.parse('https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${currency.toLowerCase()}.json');
      final resp = await httpClient.get(url, headers: _requestHeaders).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final rate = (data[currency.toLowerCase()]?['ves'] as num?)?.toDouble();
        if (rate != null && rate > 0) return rate;
      }
    } catch (_) {}
    return null;
  }

  /// Consulta el Gateway Cloudflare Worker en Miami ante emergencias de conectividad local
  static Future<Map<String, double>?> _fetchGatewayRates({http.Client? client}) async {
    try {
      final httpClient = client ?? http.Client();
      final url = Uri.parse('${AppConstants.defaultGatewayUrl}/tasas');
      final resp = await httpClient.get(url, headers: _requestHeaders).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final Map<String, double> result = {};
        final u = (data['usd'] as num?)?.toDouble();
        final e = (data['eur'] as num?)?.toDouble();
        final us = (data['usdt'] as num?)?.toDouble();
        if (u != null && u > 0) result['usd'] = u;
        if (e != null && e > 0) result['eur'] = e;
        if (us != null && us > 0) result['usdt'] = us;
        if (result.isNotEmpty) return result;
      }
    } catch (_) {}
    return null;
  }


  /// Obtiene la tasa de cambio para una fecha específica (formato YYYY-MM-DD) y moneda.
  /// Si la fecha es hoy o no hay histórico, consulta en vivo.
  static Future<double> getRateForDate(
    String isoDate, {
    String moneda = 'USD',
    String tipo = 'oficial',
    http.Client? client,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final monedaClean = moneda.toUpperCase();
    final httpClient = client ?? http.Client();

    // Si es hoy, consultar en vivo
    if (isoDate.isEmpty || isoDate == today) {
      final allRates = await getAllTodayRates(client: client);
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
      final response = await httpClient.get(url, headers: _requestHeaders).timeout(const Duration(seconds: 6));
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
          final response = await httpClient.get(url, headers: _requestHeaders).timeout(const Duration(seconds: 5));
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

    // 4. Fallback final a tasa del día (o última conocida en caché)
    final allRates = await getAllTodayRates(client: client);
    double finalRate = 0.0;
    if (monedaClean == 'EUR') {
      finalRate = allRates.eur;
    } else if (monedaClean == 'USDT') {
      finalRate = allRates.usdt;
    } else {
      finalRate = allRates.usd;
    }

    if (finalRate <= 0) {
      finalRate = prefs.getDouble('cached_rate_usd') ?? prefs.getDouble('cached_exchange_rate') ?? 0.0;
    }
    if (finalRate <= 50.0) {
      finalRate = AppConstants.defaultTasaCambio;
    }
    return finalRate;
  }

  /// Obtiene la tasa de cambio de hoy en tiempo real (retrocompatibilidad)
  static Future<double> getTodayRate({String tipo = 'oficial'}) async {
    final allRates = await getAllTodayRates();
    if (tipo == 'paralelo') return allRates.usdt;
    return allRates.usd;
  }
}
