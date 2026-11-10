import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../domain/monetary/rate_market.dart';

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

  factory ExchangeRatesData.fromJson(Map<String, dynamic> json) {
    final rawUsd = json['usd'];
    final rawEur = json['eur'];
    final rawUsdt = json['usdt'];
    final rawFecha = json['fecha'];
    final rawEsReferencia = json['esReferencia'];

    final double validUsd = isValidMonetaryRate(rawUsd) ? (rawUsd as num).toDouble() : 0.0;
    final double validEur = isValidMonetaryRate(rawEur) ? (rawEur as num).toDouble() : 0.0;
    final double validUsdt = isValidMonetaryRate(rawUsdt) ? (rawUsdt as num).toDouble() : 0.0;

    final DateTime? maybeFecha = (rawFecha is String) ? DateTime.tryParse(rawFecha) : null;
    final DateTime parsedFecha;
    final bool parsedEsReferencia;

    if (maybeFecha != null) {
      parsedFecha = maybeFecha;
      parsedEsReferencia = (rawEsReferencia is bool) ? rawEsReferencia : true;
    } else {
      parsedFecha = DateTime.fromMillisecondsSinceEpoch(0);
      parsedEsReferencia = true;
    }

    return ExchangeRatesData(
      usd: validUsd,
      eur: validEur,
      usdt: validUsdt,
      fecha: parsedFecha,
      esReferencia: parsedEsReferencia,
    );
  }
}

/// Tipo de mutación de caché pendiente de confirmación física en disco (U2 / NEW-1).
enum PendingPurgeMutationType {
  setString,
  remove,
}

/// Registro inmutable de una mutación de purga pendiente de confirmación física en disco (U2 / NEW-1).
class PendingPurgeOperation {
  final String key;
  final PendingPurgeMutationType type;
  final String? stringPayload;
  final int entriesCleanedCount;

  const PendingPurgeOperation.setString({
    required this.key,
    required this.stringPayload,
    this.entriesCleanedCount = 1,
  }) : type = PendingPurgeMutationType.setString;

  const PendingPurgeOperation.remove({
    required this.key,
    this.entriesCleanedCount = 1,
  })  : type = PendingPurgeMutationType.remove,
        stringPayload = null;

  @override
  String toString() =>
      'PendingPurgeOperation(key: $key, type: $type, entriesCleanedCount: $entriesCleanedCount)';
}

class ExchangeRateService {
  static const String _gatewayTasas = 'https://rindemas-gateway.cesarluispuntocom.workers.dev/tasas';
  static const String _dolarApiOficial = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const String _euroApiOficial = 'https://ve.dolarapi.com/v1/euros/oficial';
  static const String _dolarApiParalelo = 'https://ve.dolarapi.com/v1/dolares/paralelo';
  static const String _yadioJson = 'https://api.yadio.io/json';
  static const String _jsdelivrUsd = 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json';
  static const String _jsdelivrEur = 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json';

  /// Obtiene las 3 tasas del día (USD BCV, EUR BCV, USDT P2P) en paralelo
  /// con respaldo automático (Gateway Cloudflare -> DolarAPI -> Yadio Oficial -> jsDelivr).
  /// Descarta cualquier valor no finito o fuera del dominio canónico [isValidMonetaryRate].
  static Future<ExchangeRatesData> getAllTodayRates({
    http.Client? client,
    SharedPreferences? prefsInstance,
  }) async {
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();
    final purgeResult = await ensureCacheHistoricaPurgada(prefsInstance: prefs);
    final httpClient = client ?? http.Client();

    // Semillas: solo caché real válida según el predicado canónico (D-08). null = "sin dato".
    // Si la purga falló (purgeResult == -1), NO consumimos semillas de SharedPreferences (fail-closed).
    double? usdRate;
    double? eurRate;
    double? usdtRate;

    if (purgeResult != -1) {
      final rawUsd = prefs.get('cached_rate_usd') ?? prefs.get('cached_exchange_rate');
      if (isValidMonetaryRate(rawUsd)) {
        usdRate = (rawUsd as num).toDouble();
      }
      final rawEur = prefs.get('cached_rate_eur');
      if (isValidMonetaryRate(rawEur)) {
        eurRate = (rawEur as num).toDouble();
      }
      final rawUsdt = prefs.get('cached_rate_usdt');
      if (isValidMonetaryRate(rawUsdt)) {
        usdtRate = (rawUsdt as num).toDouble();
      }
    } else {
      debugPrint('ExchangeRateService: Purga fallida (-1). Se omiten semillas en getAllTodayRates.');
    }

    // 1. Intento prioritario con el Gateway Cloudflare de Rinde Más
    try {
      final gwResp = await httpClient.get(
        Uri.parse(_gatewayTasas),
        headers: {'User-Agent': 'RindeMas/1.0 (Android; Linux)'},
      ).timeout(const Duration(seconds: 4));
      if (gwResp.statusCode == 200) {
        final gwData = jsonDecode(gwResp.body);
        final rawGwUsd = gwData['usd'];
        final rawGwEur = gwData['eur'];
        final rawGwUsdt = gwData['usdt'];
        final gUsd = isValidMonetaryRate(rawGwUsd) ? (rawGwUsd as num).toDouble() : null;
        final gEur = isValidMonetaryRate(rawGwEur) ? (rawGwEur as num).toDouble() : null;
        final gUsdt = isValidMonetaryRate(rawGwUsdt) ? (rawGwUsdt as num).toDouble() : null;
        if (gUsd != null) {
          final now = DateTime.now();
          if (await prefs.setDouble('cached_rate_usd', gUsd)) {
            _onKeyWriteConfirmed('cached_rate_usd');
          } else {
            _onKeyWriteFailed('cached_rate_usd');
          }
          if (await prefs.setDouble('cached_exchange_rate', gUsd)) {
            _onKeyWriteConfirmed('cached_exchange_rate');
          } else {
            _onKeyWriteFailed('cached_exchange_rate');
          }
          if (gEur != null) {
            if (await prefs.setDouble('cached_rate_eur', gEur)) {
              _onKeyWriteConfirmed('cached_rate_eur');
            } else {
              _onKeyWriteFailed('cached_rate_eur');
            }
          }
          if (gUsdt != null) {
            if (await prefs.setDouble('cached_rate_usdt', gUsdt)) {
              _onKeyWriteConfirmed('cached_rate_usdt');
            } else {
              _onKeyWriteFailed('cached_rate_usdt');
            }
          }
          if (await prefs.setString('cached_exchange_rates_timestamp', now.toIso8601String())) {
            _onKeyWriteConfirmed('cached_exchange_rates_timestamp');
          } else {
            _onKeyWriteFailed('cached_exchange_rates_timestamp');
          }
          return ExchangeRatesData(
            usd: gUsd,
            eur: gEur ?? (eurRate ?? 0.0),
            usdt: gUsdt ?? (usdtRate ?? gUsd),
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

    if (isValidMonetaryRate(results[0])) {
      usdRate = results[0]!;
      if (await prefs.setDouble('cached_rate_usd', usdRate)) {
        _onKeyWriteConfirmed('cached_rate_usd');
      } else {
        _onKeyWriteFailed('cached_rate_usd');
      }
      if (await prefs.setDouble('cached_exchange_rate', usdRate)) {
        _onKeyWriteConfirmed('cached_exchange_rate');
      } else {
        _onKeyWriteFailed('cached_exchange_rate');
      }
      fetchedAny = true;
    }

    if (isValidMonetaryRate(results[1])) {
      eurRate = results[1]!;
      if (await prefs.setDouble('cached_rate_eur', eurRate)) {
        _onKeyWriteConfirmed('cached_rate_eur');
      } else {
        _onKeyWriteFailed('cached_rate_eur');
      }
      fetchedAny = true;
    }

    if (isValidMonetaryRate(results[2])) {
      usdtRate = results[2]!;
      if (await prefs.setDouble('cached_rate_usdt', usdtRate)) {
        _onKeyWriteConfirmed('cached_rate_usdt');
      } else {
        _onKeyWriteFailed('cached_rate_usdt');
      }
      fetchedAny = true;
    } else if (!isValidMonetaryRate(usdtRate) && isValidMonetaryRate(usdRate)) {
      // Último recurso histórico: USDT ≈ USD. Queda señalado vía
      // `esReferencia` cuando nada se obtuvo en vivo.
      usdtRate = usdRate;
    }

    if (fetchedAny) {
      final now = DateTime.now();
      if (await prefs.setString('cached_exchange_rates_timestamp', now.toIso8601String())) {
        _onKeyWriteConfirmed('cached_exchange_rates_timestamp');
      } else {
        _onKeyWriteFailed('cached_exchange_rates_timestamp');
      }
      return ExchangeRatesData(
        usd: isValidMonetaryRate(usdRate) ? usdRate! : 0.0,
        eur: isValidMonetaryRate(eurRate) ? eurRate! : 0.0,
        usdt: isValidMonetaryRate(usdtRate) ? usdtRate! : 0.0,
        fecha: now,
      );
    }

    // Sin dato en vivo: NO se escribe el timestamp. `fecha` es la última
    // actualización real conocida, no "ahora".
    // NEW-6: Comprobación segura de tipo antes de invocar tryParse
    final rawPrevTimestamp = prefs.get('cached_exchange_rates_timestamp');
    final prevTimestampStr = rawPrevTimestamp is String ? rawPrevTimestamp : null;
    final prevTimestamp = prevTimestampStr == null ? null : DateTime.tryParse(prevTimestampStr);
    return ExchangeRatesData(
      usd: isValidMonetaryRate(usdRate) ? usdRate! : 0.0,
      eur: isValidMonetaryRate(eurRate) ? eurRate! : 0.0,
      usdt: isValidMonetaryRate(usdtRate) ? usdtRate! : 0.0,
      fecha: prevTimestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
      esReferencia: true,
    );
  }

  /// Consulta USD Oficial con respaldo en cascada: DolarAPI -> Yadio Oficial -> jsDelivr
  static Future<double?> _fetchUsdLiveRate({http.Client? client}) async {
    final httpClient = client ?? http.Client();

    // 1. DolarAPI Oficial
    final dolarApiVal = await _fetchUrlDouble(_dolarApiOficial, 'promedio', client: httpClient);
    if (isValidMonetaryRate(dolarApiVal)) return dolarApiVal;

    // 2. Fallback Yadio Oficial
    try {
      final yadioUrl = Uri.parse(_yadioJson);
      final resp = await httpClient.get(yadioUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final rawOfficial = data['USD']?['other']?['official']?['rate'];
        if (isValidMonetaryRate(rawOfficial)) return (rawOfficial as num).toDouble();
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
        final rawVes = data['usd']?['ves'];
        if (isValidMonetaryRate(rawVes)) return (rawVes as num).toDouble();
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
    if (isValidMonetaryRate(euroApiVal)) return euroApiVal;

    // 2. Fallback jsDelivr Euro
    try {
      final jsdelivrUrl = Uri.parse(_jsdelivrEur);
      final resp = await httpClient.get(jsdelivrUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final rawVes = data['eur']?['ves'];
        if (isValidMonetaryRate(rawVes)) return (rawVes as num).toDouble();
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
        final rawOfficial = data['USD']?['other']?['official']?['rate'];
        final rawRatio = data['USD']?['EUR'];
        if (isValidMonetaryRate(rawOfficial) && rawRatio is num && rawRatio.isFinite && rawRatio > 0) {
          final computedEur = (rawOfficial as num).toDouble() / rawRatio.toDouble();
          if (isValidMonetaryRate(computedEur)) return computedEur;
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
        final rawVal = data[fieldKey];
        if (isValidMonetaryRate(rawVal)) return (rawVal as num).toDouble();
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
        final rawP2p = data['USD']?['other']?['p2p_usdt']?['rate'];
        if (isValidMonetaryRate(rawP2p)) return (rawP2p as num).toDouble();
        final rawUsd = data['USD']?['rate'];
        if (isValidMonetaryRate(rawUsd)) return (rawUsd as num).toDouble();
      }
    } catch (e) {
      debugPrint('ExchangeRateService: Fallback Yadio USDT falló: $e');
    }

    // Fallback directo a DolarAPI paralelo
    final paraleloVal = await _fetchUrlDouble(_dolarApiParalelo, 'promedio', client: client);
    if (isValidMonetaryRate(paraleloVal)) return paraleloVal;
    return null;
  }

  static final Map<String, List<dynamic>> _historicosMemoryCache = {};

  /// Limpia la caché en memoria de históricos (útil en pruebas)
  @visibleForTesting
  static void clearHistoricosCache() {
    _historicosMemoryCache.clear();
  }

  /// Obtiene la tasa de cambio para una fecha específica (formato YYYY-MM-DD) y moneda.
  /// Si la fecha es hoy o no hay histórico, consulta en vivo.
  static Future<double> getRateForDate(
    String isoDate, {
    String moneda = 'USD',
    String tipo = 'oficial',
    http.Client? client,
    SharedPreferences? prefsInstance,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final monedaClean = moneda.toUpperCase();
    final httpClient = client ?? http.Client();

    // Si es hoy, consultar en vivo
    if (isoDate.isEmpty || isoDate == today) {
      final allRates = await getAllTodayRates(client: client, prefsInstance: prefsInstance);
      if (monedaClean == 'EUR') return isValidMonetaryRate(allRates.eur) ? allRates.eur : 0.0;
      if (monedaClean == 'USDT') return isValidMonetaryRate(allRates.usdt) ? allRates.usdt : 0.0;
      return isValidMonetaryRate(allRates.usd) ? allRates.usd : 0.0;
    }

    // Validar formato e integridad de calendario de la fecha solicitada (N-11)
    if (!_isValidCalendarDate(isoDate)) {
      debugPrint('ExchangeRateService: Fecha no válida según calendario gregoriano ($isoDate); retorna 0.0.');
      return 0.0;
    }

    // 1. Revisar caché local por fecha y moneda
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();
    final purgeResult = await ensureCacheHistoricaPurgada(prefsInstance: prefs);
    final cacheKey = 'cached_rate_${monedaClean}_$isoDate';

    // Comportamiento fail-closed (Objetivo 3 y N1):
    // Si la purga falló (purgeResult == -1), la integridad de la caché no está verificada;
    // se omite la lectura de la caché local para no consumir datos potencialmente corruptos.
    if (purgeResult != -1) {
      final rawCached = prefs.get(cacheKey);
      if (isValidMonetaryRate(rawCached)) {
        return (rawCached as num).toDouble();
      }
    } else {
      debugPrint('ExchangeRateService: Purga fallida (-1). Se omite lectura de caché para $cacheKey.');
    }

    // Fechas anteriores al límite de histórico confiable no tienen datos
    if (isoDate.compareTo(AppConstants.fechaMinimaHistoricoTasasIso) < 0) {
      return 0.0;
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

      // Si no se proporcionó cliente mock específico, usar la caché en memoria para no repetir descargas de 113KB
      List<dynamic>? list = client == null ? _historicosMemoryCache[endpoint] : null;

      if (list == null) {
        final url = Uri.parse(endpoint);
        final response = await httpClient.get(
          url,
          headers: {'User-Agent': 'RindeMas/1.0 (Android; Linux)'},
        ).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          list = jsonDecode(response.body) as List<dynamic>;
          if (client == null) {
            _historicosMemoryCache[endpoint] = list;
          }
        }
      }

      if (list != null) {
        // Buscar coincidencia exacta
        for (final item in list) {
          if (item['fecha'] == isoDate) {
            final rawRate = item['promedio'];
            if (isValidMonetaryRate(rawRate)) {
              final rate = (rawRate as num).toDouble();
              if (await prefs.setDouble(cacheKey, rate)) {
                _onKeyWriteConfirmed(cacheKey);
              } else {
                _onKeyWriteFailed(cacheKey);
              }
              return rate;
            }
          }
        }

        // Si no hay fecha exacta (ej. fin de semana o feriado), buscar el último día hábil anterior a isoDate
        double? lastValidRate;
        String? lastValidDate;
        for (final item in list) {
          final itemFecha = item['fecha']?.toString() ?? '';
          if (itemFecha.isNotEmpty && itemFecha.compareTo(isoDate) <= 0) {
            final rawRate = item['promedio'];
            if (isValidMonetaryRate(rawRate)) {
              final rate = (rawRate as num).toDouble();
              if (lastValidDate == null || itemFecha.compareTo(lastValidDate) >= 0) {
                lastValidDate = itemFecha;
                lastValidRate = rate;
              }
            }
          }
        }

        if (lastValidRate != null) {
          if (await prefs.setDouble(cacheKey, lastValidRate)) {
            _onKeyWriteConfirmed(cacheKey);
          } else {
            _onKeyWriteFailed(cacheKey);
          }
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
            final rawVes = data['usd']?['ves'];
            if (isValidMonetaryRate(rawVes)) {
              final vesRate = (rawVes as num).toDouble();
              if (await prefs.setDouble(cacheKey, vesRate)) {
                _onKeyWriteConfirmed(cacheKey);
              } else {
                _onKeyWriteFailed(cacheKey);
              }
              return vesRate;
            }
          }
        }
      } catch (e) {
        debugPrint('ExchangeRateService: Error en getRateForDate Fawaz Ahmed: $e');
      }
    }

    // 4. Fallback de USDT a USD oficial de la misma fecha histórica si el histórico paralelo no existía
    if (monedaClean == 'USDT') {
      final usdHistorical = await getRateForDate(
        isoDate,
        moneda: 'USD',
        tipo: 'oficial',
        client: httpClient,
        prefsInstance: prefs,
      );
      if (isValidMonetaryRate(usdHistorical)) {
        if (await prefs.setDouble(cacheKey, usdHistorical)) {
          _onKeyWriteConfirmed(cacheKey);
        } else {
          _onKeyWriteFailed(cacheKey);
        }
        return usdHistorical;
      }
    }

    // 5. Para fechas históricas sin datos, retornar 0.0 para no falsificar la tasa
    // asignando erróneamente la tasa del día de hoy.
    return 0.0;
  }

  /// Obtiene la tasa de cambio de hoy en tiempo real (retrocompatibilidad)
  static Future<double> getTodayRate({String tipo = 'oficial'}) async {
    final allRates = await getAllTodayRates();
    if (tipo == 'paralelo') return allRates.usdt;
    return allRates.usd;
  }

  /// Clave persistente para garantizar la ejecución única e idempotente de la purga de caché histórica.
  static const String prefKeyCacheHistoricaPurgada = 'tasas_cache_historica_purgada_v1';

  /// Registro en memoria de operaciones pendientes de persistencia física en disco (U2 / NEW-1).
  /// Permite reintentar en el mismo proceso incluso si SharedPreferences ya mutó su caché en memoria.
  static final Map<String, PendingPurgeOperation> _pendingPurgeOperations = {};

  /// Claves cuya persistencia física válida en disco ha sido confirmada durante la generación actual (M-05 TOCTOU).
  static final Set<String> _confirmedWrites = {};

  /// Claves cuya persistencia física en disco ha fallado durante la generación actual (M-05 Scan).
  static final Set<String> _failedWrites = {};

  /// Indica si la persistencia física de la marca [prefKeyCacheHistoricaPurgada] está pendiente de confirmación (U2 / NEW-1).
  static bool _purgeMarkPendingConfirmation = false;

  /// Control de concurrencia para evitar purgas simultáneas.
  static Future<int>? _activePurgeFuture;

  @visibleForTesting
  static Future<int>? get activePurgeFuture => _activePurgeFuture;

  /// Contador monotónico de generación de purga para aislar purgas en vuelo tras un reset (M-08).
  static int _purgeGeneration = 0;

  /// Retorna si la marca de purga está pendiente de confirmación en disco (O2 / NEW-1).
  @visibleForTesting
  static bool get isPurgeMarkPendingConfirmation => _purgeMarkPendingConfirmation;

  /// Retorna las operaciones pendientes de confirmación física (O2 / NEW-1).
  @visibleForTesting
  static Map<String, PendingPurgeOperation> get pendingPurgeOperations =>
      Map.unmodifiable(_pendingPurgeOperations);

  /// Retorna el conjunto de claves con escritura confirmada (M-05).
  @visibleForTesting
  static Set<String> get confirmedWrites => Set.unmodifiable(_confirmedWrites);

  /// Retorna el conjunto de claves con escritura fallida no confirmada en disco (M-05).
  @visibleForTesting
  static Set<String> get failedWrites => Set.unmodifiable(_failedWrites);

  /// Limpia las operaciones pendientes en memoria y futuros activos (aislamiento de pruebas, M-08).
  @visibleForTesting
  static void resetPendingPurgeOperationsForTesting() {
    _purgeGeneration++;
    _pendingPurgeOperations.clear();
    _confirmedWrites.clear();
    _failedWrites.clear();
    _purgeMarkPendingConfirmation = false;
    _activePurgeFuture = null;
  }

  /// Si una escritura física en disco de un valor válido para [key] se confirmó correctamente,
  /// rescinde cualquier operación de purga pendiente obsoleta sobre esa misma clave (M-05)
  /// y registra la confirmación física para proteger contra condiciones de carrera TOCTOU.
  static void onKeyWriteConfirmed(String key) {
    _failedWrites.remove(key);
    _pendingPurgeOperations.remove(key);
    _confirmedWrites.add(key);
  }

  /// Si una escritura física en disco falló en plataforma (`return false` o excepción),
  /// registra la clave como no confiable en disco para que el escaneo de purga no la omita
  /// aunque su valor volátil en la memoria de SharedPreferences parezca válido (M-05).
  static void onKeyWriteFailed(String key) {
    _confirmedWrites.remove(key);
    _failedWrites.add(key);
  }

  static void _onKeyWriteConfirmed(String key) => onKeyWriteConfirmed(key);
  static void _onKeyWriteFailed(String key) => onKeyWriteFailed(key);

  /// Valida si una cadena ISO 'YYYY-MM-DD' corresponde a una fecha real del calendario gregoriano.
  static bool _isValidCalendarDate(String dateStr) {
    final isoPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!isoPattern.hasMatch(dateStr)) return false;
    final parts = dateStr.split('-');
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return false;
    if (m < 1 || m > 12) return false;
    if (d < 1 || d > 31) return false;
    try {
      final dt = DateTime(y, m, d);
      return dt.year == y && dt.month == m && dt.day == d;
    } catch (_) {
      return false;
    }
  }

  /// Garantiza la ejecución controlada de una sola vez de la purga selectiva de caché histórica.
  /// Es idempotente: si la marca persistente ya existe y fue confirmada físicamente, retorna 0.
  /// Si ocurre un fallo parcial o de persistencia, NO fija la marca persistente y retorna -1 para permitir reintentos.
  /// Si existen llamadas concurrentes, ambas esperan y retornan el resultado de la misma purga en curso.
  static Future<int> ensureCacheHistoricaPurgada({SharedPreferences? prefsInstance}) async {
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();

    // Comprobación de marca persistente (Criterio 4.3):
    // Solo consideramos confirmada la purga si:
    // 1. La marca en SharedPreferences es true.
    // 2. NO existe una confirmación física de marca pendiente (_purgeMarkPendingConfirmation == false).
    // 3. NO existe ninguna mutación de caché pendiente en _pendingPurgeOperations.
    final rawMark = prefs.get(prefKeyCacheHistoricaPurgada);
    if (rawMark is bool) {
      if (rawMark == true && !_purgeMarkPendingConfirmation && _pendingPurgeOperations.isEmpty) {
        return 0; // Idempotente: purga ya completada y confirmada físicamente en disco
      }
    } else if (rawMark != null) {
      debugPrint('ExchangeRateService: La marca $prefKeyCacheHistoricaPurgada tiene un tipo inesperado (${rawMark.runtimeType}). Se tratará como no purgada.');
    }

    if (_activePurgeFuture != null) {
      return await _activePurgeFuture!;
    }

    final currentGen = _purgeGeneration;

    final purgeTask = () async {
      try {
        final count = await purgarCacheHistoricaInvalida(prefsInstance: prefs);

        // Si la generación cambió (se invocó reset durante la ejecución), descartar mutación de estado
        if (_purgeGeneration != currentGen) {
          debugPrint('ExchangeRateService: Purga descartada por cambio de generación ($currentGen vs $_purgeGeneration).');
          return -1;
        }

        // Si quedaron mutaciones pendientes sin confirmar físicamente, no marcar éxito
        if (_pendingPurgeOperations.isNotEmpty) {
          debugPrint('ExchangeRateService: Quedan ${_pendingPurgeOperations.length} mutaciones pendientes. No se fija la marca.');
          return -1;
        }

        // Persistir la marca de purga. Si falla, registrar que la marca quedó pendiente (C. Marca pendiente)
        _purgeMarkPendingConfirmation = true;
        bool markSaved = false;
        try {
          markSaved = await prefs.setBool(prefKeyCacheHistoricaPurgada, true);
        } catch (e) {
          debugPrint('ExchangeRateService: Excepción al persistir marca $prefKeyCacheHistoricaPurgada: $e');
          markSaved = false;
        }

        if (_purgeGeneration != currentGen) {
          return -1;
        }

        if (!markSaved) {
          _purgeMarkPendingConfirmation = true;
          debugPrint('ExchangeRateService: No se pudo persistir la marca $prefKeyCacheHistoricaPurgada (retornó false o lanzó).');
          return -1;
        }

        // Éxito confirmado: todas las mutaciones confirmadas y marca persistida físicamente
        _purgeMarkPendingConfirmation = false;
        return count;
      } catch (e) {
        debugPrint('ExchangeRateService: Fallo en ensureCacheHistoricaPurgada: $e');
        return -1;
      }
    }();

    _activePurgeFuture = purgeTask;
    try {
      return await purgeTask;
    } finally {
      // M-08: Limpiar únicamente si sigue siendo esta misma futura (evita pisar una futura posterior si hubo reset)
      if (identical(_activePurgeFuture, purgeTask)) {
        _activePurgeFuture = null;
      }
    }
  }

  /// Limpieza selectiva de la caché histórica de tasas en SharedPreferences.
  /// Remueve únicamente:
  /// 1) Entradas con valores <= 1.0, NaN o no finitos según [isValidMonetaryRate].
  /// 2) Entradas en 'tasas_historico_v1' corruptas, con fechas no válidas en calendario o valores fuera de dominio o sin procedencia.
  /// 3) Claves 'cached_rate_...' con fechas de calendario no válidas o valores fuera de dominio.
  /// 4) Claves semillas 'cached_exchange_rate' y 'tasa_cambio_ves_usd' (AppConstants.prefTasaCambio) si contienen valores fuera de dominio.
  /// 5) Metadato corrupto 'cached_exchange_rates_timestamp' si no es String o fecha válida.
  /// No elimina entradas válidas por tener fecha anterior a 2023-01-03.
  /// Retorna el número total de entradas eliminadas o depuradas confirmadas físicamente
  /// en esta ejecución (contabilizando tanto las detectadas y persistidas en esta llamada
  /// como las operaciones pendientes de reintentos previos cuya persistencia en disco se
  /// confirmó exitosamente en esta llamada).
  /// Lanza [StateError] si alguna operación de escritura o borrado falla (fallo parcial).
  /// NO borra indiscriminadamente la caché histórica válida ante excepciones de persistencia (B1 y NEW-1).
  static Future<int> purgarCacheHistoricaInvalida({SharedPreferences? prefsInstance}) async {
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();
    final currentGen = _purgeGeneration;
    int cleanedCount = 0;
    bool allWritesSucceeded = true;

    // 0. Reintentar operaciones pendientes previas (NEW-1: divergencia memoria/disco)
    // Si una llamada anterior mutó memoria pero falló en plataforma, volvemos a persistir exactamente
    // el payload o la eliminación pendiente aunque la memoria ya parezca limpia.
    final previousPendingKeys = List<String>.from(_pendingPurgeOperations.keys);
    for (final pk in previousPendingKeys) {
      if (_purgeGeneration != currentGen) break;
      final op = _pendingPurgeOperations[pk];
      if (op == null) continue;
      if (op.type == PendingPurgeMutationType.setString) {
        try {
          final ok = await prefs.setString(op.key, op.stringPayload!);
          if (_purgeGeneration != currentGen) break;
          if (ok) {
            _pendingPurgeOperations.remove(pk);
            cleanedCount += op.entriesCleanedCount;
          } else {
            allWritesSucceeded = false;
            debugPrint('ExchangeRateService: Reintento de setString(${op.key}) retornó false.');
          }
        } catch (e) {
          allWritesSucceeded = false;
          debugPrint('ExchangeRateService: Excepción en reintento de setString(${op.key}): $e');
        }
      } else if (op.type == PendingPurgeMutationType.remove) {
        // M-05 / M5-a: En el replay de operaciones pendientes se ejecuta la persistencia física directa.
        // La rescisión de un remove pendiente por tasa fresca ocurre exclusivamente ante confirmación
        // física de disco mediante onKeyWriteConfirmed(key), no mediante lectura de la caché volátil en memoria.
        try {
          final ok = await prefs.remove(op.key);
          if (_purgeGeneration != currentGen) break;
          if (ok) {
            _pendingPurgeOperations.remove(pk);
            cleanedCount += op.entriesCleanedCount;
          } else {
            allWritesSucceeded = false;
            debugPrint('ExchangeRateService: Reintento de remove(${op.key}) retornó false.');
          }
        } catch (e) {
          allWritesSucceeded = false;
          debugPrint('ExchangeRateService: Excepción en reintento de remove(${op.key}): $e');
        }
      }
    }

    final allKeys = prefs.getKeys();
    final keysToRemove = <String>[];

    for (final key in allKeys) {
      if (key == 'tasas_historico_v1') {
        // Si ya hay una operación pendiente para esta clave que aún no se resolvió, no re-procesar
        if (_pendingPurgeOperations.containsKey(key)) {
          continue;
        }

        final rawVal = prefs.get(key);
        if (rawVal == null) continue;
        if (rawVal is! String) {
          debugPrint('ExchangeRateService: $key tiene un tipo no esperado (${rawVal.runtimeType}); se marca para eliminación por corrupción de tipo.');
          keysToRemove.add(key);
          continue;
        }
        if (rawVal.trim().isEmpty) {
          keysToRemove.add(key);
          continue;
        }

        // 1. Decodificación aislada de JSON (B1: nunca mezclar con setString)
        Map<String, dynamic>? decodedMap;
        try {
          final decoded = jsonDecode(rawVal);
          if (decoded is Map) {
            decodedMap = decoded.cast<String, dynamic>();
          } else {
            debugPrint('ExchangeRateService: $key no es un Map serializado. Se marca para eliminación.');
            keysToRemove.add(key);
            continue;
          }
        } catch (e) {
          debugPrint('ExchangeRateService: Error de sintaxis JSON en $key: $e. Se marca para eliminación.');
          keysToRemove.add(key);
          continue;
        }

        // 2. Filtrado selectivo de entradas
        final cleanedMap = <String, dynamic>{};
        bool mapMutated = false;
        int entriesCleanedInMap = 0;

        decodedMap.forEach((dateKey, val) {
          try {
            final dateStr = dateKey.toString();
            if (!_isValidCalendarDate(dateStr)) {
              mapMutated = true;
              entriesCleanedInMap++;
              return;
            }

            if (isValidMonetaryRate(val)) {
              cleanedMap[dateStr] = (val as num).toDouble();
            } else if (val is Map) {
              // Búsqueda del primer valor numérico válido conforme al predicado canónico (D-08)
              num? validRate;
              for (final field in const ['valor', 'rate', 'promedio']) {
                final fVal = val[field];
                if (isValidMonetaryRate(fVal)) {
                  validRate = fVal as num;
                  break;
                }
              }

              // Búsqueda de procedencia válida (no vacía) conforme a RM-03 v1.2 §6.1
              String? validSource;
              for (final field in const ['source', 'fuente']) {
                final fVal = val[field];
                if (fVal is String && fVal.trim().isNotEmpty) {
                  validSource = fVal.trim();
                  break;
                }
              }

              if (validRate != null && validSource != null) {
                cleanedMap[dateStr] = val;
              } else {
                mapMutated = true;
                entriesCleanedInMap++;
              }
            } else {
              mapMutated = true;
              entriesCleanedInMap++;
            }
          } catch (e) {
            debugPrint('ExchangeRateService: Excepción procesando entrada $dateKey en $key: $e');
            mapMutated = true;
            entriesCleanedInMap++;
          }
        });

        // 3. Persistencia aislada del mapa depurado (B1, B-02 & NEW-1)
        if (mapMutated) {
          if (cleanedMap.isEmpty) {
            // B-02: Se elimina la clave completa del mapa corrupto; la cantidad de entradas
            // depuradas es entriesCleanedInMap tanto en el primer intento como en el reintento.
            _pendingPurgeOperations[key] = PendingPurgeOperation.remove(
              key: key,
              entriesCleanedCount: entriesCleanedInMap,
            );
            try {
              final removed = await prefs.remove(key);
              if (_purgeGeneration != currentGen) break;
              if (removed) {
                _pendingPurgeOperations.remove(key);
                cleanedCount += entriesCleanedInMap;
              } else {
                debugPrint('ExchangeRateService: prefs.remove($key) retornó false. Se registra operación pendiente.');
                allWritesSucceeded = false;
              }
            } catch (e) {
              debugPrint('ExchangeRateService: Excepción al eliminar $key vacío: $e. Se registra operación pendiente.');
              allWritesSucceeded = false;
            }
          } else {
            final payload = jsonEncode(cleanedMap);
            _pendingPurgeOperations[key] = PendingPurgeOperation.setString(
              key: key,
              stringPayload: payload,
              entriesCleanedCount: entriesCleanedInMap,
            );
            try {
              final saved = await prefs.setString(key, payload);
              if (_purgeGeneration != currentGen) break;
              if (saved) {
                _pendingPurgeOperations.remove(key);
                cleanedCount += entriesCleanedInMap;
              } else {
                debugPrint('ExchangeRateService: prefs.setString($key) retornó false. Se registra operación pendiente.');
                allWritesSucceeded = false;
              }
            } catch (e) {
              debugPrint('ExchangeRateService: Excepción al guardar $key depurado: $e. Se registra operación pendiente.');
              allWritesSucceeded = false;
            }
          }
        }
      } else if (key == 'cached_exchange_rate' || key == AppConstants.prefTasaCambio) {
        if (_pendingPurgeOperations.containsKey(key)) continue;
        final rawVal = prefs.get(key);
        if (rawVal == null) continue;
        if (!isValidMonetaryRate(rawVal) || _failedWrites.contains(key)) {
          keysToRemove.add(key);
        }
      } else if (key == 'cached_exchange_rates_timestamp') {
        // NEW-6 y M-04: Si el timestamp está corrupto (no String, no parseable o fecha imposible), se purga selectivamente
        if (_pendingPurgeOperations.containsKey(key)) continue;
        final rawVal = prefs.get(key);
        if (rawVal == null) continue;
        bool isCorruptTimestamp = false;
        if (rawVal is! String) {
          isCorruptTimestamp = true;
        } else {
          final parsed = DateTime.tryParse(rawVal);
          if (parsed == null) {
            isCorruptTimestamp = true;
          } else {
            final datePart = rawVal.split('T')[0];
            if (!_isValidCalendarDate(datePart)) {
              isCorruptTimestamp = true;
            }
          }
        }
        if (isCorruptTimestamp || _failedWrites.contains(key)) {
          debugPrint('ExchangeRateService: $key corrupto o no confirmado físicamente; se marca para eliminación.');
          keysToRemove.add(key);
        }
      } else if (key.startsWith('cached_rate_')) {
        if (_pendingPurgeOperations.containsKey(key)) continue;
        final parts = key.split('_');
        if (parts.length >= 4) {
          final datePart = parts.sublist(3).join('_');
          final rawVal = prefs.get(key);
          final bool dateInvalid = !_isValidCalendarDate(datePart);
          final bool valInvalid = !isValidMonetaryRate(rawVal) || _failedWrites.contains(key);
          if (dateInvalid || valInvalid) {
            keysToRemove.add(key);
          }
        } else {
          // Claves de tasa del día (ej. cached_rate_usd, cached_rate_eur, cached_rate_usdt)
          final rawVal = prefs.get(key);
          if (!isValidMonetaryRate(rawVal) || _failedWrites.contains(key)) {
            keysToRemove.add(key);
          }
        }
      }
    }

    // Claves marcadas como inválidas no pueden ser protegidas por confirmaciones de escrituras anteriores (M-05).
    _confirmedWrites.removeAll(keysToRemove);

    for (final k in keysToRemove) {
      if (_purgeGeneration != currentGen) break;

      // M-05 (TOCTOU): Solo se puede omitir el borrado si una escritura física en disco
      // fue explícitamente confirmada mediante onKeyWriteConfirmed(k) durante la purga,
      // NUNCA basándose únicamente en la lectura de memoria de prefs.get(k).
      // NUNCA omitir el borrado de claves con corrupción estructural (fechas imposibles o tipos corruptos, R-01).
      final bool writeConfirmed = _confirmedWrites.contains(k);
      final currentVal = prefs.get(k);

      if (writeConfirmed) {
        if (k == 'cached_exchange_rates_timestamp') {
          if (currentVal is String) {
            final parsed = DateTime.tryParse(currentVal);
            if (parsed != null && _isValidCalendarDate(currentVal.split('T')[0])) {
              continue;
            }
          }
        } else if (k == 'cached_exchange_rate' ||
                   k == AppConstants.prefTasaCambio ||
                   k == 'cached_rate_usd' ||
                   k == 'cached_rate_eur' ||
                   k == 'cached_rate_usdt') {
          if (isValidMonetaryRate(currentVal)) {
            continue;
          }
        } else if (k.startsWith('cached_rate_')) {
          final parts = k.split('_');
          if (parts.length >= 4) {
            final datePart = parts.sublist(3).join('_');
            if (_isValidCalendarDate(datePart) && isValidMonetaryRate(currentVal)) {
              continue;
            }
          }
        }
      }

      _pendingPurgeOperations[k] = PendingPurgeOperation.remove(key: k, entriesCleanedCount: 1);
      try {
        final removed = await prefs.remove(k);
        if (_purgeGeneration != currentGen) break;
        if (_confirmedWrites.contains(k)) {
          // Si durante el await de remove se confirmó concurrentemente una escritura física fresca,
          // se rescinde la operación y se preserva el dato fresco (§2.5).
          _pendingPurgeOperations.remove(k);
        } else if (removed) {
          _pendingPurgeOperations.remove(k);
          _failedWrites.remove(k);
          cleanedCount++;
        } else {
          debugPrint('ExchangeRateService: prefs.remove($k) retornó false. Se registra operación pendiente.');
          allWritesSucceeded = false;
        }
      } catch (e) {
        debugPrint('ExchangeRateService: Excepción en prefs.remove($k): $e. Se registra operación pendiente.');
        allWritesSucceeded = false;
      }
    }

    if (_purgeGeneration != currentGen) {
      throw StateError('Purga abortada por cambio de generación.');
    }

    if (!allWritesSucceeded || _pendingPurgeOperations.isNotEmpty) {
      throw StateError('Fallo de persistencia al purgar la caché histórica en SharedPreferences (${_pendingPurgeOperations.length} pendientes)');
    }

    return cleanedCount;
  }
}
