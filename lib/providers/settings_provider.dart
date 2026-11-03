import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../domain/monetary/rate_market.dart';
import '../services/exchange_rate_service.dart';
import '../services/notification_service.dart';

class SettingsProvider with ChangeNotifier {
  final FlutterSecureStorage _secureStorage;

  String _apiKey = '';
  int _apiKeyRevision = 0;
  bool _guardarFotos = AppConstants.defaultGuardarFotos;
  double _tasaCambioVesUsd = AppConstants.defaultTasaCambio;
  double _tasaCambioVesEur = 0.0;
  double _tasaCambioVesUsdt = AppConstants.defaultTasaCambio;
  DateTime? _ultimaActualizacionTasas;
  /// true mientras no se haya verificado una tasa en vivo: los valores
  /// pueden venir de caché antigua o de semillas. La UI lo muestra.
  bool _tasasSonReferencia = true;
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
  double get tasaCambioVesUsd => _tasaCambioVesUsd;
  double get tasaCambioVesEur => _tasaCambioVesEur;
  double get tasaCambioVesUsdt => _tasaCambioVesUsdt;
  DateTime? get ultimaActualizacionTasas => _ultimaActualizacionTasas;
  bool get tasasSonReferencia => _tasasSonReferencia;
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

  SettingsProvider({FlutterSecureStorage? secureStorage, bool autoLoad = true})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    if (autoLoad) {
      loadSettings();
    }
  }

  Future<void> loadSettings({SharedPreferences? prefsInstance}) async {
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();

    // 1. Lectura inmediata de preferencias (primer milisegundo)
    _guardarFotos = prefs.getBool(AppConstants.prefGuardarFotos) ?? AppConstants.defaultGuardarFotos;

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
      final rawUsd = prefs.get('cached_rate_usd') ?? prefs.get(AppConstants.prefTasaCambio);
      if (isValidMonetaryRate(rawUsd)) {
        cachedUsd = (rawUsd as num).toDouble();
      }
      _tasaCambioVesUsd = cachedUsd ?? AppConstants.defaultTasaCambio;

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
      // Preservar fallback semántico USD -> USDT (H-1 pendiente de E0-03)
      _tasaCambioVesUsdt = cachedUsdt ?? _tasaCambioVesUsd;

      // NEW-6: Comprobación segura de tipo String antes de leer timestamp
      final rawTimestamp = prefs.get('cached_exchange_rates_timestamp');
      if (rawTimestamp is String) {
        _ultimaActualizacionTasas = DateTime.tryParse(rawTimestamp);
      } else {
        _ultimaActualizacionTasas = null;
      }
    } else {
      // Purga fallida (-1): comportamiento fail-closed. No consumir semillas locales no verificadas
      debugPrint('SettingsProvider: Purga fallida (-1). Se omite caché local no verificada.');
      _tasaCambioVesUsd = AppConstants.defaultTasaCambio;
      _tasaCambioVesEur = 0.0;
      _tasaCambioVesUsdt = AppConstants.defaultTasaCambio;
      _ultimaActualizacionTasas = null;
    }

    _monedaPrincipal = prefs.getString(AppConstants.prefMonedaPrincipal) ?? AppConstants.defaultMoneda;
    _tipoTasa = prefs.getString('tipo_tasa') ?? 'oficial';
    _presupuestoMensual = prefs.getDouble('presupuesto_mensual') ?? 0.0;

    // Preferencias de notificaciones
    _recordatoriosActivos = prefs.getBool(AppConstants.prefRecordatoriosActivos) ?? true;
    _recordatorioFinDeSemana = prefs.getBool(AppConstants.prefRecordatorioFinDeSemana) ?? true;
    _anunciosActivos = prefs.getBool(AppConstants.prefAnunciosActivos) ?? true;

    // Cargar caché local de mensajes de recordatorios si existe
    final cachedQuincenalJson = prefs.getString(AppConstants.prefCachedMensajesQuincenalesJson);
    if (cachedQuincenalJson != null && cachedQuincenalJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedQuincenalJson) as List;
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
      final prefs = await SharedPreferences.getInstance();

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

  Future<bool> actualizarTasaAutomatica({http.Client? client}) async {
    _isSyncingRate = true;
    notifyListeners();
    bool exito = false;
    try {
      final allRates = await ExchangeRateService.getAllTodayRates(client: client);
      final prefs = await SharedPreferences.getInstance();

      if (!allRates.esReferencia) {
        // Solo se aplica lo que llegó en vivo válido según validador canónico (D-08); el resto conserva su
        // valor previo en vez de pisarse con ceros o semillas obsoletas.
        if (isValidMonetaryRate(allRates.usd)) {
          _tasaCambioVesUsd = allRates.usd;
          await prefs.setDouble(AppConstants.prefTasaCambio, _tasaCambioVesUsd);
          await prefs.setDouble('cached_rate_usd', _tasaCambioVesUsd);
        }
        if (isValidMonetaryRate(allRates.eur)) {
          _tasaCambioVesEur = allRates.eur;
          await prefs.setDouble('cached_rate_eur', _tasaCambioVesEur);
        }
        if (isValidMonetaryRate(allRates.usdt)) {
          _tasaCambioVesUsdt = allRates.usdt;
          await prefs.setDouble('cached_rate_usdt', _tasaCambioVesUsdt);
        }
        _ultimaActualizacionTasas = allRates.fecha;
        _tasasSonReferencia = false;
        await prefs.setString('cached_exchange_rates_timestamp', _ultimaActualizacionTasas!.toIso8601String());
        exito = true;
      } else {
        // Modo referencia: si allRates trajo tasas válidas por caché o fallback, asignarlas
        if (isValidMonetaryRate(allRates.usd)) {
          _tasaCambioVesUsd = allRates.usd;
          await prefs.setDouble(AppConstants.prefTasaCambio, _tasaCambioVesUsd);
        }
        if (isValidMonetaryRate(allRates.eur)) {
          _tasaCambioVesEur = allRates.eur;
        }
        if (isValidMonetaryRate(allRates.usdt)) {
          _tasaCambioVesUsdt = allRates.usdt;
        }
        _tasasSonReferencia = true;
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

  Future<void> setTasaCambio(double tasa) async {
    if (!isValidMonetaryRate(tasa)) {
      debugPrint("SettingsProvider: Tasa manual rechazada por fuera de dominio: $tasa");
      return;
    }
    _tasaCambioVesUsd = tasa;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.prefTasaCambio, _tasaCambioVesUsd);
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
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }
}
