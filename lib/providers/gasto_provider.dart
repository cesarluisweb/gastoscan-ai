import 'package:flutter/foundation.dart';
import '../data/models/gasto_model.dart';
import '../data/models/item_gasto_model.dart';
import '../data/repositories/gasto_repository.dart';
import '../data/datasources/local/database_helper.dart';
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
  Map<String, double> _totalesPorCategoria = {};
  Map<String, double> _presupuestosPorCategoria = {};

  List<GastoModel> get gastos => _gastos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;
  double get totalMesUsd => _totalMesUsd;
  double get totalMesVes => _totalMesVes;
  Map<String, double> get totalesPorCategoria => _totalesPorCategoria;
  Map<String, double> get presupuestosPorCategoria => _presupuestosPorCategoria;

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

      _totalesPorCategoria = await _repository.obtenerTotalesPorCategoria(_selectedYear, _selectedMonth);
      _presupuestosPorCategoria = await _repository.obtenerPresupuestosCategorias();
    } catch (e) {
      _errorMessage = 'Error al cargar los gastos: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  Future<Map<String, dynamic>?> buscarPrecioAnterior(String descripcion) async {
    return await _repository.buscarPrecioAnterior(descripcion);
  }

  Future<void> setPresupuestoCategoria(String categoria, double presupuesto) async {
    try {
      await _repository.guardarPresupuestoCategoria(categoria, presupuesto);
      if (presupuesto <= 0) {
        _presupuestosPorCategoria.remove(categoria);
        _presupuestosPorCategoria.removeWhere((key, value) => key.toLowerCase().trim() == categoria.toLowerCase().trim());
      } else {
        _presupuestosPorCategoria[categoria] = presupuesto;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al guardar presupuesto: ${e.toString()}';
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
}
