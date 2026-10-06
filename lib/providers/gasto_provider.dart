import 'package:flutter/foundation.dart';
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
  double _presupuestoGeneral = 0.0;
  double _metaAhorro = 0.0;
  String _monedaPresupuesto = 'USD';
  Map<String, double> _totalesPorCategoria = {};
  Map<String, double> _totalesPorCategoriaVes = {};
  Map<String, double> _presupuestosPorCategoria = {};

  List<GastoModel> get gastos => _gastos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;
  double get totalMesUsd => _totalMesUsd;
  double get totalMesVes => _totalMesVes;
  double get presupuestoGeneral => _presupuestoGeneral;
  double get metaAhorro => _metaAhorro;
  String get monedaPresupuesto => _monedaPresupuesto;
  Map<String, double> get totalesPorCategoria => _totalesPorCategoria;
  Map<String, double> get totalesPorCategoriaVes =>
      _totalesPorCategoriaVes.isNotEmpty ? _totalesPorCategoriaVes : _totalesPorCategoria;

  Map<String, double> totalesPorCategoriaPara(String moneda) {
    return moneda == 'VES' ? _totalesPorCategoriaVes : _totalesPorCategoria;
  }

  Map<String, double> get presupuestosPorCategoria => _presupuestosPorCategoria;

  SavingsHealthSnapshot get savingsSnapshot {
    final double gastoAcumulado = _monedaPresupuesto == 'VES' ? _totalMesVes : _totalMesUsd;

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
      _gastos = await _repository.obtenerGastosPorMes(_selectedYear, _selectedMonth);
      
      final totales = await _repository.obtenerTotalesMes(_selectedYear, _selectedMonth);
      _totalMesUsd = totales['USD'] ?? 0.0;
      _totalMesVes = totales['VES'] ?? 0.0;

      _totalesPorCategoria = await _repository.obtenerTotalesPorCategoria(_selectedYear, _selectedMonth, moneda: 'USD');
      _totalesPorCategoriaVes = await _repository.obtenerTotalesPorCategoria(_selectedYear, _selectedMonth, moneda: 'VES');

      // Copiar del mes anterior si este mes no tiene registros de presupuesto
      await _repository.copiarPresupuestosMesAnteriorSiVacio(_selectedYear, _selectedMonth);

      _presupuestoGeneral = await _repository.obtenerPresupuestoGeneralMes(_selectedYear, _selectedMonth);
      _metaAhorro = await _repository.obtenerMetaAhorroMes(_selectedYear, _selectedMonth);
      _monedaPresupuesto = await _repository.obtenerMonedaPresupuestoGeneralMes(_selectedYear, _selectedMonth);
      _presupuestosPorCategoria = await _repository.obtenerPresupuestosCategoriasMes(_selectedYear, _selectedMonth);
    } catch (e) {
      _errorMessage = 'Error al cargar los gastos: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> repararTasasHistoricas({double tasaFallback = 40.0}) async {
    final count = await _repository.repararTasasHistoricasIncompletas(tasaFallback: tasaFallback);
    if (count > 0) {
      await cargarDatos();
    }
    return count;
  }

  Future<bool> agregarGasto(GastoModel gasto, List<ItemGastoModel> items, {List<int>? shoppingItemIds}) async {
    try {
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
      _errorMessage = 'Error al guardar el gasto: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarGasto(GastoModel gasto, List<ItemGastoModel> items) async {
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
      _errorMessage = 'Error al actualizar el gasto: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<String?> vincularCuentaGoogle() async {
    final error = await _syncService.vincularCuentaGoogle();
    if (error == null) {
      await cargarDatos(); // Recargar tras sincronizar
      notifyListeners();
    }
    return error;
  }

  Future<void> sincronizarConFirestore() async {
    await _syncService.syncBidirectional();
    await cargarDatos();
  }

  Future<bool> eliminarGasto(int id) async {
    try {
      await _repository.eliminarGasto(id); // Ahora hace borrado lógico
      await cargarDatos();
      _syncService.syncBidirectional(); // Manda a borrar en firebase
      return true;
    } catch (e) {
      _errorMessage = 'Error al eliminar el gasto: ${e.toString()}';
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

  Future<Map<String, dynamic>?> buscarPrecioAnterior(String descripcion, {int? excludeGastoId}) async {
    return await _repository.buscarPrecioAnterior(descripcion, excludeGastoId: excludeGastoId);
  }

  Future<void> setPresupuestoGeneral(double monto, {String moneda = 'USD'}) async {
    try {
      await _repository.guardarPresupuestoGeneralMes(_selectedYear, _selectedMonth, monto, moneda: moneda);
      _presupuestoGeneral = monto >= 0 ? monto : 0.0;
      _monedaPresupuesto = moneda;
      notifyListeners();
      _syncService.syncBidirectional();
    } catch (e) {
      _errorMessage = 'Error al guardar presupuesto general: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> setPresupuestoCategoria(String categoria, double presupuesto, {String moneda = 'USD'}) async {
    try {
      await _repository.guardarPresupuestoCategoriaMes(_selectedYear, _selectedMonth, categoria, presupuesto, moneda: moneda);
      if (presupuesto <= 0) {
        _presupuestosPorCategoria.remove(categoria);
        _presupuestosPorCategoria.removeWhere((key, value) => key.toLowerCase().trim() == categoria.toLowerCase().trim());
      } else {
        _presupuestosPorCategoria[categoria] = presupuesto;
      }
      notifyListeners();
      _syncService.syncBidirectional();
    } catch (e) {
      _errorMessage = 'Error al guardar presupuesto: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> guardarTodoElPresupuesto(
    double general,
    Map<String, double> categorias, {
    String moneda = 'USD',
    double metaAhorro = 0.0,
  }) async {
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
      notifyListeners();
      _syncService.syncBidirectional();
    } catch (e) {
      _errorMessage = 'Error al guardar presupuestos: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> setMetaAhorro(double meta) async {
    try {
      await _repository.guardarPresupuestoGeneralMes(
        _selectedYear,
        _selectedMonth,
        _presupuestoGeneral,
        moneda: _monedaPresupuesto,
        metaAhorro: meta,
      );
      _metaAhorro = meta >= 0 ? meta : 0.0;
      notifyListeners();
      _syncService.syncBidirectional();
    } catch (e) {
      _errorMessage = 'Error al guardar meta de ahorro: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> eliminarPresupuestoCategoria(String categoria) async {
    await setPresupuestoCategoria(categoria, 0.0);
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

  double getSpentForCategory(String categoria) {
    if (_totalesPorCategoria.containsKey(categoria)) {
      return _totalesPorCategoria[categoria]!;
    }
    for (final entry in _totalesPorCategoria.entries) {
      if (entry.key.toLowerCase().trim() == categoria.toLowerCase().trim()) {
        return entry.value;
      }
    }
    return 0.0;
  }

  bool isCategoryOverBudget(String categoria) {
    final budget = getPresupuestoCategoria(categoria);
    if (budget <= 0) return false;
    final spent = getSpentForCategory(categoria);
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
