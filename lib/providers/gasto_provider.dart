import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../data/models/gasto_model.dart';
import '../data/models/item_gasto_model.dart';
import '../data/repositories/gasto_repository.dart';
import '../data/datasources/local/database_helper.dart';
import '../domain/finance/savings_health_models.dart';
import '../domain/finance/savings_health_calculator.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

class GastoProvider with ChangeNotifier {
  final GastoRepository _repository;
  final SyncService _syncService;

  List<GastoModel> _gastos = [];
  bool _isLoading = false;
  String? _errorMessage;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  double _totalMesUsd = 0.0;
  double _totalMesVes = 0.0;
  double _totalMesUsdt = 0.0;
  double _presupuestoGeneral = 0.0;
  double _metaAhorro = 0.0;
  String _monedaPresupuesto = 'USD';
  Map<String, double> _totalesPorCategoria = {};
  Map<String, double> _totalesPorCategoriaVes = {};
  Map<String, double> _totalesPorCategoriaUsdt = {};
  Map<String, double> _presupuestosPorCategoria = {};
  bool _presupuestoEsAdoptado = false;
  double _tasaUsd = AppConstants.defaultTasaCambio;
  double _tasaEur = 0.0;

  void setTasasReferencia({double? tasaUsd, double? tasaEur}) {
    if (tasaUsd != null && tasaUsd > 0) _tasaUsd = tasaUsd;
    if (tasaEur != null && tasaEur > 0) _tasaEur = tasaEur;
  }

  List<GastoModel> get gastos => _gastos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;
  double get totalMesUsd => _totalMesUsd;
  double get totalMesVes => _totalMesVes;
  double get totalMesUsdt => _totalMesUsdt;
  double get presupuestoGeneral => _presupuestoGeneral;
  double get metaAhorro => _metaAhorro;
  String get monedaPresupuesto => _monedaPresupuesto;
  bool get presupuestoEsAdoptado => _presupuestoEsAdoptado;
  Map<String, double> get totalesPorCategoria => _totalesPorCategoria;
  Map<String, double> get totalesPorCategoriaVes =>
      _totalesPorCategoriaVes.isNotEmpty ? _totalesPorCategoriaVes : _totalesPorCategoria;
  Map<String, double> get totalesPorCategoriaUsdt =>
      _totalesPorCategoriaUsdt.isNotEmpty ? _totalesPorCategoriaUsdt : _totalesPorCategoria;

  Map<String, double> get presupuestosPorCategoria => _presupuestosPorCategoria;

  SavingsHealthSnapshot get savingsSnapshot {
    final double gastoAcumulado;
    if (_monedaPresupuesto == 'VES') {
      gastoAcumulado = _totalMesVes;
    } else if (_monedaPresupuesto == 'USDT') {
      gastoAcumulado = _totalMesUsdt > 0 ? _totalMesUsdt : _totalMesUsd;
    } else if (_monedaPresupuesto == 'EUR') {
      final double eurRate = _tasaEur > 0 ? _tasaEur : (_tasaUsd > 0 ? _tasaUsd : 0.0);
      if (eurRate > 0 && _totalMesVes > 0) {
        gastoAcumulado = _totalMesVes / eurRate;
      } else if (eurRate > 0 && _tasaUsd > 0) {
        gastoAcumulado = (_totalMesUsd * _tasaUsd) / eurRate;
      } else {
        gastoAcumulado = _totalMesUsd;
      }
    } else {
      gastoAcumulado = _totalMesUsd;
    }

    final now = DateTime.now();
    final isCurrentMonth = (now.year == _selectedYear && now.month == _selectedMonth);
    final totalDias = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final diaActual = isCurrentMonth ? now.day : totalDias;

    return SavingsHealthCalculator.calculate(
      presupuestoGeneral: _presupuestoGeneral,
      metaAhorro: _metaAhorro,
      gastoAcumulado: gastoAcumulado,
      diaActual: diaActual,
      diasTotalesMes: totalDias,
      moneda: _monedaPresupuesto,
    );
  }

  GastoProvider({GastoRepository? repository, SyncService? syncService, bool autoLoad = true})
      : _repository = repository ?? GastoRepository(),
        _syncService = syncService ?? SyncService(repository: repository ?? GastoRepository()) {
    if (autoLoad) {
      cargarDatos();
    }
  }

  Future<void> cargarDatos() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedUsd = prefs.getDouble('cached_rate_usd') ??
            prefs.getDouble(AppConstants.prefTasaCambio);
        if (cachedUsd != null && cachedUsd > 1.0) _tasaUsd = cachedUsd;
        final cachedEur = prefs.getDouble('cached_rate_eur');
        if (cachedEur != null && cachedEur > 1.0) _tasaEur = cachedEur;
      } catch (_) {}

      _gastos = await _repository.obtenerGastosPorMes(_selectedYear, _selectedMonth);
      
      final totales = await _repository.obtenerTotalesMes(_selectedYear, _selectedMonth);
      _totalMesUsd = totales['USD'] ?? 0.0;
      _totalMesVes = totales['VES'] ?? 0.0;
      _totalMesUsdt = totales['USDT'] ?? _totalMesUsd;

      _totalesPorCategoria = await _repository.obtenerTotalesPorCategoria(_selectedYear, _selectedMonth, moneda: 'USD');
      _totalesPorCategoriaVes = await _repository.obtenerTotalesPorCategoria(_selectedYear, _selectedMonth, moneda: 'VES');
      _totalesPorCategoriaUsdt = await _repository.obtenerTotalesPorCategoria(_selectedYear, _selectedMonth, moneda: 'USDT');

      _presupuestoGeneral = await _repository.obtenerPresupuestoGeneralMes(_selectedYear, _selectedMonth);
      _metaAhorro = await _repository.obtenerMetaAhorroMes(_selectedYear, _selectedMonth);
      _monedaPresupuesto = await _repository.obtenerMonedaPresupuestoGeneralMes(_selectedYear, _selectedMonth);
      _presupuestosPorCategoria = await _repository.obtenerPresupuestosCategoriasMes(_selectedYear, _selectedMonth);
      _presupuestoEsAdoptado = false;

      // Si este mes no tiene registros de presupuesto en BD, adoptar en memoria la configuración
      // del presupuesto más reciente configurado previamente (sin escribir filas fantasmas en SQLite)
      if (_presupuestoGeneral == 0.0 && _metaAhorro == 0.0 && _presupuestosPorCategoria.isEmpty) {
        final ultimo = await _repository.obtenerUltimoPresupuestoConfigurado(
          antesDeAnio: _selectedYear,
          antesDeMes: _selectedMonth,
          estrictamenteAnterior: true,
        );

        if (ultimo != null) {
          final prevGeneral = (ultimo['presupuesto_general'] as num?)?.toDouble() ?? 0.0;
          final prevMeta = (ultimo['meta_ahorro'] as num?)?.toDouble() ?? 0.0;
          final prevMoneda = (ultimo['moneda'] as String?) ?? 'USD';
          final prevCats = (ultimo['categorias'] as Map<String, double>?) ?? {};

          if (prevGeneral > 0 || prevMeta > 0 || prevCats.isNotEmpty) {
            _presupuestoGeneral = prevGeneral;
            _metaAhorro = prevMeta;
            _monedaPresupuesto = prevMoneda;
            _presupuestosPorCategoria = prevCats;
            _presupuestoEsAdoptado = true;
          }
        }
      }
    } catch (e) {
      _errorMessage = _mapHumanFriendlyError(e, 'Error al cargar los gastos: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _consolidarPresupuestoAdoptadoSiAplica() async {
    if (!_presupuestoEsAdoptado) return;
    try {
      if (_presupuestoGeneral > 0 || _metaAhorro > 0) {
        await _repository.guardarPresupuestoGeneralMes(
          _selectedYear,
          _selectedMonth,
          _presupuestoGeneral,
          moneda: _monedaPresupuesto,
          metaAhorro: _metaAhorro,
        );
      }
      if (_presupuestosPorCategoria.isNotEmpty) {
        await _repository.guardarPresupuestosCategoriasMes(
          _selectedYear,
          _selectedMonth,
          _presupuestosPorCategoria,
          moneda: _monedaPresupuesto,
        );
      }
      _presupuestoEsAdoptado = false;
    } catch (e) {
      debugPrint('Error al consolidar presupuesto adoptado: $e');
    }
  }

  String _mapHumanFriendlyError(dynamic e, String defaultMessage) {
    final str = e.toString();
    if (str.contains('SocketException') || str.contains('Failed host lookup') || str.contains('ClientException')) {
      return 'No hay conexión a internet para sincronizar con la nube.';
    }
    if (str.contains('DatabaseException') || str.contains('sqflite')) {
      return 'Error al acceder a la base de datos local.';
    }
    return defaultMessage;
  }

  Future<int> repararTasasHistoricas({double tasaFallback = AppConstants.defaultTasaCambio}) async {
    final count = await _repository.repararTasasHistoricasIncompletas(tasaFallback: tasaFallback);
    if (count > 0) {
      await cargarDatos();
    }
    return count;
  }

  Future<bool> agregarGasto(GastoModel gasto, List<ItemGastoModel> items, {List<int>? shoppingItemIds}) async {
    _errorMessage = null;
    try {
      await _consolidarPresupuestoAdoptadoSiAplica();
      final newId = await _repository.guardarGasto(gasto, items);
      
      if (shoppingItemIds != null && shoppingItemIds.isNotEmpty) {
        final dbHelper = DatabaseHelper.instance;
        await dbHelper.markShoppingItemsAsPurchased(shoppingItemIds, newId);
      }

      await cargarDatos();
      _syncService.syncBidirectional(); // Sincronizar en segundo plano
      NotificationService.instance.recordActivityAndReschedule();
      return true;
    } catch (e) {
      _errorMessage = _mapHumanFriendlyError(e, 'Error al guardar el gasto: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarGasto(GastoModel gasto, List<ItemGastoModel> items) async {
    _errorMessage = null;
    try {
      final gastoAActualizar = gasto.copyWith(
        actualizadoEn: DateTime.now().toIso8601String(),
        synced: 0
      ); 
      await _repository.actualizarGasto(gastoAActualizar, items);
      await cargarDatos();
      _syncService.syncBidirectional();
      NotificationService.instance.recordActivityAndReschedule();
      return true;
    } catch (e) {
      _errorMessage = _mapHumanFriendlyError(e, 'Error al actualizar el gasto: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  Future<String?> vincularCuentaGoogle({bool descartarDatosLocales = false}) async {
    final error = await _syncService.vincularCuentaGoogle(descartarDatosLocales: descartarDatosLocales);
    if (error == null) {
      await cargarDatos(); // Recargar tras sincronizar
      notifyListeners();
    }
    return error;
  }

  Future<String?> vincularConEmail(String email, String password, {bool descartarDatosLocales = false}) async {
    final error = await _syncService.vincularConEmail(email, password, descartarDatosLocales: descartarDatosLocales);
    if (error == null) {
      await cargarDatos();
      notifyListeners();
    }
    return error;
  }

  Future<String?> iniciarSesionConEmail(String email, String password, {bool descartarDatosLocales = true}) async {
    final error = await _syncService.iniciarSesionConEmail(email, password, descartarDatosLocales: descartarDatosLocales);
    if (error == null) {
      await cargarDatos();
      notifyListeners();
    }
    return error;
  }

  Future<void> cerrarSesion() async {
    _errorMessage = null;
    try {
      await _syncService.cerrarSesion();
      _gastos = [];
      _presupuestoGeneral = 0.0;
      _metaAhorro = 0.0;
      _presupuestosPorCategoria = {};
      await cargarDatos();
      notifyListeners();
    } catch (e) {
      _errorMessage = _mapHumanFriendlyError(e, 'Error al cerrar sesión: $e');
      notifyListeners();
    }
  }

  Future<String?> eliminarCuentaYDatos({String? reauthPassword}) async {
    _errorMessage = null;
    try {
      final error = await _syncService.eliminarCuentaYDatos(reauthPassword: reauthPassword);
      if (error != null) {
        _errorMessage = error;
        notifyListeners();
        return error;
      }
      _gastos = [];
      _presupuestoGeneral = 0.0;
      _metaAhorro = 0.0;
      _presupuestosPorCategoria = {};
      await cargarDatos();
      notifyListeners();
      return null;
    } catch (e) {
      final err = _mapHumanFriendlyError(e, 'Error al eliminar cuenta: $e');
      _errorMessage = err;
      notifyListeners();
      return err;
    }
  }

  Future<void> sincronizarConFirestore() async {
    await _syncService.syncBidirectional();
    await cargarDatos();
  }

  Future<bool> eliminarGasto(int id) async {
    _errorMessage = null;
    try {
      await _repository.eliminarGasto(id); // Ahora hace borrado lógico
      await cargarDatos();
      _syncService.syncBidirectional(); // Manda a borrar en firebase
      return true;
    } catch (e) {
      _errorMessage = _mapHumanFriendlyError(e, 'Error al eliminar el gasto: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  void cambiarMes(int year, int month) {
    _selectedYear = year;
    _selectedMonth = month;
    cargarDatos();
  }

  Future<List<GastoModel>> obtenerTodosParaExportar() async {
    return await _repository.obtenerGastos();
  }

  /// Retorna todos los gastos sin filtrar por mes para búsqueda global
  Future<List<GastoModel>> obtenerTodosLosGastos() async {
    try {
      return await _repository.obtenerGastos();
    } catch (_) {
      return _gastos;
    }
  }

  Future<Map<String, dynamic>?> buscarPrecioAnterior(String descripcion, {int? excludeGastoId}) async {
    return await _repository.buscarPrecioAnterior(descripcion, excludeGastoId: excludeGastoId);
  }

  Future<bool> setPresupuestoGeneral(double monto, {String moneda = 'USD'}) async {
    _errorMessage = null;
    try {
      await _repository.guardarPresupuestoGeneralMes(_selectedYear, _selectedMonth, monto, moneda: moneda);
      _presupuestoGeneral = monto >= 0 ? monto : 0.0;
      _monedaPresupuesto = moneda;
      _presupuestoEsAdoptado = false;
      notifyListeners();
      _syncService.syncBidirectional();
      return true;
    } catch (e) {
      _errorMessage = _mapHumanFriendlyError(e, 'Error al guardar presupuesto general: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  Future<bool> setPresupuestoCategoria(String categoria, double presupuesto, {String? moneda}) async {
    _errorMessage = null;
    // Herencia formal (auditoría 2): las categorías siempre usan la moneda del
    // presupuesto general, salvo que se indique otra explícitamente.
    final effectiveMoneda = moneda ?? _monedaPresupuesto;
    try {
      await _repository.guardarPresupuestoCategoriaMes(_selectedYear, _selectedMonth, categoria, presupuesto, moneda: effectiveMoneda);
      if (presupuesto <= 0) {
        _presupuestosPorCategoria.remove(categoria);
        _presupuestosPorCategoria.removeWhere((key, value) => key.toLowerCase().trim() == categoria.toLowerCase().trim());
      } else {
        _presupuestosPorCategoria[categoria] = presupuesto;
      }
      _presupuestoEsAdoptado = false;
      notifyListeners();
      _syncService.syncBidirectional();
      return true;
    } catch (e) {
      _errorMessage = _mapHumanFriendlyError(e, 'Error al guardar presupuesto: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  Future<bool> guardarTodoElPresupuesto(
    double general,
    Map<String, double> categorias, {
    String moneda = 'USD',
    double metaAhorro = 0.0,
  }) async {
    _errorMessage = null;
    try {
      await _repository.guardarPresupuestoGeneralMes(
        _selectedYear,
        _selectedMonth,
        general,
        moneda: moneda,
        metaAhorro: metaAhorro,
      );
      await _repository.guardarPresupuestosCategoriasMes(_selectedYear, _selectedMonth, categorias, moneda: moneda);
      _presupuestoGeneral = general >= 0 ? general : 0.0;
      _metaAhorro = metaAhorro >= 0 ? metaAhorro : 0.0;
      _monedaPresupuesto = moneda;
      _presupuestosPorCategoria = Map.from(categorias)..removeWhere((key, value) => value <= 0);
      _presupuestoEsAdoptado = false;
      notifyListeners();
      _syncService.syncBidirectional();
      return true;
    } catch (e) {
      _errorMessage = _mapHumanFriendlyError(e, 'Error al guardar presupuestos: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  Future<bool> setMetaAhorro(double meta) async {
    _errorMessage = null;
    try {
      await _repository.guardarPresupuestoGeneralMes(
        _selectedYear,
        _selectedMonth,
        _presupuestoGeneral,
        moneda: _monedaPresupuesto,
        metaAhorro: meta,
      );
      _metaAhorro = meta >= 0 ? meta : 0.0;
      _presupuestoEsAdoptado = false;
      notifyListeners();
      _syncService.syncBidirectional();
      return true;
    } catch (e) {
      _errorMessage = _mapHumanFriendlyError(e, 'Error al guardar meta de ahorro: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarPresupuestoCategoria(String categoria) async {
    return await setPresupuestoCategoria(categoria, 0.0);
  }

  double getPresupuestoCategoria(String categoria) {
    if (_presupuestosPorCategoria.containsKey(categoria)) {
      return _presupuestosPorCategoria[categoria]!;
    }
    for (final entry in _presupuestosPorCategoria.entries) {
      if (entry.key.toLowerCase().trim() == categoria.toLowerCase().trim()) {
        return entry.value;
      }
    }
    return 0.0;
  }

  double getSpentForCategory(String categoria, {String? moneda}) {
    final normMoneda = (moneda ?? 'USD').toUpperCase().trim();
    Map<String, double> map;
    double factor = 1.0;

    if (normMoneda == 'VES') {
      map = totalesPorCategoriaVes;
    } else if (normMoneda == 'USDT') {
      map = totalesPorCategoriaUsdt;
    } else if (normMoneda == 'EUR') {
      final double effEur = _tasaEur > 0 ? _tasaEur : 0.0;
      final double effUsd = _tasaUsd > 0 ? _tasaUsd : 0.0;
      if (effEur > 0 && _totalesPorCategoriaVes.isNotEmpty) {
        map = _totalesPorCategoriaVes;
        factor = 1.0 / effEur;
      } else if (effEur > 0 && effUsd > 0) {
        map = _totalesPorCategoria;
        factor = effUsd / effEur;
      } else {
        map = _totalesPorCategoria;
      }
    } else {
      map = _totalesPorCategoria;
    }

    if (map.containsKey(categoria)) {
      return map[categoria]! * factor;
    }
    for (final entry in map.entries) {
      if (entry.key.toLowerCase().trim() == categoria.toLowerCase().trim()) {
        return entry.value * factor;
      }
    }
    return 0.0;
  }

  bool isCategoryOverBudget(String categoria, {String? moneda}) {
    final budget = getPresupuestoCategoria(categoria);
    if (budget <= 0) return false;
    final effectiveMoneda = moneda ?? _monedaPresupuesto;
    final spent = getSpentForCategory(categoria, moneda: effectiveMoneda);
    return spent > budget;
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
