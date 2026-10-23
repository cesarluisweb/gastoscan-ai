import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/app_constants.dart';
import '../services/exchange_rate_service.dart';

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
  bool _recordatoriosActivos = true;

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

  SettingsProvider({FlutterSecureStorage? secureStorage, bool autoLoad = true})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    if (autoLoad) {
      loadSettings();
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Lectura inmediata de preferencias y tasas en caché (primer milisegundo)
    _guardarFotos = prefs.getBool(AppConstants.prefGuardarFotos) ?? AppConstants.defaultGuardarFotos;

    // Descartar valores obsoletos <= 50.0 guardados en caché de pruebas previas
    double? cachedUsd = prefs.getDouble('cached_rate_usd') ??
        prefs.getDouble(AppConstants.prefTasaCambio);
    if (cachedUsd != null && cachedUsd <= 50.0) cachedUsd = null;
    _tasaCambioVesUsd = cachedUsd ?? AppConstants.defaultTasaCambio;

    double? cachedEur = prefs.getDouble('cached_rate_eur');
    if (cachedEur != null && cachedEur <= 50.0) cachedEur = null;
    _tasaCambioVesEur = cachedEur ?? 0.0;

    double? cachedUsdt = prefs.getDouble('cached_rate_usdt');
    if (cachedUsdt != null && cachedUsdt <= 50.0) cachedUsdt = null;
    _tasaCambioVesUsdt = cachedUsdt ?? _tasaCambioVesUsd;

    final timestampStr = prefs.getString('cached_exchange_rates_timestamp');
    if (timestampStr != null) {
      _ultimaActualizacionTasas = DateTime.tryParse(timestampStr);
    }

    _monedaPrincipal = prefs.getString(AppConstants.prefMonedaPrincipal) ?? AppConstants.defaultMoneda;
    _tipoTasa = prefs.getString('tipo_tasa') ?? 'oficial';
    _presupuestoMensual = prefs.getDouble('presupuesto_mensual') ?? 0.0;
    _recordatoriosActivos = prefs.getBool(AppConstants.prefRecordatoriosActivos) ?? true;
    _isInitialized = true;
    notifyListeners();

    // Sincroniza las tasas automáticamente en segundo plano de inmediato
    actualizarTasaAutomatica();

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

  Future<bool> actualizarTasaAutomatica({http.Client? client}) async {
    _isSyncingRate = true;
    notifyListeners();
    bool exito = false;
    try {
      final allRates = await ExchangeRateService.getAllTodayRates(client: client);
      final prefs = await SharedPreferences.getInstance();

      if (!allRates.esReferencia) {
        // Solo se aplica lo que llegó en vivo válido (> 50.0); el resto conserva su
        // valor previo en vez de pisarse con ceros o semillas obsoletas.
        if (allRates.usd > 50.0) {
          _tasaCambioVesUsd = allRates.usd;
          await prefs.setDouble(AppConstants.prefTasaCambio, _tasaCambioVesUsd);
          await prefs.setDouble('cached_rate_usd', _tasaCambioVesUsd);
        }
        if (allRates.eur > 50.0) {
          _tasaCambioVesEur = allRates.eur;
          await prefs.setDouble('cached_rate_eur', _tasaCambioVesEur);
        }
        if (allRates.usdt > 50.0) {
          _tasaCambioVesUsdt = allRates.usdt;
          await prefs.setDouble('cached_rate_usdt', _tasaCambioVesUsdt);
        }
        _ultimaActualizacionTasas = allRates.fecha;
        _tasasSonReferencia = false;
        await prefs.setString('cached_exchange_rates_timestamp', _ultimaActualizacionTasas!.toIso8601String());
        exito = true;
      } else {
        // Modo referencia: si allRates trajo tasas válidas (> 50.0) por caché o fallback, asignarlas
        if (allRates.usd > 50.0) {
          _tasaCambioVesUsd = allRates.usd;
          await prefs.setDouble(AppConstants.prefTasaCambio, _tasaCambioVesUsd);
        }
        if (allRates.eur > 50.0) {
          _tasaCambioVesEur = allRates.eur;
        }
        if (allRates.usdt > 50.0) {
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
