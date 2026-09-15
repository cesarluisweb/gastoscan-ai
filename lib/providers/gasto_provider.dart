import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/gasto_model.dart';
import '../data/models/item_gasto_model.dart';
import '../data/repositories/gasto_repository.dart';

class GastoProvider with ChangeNotifier {
  final GastoRepository _repository = GastoRepository();

  List<GastoModel> _gastos = [];
  bool _isLoading = false;
  String? _errorMessage;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  double _totalMesUsd = 0.0;
  double _totalMesVes = 0.0;
  Map<String, double> _totalesPorCategoria = {};

  List<GastoModel> get gastos => _gastos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;
  double get totalMesUsd => _totalMesUsd;
  double get totalMesVes => _totalMesVes;
  Map<String, double> get totalesPorCategoria => _totalesPorCategoria;

  GastoProvider() {
    cargarDatos();
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
    } catch (e) {
      _errorMessage = 'Error al cargar los gastos: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> agregarGasto(GastoModel gasto, List<ItemGastoModel> items) async {
    try {
      await _repository.guardarGasto(gasto, items);
      await cargarDatos();
      syncToFirestore(); // Intentar sincronizar en segundo plano
      return true;
    } catch (e) {
      _errorMessage = 'Error al guardar el gasto: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarGasto(GastoModel gasto, List<ItemGastoModel> items) async {
    try {
      final gastoAActualizar = gasto.copyWith(synced: 0); // Marcar como no sincronizado
      await _repository.actualizarGasto(gastoAActualizar, items);
      await cargarDatos();
      syncToFirestore();
      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar el gasto: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> syncToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;

      final unsyncedGastos = await _repository.obtenerGastosNoSincronizados();
      
      for (var gasto in unsyncedGastos) {
        final docRef = gasto.firestoreId != null 
          ? FirebaseFirestore.instance.collection('users').doc(user.uid).collection('gastos').doc(gasto.firestoreId)
          : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('gastos').doc();
          
        final data = gasto.toMap();
        data['firestore_id'] = docRef.id;
        
        await docRef.set(data);
        
        final syncedGasto = gasto.copyWith(firestoreId: docRef.id, synced: 1);
        await _repository.actualizarGastoSyncStatus(syncedGasto);
      }
    } catch (e) {
      debugPrint("Error al sincronizar con Firestore: $e");
    }
  }

  Future<bool> eliminarGasto(int id) async {
    try {
      await _repository.eliminarGasto(id);
      await cargarDatos();
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
}
