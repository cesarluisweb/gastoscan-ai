import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../services/exchange_rate_service.dart';

class SettingsProvider with ChangeNotifier {
  String _apiKey = '';
  bool _guardarFotos = AppConstants.defaultGuardarFotos;
  double _tasaCambioVesUsd = AppConstants.defaultTasaCambio;
  String _monedaPrincipal = AppConstants.defaultMoneda;
  String _tipoTasa = 'oficial'; // 'oficial' (BCV) o 'paralelo'
  bool _isSyncingRate = false;
  bool _isInitialized = false;

  String get apiKey => _apiKey;
  String get effectiveApiKey => _apiKey.trim().isNotEmpty ? _apiKey.trim() : AppConstants.defaultApiKey.trim();
  bool get guardarFotos => _guardarFotos;
  double get tasaCambioVesUsd => _tasaCambioVesUsd;
  String get monedaPrincipal => _monedaPrincipal;
  String get tipoTasa => _tipoTasa;
  bool get isSyncingRate => _isSyncingRate;
  bool get isInitialized => _isInitialized;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(AppConstants.prefApiKey) ?? '';
    _guardarFotos = prefs.getBool(AppConstants.prefGuardarFotos) ?? AppConstants.defaultGuardarFotos;
    _tasaCambioVesUsd = prefs.getDouble(AppConstants.prefTasaCambio) ?? AppConstants.defaultTasaCambio;
    _monedaPrincipal = prefs.getString(AppConstants.prefMonedaPrincipal) ?? AppConstants.defaultMoneda;
    _tipoTasa = prefs.getString('tipo_tasa') ?? 'oficial';
    _isInitialized = true;
    notifyListeners();

    // Sincroniza la tasa oficial automáticamente en segundo plano
    actualizarTasaAutomatica();
  }

  Future<void> actualizarTasaAutomatica() async {
    _isSyncingRate = true;
    notifyListeners();
    try {
      final nuevaTasa = await ExchangeRateService.getTodayRate(tipo: _tipoTasa);
      if (nuevaTasa > 0) {
        _tasaCambioVesUsd = nuevaTasa;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(AppConstants.prefTasaCambio, _tasaCambioVesUsd);
      }
    } finally {
      _isSyncingRate = false;
      notifyListeners();
    }
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefApiKey, _apiKey);
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
}
