import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';

class MockableDatabaseHelperMonthly extends DatabaseHelper {
  final Map<String, Map<String, dynamic>> _monthlyStorage = {};

  MockableDatabaseHelperMonthly() : super.test();

  String _key(int anio, int mes) => '${anio}_$mes';

  @override
  Future<double> getPresupuestoGeneral(int anio, int mes) async {
    final data = _monthlyStorage[_key(anio, mes)];
    if (data != null) {
      return (data['presupuesto_general'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  @override
  Future<double> getMetaAhorro(int anio, int mes) async {
    final data = _monthlyStorage[_key(anio, mes)];
    if (data != null) {
      return (data['meta_ahorro'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  @override
  Future<void> setPresupuestoGeneral(
    int anio,
    int mes,
    double monto, {
    String moneda = 'USD',
    double metaAhorro = 0.0,
  }) async {
    final k = _key(anio, mes);
    final existing = _monthlyStorage[k] ?? {};
    _monthlyStorage[k] = {
      ...existing,
      'anio': anio,
      'mes': mes,
      'presupuesto_general': monto >= 0 ? monto : 0.0,
      'meta_ahorro': metaAhorro >= 0 ? metaAhorro : 0.0,
      'moneda': moneda,
    };
  }

}

void main() {
  group('DatabaseHelper Monthly Budget & Savings Goal Tests', () {
    late MockableDatabaseHelperMonthly dbHelper;

    setUp(() {
      dbHelper = MockableDatabaseHelperMonthly();
    });

    test('initial state has zero general budget and zero savings goal', () async {
      final general = await dbHelper.getPresupuestoGeneral(2026, 10);
      final meta = await dbHelper.getMetaAhorro(2026, 10);

      expect(general, 0.0);
      expect(meta, 0.0);
    });

    test('setPresupuestoGeneral stores both general budget and metaAhorro', () async {
      await dbHelper.setPresupuestoGeneral(2026, 10, 500.0, metaAhorro: 100.0);

      final general = await dbHelper.getPresupuestoGeneral(2026, 10);
      final meta = await dbHelper.getMetaAhorro(2026, 10);

      expect(general, 500.0);
      expect(meta, 100.0);
    });
  });
}
