import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// Candidato de una fuente de tasa. `name` se usa para trazabilidad.
class _Candidate {
  const _Candidate(this.name, this.fetch);
  final String name;
  final Future<double?> Function() fetch;
}

/// Resultado de resolver una divisa: valor y fuente que lo entregó
/// (`''` cuando ninguna respondió).
class _Resolved {
  const _Resolved(this.value, this.source);
  /// 0.0 == sin dato en vivo.
  final double value;
  final String source;
  bool get esEnVivo => value > 0;
}

/// Tasa agregada del Gateway propio: una sola petición cubre las 3 divisas.
class _GatewayRates {
  const _GatewayRates({this.usd, this.eur, this.usdt});
  final double? usd;
  final double? eur;
  final double? usdt;
  bool get vacio => usd == null && eur == null && usdt == null;
}

/// Tasas de Yadio relevantes: USD oficial y USDT P2P.
class _YadioRates {
  const _YadioRates({this.oficialUsd, this.p2pUsdt});
  final double? oficialUsd;
  final double? p2pUsdt;
}

class ExchangeRatesData {
  final double usd;
  final double eur;
  final double usdt;
  final DateTime fecha;
  /// true cuando ESE valor NO se obtuvo en vivo (viene de caché o queda en 0).
  /// Es por divisa a propósito: que Yadio entregue el USDT no convierte el USD
  /// en un dato vigente.
  final bool usdEsReferencia;
  final bool eurEsReferencia;
  final bool usdtEsReferencia;
  /// Fuente que entregó cada divisa (trazabilidad; no se muestra cruda al usuario).
  final Map<String, String> fuentes;

  const ExchangeRatesData({
    required this.usd,
    required this.eur,
    required this.usdt,
    required this.fecha,
    this.usdEsReferencia = false,
    this.eurEsReferencia = false,
    this.usdtEsReferencia = false,
    this.fuentes = const {},
  });

  /// true si NINGUNA divisa se obtuvo en vivo (compatibilidad de badge único).
  bool get esReferencia => usdEsReferencia && eurEsReferencia && usdtEsReferencia;

  /// true si al menos una divisa llegó en vivo.
  bool get algoEnVivo => !esReferencia;

  Map<String, dynamic> toJson() => {
    'usd': usd,
    'eur': eur,
    'usdt': usdt,
    'fecha': fecha.toIso8601String(),
    'esReferencia': esReferencia,
    'usdEsReferencia': usdEsReferencia,
    'eurEsReferencia': eurEsReferencia,
    'usdtEsReferencia': usdtEsReferencia,
    'fuentes': fuentes,
  };

  factory ExchangeRatesData.fromJson(Map<String, dynamic> json) {
    // `esReferencia` se conserva para leer JSON viejo que no traía banderas
    // por divisa.
    final legacy = json['esReferencia'] as bool? ?? true;
    return ExchangeRatesData(
      usd: (json['usd'] as num?)?.toDouble() ?? 0.0,
      eur: (json['eur'] as num?)?.toDouble() ?? 0.0,
      usdt: (json['usdt'] as num?)?.toDouble() ?? 0.0,
      fecha: DateTime.tryParse(json['fecha'] ?? '') ?? DateTime.now(),
      usdEsReferencia: json['usdEsReferencia'] as bool? ?? legacy,
      eurEsReferencia: json['eurEsReferencia'] as bool? ?? legacy,
      usdtEsReferencia: json['usdtEsReferencia'] as bool? ?? legacy,
      fuentes: (json['fuentes'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
    );
  }
}

class ExchangeRateService {
  static const String _dolarApiOficial = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const String _euroApiOficial = 'https://ve.dolarapi.com/v1/euros/oficial';
  static const String _dolarApiParalelo = 'https://ve.dolarapi.com/v1/dolares/paralelo';
  static const String _yadioJson = 'https://api.yadio.io/json';
  static const String _jsDelivrUsd =
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json';
  static const String _jsDelivrEur =
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json';

  static const Duration _timeoutFuente = Duration(seconds: 6);

  // Caché en memoria de la última resolución: guardar un gasto llama
  // `getRateForDate` 3 veces seguidas (USD/EUR/USDT) y no tiene sentido repetir
  // la cascada completa en cada llamada.
  static ExchangeRatesData? _memo;
  static DateTime? _memoAt;
  static Future<ExchangeRatesData>? _enVuelo;
  static const Duration _memoTtl = Duration(minutes: 10);

  static bool get _memoVigente =>
      _memo != null && _memoAt != null && DateTime.now().difference(_memoAt!) < _memoTtl;

  @visibleForTesting
  static void limpiarCache() {
    _memo = null;
    _memoAt = null;
    _enVuelo = null;
  }

  /// Obtiene las 3 tasas del día (USD BCV, EUR BCV, USDT P2P) con cascada
  /// INDEPENDIENTE POR DIVISA.
  ///
  /// Antes solo `ve.dolarapi.com` podía entregar el USD oficial y cualquier
  /// éxito parcial (por ejemplo, solo Yadio) se reportaba como "en vivo": si ese
  /// único dominio fallaba desde el teléfono, la app mostraba la semilla
  /// (40 Bs) como si fuera la tasa vigente, sin advertencia y sin forma de
  /// diagnosticarlo. Ahora cada divisa tiene 3 fuentes independientes y se
  /// marca como referencia únicamente la divisa que no llegó en vivo.
  ///
  /// [forzar] ignora la caché en memoria (lo usa el botón de actualizar).
  static Future<ExchangeRatesData> getAllTodayRates({
    http.Client? client,
    bool forzar = false,
  }) async {
    final puedeCachear = client == null && !forzar;
    if (puedeCachear) {
      if (_memoVigente) return _memo!;
      final enVuelo = _enVuelo;
      if (enVuelo != null) return enVuelo;
    }

    final futuro = _resolverTasasDeHoy(client: client);
    if (!puedeCachear) return futuro;

    _enVuelo = futuro;
    try {
      final data = await futuro;
      if (data.algoEnVivo) {
        _memo = data;
        _memoAt = DateTime.now();
      }
      return data;
    } finally {
      _enVuelo = null;
    }
  }

  static Future<ExchangeRatesData> _resolverTasasDeHoy({http.Client? client}) async {
    final prefs = await SharedPreferences.getInstance();
    final httpClient = client ?? http.Client();

    // Semillas: solo caché real y verosímil (se descarta la semilla 40).
    double? usd = _verosimil(prefs.getDouble('cached_rate_usd') ?? prefs.getDouble('cached_exchange_rate'));
    double? eur = _verosimil(prefs.getDouble('cached_rate_eur'));
    double? usdt = _verosimil(prefs.getDouble('cached_rate_usdt'));

    // Fuentes agregadas: 2 peticiones cubren todo (gateway + Yadio).
    final agregadas = await Future.wait([
      _fetchGateway(client: httpClient),
      _fetchYadio(client: httpClient),
    ]);
    final gateway = agregadas[0] as _GatewayRates?;
    final yadio = agregadas[1] as _YadioRates?;

    // Cascada por divisa, en paralelo entre sí. Dentro de una divisa el orden
    // de la lista ES la prioridad: se toma la primera con valor positivo.
    Future<_Resolved> resolverUsd() async {
      final golpe = _golpeDirecto('gateway', gateway?.usd);
      if (golpe != null) return golpe; // una sola petición, sin cascada
      return _resolver([
        _Candidate('dolarapi', () => _fetchUrlDouble(_dolarApiOficial, 'promedio', client: httpClient)),
        _Candidate('yadio-oficial', () async => yadio?.oficialUsd),
        _Candidate('jsdelivr', () => _fetchJsDelivr(_jsDelivrUsd, 'usd', client: httpClient)),
      ]);
    }

    Future<_Resolved> resolverEur() async {
      final golpe = _golpeDirecto('gateway', gateway?.eur);
      if (golpe != null) return golpe;
      return _resolver([
        _Candidate('dolarapi', () => _fetchUrlDouble(_euroApiOficial, 'promedio', client: httpClient)),
        _Candidate('jsdelivr', () => _fetchJsDelivr(_jsDelivrEur, 'eur', client: httpClient)),
      ]);
    }

    Future<_Resolved> resolverUsdt() async {
      final golpe = _golpeDirecto('gateway', gateway?.usdt);
      if (golpe != null) return golpe;
      return _resolver([
        _Candidate('yadio-p2p', () async => yadio?.p2pUsdt),
        _Candidate('dolarapi-paralelo', () => _fetchUrlDouble(_dolarApiParalelo, 'promedio', client: httpClient)),
      ]);
    }

    final resueltas = await Future.wait([resolverUsd(), resolverEur(), resolverUsdt()]);

    final usdLive = resueltas[0];
    final eurLive = resueltas[1];
    final usdtLive = resueltas[2];

    final fuentes = <String, String>{};

    if (usdLive.esEnVivo) {
      usd = usdLive.value;
      fuentes['usd'] = usdLive.source;
      await prefs.setDouble('cached_rate_usd', usd);
      await prefs.setDouble('cached_exchange_rate', usd);
    } else if (usd != null) {
      fuentes['usd'] = 'cache';
    }

    if (eurLive.esEnVivo) {
      eur = eurLive.value;
      fuentes['eur'] = eurLive.source;
      await prefs.setDouble('cached_rate_eur', eur);
    } else if (eur != null) {
      fuentes['eur'] = 'cache';
    }

    if (usdtLive.esEnVivo) {
      usdt = usdtLive.value;
      fuentes['usdt'] = usdtLive.source;
      await prefs.setDouble('cached_rate_usdt', usdt);
    } else if (usdt != null) {
      fuentes['usdt'] = 'cache';
    } else if (usd != null && usd > 0) {
      // Último recurso histórico: USDT ≈ USD. Queda marcado como referencia.
      usdt = usd;
    }

    debugPrint(
      '[tasas] USD=${usd?.toStringAsFixed(2) ?? '0'} '
      '(${usdLive.esEnVivo ? usdLive.source : 'referencia'}) | '
      'EUR=${eur?.toStringAsFixed(2) ?? '0'} '
      '(${eurLive.esEnVivo ? eurLive.source : 'referencia'}) | '
      'USDT=${usdt?.toStringAsFixed(2) ?? '0'} '
      '(${usdtLive.esEnVivo ? usdtLive.source : 'referencia'})',
    );

    if (usdLive.esEnVivo || eurLive.esEnVivo || usdtLive.esEnVivo) {
      final now = DateTime.now();
      await prefs.setString('cached_exchange_rates_timestamp', now.toIso8601String());
      return ExchangeRatesData(
        usd: usd ?? 0.0,
        eur: eur ?? 0.0,
        usdt: usdt ?? 0.0,
        fecha: now,
        usdEsReferencia: !usdLive.esEnVivo,
        eurEsReferencia: !eurLive.esEnVivo,
        usdtEsReferencia: !usdtLive.esEnVivo,
        fuentes: fuentes,
      );
    }

    // Sin dato en vivo: NO se escribe el timestamp ni se inventan valores.
    // `fecha` sigue siendo la última actualización real conocida.
    final prevTimestampStr = prefs.getString('cached_exchange_rates_timestamp');
    final prevTimestamp = prevTimestampStr == null ? null : DateTime.tryParse(prevTimestampStr);
    return ExchangeRatesData(
      usd: usd ?? 0.0,
      eur: eur ?? 0.0,
      usdt: usdt ?? 0.0,
      fecha: prevTimestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
      usdEsReferencia: true,
      eurEsReferencia: true,
      usdtEsReferencia: true,
      fuentes: fuentes,
    );
  }

  static _Resolved? _golpeDirecto(String fuente, double? valor) {
    if (valor != null && valor > 0) return _Resolved(valor, fuente);
    return null;
  }

  /// Descarta valores no verosímiles para una tasa BCV vigente.
  static double? _verosimil(double? valor) {
    if (valor == null || valor < AppConstants.tasaMinimaPlausible) return null;
    return valor;
  }

  /// Resuelve una divisa tomando la primera fuente que respondió. Todas se
  /// piden en paralelo (se espera a la más lenta, no a la suma) y una fuente
  /// caída no puede impedir que las demás entreguen su valor.
  static Future<_Resolved> _resolver(List<_Candidate> candidatos) async {
    final valores = await Future.wait(candidatos.map((c) async {
      try {
        return await c.fetch();
      } catch (_) {
        return null;
      }
    }));
    for (var i = 0; i < candidatos.length; i++) {
      final v = valores[i];
      if (v != null && v > 0) return _Resolved(v, candidatos[i].name);
    }
    return const _Resolved(0.0, '');
  }

  static Future<double?> _fetchUrlDouble(String urlString, String fieldKey, {http.Client? client}) async {
    try {
      final url = Uri.parse(urlString);
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(url).timeout(_timeoutFuente);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final val = (data[fieldKey] as num?)?.toDouble();
        if (val != null && val > 0) return val;
      }
    } catch (_) {}
    return null;
  }

  /// Gateway propio (Cloudflare Worker). Su salida hacia los APIs de origen no
  /// depende del ISP del teléfono, así que sobrevive a bloqueos por IP de
  /// operadora que sí derriban al cliente directo.
  static Future<_GatewayRates?> _fetchGateway({http.Client? client}) async {
    try {
      final httpClient = client ?? http.Client();
      final base = AppConstants.defaultGatewayUrl.replaceAll(RegExp(r'/+$'), '');
      final response = await httpClient.get(Uri.parse('$base/tasas')).timeout(_timeoutFuente);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = _GatewayRates(
          usd: _positivo(data['usd']),
          eur: _positivo(data['eur']),
          usdt: _positivo(data['usdt']),
        );
        if (!rates.vacio) return rates;
      }
    } catch (_) {}
    return null;
  }

  /// Yadio expone la tasa oficial del BCV (`USD.other.official.rate`) además del
  /// P2P de USDT. Antes solo se usaba el segundo.
  static Future<_YadioRates?> _fetchYadio({http.Client? client}) async {
    try {
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(Uri.parse(_yadioJson)).timeout(_timeoutFuente);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = _YadioRates(
          oficialUsd: _positivo(data['USD']?['other']?['official']?['rate']),
          p2pUsdt: _positivo(data['USD']?['other']?['p2p_usdt']?['rate']) ??
              _positivo(data['USD']?['rate']),
        );
        if (rates.oficialUsd != null || rates.p2pUsdt != null) return rates;
      }
    } catch (_) {}
    return null;
  }

  /// Espejo del BCV servido por jsDelivr (CDN de Cloudflare, dominio sin
  /// "dolar"): fuente independiente que ya se usaba para fechas pasadas.
  static Future<double?> _fetchJsDelivr(String url, String moneda, {http.Client? client}) async {
    try {
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(Uri.parse(url)).timeout(_timeoutFuente);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final val = (data[moneda]?['ves'] as num?)?.toDouble();
        if (val != null && val > 0) return val;
      }
    } catch (_) {}
    return null;
  }

  static double? _positivo(Object? value) {
    if (value is num) {
      final n = value.toDouble();
      return n > 0 ? n : null;
    }
    final n = double.tryParse('$value');
    if (n == null || n <= 0) return null;
    return n;
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
      final response = await httpClient.get(url).timeout(_timeoutFuente);
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
      } catch (_) {}
    }

    // 4. Fallback final a tasa del día
    final allRates = await getAllTodayRates(client: client);
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
