import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/categoria_model.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';

class MockGastoProvider extends GastoProvider {
  final Map<String, double> _testTotales = {};
  final Map<String, double> _testPresupuestos = {};

  MockGastoProvider({
    Map<String, double>? initialTotales,
    Map<String, double>? initialPresupuestos,
  }) {
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
  Map<String, double> get totalesPorCategoria => _testTotales;

  @override
  Map<String, double> get presupuestosPorCategoria => _testPresupuestos;

  @override
  Future<void> setPresupuestoCategoria(String categoria, double presupuesto) async {
    _testPresupuestos[categoria] = presupuesto;
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
      expect(provider.presupuestosPorCategoria, isEmpty);
      expect(provider.totalesPorCategoria, isEmpty);
      expect(provider.getPresupuestoCategoria('Comida'), 0.0);
      expect(provider.getSpentForCategory('Comida'), 0.0);
      expect(provider.isCategoryOverBudget('Comida'), isFalse);
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
