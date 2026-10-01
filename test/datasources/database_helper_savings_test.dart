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

  @override
  Future<bool> copiarPresupuestosMesAnteriorSiVacio(int anio, int mes) async {
    final currentGeneral = await getPresupuestoGeneral(anio, mes);
    final currentMeta = await getMetaAhorro(anio, mes);

    if (currentGeneral > 0 || currentMeta > 0) {
      return false;
    }

    final int prevMes = mes == 1 ? 12 : mes - 1;
    final int prevAnio = mes == 1 ? anio - 1 : anio;

    final prevGeneral = await getPresupuestoGeneral(prevAnio, prevMes);
    final prevMeta = await getMetaAhorro(prevAnio, prevMes);

    if (prevGeneral > 0 || prevMeta > 0) {
      await setPresupuestoGeneral(anio, mes, prevGeneral, metaAhorro: prevMeta);
      return true;
    }
    return false;
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

    test('copiarPresupuestosMesAnteriorSiVacio copies both general budget and metaAhorro', () async {
      // Configurar mes previo (Septiembre 2026)
      await dbHelper.setPresupuestoGeneral(2026, 9, 600.0, metaAhorro: 150.0);

      // Copiar a Octubre 2026 (vacio)
      final copied = await dbHelper.copiarPresupuestosMesAnteriorSiVacio(2026, 10);
      expect(copied, isTrue);

      final generalOct = await dbHelper.getPresupuestoGeneral(2026, 10);
      final metaOct = await dbHelper.getMetaAhorro(2026, 10);

      expect(generalOct, 600.0);
      expect(metaOct, 150.0);
    });

    test('copiarPresupuestosMesAnteriorSiVacio does not overwrite existing records', () async {
      await dbHelper.setPresupuestoGeneral(2026, 9, 600.0, metaAhorro: 150.0);
      await dbHelper.setPresupuestoGeneral(2026, 10, 400.0, metaAhorro: 50.0);

      final copied = await dbHelper.copiarPresupuestosMesAnteriorSiVacio(2026, 10);
      expect(copied, isFalse);

      final generalOct = await dbHelper.getPresupuestoGeneral(2026, 10);
      final metaOct = await dbHelper.getMetaAhorro(2026, 10);

      expect(generalOct, 400.0);
      expect(metaOct, 50.0);
    });
  });
}
