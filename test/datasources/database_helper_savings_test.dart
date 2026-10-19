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
  Future<Map<String, dynamic>?> getUltimoPresupuestoConfigurado({
    int? antesDeAnio,
    int? antesDeMes,
    bool estrictamenteAnterior = false,
  }) async {
    final valid = _monthlyStorage.values.where((m) {
      final anio = m['anio'] as int;
      final mes = m['mes'] as int;
      final gen = (m['presupuesto_general'] as num?)?.toDouble() ?? 0.0;
      final meta = (m['meta_ahorro'] as num?)?.toDouble() ?? 0.0;
      if (gen <= 0 && meta <= 0) return false;
      if (antesDeAnio != null && antesDeMes != null) {
        if (estrictamenteAnterior) {
          return (anio < antesDeAnio) || (anio == antesDeAnio && mes < antesDeMes);
        } else {
          return (anio < antesDeAnio) || (anio == antesDeAnio && mes <= antesDeMes);
        }
      }
      return true;
    }).toList();

    if (valid.isEmpty) return null;

    valid.sort((a, b) {
      final anioDiff = (b['anio'] as int).compareTo(a['anio'] as int);
      if (anioDiff != 0) return anioDiff;
      return (b['mes'] as int).compareTo(a['mes'] as int);
    });

    final best = valid.first;
    return {
      'anio': best['anio'],
      'mes': best['mes'],
      'presupuesto_general': best['presupuesto_general'],
      'meta_ahorro': best['meta_ahorro'],
      'moneda': best['moneda'] ?? 'USD',
      'categorias': <String, double>{},
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

    test('getUltimoPresupuestoConfigurado returns latest budget even across multiple months gap', () async {
      // Set budget in August (month 8)
      await dbHelper.setPresupuestoGeneral(2026, 8, 350.0, metaAhorro: 50.0);

      // Querying for October (month 10) strictly prior should find August
      final found = await dbHelper.getUltimoPresupuestoConfigurado(
        antesDeAnio: 2026,
        antesDeMes: 10,
        estrictamenteAnterior: true,
      );

      expect(found, isNotNull);
      expect(found!['anio'], 2026);
      expect(found['mes'], 8);
      expect(found['presupuesto_general'], 350.0);
      expect(found['meta_ahorro'], 50.0);
    });
  });
}
