import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/app_constants.dart';
import '../services/exchange_rate_service.dart';

class SettingsProvider with ChangeNotifier {
  final _secureStorage = const FlutterSecureStorage();
  
  String _apiKey = '';
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
    // Sin caché EUR no se inventa ratio (antes: USD * 1.08): queda en 0 y los
    // formateadores usan sus ramas neutras hasta la primera sincronización.
    _tasaCambioVesEur = prefs.getDouble('cached_rate_eur') ?? 0.0;
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

  Future<void> actualizarTasaAutomatica({http.Client? client}) async {
    _isSyncingRate = true;
    notifyListeners();
    try {
      final allRates = await ExchangeRateService.getAllTodayRates(client: client);
      if (!allRates.esReferencia) {
        final prefs = await SharedPreferences.getInstance();
        // Solo se aplica lo que llegó en vivo (> 0); el resto conserva su
        // valor previo en vez de pisarse con ceros.
        if (allRates.usd > 0) {
          _tasaCambioVesUsd = allRates.usd;
          await prefs.setDouble(AppConstants.prefTasaCambio, _tasaCambioVesUsd);
        }
        if (allRates.eur > 0) {
          _tasaCambioVesEur = allRates.eur;
          await prefs.setDouble('cached_rate_eur', _tasaCambioVesEur);
        }
        if (allRates.usdt > 0) {
          _tasaCambioVesUsdt = allRates.usdt;
          await prefs.setDouble('cached_rate_usdt', _tasaCambioVesUsdt);
        }
        _ultimaActualizacionTasas = allRates.fecha;
        _tasasSonReferencia = false;
        await prefs.setString('cached_exchange_rates_timestamp', _ultimaActualizacionTasas!.toIso8601String());
      } else {
        // Sin dato en vivo: NO se toca el timestamp. La fecha mostrada sigue
        // siendo la última actualización real y el badge lo señala.
        _tasasSonReferencia = true;
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

  Future<void> removeApiKey() async {
    _apiKey = '';
    await _secureStorage.delete(key: AppConstants.prefApiKey);
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
