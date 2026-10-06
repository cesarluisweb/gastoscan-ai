import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/app_constants.dart';
import '../services/exchange_rate_service.dart';

class SettingsProvider with ChangeNotifier {
  final _secureStorage = const FlutterSecureStorage();
  
  String _apiKey = '';
  bool _guardarFotos = AppConstants.defaultGuardarFotos;
  double _tasaCambioVesUsd = AppConstants.defaultTasaCambio;
  double _tasaCambioVesEur = 43.0;
  double _tasaCambioVesUsdt = AppConstants.defaultTasaCambio;
  DateTime? _ultimaActualizacionTasas;
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
  String get monedaPrincipal => _monedaPrincipal;
  String get tipoTasa => _tipoTasa;
  bool get isSyncingRate => _isSyncingRate;
  bool get isInitialized => _isInitialized;
  double get presupuestoMensual => _presupuestoMensual;
  bool get recordatoriosActivos => _recordatoriosActivos;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    String? secureKey = await _secureStorage.read(key: AppConstants.prefApiKey);
    if (secureKey == null) {
      String oldKey = prefs.getString(AppConstants.prefApiKey) ?? '';
      if (oldKey.isNotEmpty) {
        await _secureStorage.write(key: AppConstants.prefApiKey, value: oldKey);
        await prefs.remove(AppConstants.prefApiKey);
        _apiKey = oldKey;
      } else {
        _apiKey = '';
      }
    } else {
      _apiKey = secureKey;
    }

    _guardarFotos = prefs.getBool(AppConstants.prefGuardarFotos) ?? AppConstants.defaultGuardarFotos;
    _tasaCambioVesUsd = prefs.getDouble(AppConstants.prefTasaCambio) ?? AppConstants.defaultTasaCambio;
    _tasaCambioVesEur = prefs.getDouble('cached_rate_eur') ?? (_tasaCambioVesUsd * 1.08);
    _tasaCambioVesUsdt = prefs.getDouble('cached_rate_usdt') ?? _tasaCambioVesUsd;

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

    // Sincroniza las tasas automáticamente en segundo plano
    actualizarTasaAutomatica();
  }

  Future<void> actualizarTasaAutomatica() async {
    _isSyncingRate = true;
    notifyListeners();
    try {
      final allRates = await ExchangeRateService.getAllTodayRates();
      if (allRates.usd > 0) {
        _tasaCambioVesUsd = allRates.usd;
        _tasaCambioVesEur = allRates.eur;
        _tasaCambioVesUsdt = allRates.usdt;
        _ultimaActualizacionTasas = allRates.fecha;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(AppConstants.prefTasaCambio, _tasaCambioVesUsd);
        await prefs.setDouble('cached_rate_eur', _tasaCambioVesEur);
        await prefs.setDouble('cached_rate_usdt', _tasaCambioVesUsdt);
        await prefs.setString('cached_exchange_rates_timestamp', _ultimaActualizacionTasas!.toIso8601String());
      }
    } finally {
      _isSyncingRate = false;
      notifyListeners();
    }
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    await _secureStorage.write(key: AppConstants.prefApiKey, value: _apiKey);
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
