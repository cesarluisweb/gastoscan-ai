import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _gatewayTasas = 'https://rindemas-gateway.cesarluispuntocom.workers.dev/tasas';
  static const String _dolarApiOficial = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const String _euroApiOficial = 'https://ve.dolarapi.com/v1/euros/oficial';
  static const String _dolarApiParalelo = 'https://ve.dolarapi.com/v1/dolares/paralelo';
  static const String _yadioJson = 'https://api.yadio.io/json';
  static const String _jsdelivrUsd = 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json';
  static const String _jsdelivrEur = 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json';

  /// Obtiene las 3 tasas del día (USD BCV, EUR BCV, USDT Binance / Paralelo) en paralelo
  /// con respaldo automático (Gateway Cloudflare -> DolarAPI -> Yadio Oficial -> jsDelivr).
  /// Descarta cualquier valor obsoleto <= 50.0 proveniente de semillas o pruebas previas.
  static Future<ExchangeRatesData> getAllTodayRates({http.Client? client}) async {
    final prefs = await SharedPreferences.getInstance();
    final httpClient = client ?? http.Client();

    // Semillas: solo caché real válida (> 50.0). null = "sin dato".
    double? usdRate = prefs.getDouble('cached_rate_usd') ?? prefs.getDouble('cached_exchange_rate');
    if (usdRate != null && usdRate <= 50.0) usdRate = null;
    double? eurRate = prefs.getDouble('cached_rate_eur');
    if (eurRate != null && eurRate <= 50.0) eurRate = null;
    double? usdtRate = prefs.getDouble('cached_rate_usdt');
    if (usdtRate != null && usdtRate <= 50.0) usdtRate = null;

    // 1. Intento prioritario con el Gateway Cloudflare de Rinde Más
    try {
      final gwResp = await httpClient.get(
        Uri.parse(_gatewayTasas),
        headers: {'User-Agent': 'RindeMas/1.0 (Android; Linux)'},
      ).timeout(const Duration(seconds: 4));
      if (gwResp.statusCode == 200) {
        final gwData = jsonDecode(gwResp.body);
        final gUsd = (gwData['usd'] as num?)?.toDouble();
        final gEur = (gwData['eur'] as num?)?.toDouble();
        final gUsdt = (gwData['usdt'] as num?)?.toDouble();
        if (gUsd != null && gUsd > 50.0) {
          final now = DateTime.now();
          await prefs.setDouble('cached_rate_usd', gUsd);
          await prefs.setDouble('cached_exchange_rate', gUsd);
          if (gEur != null && gEur > 50.0) {
            await prefs.setDouble('cached_rate_eur', gEur);
          }
          if (gUsdt != null && gUsdt > 50.0) {
            await prefs.setDouble('cached_rate_usdt', gUsdt);
          }
          await prefs.setString('cached_exchange_rates_timestamp', now.toIso8601String());
          return ExchangeRatesData(
            usd: gUsd,
            eur: (gEur != null && gEur > 50.0) ? gEur : (eurRate ?? 0.0),
            usdt: (gUsdt != null && gUsdt > 50.0) ? gUsdt : (usdtRate ?? gUsd),
            fecha: now,
          );
        }
      }
    } catch (e) {
      debugPrint('ExchangeRateService: Gateway no disponible, usando cascada directa: $e');
    }

    final results = await Future.wait([
      _fetchUsdLiveRate(client: httpClient),
      _fetchEurLiveRate(client: httpClient),
      _fetchUsdtLiveRate(client: httpClient),
    ]);

    bool fetchedAny = false;

    if (results[0] != null && results[0]! > 50.0) {
      usdRate = results[0]!;
      await prefs.setDouble('cached_rate_usd', usdRate);
      await prefs.setDouble('cached_exchange_rate', usdRate);
      fetchedAny = true;
    }

    if (results[1] != null && results[1]! > 50.0) {
      eurRate = results[1]!;
      await prefs.setDouble('cached_rate_eur', eurRate);
      fetchedAny = true;
    }

    if (results[2] != null && results[2]! > 50.0) {
      usdtRate = results[2]!;
      await prefs.setDouble('cached_rate_usdt', usdtRate);
      fetchedAny = true;
    } else if ((usdtRate == null || usdtRate <= 50.0) && (usdRate != null && usdRate > 50.0)) {
      // Último recurso histórico: USDT ≈ USD. Queda señalado vía
      // `esReferencia` cuando nada se obtuvo en vivo.
      usdtRate = usdRate;
    }

    if (fetchedAny) {
      final now = DateTime.now();
      await prefs.setString('cached_exchange_rates_timestamp', now.toIso8601String());
      return ExchangeRatesData(
        usd: usdRate ?? 0.0,
        eur: eurRate ?? 0.0,
        usdt: usdtRate ?? 0.0,
        fecha: now,
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

  /// Consulta USD Oficial con respaldo en cascada: DolarAPI -> Yadio Oficial -> jsDelivr
  static Future<double?> _fetchUsdLiveRate({http.Client? client}) async {
    final httpClient = client ?? http.Client();

    // 1. DolarAPI Oficial
    final dolarApiVal = await _fetchUrlDouble(_dolarApiOficial, 'promedio', client: httpClient);
    if (dolarApiVal != null && dolarApiVal > 50.0) return dolarApiVal;

    // 2. Fallback Yadio Oficial
    try {
      final yadioUrl = Uri.parse(_yadioJson);
      final resp = await httpClient.get(yadioUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final officialRate = (data['USD']?['other']?['official']?['rate'] as num?)?.toDouble();
        if (officialRate != null && officialRate > 50.0) return officialRate;
      }
    } catch (e) {
      debugPrint('ExchangeRateService: Fallback Yadio USD falló: $e');
    }

    // 3. Fallback jsDelivr
    try {
      final jsdelivrUrl = Uri.parse(_jsdelivrUsd);
      final resp = await httpClient.get(jsdelivrUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final vesRate = (data['usd']?['ves'] as num?)?.toDouble();
        if (vesRate != null && vesRate > 50.0) return vesRate;
      }
    } catch (e) {
      debugPrint('ExchangeRateService: Fallback jsDelivr USD falló: $e');
    }

    return null;
  }

  /// Consulta EUR Oficial con respaldo en cascada: DolarAPI -> jsDelivr -> Yadio
  static Future<double?> _fetchEurLiveRate({http.Client? client}) async {
    final httpClient = client ?? http.Client();

    // 1. DolarAPI Euro Oficial
    final euroApiVal = await _fetchUrlDouble(_euroApiOficial, 'promedio', client: httpClient);
    if (euroApiVal != null && euroApiVal > 50.0) return euroApiVal;

    // 2. Fallback jsDelivr Euro
    try {
      final jsdelivrUrl = Uri.parse(_jsdelivrEur);
      final resp = await httpClient.get(jsdelivrUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final vesRate = (data['eur']?['ves'] as num?)?.toDouble();
        if (vesRate != null && vesRate > 50.0) return vesRate;
      }
    } catch (e) {
      debugPrint('ExchangeRateService: Fallback jsDelivr EUR falló: $e');
    }

    // 3. Fallback Yadio Official / EUR ratio
    try {
      final yadioUrl = Uri.parse(_yadioJson);
      final resp = await httpClient.get(yadioUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final officialRate = (data['USD']?['other']?['official']?['rate'] as num?)?.toDouble();
        final eurRatio = (data['USD']?['EUR'] as num?)?.toDouble();
        if (officialRate != null && officialRate > 50.0 && eurRatio != null && eurRatio > 0) {
          final computedEur = officialRate / eurRatio;
          if (computedEur > 50.0) return computedEur;
        }
      }
    } catch (e) {
      debugPrint('ExchangeRateService: Fallback Yadio EUR falló: $e');
    }

    return null;
  }

  static Future<double?> _fetchUrlDouble(String urlString, String fieldKey, {http.Client? client}) async {
    try {
      final url = Uri.parse(urlString);
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(
        url,
        headers: {'User-Agent': 'RindeMas/1.0 (Android; Linux)'},
      ).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final val = (data[fieldKey] as num?)?.toDouble();
        if (val != null && val > 0) return val;
      }
    } catch (e) {
      debugPrint('ExchangeRateService: Error en _fetchUrlDouble ($urlString): $e');
    }
    return null;
  }

  /// Intenta consultar Yadio P2P / DolarAPI paralelo para USDT
  static Future<double?> _fetchUsdtLiveRate({http.Client? client}) async {
    try {
      final httpClient = client ?? http.Client();
      final yadioUrl = Uri.parse(_yadioJson);
      final resp = await httpClient.get(yadioUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final p2pUsdt = (data['USD']?['other']?['p2p_usdt']?['rate'] as num?)?.toDouble();
        if (p2pUsdt != null && p2pUsdt > 50.0) return p2pUsdt;
        final usdRate = (data['USD']?['rate'] as num?)?.toDouble();
        if (usdRate != null && usdRate > 50.0) return usdRate;
      }
    } catch (e) {
      debugPrint('ExchangeRateService: Fallback Yadio USDT falló: $e');
    }

    // Fallback directo a DolarAPI paralelo
    final paraleloVal = await _fetchUrlDouble(_dolarApiParalelo, 'promedio', client: client);
    if (paraleloVal != null && paraleloVal > 50.0) return paraleloVal;
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
      final response = await httpClient.get(url).timeout(const Duration(seconds: 5));
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
    } catch (e) {
      debugPrint('ExchangeRateService: Error en getRateForDate históricos DolarAPI: $e');
    }

    // 3. Fallback retrocediendo día a día en Fawaz Ahmed Currency API para USD
    if (monedaClean == 'USD') {
      try {
        DateTime parsedDate = DateTime.tryParse(isoDate) ?? DateTime.now();
        for (int i = 0; i < 5; i++) {
          final targetIso = parsedDate.subtract(Duration(days: i)).toIso8601String().substring(0, 10);
          final url = Uri.parse('https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@$targetIso/v1/currencies/usd.json');
          final response = await httpClient.get(url).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final vesRate = (data['usd']?['ves'] as num?)?.toDouble();
            if (vesRate != null && vesRate > 0) {
              await prefs.setDouble(cacheKey, vesRate);
              return vesRate;
            }
          }
        }
      } catch (e) {
        debugPrint('ExchangeRateService: Error en getRateForDate Fawaz Ahmed: $e');
      }
    }

    // 4. Fallback final a tasa del día (o última tasa en caché si no hay conexión)
    final allRates = await getAllTodayRates(client: client);
    double finalRate = 0.0;
    if (monedaClean == 'EUR') {
      finalRate = allRates.eur > 0 ? allRates.eur : allRates.usd;
    } else if (monedaClean == 'USDT') {
      finalRate = allRates.usdt > 0 ? allRates.usdt : allRates.usd;
    } else {
      finalRate = allRates.usd;
    }

    if (finalRate <= 50.0) {
      final cachedVal = prefs.getDouble('cached_rate_usd') ??
          prefs.getDouble('cached_exchange_rate') ??
          prefs.getDouble('tasa_cambio_ves_usd');
      if (cachedVal != null && cachedVal > 50.0) {
        finalRate = cachedVal;
      } else {
        finalRate = 0.0;
      }
    }
    return finalRate > 50.0 ? finalRate : 0.0;
  }

  /// Obtiene la tasa de cambio de hoy en tiempo real (retrocompatibilidad)
  static Future<double> getTodayRate({String tipo = 'oficial'}) async {
    final allRates = await getAllTodayRates();
    if (tipo == 'paralelo') return allRates.usdt;
    return allRates.usd;
  }
}
