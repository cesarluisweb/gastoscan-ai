import '../datasources/local/database_helper.dart';
import '../models/gasto_model.dart';
import '../models/item_gasto_model.dart';
import '../models/categoria_model.dart';

class GastoRepository {
  final DatabaseHelper _dbHelper;

  GastoRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<int> guardarGasto(GastoModel gasto, List<ItemGastoModel> items) {
    return _dbHelper.insertGasto(gasto, items);
  }

  Future<void> actualizarGasto(GastoModel gasto, List<ItemGastoModel> items) {
    return _dbHelper.updateGasto(gasto, items);
  }

  Future<void> actualizarGastoSyncStatus(GastoModel gasto) {
    return _dbHelper.updateGastoSyncStatus(gasto);
  }

  /// Borrado lógico
  Future<int> eliminarGasto(int id) async {
    final gastos = await _dbHelper.getAllGastos();
    final index = gastos.indexWhere((g) => g.id == id);
    if (index != -1) {
      final gasto = gastos[index];
      final gastoBorrado = gasto.copyWith(
        eliminadoEn: DateTime.now().toIso8601String(),
        synced: 0,
      );
      await _dbHelper.updateGasto(gastoBorrado, gasto.items);
      return 1;
    }
    return 0;
  }

  /// Borrado físico (usado por el SyncService cuando ya se borró en Firebase)
  Future<int> eliminarGastoFisico(int id) {
    return _dbHelper.deleteGasto(id);
  }

  Future<List<GastoModel>> obtenerGastos() {
    return _dbHelper.getAllGastos();
  }

  Future<List<GastoModel>> obtenerTodosLosGastosConBorrados() {
    return _dbHelper.getAllGastosConBorrados();
  }

  Future<List<GastoModel>> obtenerGastosNoSincronizados() {
    return _dbHelper.getUnsyncedGastos();
  }

  Future<List<GastoModel>> obtenerGastosPorMes(int year, int month) {
    return _dbHelper.getGastosByMonth(year, month);
  }

  Future<Map<String, double>> obtenerTotalesMes(int year, int month) {
    return _dbHelper.getMonthlyTotals(year, month);
  }

  Future<Map<String, double>> obtenerTotalesPorCategoria(int year, int month) {
    return _dbHelper.getCategoryTotals(year, month);
  }

  Future<Map<String, dynamic>?> buscarPrecioAnterior(String descripcion) {
    return _dbHelper.findPreviousPrice(descripcion);
  }

  Future<Map<String, double>> obtenerPresupuestosCategorias() {
    return _dbHelper.getAllPresupuestosCategorias();
  }

  Future<void> guardarPresupuestoCategoria(String categoria, double presupuesto) {
    return _dbHelper.setPresupuestoCategoria(categoria, presupuesto);
  }

  Future<double> obtenerPresupuestoGeneralMes(int anio, int mes) {
    return _dbHelper.getPresupuestoGeneral(anio, mes);
  }

  Future<void> guardarPresupuestoGeneralMes(int anio, int mes, double monto) {
    return _dbHelper.setPresupuestoGeneral(anio, mes, monto);
  }

  Future<Map<String, double>> obtenerPresupuestosCategoriasMes(int anio, int mes) {
    return _dbHelper.getPresupuestosCategorias(anio, mes);
  }

  Future<void> guardarPresupuestoCategoriaMes(int anio, int mes, String categoria, double presupuesto) {
    return _dbHelper.setPresupuestoCategoriaMensual(anio, mes, categoria, presupuesto);
  }

  Future<void> guardarPresupuestosCategoriasMes(int anio, int mes, Map<String, double> presupuestos) {
    return _dbHelper.setPresupuestosCategorias(anio, mes, presupuestos);
  }

  Future<bool> copiarPresupuestosMesAnteriorSiVacio(int anio, int mes) {
    return _dbHelper.copiarPresupuestosMesAnteriorSiVacio(anio, mes);
  }

  Future<List<CategoriaModel>> obtenerCategorias() {
    return _dbHelper.getAllCategorias();
  }

  Future<int> guardarCategoria(CategoriaModel categoria) {
    return _dbHelper.insertCategoria(categoria);
  }

  Future<double> obtenerPresupuestoPorCategoria(String categoria) {
    return _dbHelper.getPresupuestoPorCategoria(categoria);
  }
}
