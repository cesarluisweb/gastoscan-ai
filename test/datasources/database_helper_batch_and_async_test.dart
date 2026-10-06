import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/datasources/remote/gemini_service.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/repositories/gasto_repository.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';

class MockBatchDatabaseHelper extends DatabaseHelper {
  final Map<int, Map<String, dynamic>> gastos = {};
  int softDeleteCalls = 0;
  int lastSoftDeletedId = -1;

  MockBatchDatabaseHelper() : super.test();

  @override
  Future<int> softDeleteGasto(int id) async {
    softDeleteCalls++;
    lastSoftDeletedId = id;
    if (gastos.containsKey(id)) {
      gastos[id]!['eliminado_en'] = DateTime.now().toIso8601String();
      gastos[id]!['synced'] = 0;
      return 1;
    }
    return 0;
  }
}

class MockFailingGastoRepository extends GastoRepository {
  MockFailingGastoRepository() : super(dbHelper: DatabaseHelper.test());

  @override
  Future<void> guardarPresupuestoGeneralMes(
    int anio,
    int mes,
    double monto, {
    String moneda = 'USD',
    double metaAhorro = 0.0,
  }) async {
    throw Exception('SocketException: Failed host lookup');
  }

  @override
  Future<void> guardarPresupuestosCategoriasMes(
    int anio,
    int mes,
    Map<String, double> presupuestos, {
    String moneda = 'USD',
  }) async {
    throw Exception('DatabaseException: disk I/O error');
  }
}

class MockMemoryBudgetRepository extends GastoRepository {
  final Map<String, double> _prevBudgets;
  final double _prevGeneral;

  MockMemoryBudgetRepository({
    double prevGeneral = 500.0,
    Map<String, double>? prevBudgets,
  })  : _prevGeneral = prevGeneral,
        _prevBudgets = prevBudgets ?? {'Comida': 200.0},
        super(dbHelper: DatabaseHelper.test());

  @override
  Future<double> obtenerPresupuestoGeneralMes(int anio, int mes) async {
    // Current month has 0.0, previous month has _prevGeneral
    if (anio == 2026 && mes == 10) return 0.0;
    if (anio == 2026 && mes == 9) return _prevGeneral;
    return 0.0;
  }

  @override
  Future<double> obtenerMetaAhorroMes(int anio, int mes) async {
    if (anio == 2026 && mes == 10) return 0.0;
    if (anio == 2026 && mes == 9) return 100.0;
    return 0.0;
  }

  @override
  Future<String> obtenerMonedaPresupuestoGeneralMes(int anio, int mes) async => 'USD';

  @override
  Future<Map<String, double>> obtenerPresupuestosCategoriasMes(int anio, int mes) async {
    if (anio == 2026 && mes == 10) return {};
    if (anio == 2026 && mes == 9) return Map.from(_prevBudgets);
    return {};
  }

  @override
  Future<Map<String, double>> obtenerTotalesMes(int year, int month) async => {'USD': 0.0, 'VES': 0.0};

  @override
  Future<Map<String, double>> obtenerTotalesPorCategoria(int year, int month, {String moneda = 'USD'}) async => {};

  @override
  Future<List<GastoModel>> obtenerGastosPorMes(int year, int month) async => [];
}

void main() {
  group('Bloque 2: Database & Async Unit Tests', () {
    test('GastoRepository.eliminarGasto calls softDeleteGasto directly', () async {
      final mockDb = MockBatchDatabaseHelper();
      mockDb.gastos[42] = {'id': 42, 'comercio': 'Farmatodo'};
      final repo = GastoRepository(dbHelper: mockDb);

      final result = await repo.eliminarGasto(42);

      expect(result, 1);
      expect(mockDb.softDeleteCalls, 1);
      expect(mockDb.lastSoftDeletedId, 42);
      expect(mockDb.gastos[42]!['eliminado_en'], isNotNull);
      expect(mockDb.gastos[42]!['synced'], 0);
    });

    test('GastoProvider adopts previous month budget in memory when month is unconfigured', () async {
      final memoryRepo = MockMemoryBudgetRepository(
        prevGeneral: 450.0,
        prevBudgets: {'Mercado': 200.0},
      );
      final provider = GastoProvider(repository: memoryRepo, autoLoad: false);

      provider.cambiarMes(2026, 10);
      await provider.cargarDatos();

      expect(provider.presupuestoGeneral, 450.0);
      expect(provider.metaAhorro, 100.0);
      expect(provider.presupuestosPorCategoria['Mercado'], 200.0);
    });

    test('GastoProvider mutators return false and map friendly error on failure', () async {
      final failingRepo = MockFailingGastoRepository();
      final provider = GastoProvider(repository: failingRepo, autoLoad: false);

      final success = await provider.guardarTodoElPresupuesto(
        300.0,
        {'Transporte': 50.0},
      );

      expect(success, isFalse);
      expect(provider.errorMessage, isNotNull);
      expect(
        provider.errorMessage!.contains('No hay conexión a internet') ||
            provider.errorMessage!.contains('almacenamiento local') ||
            provider.errorMessage!.contains('base de datos'),
        isTrue,
      );
    });

    test('GeminiService.parseVoiceExpense throws when speech contains no amounts', () async {
      final geminiService = GeminiService();

      expect(
        () async => await geminiService.parseVoiceExpense('compré varias cosas en la panadería'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
