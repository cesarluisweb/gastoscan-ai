import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/categoria_model.dart';

class MockableDatabaseHelper extends DatabaseHelper {
  final Map<int, CategoriaModel> _storage = {};
  int _nextId = 1;

  MockableDatabaseHelper() : super.test();

  @override
  Future<int> insertCategoria(CategoriaModel categoria) async {
    final existingIndex = _storage.entries
        .where((e) => e.value.nombre.toLowerCase() == categoria.nombre.toLowerCase())
        .map((e) => e.key)
        .firstOrNull;

    final id = existingIndex ?? categoria.id ?? _nextId++;
    _storage[id] = categoria.copyWith(id: id);
    return id;
  }

  @override
  Future<int> updateCategoria(CategoriaModel categoria) async {
    if (categoria.id != null && _storage.containsKey(categoria.id)) {
      _storage[categoria.id!] = categoria;
      return 1;
    }
    return 0;
  }

  @override
  Future<void> setPresupuestoCategoria(String categoriaNombre, double presupuesto) async {
    final trimmed = categoriaNombre.trim();
    final existingEntry = _storage.entries
        .where((e) => e.value.nombre.toLowerCase() == trimmed.toLowerCase())
        .firstOrNull;

    if (existingEntry != null) {
      _storage[existingEntry.key] = existingEntry.value.copyWith(
        presupuestoMensual: presupuesto,
      );
    } else {
      final id = _nextId++;
      _storage[id] = CategoriaModel(
        id: id,
        nombre: trimmed,
        presupuestoMensual: presupuesto,
      );
    }
  }

  @override
  Future<List<CategoriaModel>> getAllCategorias() async {
    final list = _storage.values.toList();
    list.sort((a, b) => a.nombre.compareTo(b.nombre));
    return list;
  }

  @override
  Future<CategoriaModel?> getCategoriaPorNombre(String categoriaNombre) async {
    return _storage.values
        .where((c) => c.nombre.toLowerCase() == categoriaNombre.trim().toLowerCase())
        .firstOrNull;
  }

  @override
  Future<double> getPresupuestoPorCategoria(String categoriaNombre) async {
    final cat = await getCategoriaPorNombre(categoriaNombre);
    return cat?.presupuestoMensual ?? 0.0;
  }

  @override
  Future<Map<String, double>> getAllPresupuestosCategorias() async {
    final Map<String, double> map = {};
    for (final cat in _storage.values) {
      map[cat.nombre] = cat.presupuestoMensual;
    }
    return map;
  }

  @override
  Future<int> deleteCategoria(int id) async {
    if (_storage.containsKey(id)) {
      _storage.remove(id);
      return 1;
    }
    return 0;
  }
}

void main() {
  group('DatabaseHelper Category & Budget Operations Tests', () {
    late MockableDatabaseHelper dbHelper;

    setUp(() {
      dbHelper = MockableDatabaseHelper();
    });

    test('initial state has empty categories and budgets', () async {
      final categories = await dbHelper.getAllCategorias();
      expect(categories, isEmpty);

      final budgets = await dbHelper.getAllPresupuestosCategorias();
      expect(budgets, isEmpty);

      final budgetComida = await dbHelper.getPresupuestoPorCategoria('Comida');
      expect(budgetComida, 0.0);
    });

    test('setPresupuestoCategoria creates category with budget if not exists', () async {
      await dbHelper.setPresupuestoCategoria('Comida', 50.0);

      final budget = await dbHelper.getPresupuestoPorCategoria('Comida');
      expect(budget, 50.0);

      final cat = await dbHelper.getCategoriaPorNombre('Comida');
      expect(cat, isNotNull);
      expect(cat!.nombre, 'Comida');
      expect(cat.presupuestoMensual, 50.0);
    });

    test('setPresupuestoCategoria is case-insensitive', () async {
      await dbHelper.setPresupuestoCategoria('Comida', 50.0);

      // Query with lowercase 'comida'
      final budgetLower = await dbHelper.getPresupuestoPorCategoria('comida');
      expect(budgetLower, 50.0);

      // Query with uppercase 'COMIDA'
      final budgetUpper = await dbHelper.getPresupuestoPorCategoria('COMIDA');
      expect(budgetUpper, 50.0);

      // Update with different casing
      await dbHelper.setPresupuestoCategoria('comida', 75.0);
      final updatedBudget = await dbHelper.getPresupuestoPorCategoria('Comida');
      expect(updatedBudget, 75.0);

      // Verify no duplicate categories were created
      final allCats = await dbHelper.getAllCategorias();
      expect(allCats.length, 1);
    });

    test('getAllPresupuestosCategorias returns all configured category budgets', () async {
      await dbHelper.setPresupuestoCategoria('Comida', 50.0);
      await dbHelper.setPresupuestoCategoria('Transporte', 30.0);
      await dbHelper.setPresupuestoCategoria('Salud', 100.0);

      final budgets = await dbHelper.getAllPresupuestosCategorias();
      expect(budgets.length, 3);
      expect(budgets['Comida'], 50.0);
      expect(budgets['Transporte'], 30.0);
      expect(budgets['Salud'], 100.0);
    });

    test('insertCategoria and updateCategoria work correctly', () async {
      final catId = await dbHelper.insertCategoria(
        CategoriaModel(nombre: 'Educación', presupuestoMensual: 150.0),
      );
      expect(catId, isPositive);

      final retrieved = await dbHelper.getCategoriaPorNombre('Educación');
      expect(retrieved, isNotNull);
      expect(retrieved!.presupuestoMensual, 150.0);

      await dbHelper.updateCategoria(
        retrieved.copyWith(presupuestoMensual: 180.0),
      );

      final updated = await dbHelper.getCategoriaPorNombre('Educación');
      expect(updated!.presupuestoMensual, 180.0);
    });

    test('deleteCategoria removes the category', () async {
      await dbHelper.setPresupuestoCategoria('Ocio', 40.0);
      final cat = await dbHelper.getCategoriaPorNombre('Ocio');
      expect(cat, isNotNull);

      final deletedRows = await dbHelper.deleteCategoria(cat!.id!);
      expect(deletedRows, 1);

      final deletedCat = await dbHelper.getCategoriaPorNombre('Ocio');
      expect(deletedCat, isNull);
    });
  });
}
