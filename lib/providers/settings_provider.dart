import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../domain/monetary/rate_market.dart';
import '../services/connectivity_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/notification_service.dart';

class SettingsProvider with ChangeNotifier {
  final FlutterSecureStorage _secureStorage;
  final ConnectivityService _connectivityService;
  final DateTime Function() _now;
  final Duration _reconnectDebounce;
  final Duration _autoRefreshCooldown;
  final http.Client? _defaultHttpClient;

  StreamSubscription<bool>? _connectivitySub;
  Timer? _reconnectDebounceTimer;
  Future<bool>? _inFlightRateSync;
  DateTime? _lastAutoRefreshAttemptAt;

  String _apiKey = '';
  int _apiKeyRevision = 0;
  bool _guardarFotos = AppConstants.defaultGuardarFotos;
  bool _avisoGaleriaMostrado = false;
  double _tasaCambioVesUsd = 0.0;
  double _tasaCambioVesEur = 0.0;
  double _tasaCambioVesUsdt = 0.0;
  DateTime? _ultimaActualizacionTasas;
  /// D-06: Tres estados independientes por moneda
  EstadoTasaMoneda _estadoTasaUsd = EstadoTasaMoneda.sinTasa;
  EstadoTasaMoneda _estadoTasaEur = EstadoTasaMoneda.sinTasa;
  EstadoTasaMoneda _estadoTasaUsdt = EstadoTasaMoneda.sinTasa;
  bool _esTasaManualUsd = false;
  String _monedaPrincipal = AppConstants.defaultMoneda;
  String _tipoTasa = 'oficial'; // 'oficial' o 'paralelo'
  bool _isSyncingRate = false;
  bool _isInitialized = false;
  double _presupuestoMensual = 0.0;

  // Notificaciones y Recordatorios
  bool _recordatoriosActivos = true; // Inactividad a 30 días
  bool _recordatorioFinDeSemana = true; // Quincenal sábados 18:30
  bool _anunciosActivos = true; // Broadcast masivo de novedades

  List<Map<String, String>> _mensajesQuincenales = AppConstants.defaultMensajesAsistenteQuincenal;
  String _tituloInactividad = AppConstants.defaultInactivityTitle;
  String _cuerpoInactividad = AppConstants.defaultInactivityBody;

  String get apiKey => _apiKey;
  String get effectiveApiKey => _apiKey.trim().isNotEmpty ? _apiKey.trim() : AppConstants.defaultApiKey.trim();
  bool get guardarFotos => _guardarFotos;
  bool get avisoGaleriaMostrado => _avisoGaleriaMostrado;
  double get tasaCambioVesUsd => _tasaCambioVesUsd;
  double get tasaCambioVesEur => _tasaCambioVesEur;
  double get tasaCambioVesUsdt => _tasaCambioVesUsdt;
  DateTime? get ultimaActualizacionTasas => _ultimaActualizacionTasas;
  bool get tasasSonReferencia => _estadoTasaUsd != EstadoTasaMoneda.actualizada;
  EstadoTasaMoneda get estadoTasaUsd => _estadoTasaUsd;
  EstadoTasaMoneda get estadoTasaEur => _estadoTasaEur;
  EstadoTasaMoneda get estadoTasaUsdt => _estadoTasaUsdt;

  EstadoTasaMoneda getEstadoTasa(String moneda) {
    switch (moneda.toUpperCase().trim()) {
      case 'EUR':
        return _estadoTasaEur;
      case 'USDT':
        return _estadoTasaUsdt;
      case 'USD':
      default:
        return _estadoTasaUsd;
    }
  }
  bool get esTasaManualUsd => _esTasaManualUsd;
  String get monedaPrincipal => _monedaPrincipal;
  String get tipoTasa => _tipoTasa;
  bool get isSyncingRate => _isSyncingRate;
  bool get isInitialized => _isInitialized;
  double get presupuestoMensual => _presupuestoMensual;

  bool get recordatoriosActivos => _recordatoriosActivos;
  bool get recordatorioFinDeSemana => _recordatorioFinDeSemana;
  bool get anunciosActivos => _anunciosActivos;
  List<Map<String, String>> get mensajesQuincenales => _mensajesQuincenales;
  String get tituloInactividad => _tituloInactividad;
  String get cuerpoInactividad => _cuerpoInactividad;

  SettingsProvider({
    FlutterSecureStorage? secureStorage,
    bool autoLoad = true,
    SharedPreferences? prefsInstance,
    ConnectivityService? connectivityService,
    DateTime Function()? nowProvider,
    Duration reconnectDebounce = const Duration(seconds: 2),
    Duration autoRefreshCooldown = const Duration(minutes: 3),
    http.Client? httpClient,
    bool enableConnectivityListener = true,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _connectivityService = connectivityService ?? ConnectivityService.instance,
        _now = nowProvider ?? DateTime.now,
        _reconnectDebounce = reconnectDebounce,
        _autoRefreshCooldown = autoRefreshCooldown,
        _defaultHttpClient = httpClient,
        _prefsInstance = prefsInstance {
    if (enableConnectivityListener && (autoLoad || connectivityService != null)) {
      _initConnectivityListener();
    }
    if (autoLoad) {
      loadSettings();
    }
  }

  void _initConnectivityListener() {
    _connectivitySub = _connectivityService.onConnectivityChanged.listen((hasConnection) {
      if (_disposed) return;
      _reconnectDebounceTimer?.cancel();
      if (!hasConnection) return;

      _reconnectDebounceTimer = Timer(_reconnectDebounce, () {
        if (_disposed) return;
        refrescarTasasSiDesactualizadas(bypassCooldown: true);
      });
    });
  }

  static bool _esMismoDiaLocal(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  /// Indica si hace falta refrescar tasas desde red (alguna inválida,
  /// en estado referencia/sinTasa, tasa manual D-05 o fecha anterior al día local actual).
  bool get necesitaActualizarTasas {
    if (_esTasaManualUsd) return true;
    if (!isValidMonetaryRate(_tasaCambioVesUsd) ||
        !isValidMonetaryRate(_tasaCambioVesEur) ||
        !isValidMonetaryRate(_tasaCambioVesUsdt)) {
      return true;
    }
    if (_estadoTasaUsd != EstadoTasaMoneda.actualizada ||
        _estadoTasaEur != EstadoTasaMoneda.actualizada ||
        _estadoTasaUsdt != EstadoTasaMoneda.actualizada) {
      return true;
    }
    final last = _ultimaActualizacionTasas;
    if (last == null) return true;
    return !_esMismoDiaLocal(last, _now());
  }

  SharedPreferences? _prefsInstance;
  @visibleForTesting
  set prefsInstance(SharedPreferences? prefs) => _prefsInstance = prefs;

  static bool _safeGetBool(SharedPreferences prefs, String key, bool defaultValue) {
    final val = prefs.get(key);
    return val is bool ? val : defaultValue;
  }

  static String _safeGetString(SharedPreferences prefs, String key, String defaultValue) {
    final val = prefs.get(key);
    return val is String ? val : defaultValue;
  }

  static double _safeGetDouble(SharedPreferences prefs, String key, double defaultValue) {
    final val = prefs.get(key);
    return val is num ? val.toDouble() : defaultValue;
  }

  Future<void> loadSettings() async {
    final prefs = _prefsInstance ?? await SharedPreferences.getInstance();

    // 1. Lectura inmediata de preferencias (primer milisegundo)
    _guardarFotos = _safeGetBool(prefs, AppConstants.prefGuardarFotos, AppConstants.defaultGuardarFotos);
    _avisoGaleriaMostrado = _safeGetBool(prefs, 'aviso_galeria_mostrado', false);

    // Asegurar purga de caché histórica previa al consumo de semillas (A-07 & B2)
    int purgeResult = -1;
    try {
      purgeResult = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: prefs);
    } catch (e) {
      debugPrint('SettingsProvider: Error al asegurar purga de caché histórica: $e');
      purgeResult = -1;
    }

    if (purgeResult != -1) {
      // Purga exitosa: consumir semillas locales verificadas según validador canónico (D-08)
      double? cachedUsd;
      _esTasaManualUsd = _safeGetBool(prefs, 'pref_es_tasa_manual_usd', false);
      final rawManual = prefs.get(AppConstants.prefTasaCambio);
      final rawAuto = prefs.get('cached_rate_usd');

      if (_esTasaManualUsd && isValidMonetaryRate(rawManual)) {
        // Tasa manual global prevalece al reiniciar mientras no haya conexión (D-05 / NEW-3b)
        cachedUsd = (rawManual as num).toDouble();
      } else if (isValidMonetaryRate(rawAuto)) {
        cachedUsd = (rawAuto as num).toDouble();
      } else if (isValidMonetaryRate(rawManual)) {
        cachedUsd = (rawManual as num).toDouble();
      }
      _tasaCambioVesUsd = cachedUsd ?? 0.0;

      double? cachedEur;
      final rawEur = prefs.get('cached_rate_eur');
      if (isValidMonetaryRate(rawEur)) {
        cachedEur = (rawEur as num).toDouble();
      }
      _tasaCambioVesEur = cachedEur ?? 0.0;

      double? cachedUsdt;
      final rawUsdt = prefs.get('cached_rate_usdt');
      if (isValidMonetaryRate(rawUsdt)) {
        cachedUsdt = (rawUsdt as num).toDouble();
      }
      // H-1 (E0-03): Eliminado fallback cruzado USD -> USDT (D-04)
      _tasaCambioVesUsdt = cachedUsdt ?? 0.0;

      // NEW-6: Comprobación segura de tipo String antes de leer timestamp
      final rawTimestamp = prefs.get('cached_exchange_rates_timestamp');
      if (rawTimestamp is String) {
        _ultimaActualizacionTasas = DateTime.tryParse(rawTimestamp);
      } else {
        _ultimaActualizacionTasas = null;
      }
      final lastUpdated = _ultimaActualizacionTasas;
      final bool esHoy = lastUpdated != null && _esMismoDiaLocal(lastUpdated, _now());

      if (isValidMonetaryRate(_tasaCambioVesUsd)) {
        _estadoTasaUsd = (!_esTasaManualUsd && esHoy)
            ? EstadoTasaMoneda.actualizada
            : EstadoTasaMoneda.referencia;
      } else {
        _estadoTasaUsd = EstadoTasaMoneda.sinTasa;
      }

      if (isValidMonetaryRate(_tasaCambioVesEur)) {
        _estadoTasaEur = esHoy ? EstadoTasaMoneda.actualizada : EstadoTasaMoneda.referencia;
      } else {
        _estadoTasaEur = EstadoTasaMoneda.sinTasa;
      }

      if (isValidMonetaryRate(_tasaCambioVesUsdt)) {
        _estadoTasaUsdt = esHoy ? EstadoTasaMoneda.actualizada : EstadoTasaMoneda.referencia;
      } else {
        _estadoTasaUsdt = EstadoTasaMoneda.sinTasa;
      }
    } else {
      // Purga fallida (-1): comportamiento fail-closed. No consumir semillas locales no verificadas
      debugPrint('SettingsProvider: Purga fallida (-1). Se omite caché local no verificada.');
      _tasaCambioVesUsd = 0.0;
      _tasaCambioVesEur = 0.0;
      _tasaCambioVesUsdt = 0.0;
      _ultimaActualizacionTasas = null;
      _estadoTasaUsd = EstadoTasaMoneda.sinTasa;
      _estadoTasaEur = EstadoTasaMoneda.sinTasa;
      _estadoTasaUsdt = EstadoTasaMoneda.sinTasa;
      _esTasaManualUsd = false;
    }

    _monedaPrincipal = _safeGetString(prefs, AppConstants.prefMonedaPrincipal, AppConstants.defaultMoneda);
    _tipoTasa = _safeGetString(prefs, 'tipo_tasa', 'oficial');
    _presupuestoMensual = _safeGetDouble(prefs, 'presupuesto_mensual', 0.0);

    // Preferencias de notificaciones
    _recordatoriosActivos = _safeGetBool(prefs, AppConstants.prefRecordatoriosActivos, true);
    _recordatorioFinDeSemana = _safeGetBool(prefs, AppConstants.prefRecordatorioFinDeSemana, true);
    _anunciosActivos = _safeGetBool(prefs, AppConstants.prefAnunciosActivos, true);

    // Cargar caché local de mensajes de recordatorios si existe
    final rawCachedQuincenal = prefs.get(AppConstants.prefCachedMensajesQuincenalesJson);
    if (rawCachedQuincenal is String && rawCachedQuincenal.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCachedQuincenal) as List;
        final list = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
        if (list.isNotEmpty) {
          _mensajesQuincenales = list;
        }
      } catch (_) {}
    }

    _isInitialized = true;
    notifyListeners();

    // Sincroniza las tasas automáticamente en segundo plano de inmediato
    actualizarTasaAutomatica();

    // Sincronizar textos remotos de recordatorios desde Firestore en segundo plano
    sincronizarRecordatoriosRemotos();

    // 2. Cargar API Key exclusivamente desde el almacenamiento seguro local del dispositivo
    final int revBeforeRead = _apiKeyRevision;
    try {
      String? secureKey = await _secureStorage.read(key: AppConstants.prefApiKey);
      if (_apiKeyRevision != revBeforeRead) return;
      if (secureKey == null) {
        String oldKey = prefs.getString(AppConstants.prefApiKey) ?? '';
        if (_apiKeyRevision != revBeforeRead) return;
        if (oldKey.isNotEmpty) {
          await _secureStorage.write(key: AppConstants.prefApiKey, value: oldKey);
          await prefs.remove(AppConstants.prefApiKey);
          if (_apiKeyRevision != revBeforeRead) return;
          _apiKey = oldKey;
          notifyListeners();
        } else {
          _apiKey = '';
        }
      } else {
        _apiKey = secureKey;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error leyendo API Key desde SecureStorage en loadSettings: $e");
    }
  }

  /// Sincroniza la configuración y banco de mensajes de recordatorios desde Firestore.
  /// Permite modificar textos online sin lanzar nuevas versiones en Google Play.
  Future<void> sincronizarRecordatoriosRemotos({FirebaseFirestore? firestore}) async {
    try {
      final fs = firestore ?? (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null);
      if (fs == null) return;

      final doc = await fs.collection('config').doc('recordatorios').get();
      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      final prefs = _prefsInstance ?? await SharedPreferences.getInstance();

      if (data['mensajes_quincenales'] is List) {
        final rawList = data['mensajes_quincenales'] as List;
        final parsed = rawList.map((e) => Map<String, String>.from(e as Map)).toList();
        if (parsed.isNotEmpty) {
          _mensajesQuincenales = parsed;
          await prefs.setString(
            AppConstants.prefCachedMensajesQuincenalesJson,
            jsonEncode(parsed),
          );
        }
      }

      if (data['inactividad_titulo'] is String && (data['inactividad_titulo'] as String).trim().isNotEmpty) {
        _tituloInactividad = data['inactividad_titulo'];
      }
      if (data['inactividad_cuerpo'] is String && (data['inactividad_cuerpo'] as String).trim().isNotEmpty) {
        _cuerpoInactividad = data['inactividad_cuerpo'];
      }
      notifyListeners();
    } catch (e) {
      debugPrint("SettingsProvider: Sincronización remota de recordatorios omitida: $e");
    }
  }

  /// Refresca las tasas automáticamente solo si falta frescura en el día local actual
  /// y existe conectividad. Aplica cooldown anti-flapping salvo [bypassCooldown].
  Future<bool> refrescarTasasSiDesactualizadas({
    http.Client? client,
    bool bypassCooldown = false,
  }) async {
    if (_disposed || _isSyncingRate || !necesitaActualizarTasas) {
      return false;
    }
    final now = _now();
    if (!bypassCooldown && _lastAutoRefreshAttemptAt != null) {
      if (now.difference(_lastAutoRefreshAttemptAt!) < _autoRefreshCooldown) {
        return false;
      }
    }
    final hasConnection = await _connectivityService.isConnected();
    if (_disposed || !hasConnection) {
      return false;
    }
    _lastAutoRefreshAttemptAt = now;
    return actualizarTasaAutomatica(client: client);
  }

  Future<bool> actualizarTasaAutomatica({http.Client? client}) {
    if (_disposed) return Future.value(false);
    final inFlight = _inFlightRateSync;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _ejecutarActualizacionTasa(client: client ?? _defaultHttpClient);
    _inFlightRateSync = future;
    return future.whenComplete(() {
      if (identical(_inFlightRateSync, future)) {
        _inFlightRateSync = null;
      }
    });
  }

  Future<bool> _ejecutarActualizacionTasa({http.Client? client}) async {
    _isSyncingRate = true;
    notifyListeners();
    bool exito = false;
    try {
      final allRates = await ExchangeRateService.getAllTodayRates(
        client: client,
        prefsInstance: _prefsInstance,
        connectivityService: _connectivityService,
      );
      if (_disposed) return false;
      final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
      if (_disposed) return false;

      if (!allRates.esReferencia) {
        // Solo se aplica lo que llegó en vivo válido según validador canónico (D-08); el resto conserva su
        // valor previo en vez de pisarse con ceros o semillas obsoletas.
        final bool usdValidaEnVivo = allRates.usdEnVivo && isValidMonetaryRate(allRates.usd);
        final bool eurValidaEnVivo = allRates.eurEnVivo && isValidMonetaryRate(allRates.eur);
        final bool usdtValidaEnVivo = allRates.usdtEnVivo && isValidMonetaryRate(allRates.usdt);

        if (usdValidaEnVivo) {
          _tasaCambioVesUsd = allRates.usd;
          await ExchangeRateService.safeSetDouble(prefs, AppConstants.prefTasaCambio, _tasaCambioVesUsd);
          await ExchangeRateService.safeSetDouble(prefs, 'cached_rate_usd', _tasaCambioVesUsd);
          try {
            final okBool = await prefs.setBool('pref_es_tasa_manual_usd', false);
            if (okBool) {
              _esTasaManualUsd = false;
            }
          } catch (e) {
            debugPrint('SettingsProvider: Error limpiando pref_es_tasa_manual_usd: $e');
          }
        }
        if (eurValidaEnVivo) {
          _tasaCambioVesEur = allRates.eur;
          await ExchangeRateService.safeSetDouble(prefs, 'cached_rate_eur', _tasaCambioVesEur);
        } else if (!isValidMonetaryRate(_tasaCambioVesEur) && isValidMonetaryRate(allRates.eur)) {
          _tasaCambioVesEur = allRates.eur;
        }
        if (usdtValidaEnVivo) {
          _tasaCambioVesUsdt = allRates.usdt;
          await ExchangeRateService.safeSetDouble(prefs, 'cached_rate_usdt', _tasaCambioVesUsdt);
        } else if (!isValidMonetaryRate(_tasaCambioVesUsdt) && isValidMonetaryRate(allRates.usdt)) {
          _tasaCambioVesUsdt = allRates.usdt;
        }
        _ultimaActualizacionTasas = _now();
        _estadoTasaUsd = isValidMonetaryRate(_tasaCambioVesUsd)
            ? ((_esTasaManualUsd || !usdValidaEnVivo)
                ? EstadoTasaMoneda.referencia
                : EstadoTasaMoneda.actualizada)
            : EstadoTasaMoneda.sinTasa;
        _estadoTasaEur = isValidMonetaryRate(_tasaCambioVesEur)
            ? (eurValidaEnVivo ? EstadoTasaMoneda.actualizada : EstadoTasaMoneda.referencia)
            : EstadoTasaMoneda.sinTasa;
        _estadoTasaUsdt = isValidMonetaryRate(_tasaCambioVesUsdt)
            ? (usdtValidaEnVivo ? EstadoTasaMoneda.actualizada : EstadoTasaMoneda.referencia)
            : EstadoTasaMoneda.sinTasa;
        if (_ultimaActualizacionTasas != null) {
          await ExchangeRateService.safeSetString(
            prefs,
            'cached_exchange_rates_timestamp',
            _ultimaActualizacionTasas!.toIso8601String(),
          );
        }
        exito = true;
      } else {
        // Modo referencia: si el usuario configuró una tasa manual global válida, se conserva intacta (D-05)
        final bool isManual = _esTasaManualUsd || _safeGetBool(prefs, 'pref_es_tasa_manual_usd', false);
        final rawPrefTasa = prefs.get(AppConstants.prefTasaCambio);
        if (isManual && (isValidMonetaryRate(_tasaCambioVesUsd) || isValidMonetaryRate(rawPrefTasa))) {
          if (!isValidMonetaryRate(_tasaCambioVesUsd) && isValidMonetaryRate(rawPrefTasa)) {
            _tasaCambioVesUsd = (rawPrefTasa as num).toDouble();
          }
          // Preservar la tasa manual global en disco y memoria (D-05 / NEW-3b)
        } else if (isValidMonetaryRate(allRates.usd)) {
          _tasaCambioVesUsd = allRates.usd;
          await ExchangeRateService.safeSetDouble(prefs, AppConstants.prefTasaCambio, _tasaCambioVesUsd);
        }
        if (isValidMonetaryRate(allRates.eur)) {
          _tasaCambioVesEur = allRates.eur;
          await ExchangeRateService.safeSetDouble(prefs, 'cached_rate_eur', _tasaCambioVesEur);
        }
        if (isValidMonetaryRate(allRates.usdt)) {
          _tasaCambioVesUsdt = allRates.usdt;
          await ExchangeRateService.safeSetDouble(prefs, 'cached_rate_usdt', _tasaCambioVesUsdt);
        }
        _estadoTasaUsd = isValidMonetaryRate(_tasaCambioVesUsd) ? EstadoTasaMoneda.referencia : EstadoTasaMoneda.sinTasa;
        _estadoTasaEur = isValidMonetaryRate(_tasaCambioVesEur) ? EstadoTasaMoneda.referencia : EstadoTasaMoneda.sinTasa;
        _estadoTasaUsdt = isValidMonetaryRate(_tasaCambioVesUsdt) ? EstadoTasaMoneda.referencia : EstadoTasaMoneda.sinTasa;
      }
    } catch (e) {
      debugPrint("Error al actualizar tasas automáticas: $e");
    } finally {
      _isSyncingRate = false;
      notifyListeners();
    }
    return exito;
  }

  Future<void> setApiKey(String key) async {
    _apiKeyRevision++;
    _apiKey = key.trim();
    try {
      await _secureStorage.write(key: AppConstants.prefApiKey, value: _apiKey);
    } catch (e) {
      debugPrint("Error guardando API Key en SecureStorage: $e");
    }
    notifyListeners();
  }

  Future<void> removeApiKey() async {
    _apiKeyRevision++;
    _apiKey = '';
    try {
      await _secureStorage.delete(key: AppConstants.prefApiKey);
    } catch (e) {
      debugPrint("Error eliminando API Key de SecureStorage: $e");
    }
    notifyListeners();
  }

  Future<void> setGuardarFotos(bool value) async {
    _guardarFotos = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefGuardarFotos, _guardarFotos);
    notifyListeners();
  }

  Future<void> marcarAvisoGaleriaMostrado() async {
    _avisoGaleriaMostrado = true;
    final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
    await prefs.setBool('aviso_galeria_mostrado', true);
    notifyListeners();
  }

  Future<void> setTasaCambio(double tasa) async {
    if (!isValidMonetaryRate(tasa)) {
      debugPrint("SettingsProvider: Tasa manual rechazada por fuera de dominio: $tasa");
      return;
    }
    _tasaCambioVesUsd = tasa;
    _estadoTasaUsd = isValidMonetaryRate(tasa) ? EstadoTasaMoneda.referencia : EstadoTasaMoneda.sinTasa;
    final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
    final ok = await ExchangeRateService.safeSetDouble(prefs, AppConstants.prefTasaCambio, _tasaCambioVesUsd);
    if (ok) {
      bool okBool = false;
      try {
        okBool = await prefs.setBool('pref_es_tasa_manual_usd', true);
      } catch (_) {}
      _esTasaManualUsd = okBool;
    } else {
      debugPrint("SettingsProvider: Error persistiendo tasa manual en disco.");
      _esTasaManualUsd = false;
    }
    notifyListeners();
  }

  Future<void> setMonedaPrincipal(String moneda) async {
    _monedaPrincipal = moneda;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefMonedaPrincipal, _monedaPrincipal);
    notifyListeners();
  }

  Future<void> setPresupuestoMensual(double monto) async {
    _presupuestoMensual = monto;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('presupuesto_mensual', _presupuestoMensual);
    notifyListeners();
  }

  Future<void> setRecordatoriosActivos(bool value) async {
    _recordatoriosActivos = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefRecordatoriosActivos, _recordatoriosActivos);
    notifyListeners();

    if (!value) {
      await NotificationService.instance.cancelInactivityReminder();
    } else {
      await NotificationService.instance.scheduleInactivityReminder(
        duration: const Duration(days: 30),
        title: _tituloInactividad,
        body: _cuerpoInactividad,
      );
    }
  }

  Future<void> setRecordatorioFinDeSemana(bool value) async {
    _recordatorioFinDeSemana = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefRecordatorioFinDeSemana, _recordatorioFinDeSemana);
    notifyListeners();

    if (!value) {
      await NotificationService.instance.cancelBiweeklyWeekendReminder();
    } else {
      await NotificationService.instance.scheduleBiweeklyWeekendReminder();
    }
  }

  Future<void> setAnunciosActivos(bool value) async {
    _anunciosActivos = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefAnunciosActivos, _anunciosActivos);
    notifyListeners();

    if (value) {
      await NotificationService.instance.subscribeToBroadcastTopic();
    } else {
      await NotificationService.instance.unsubscribeFromBroadcastTopic();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _reconnectDebounceTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }
}
