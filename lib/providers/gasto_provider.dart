import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/models/gasto_model.dart';
import '../data/models/item_gasto_model.dart';
import '../data/repositories/gasto_repository.dart';
import '../data/datasources/local/database_helper.dart';
import '../services/notification_service.dart';

class GastoProvider with ChangeNotifier {
  final GastoRepository _repository;

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

  GastoProvider({GastoRepository? repository, bool autoLoad = true})
      : _repository = repository ?? GastoRepository() {
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
      syncToFirestore(); // Intentar sincronizar en segundo plano
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
      final gastoAActualizar = gasto.copyWith(synced: 0); // Marcar como no sincronizado
      await _repository.actualizarGasto(gastoAActualizar, items);
      await cargarDatos();
      syncToFirestore();
      NotificationService.instance.recordActivityAndReschedule();
      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar el gasto: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<String?> vincularCuentaGoogle() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) return "No hay sesión local activa";

      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        serverClientId: '758679432067-p4lll1b5vfia32fndd68gjif6bmfmvel.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) return null; // User canceled, no error

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      if (user.isAnonymous) {
        try {
          await user.linkWithCredential(credential);
          await user.updateProfile(displayName: googleUser.displayName, photoURL: googleUser.photoUrl);
          await user.reload();
          await syncToFirestore(); // Sync all existing anonymous data
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // El usuario ya tenía una cuenta. Iniciar sesión con ella.
            final userCred = await auth.signInWithCredential(credential);
            
            final signedInUser = userCred.user;
            if (userCred.user != null) {
              await userCred.user?.updateProfile(displayName: googleUser.displayName, photoURL: googleUser.photoUrl);
              await userCred.user?.reload();
            }

            // Forzar que los datos locales SQLite suban y se fusionen
            final gastos = await _repository.obtenerGastos();
            for (var g in gastos) {
              await _repository.actualizarGastoSyncStatus(g.copyWith(synced: 0));
            }
            await syncToFirestore();
          } else {
            return e.message ?? e.toString();
          }
        }
      } else {
        // Ya no es anonimo
      }
      return null;
    } catch (e) {
      debugPrint("Error al vincular Google: $e");
      return e.toString();
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

  /// Define o actualiza el presupuesto mensual de una categoría
  Future<void> setPresupuestoCategoria(String categoria, double presupuesto) async {
    try {
      await _repository.guardarPresupuestoCategoria(categoria, presupuesto);
      _presupuestosPorCategoria[categoria] = presupuesto;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al guardar presupuesto: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Obtiene el presupuesto asignado a una categorías)
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

  /// Obtiene el gasto mensual total acumulado en una categorías)
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

  /// Determina si una categoríado
  bool isCategoryOverBudget(String categoria) {
    final budget = getPresupuestoCategoria(categoria);
    if (budget <= 0) return false;
    final spent = getSpentForCategory(categoria);
    return spent > budget;
  }
}
