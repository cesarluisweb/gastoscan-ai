import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/app_constants.dart';
import '../services/connectivity_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/sync_service.dart';

class SettingsProvider with ChangeNotifier {
  final _secureStorage = const FlutterSecureStorage();
  
  String _apiKey = '';
  bool _guardarFotos = AppConstants.defaultGuardarFotos;
  double _tasaCambioVesUsd = AppConstants.defaultTasaCambio;
  double _tasaCambioVesEur = 0.0;
  double _tasaCambioVesUsdt = AppConstants.defaultTasaCambio;
  DateTime? _ultimaActualizacionTasas;
  /// Vigencia POR DIVISA: que Yadio entregue el USDT no convierte al USD en un
  /// dato verificado en vivo. `tasasSonReferencia` se deriva del USD porque es
  /// la divisa que gobierna las conversiones de toda la app.
  bool _usdEnVivo = false;
  bool _eurEnVivo = false;
  bool _usdtEnVivo = false;
  /// Motivo del último fallo de sincronización, para poder avisar en la UI.
  String? _ultimoErrorTasas;
  StreamSubscription<bool>? _connectivitySub;
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
  /// true si la tasa principal (USD BCV) NO es un dato verificado en vivo.
  bool get tasasSonReferencia => !_usdEnVivo;
  bool get usdEnVivo => _usdEnVivo;
  bool get eurEnVivo => _eurEnVivo;
  bool get usdtEnVivo => _usdtEnVivo;
  /// Mensaje del último fallo de sincronización (null si no hubo).
  String? get ultimoErrorTasas => _ultimoErrorTasas;
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

    // 1. Preferencias y tasas locales ANTES de cualquier operación de red: si
    //    Firestore se demora, la app ya quedó usable y con sus tasas de caché.
    _guardarFotos = prefs.getBool(AppConstants.prefGuardarFotos) ?? AppConstants.defaultGuardarFotos;
    // Se descarta una semilla o dato corrupto ya guardado (por debajo del piso
    // de verosimilitud) y se prefiere la caché real escrita por el servicio de
    // tasas: esto desatasca a quien quedó con un 40 persistido en preferencias.
    _tasaCambioVesUsd = _verosimil(prefs.getDouble(AppConstants.prefTasaCambio)) ??
        _verosimil(prefs.getDouble('cached_rate_usd')) ??
        _verosimil(prefs.getDouble('cached_exchange_rate')) ??
        AppConstants.defaultTasaCambio;
    // Sin caché EUR no se inventa ratio (antes: USD * 1.08): queda en 0 y los
    // formateadores usan sus ramas neutras hasta la primera sincronización.
    _tasaCambioVesEur = _verosimil(prefs.getDouble('cached_rate_eur')) ?? 0.0;
    _tasaCambioVesUsdt = _verosimil(prefs.getDouble('cached_rate_usdt')) ?? _tasaCambioVesUsd;

    final timestampStr = prefs.getString('cached_exchange_rates_timestamp');
    if (timestampStr != null) {
      _ultimaActualizacionTasas = DateTime.tryParse(timestampStr);
    }

    _monedaPrincipal = prefs.getString(AppConstants.prefMonedaPrincipal) ?? AppConstants.defaultMoneda;
    _tipoTasa = prefs.getString('tipo_tasa') ?? 'oficial';
    _presupuestoMensual = prefs.getDouble('presupuesto_mensual') ?? 0.0;
    _recordatoriosActivos = prefs.getBool(AppConstants.prefRecordatoriosActivos) ?? true;
    _isInitialized = true;
    // Arranque sin caché real: la UI debe advertir en vez de presentar la
    // semilla como tasa vigente. Se corrige en cuanto llegue la primera tasa.
    _usdEnVivo = false;
    _eurEnVivo = false;
    _usdtEnVivo = false;
    notifyListeners();

    // 2. Red en segundo plano, sin bloquear la interfaz.
    _escucharConectividad();
    actualizarTasaAutomatica();
    _sincronizarApiKeyEnSegundoPlano();
  }

  /// La API Key se sincroniza con Firestore ya con la interfaz lista: antes
  /// corría ANTES de cargar las tasas y sin timeout, así que una lectura lenta
  /// de Firestore dejaba la app clavada en la semilla por defecto.
  Future<void> _sincronizarApiKeyEnSegundoPlano() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;

      final remoteKey = await SyncService()
          .syncSettingsFromFirestore(user)
          .timeout(const Duration(seconds: 8));

      if (_apiKey.isEmpty) {
        if (remoteKey != null && remoteKey.trim().isNotEmpty) {
          _apiKey = remoteKey.trim();
          await _secureStorage.write(key: AppConstants.prefApiKey, value: _apiKey);
          notifyListeners();
        }
      } else if (remoteKey == null || remoteKey.trim().isEmpty) {
        await SyncService()
            .syncSettingsToFirestore(user, apiKey: _apiKey)
            .timeout(const Duration(seconds: 8));
      }
    } catch (e) {
      debugPrint("Error sincronizando API Key con Firestore en loadSettings: $e");
    }
  }

  /// Reintenta la sincronización de tasas cuando vuelve la red: si la app
  /// arrancó sin conexión no debe quedarse en la semilla para siempre.
  void _escucharConectividad() {
    if (_connectivitySub != null) return;
    try {
      _connectivitySub = ConnectivityService.instance.onConnectivityChanged.listen((conectado) {
        if (conectado && !_usdEnVivo && !_isSyncingRate) {
          actualizarTasaAutomatica();
        }
      });
    } catch (e) {
      debugPrint('No se pudo escuchar el estado de conectividad: $e');
    }
  }

  double? _verosimil(double? valor) {
    if (valor == null || valor < AppConstants.tasaMinimaPlausible) return null;
    return valor;
  }

  /// Sincroniza las tasas. Nunca lanza y siempre deja un motivo accesible en
  /// [ultimoErrorTasas] si no se pudo obtener la tasa del BCV en vivo.
  ///
  /// [forzar] (botón manual) ignora la caché en memoria del servicio.
  Future<void> actualizarTasaAutomatica({http.Client? client, bool forzar = false}) async {
    if (_isSyncingRate) return;
    _isSyncingRate = true;
    _ultimoErrorTasas = null;
    notifyListeners();
    try {
      final allRates = await ExchangeRateService.getAllTodayRates(client: client, forzar: forzar);
      final prefs = await SharedPreferences.getInstance();

      // Solo se aplica lo que llegó EN VIVO y por divisa; el resto conserva su
      // valor previo en vez de pisarse con ceros o marcarse como vigente.
      if (allRates.usd > 0 && !allRates.usdEsReferencia) {
        _tasaCambioVesUsd = allRates.usd;
        _usdEnVivo = true;
        await prefs.setDouble(AppConstants.prefTasaCambio, _tasaCambioVesUsd);
        await prefs.setDouble('cached_rate_usd', _tasaCambioVesUsd);
      }
      if (allRates.eur > 0 && !allRates.eurEsReferencia) {
        _tasaCambioVesEur = allRates.eur;
        _eurEnVivo = true;
        await prefs.setDouble('cached_rate_eur', _tasaCambioVesEur);
      }
      if (allRates.usdt > 0 && !allRates.usdtEsReferencia) {
        _tasaCambioVesUsdt = allRates.usdt;
        _usdtEnVivo = true;
        await prefs.setDouble('cached_rate_usdt', _tasaCambioVesUsdt);
      }

      if (allRates.algoEnVivo) {
        // Si nada llegó en vivo NO se toca el timestamp: la fecha mostrada
        // sigue siendo la última actualización real y el badge lo señala.
        _ultimaActualizacionTasas = allRates.fecha;
        await prefs.setString(
          'cached_exchange_rates_timestamp',
          _ultimaActualizacionTasas!.toIso8601String(),
        );
      }

      if (!_usdEnVivo) {
        // Antes esto se ocultaba por completo (éxito parcial = "en vivo") y el
        // usuario veía 40,00 Bs con un ✓ junto. Ahora se avisa explícitamente.
        _ultimoErrorTasas =
            'No se pudo obtener la tasa oficial del BCV en vivo. Se muestra el último valor conocido.';
      }
    } catch (e) {
      _usdEnVivo = false;
      _ultimoErrorTasas = 'No se pudieron actualizar las tasas: $e';
      debugPrint('Error al actualizar tasas automáticas: $e');
    } finally {
      _isSyncingRate = false;
      notifyListeners();
    }
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    await _secureStorage.write(key: AppConstants.prefApiKey, value: _apiKey);
    notifyListeners();

    if (Firebase.apps.isNotEmpty) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.isAnonymous) {
          await SyncService().syncSettingsToFirestore(user, apiKey: _apiKey);
        }
      } catch (e) {
        debugPrint("Error sincronizando API Key a Firestore en setApiKey: $e");
      }
    }
  }

  Future<void> removeApiKey() async {
    _apiKey = '';
    await _secureStorage.delete(key: AppConstants.prefApiKey);
    notifyListeners();

    if (Firebase.apps.isNotEmpty) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.isAnonymous) {
          await SyncService().syncSettingsToFirestore(user, apiKey: '');
        }
      } catch (e) {
        debugPrint("Error sincronizando API Key a Firestore en removeApiKey: $e");
      }
    }
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
