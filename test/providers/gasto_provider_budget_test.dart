import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';

class MockGastoProvider extends GastoProvider {
  final Map<String, double> _testTotales = {};
  final Map<String, double> _testTotalesVes = {};
  final Map<String, double> _testPresupuestos = {};
  double _testPresupuestoGeneral = 0.0;
  String _testMonedaPresupuesto = 'USD';

  MockGastoProvider({
    Map<String, double>? initialTotales,
    Map<String, double>? initialTotalesVes,
    Map<String, double>? initialPresupuestos,
    double initialPresupuestoGeneral = 0.0,
    String initialMonedaPresupuesto = 'USD',
  })  : _testPresupuestoGeneral = initialPresupuestoGeneral,
        _testMonedaPresupuesto = initialMonedaPresupuesto {
    if (initialTotales != null) _testTotales.addAll(initialTotales);
    if (initialTotalesVes != null) _testTotalesVes.addAll(initialTotalesVes);
    if (initialPresupuestos != null) _testPresupuestos.addAll(initialPresupuestos);
  }

  void setTestTotales(Map<String, double> totales) {
    _testTotales.clear();
    _testTotales.addAll(totales);
    notifyListeners();
  }

  void setTestTotalesVes(Map<String, double> totales) {
    _testTotalesVes.clear();
    _testTotalesVes.addAll(totales);
    notifyListeners();
  }

  void setTestMonedaPresupuesto(String moneda) {
    _testMonedaPresupuesto = moneda;
    notifyListeners();
  }

  void setTestPresupuestos(Map<String, double> presupuestos) {
    _testPresupuestos.clear();
    _testPresupuestos.addAll(presupuestos);
    notifyListeners();
  }

  @override
  String get monedaPresupuesto => _testMonedaPresupuesto;

  @override
  double get presupuestoGeneral => _testPresupuestoGeneral;

  @override
  Map<String, double> get totalesPorCategoria => _testTotales;

  @override
  Map<String, double> get totalesPorCategoriaVes =>
      _testTotalesVes.isNotEmpty ? _testTotalesVes : _testTotales;

  @override
  Map<String, double> get presupuestosPorCategoria => _testPresupuestos;

  @override
  Future<bool> setPresupuestoGeneral(double monto, {String moneda = 'USD'}) async {
    _testPresupuestoGeneral = monto;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> setPresupuestoCategoria(String categoria, double presupuesto, {String? moneda}) async {
    if (presupuesto <= 0) {
      _testPresupuestos.remove(categoria);
    } else {
      _testPresupuestos[categoria] = presupuesto;
    }
    notifyListeners();
    return true;
  }

  @override
  Future<bool> guardarTodoElPresupuesto(
    double general,
    Map<String, double> categorias, {
    String moneda = 'USD',
    double metaAhorro = 0.0,
  }) async {
    _testPresupuestoGeneral = general;
    _testPresupuestos.clear();
    categorias.forEach((k, v) {
      if (v > 0) _testPresupuestos[k] = v;
    });
    notifyListeners();
    return true;
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
  double getSpentForCategory(String categoria, {String? moneda}) {
    final isVes = (moneda?.toUpperCase() == 'VES');
    final map = isVes ? totalesPorCategoriaVes : _testTotales;
    if (map.containsKey(categoria)) {
      return map[categoria]!;
    }
    for (final entry in map.entries) {
      if (entry.key.toLowerCase().trim() == categoria.toLowerCase().trim()) {
        return entry.value;
      }
    }
    return 0.0;
  }

  @override
  bool isCategoryOverBudget(String categoria, {String? moneda}) {
    final budget = getPresupuestoCategoria(categoria);
    if (budget <= 0) return false;
    final effectiveMoneda = moneda ?? monedaPresupuesto;
    final spent = getSpentForCategory(categoria, moneda: effectiveMoneda);
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

    test('budget mutators return true on success', () async {
      final genOk = await provider.setPresupuestoGeneral(400.0);
      expect(genOk, isTrue);

      final catOk = await provider.setPresupuestoCategoria('Alimentacion', 150.0);
      expect(catOk, isTrue);

      final allOk = await provider.guardarTodoElPresupuesto(600.0, {'Alimentacion': 250.0});
      expect(allOk, isTrue);
    });

    test('getSpentForCategory returns USD by default and VES when requested', () {
      provider.setTestTotales({'Alimentacion': 25.0});
      provider.setTestTotalesVes({'Alimentacion': 1000.0});

      expect(provider.getSpentForCategory('Alimentacion'), 25.0);
      expect(provider.getSpentForCategory('Alimentacion', moneda: 'USD'), 25.0);
      expect(provider.getSpentForCategory('Alimentacion', moneda: 'VES'), 1000.0);
    });

    test('isCategoryOverBudget works correctly in VES when budget is set in VES', () async {
      provider.setTestMonedaPresupuesto('VES');
      await provider.setPresupuestoCategoria('Alimentacion', 4000.0, moneda: 'VES');
      provider.setTestTotales({'Alimentacion': 50.0});
      provider.setTestTotalesVes({'Alimentacion': 4500.0});

      expect(provider.getPresupuestoCategoria('Alimentacion'), 4000.0);
      expect(provider.getSpentForCategory('Alimentacion', moneda: 'VES'), 4500.0);
      expect(provider.isCategoryOverBudget('Alimentacion'), isTrue);

      provider.setTestTotalesVes({'Alimentacion': 3500.0});
      expect(provider.isCategoryOverBudget('Alimentacion'), isFalse);
    });

    test('isCategoryOverBudget works correctly with explicit moneda parameter', () async {
      await provider.setPresupuestoCategoria('Alimentacion', 1000.0);
      provider.setTestTotales({'Alimentacion': 20.0});
      provider.setTestTotalesVes({'Alimentacion': 1200.0});

      expect(provider.isCategoryOverBudget('Alimentacion', moneda: 'VES'), isTrue);
      expect(provider.isCategoryOverBudget('Alimentacion', moneda: 'USD'), isFalse);
    });
  });
}
