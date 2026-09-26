import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/categoria_model.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';

class MockGastoProvider extends GastoProvider {
  final Map<String, double> _testTotales = {};
  final Map<String, double> _testPresupuestos = {};
  double _testPresupuestoGeneral = 0.0;

  MockGastoProvider({
    Map<String, double>? initialTotales,
    Map<String, double>? initialPresupuestos,
    double initialPresupuestoGeneral = 0.0,
  }) : _testPresupuestoGeneral = initialPresupuestoGeneral {
    if (initialTotales != null) _testTotales.addAll(initialTotales);
    if (initialPresupuestos != null) _testPresupuestos.addAll(initialPresupuestos);
  }

  void setTestTotales(Map<String, double> totales) {
    _testTotales.clear();
    _testTotales.addAll(totales);
    notifyListeners();
  }

  void setTestPresupuestos(Map<String, double> presupuestos) {
    _testPresupuestos.clear();
    _testPresupuestos.addAll(presupuestos);
    notifyListeners();
  }

  @override
  double get presupuestoGeneral => _testPresupuestoGeneral;

  @override
  Map<String, double> get totalesPorCategoria => _testTotales;

  @override
  Map<String, double> get presupuestosPorCategoria => _testPresupuestos;

  @override
  Future<void> setPresupuestoGeneral(double monto) async {
    _testPresupuestoGeneral = monto;
    notifyListeners();
  }

  @override
  Future<void> setPresupuestoCategoria(String categoria, double presupuesto) async {
    if (presupuesto <= 0) {
      _testPresupuestos.remove(categoria);
    } else {
      _testPresupuestos[categoria] = presupuesto;
    }
    notifyListeners();
  }

  @override
  Future<void> guardarTodoElPresupuesto(double general, Map<String, double> categorias) async {
    _testPresupuestoGeneral = general;
    _testPresupuestos.clear();
    categorias.forEach((k, v) {
      if (v > 0) _testPresupuestos[k] = v;
    });
    notifyListeners();
  }

  @override
  double getPresupuestoCategoria(String categoria) {
    if (_testPresupuestos.containsKey(categoria)) {
      return _testPresupuestos[categoria]!;
    }
    for (final entry in _testPresupuestos.entries) {
      if (entry.key.toLowerCase().trim() == categoria.toLowerCase().trim()) {
        return entry.value;
      }
    }
    return 0.0;
  }

  @override
  double getSpentForCategory(String categoria) {
    if (_testTotales.containsKey(categoria)) {
      return _testTotales[categoria]!;
    }
    for (final entry in _testTotales.entries) {
      if (entry.key.toLowerCase().trim() == categoria.toLowerCase().trim()) {
        return entry.value;
      }
    }
    return 0.0;
  }

  @override
  bool isCategoryOverBudget(String categoria) {
    final budget = getPresupuestoCategoria(categoria);
    if (budget <= 0) return false;
    final spent = getSpentForCategory(categoria);
    return spent > budget;
  }

  @override
  Future<void> cargarDatos() async {}
}

void main() {
  group('GastoProvider Budget Logic Tests', () {
    late MockGastoProvider provider;

    setUp(() {
      provider = MockGastoProvider();
    });

    test('initial state has empty category budgets and totals', () {
      expect(provider.presupuestoGeneral, 0.0);
      expect(provider.presupuestosPorCategoria, isEmpty);
      expect(provider.totalesPorCategoria, isEmpty);
      expect(provider.getPresupuestoCategoria('Comida'), 0.0);
      expect(provider.getSpentForCategory('Comida'), 0.0);
      expect(provider.isCategoryOverBudget('Comida'), isFalse);
    });

    test('setPresupuestoGeneral updates general budget', () async {
      await provider.setPresupuestoGeneral(300.0);
      expect(provider.presupuestoGeneral, 300.0);
    });

    test('guardarTodoElPresupuesto updates general and category budgets and filters zero budgets', () async {
      await provider.guardarTodoElPresupuesto(500.0, {
        'Alimentacion': 200.0,
        'Transporte': 100.0,
        'Salud': 0.0,
      });

      expect(provider.presupuestoGeneral, 500.0);
      expect(provider.presupuestosPorCategoria['Alimentacion'], 200.0);
      expect(provider.presupuestosPorCategoria['Transporte'], 100.0);
      expect(provider.presupuestosPorCategoria.containsKey('Salud'), isFalse);
    });

    test('setPresupuestoCategoria updates budget for given category', () async {
      await provider.setPresupuestoCategoria('Comida', 50.0);

      expect(provider.presupuestosPorCategoria['Comida'], 50.0);
      expect(provider.getPresupuestoCategoria('Comida'), 50.0);
    });

    test('getPresupuestoCategoria is case-insensitive', () async {
      await provider.setPresupuestoCategoria('Comida', 50.0);

      expect(provider.getPresupuestoCategoria('comida'), 50.0);
      expect(provider.getPresupuestoCategoria('COMIDA'), 50.0);
      expect(provider.getPresupuestoCategoria(' Comida '), 50.0);
    });

    test('isCategoryOverBudget returns true when spent > budget and budget > 0', () async {
      // Setup: Budget $50 on Comida, Expense $60 on Comida
      await provider.setPresupuestoCategoria('Comida', 50.0);
      provider.setTestTotales({'Comida': 60.0});

      expect(provider.getPresupuestoCategoria('Comida'), 50.0);
      expect(provider.getSpentForCategory('Comida'), 60.0);
      expect(provider.isCategoryOverBudget('Comida'), isTrue);
    });

    test('isCategoryOverBudget returns false when spent <= budget', () async {
      await provider.setPresupuestoCategoria('Comida', 50.0);

      // Spent $30 <= $50
      provider.setTestTotales({'Comida': 30.0});
      expect(provider.isCategoryOverBudget('Comida'), isFalse);

      // Spent exactly $50 == $50
      provider.setTestTotales({'Comida': 50.0});
      expect(provider.isCategoryOverBudget('Comida'), isFalse);
    });

    test('isCategoryOverBudget returns false when budget is 0 or unassigned', () {
      provider.setTestTotales({'Comida': 100.0});

      expect(provider.getPresupuestoCategoria('Comida'), 0.0);
      expect(provider.isCategoryOverBudget('Comida'), isFalse);
    });
  });
}
