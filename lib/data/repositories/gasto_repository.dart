import '../datasources/local/database_helper.dart';
import '../models/gasto_model.dart';
import '../models/item_gasto_model.dart';

class GastoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> guardarGasto(GastoModel gasto, List<ItemGastoModel> items) {
    return _dbHelper.insertGasto(gasto, items);
  }

  Future<void> actualizarGasto(GastoModel gasto, List<ItemGastoModel> items) {
    return _dbHelper.updateGasto(gasto, items);
  }

  Future<int> eliminarGasto(int id) {
    return _dbHelper.deleteGasto(id);
  }

  Future<List<GastoModel>> obtenerGastos() {
    return _dbHelper.getAllGastos();
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
}
