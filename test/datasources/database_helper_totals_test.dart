import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';

class MockTotalsDatabaseHelper extends DatabaseHelper {
  final List<Map<String, dynamic>> _gastos = [];
  final Map<int, List<Map<String, dynamic>>> _items = {};

  MockTotalsDatabaseHelper() : super.test();

  void seedGasto({
    required int id,
    required String fecha,
    required String moneda,
    required int totalOriginal,
    required int totalUsd,
    required double tasaCambio,
    int? totalUsdt,
    double? tasaUsdt,
    String categoria = 'Otros',
    List<Map<String, dynamic>> items = const [],
  }) {
    _gastos.add({
      'id': id,
      'fecha': fecha,
      'moneda': moneda,
      'total_original': totalOriginal,
      'total_usd': totalUsd,
      'total_usdt': totalUsdt,
      'tasa_cambio': tasaCambio,
      'tasa_usdt': tasaUsdt,
      'categoria': categoria,
      'eliminado_en': null,
    });
    _items[id] = items;
  }

  @override
  Future<Map<String, double>> getMonthlyTotals(int year, int month) async {
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr';

    final rows = _gastos.where((g) => (g['fecha'] as String).startsWith(pattern)).toList();

    double sumUsd = 0.0;
    double sumVes = 0.0;
    double sumUsdt = 0.0;

    for (final r in rows) {
      final moneda = (r['moneda'] as String?) ?? 'VES';
      final totalOrigInt = (r['total_original'] as num?)?.toInt() ?? 0;
      final totalUsdInt = (r['total_usd'] as num?)?.toInt() ?? 0;
      final totalUsdtInt = (r['total_usdt'] as num?)?.toInt();
      final tasa = (r['tasa_cambio'] as num?)?.toDouble() ?? 1.0;
      final tasaUsdt = (r['tasa_usdt'] as num?)?.toDouble();

      final double totalOrig = totalOrigInt / 100.0;
      final double totalUsd = totalUsdInt / 100.0;

      final double totalUsdt;
      if (totalUsdtInt != null && totalUsdtInt > 0) {
        totalUsdt = totalUsdtInt / 100.0;
      } else if (moneda != 'VES') {
        totalUsdt = totalUsd;
      } else if (tasaUsdt != null && tasaUsdt > 0) {
        totalUsdt = totalOrig / tasaUsdt;
      } else {
        totalUsdt = totalUsd;
      }

      sumUsd += totalUsd;
      sumUsdt += totalUsdt;

      if (moneda == 'VES') {
        sumVes += totalOrig;
      } else {
        sumVes += (totalUsd * (tasa > 0 ? tasa : 1.0));
      }
    }

    return {
      'USD': sumUsd,
      'VES': sumVes,
      'USDT': sumUsdt,
    };
  }

  @override
  Future<Map<String, double>> getCategoryTotals(int year, int month, {String moneda = 'USD'}) async {
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr';

    final gastosRows = _gastos.where((g) => (g['fecha'] as String).startsWith(pattern)).toList();
    final Map<String, double> categoryMap = {};

    for (final g in gastosRows) {
      final gastoId = g['id'] as int;
      final gastoMoneda = (g['moneda'] as String?) ?? 'VES';
      final totalOrig = ((g['total_original'] as num?)?.toInt() ?? 0) / 100.0;
      final totalUsd = ((g['total_usd'] as num?)?.toInt() ?? 0) / 100.0;
      final totalUsdtInt = (g['total_usdt'] as num?)?.toInt();
      final tasa = (g['tasa_cambio'] as num?)?.toDouble() ?? 1.0;
      final tasaUsdt = (g['tasa_usdt'] as num?)?.toDouble();
      final gastoCat = (g['categoria'] as String?) ?? 'Otros';

      final double totalUsdt;
      if (totalUsdtInt != null && totalUsdtInt > 0) {
        totalUsdt = totalUsdtInt / 100.0;
      } else if (gastoMoneda != 'VES') {
        totalUsdt = totalUsd;
      } else if (tasaUsdt != null && tasaUsdt > 0) {
        totalUsdt = totalOrig / tasaUsdt;
      } else {
        totalUsdt = totalUsd;
      }

      final double targetTotal;
      if (moneda == 'VES') {
        targetTotal = (gastoMoneda == 'VES' ? totalOrig : totalUsd * (tasa > 0 ? tasa : 1.0));
      } else if (moneda == 'USDT') {
        targetTotal = totalUsdt;
      } else {
        targetTotal = totalUsd;
      }

      final items = _items[gastoId] ?? [];

      if (items.isEmpty) {
        categoryMap[gastoCat] = (categoryMap[gastoCat] ?? 0.0) + targetTotal;
      } else {
        double sumItems = 0.0;
        for (final item in items) {
          sumItems += ((item['total'] as num?)?.toInt() ?? 0) / 100.0;
        }

        for (final item in items) {
          final cat = (item['categoria'] as String?) ?? gastoCat;
          final itemTotal = ((item['total'] as num?)?.toInt() ?? 0) / 100.0;
          final ratio = sumItems > 0 ? (itemTotal / sumItems) : (1.0 / items.length);
          final allocated = ratio * targetTotal;
          categoryMap[cat] = (categoryMap[cat] ?? 0.0) + allocated;
        }
      }
    }

    return categoryMap;
  }
}

void main() {
  group('Determinismo y consistencia matemática de totales en Bolívares y Dólares', () {
    late MockTotalsDatabaseHelper helper;

    setUp(() {
      helper = MockTotalsDatabaseHelper();

      // Gasto 1: En Bolívares (Factura de mercado de Bs. 50.000,00 a tasa 800 -> $62.50, a tasa USDT 1000 -> 50.00 USDT)
      helper.seedGasto(
        id: 1,
        fecha: '2026-10-02',
        moneda: 'VES',
        totalOriginal: 5000000, // Bs. 50.000,00
        totalUsd: 6250,        // $62.50
        totalUsdt: 5000,       // 50.00 USDT
        tasaCambio: 800.0,
        tasaUsdt: 1000.0,
        categoria: 'Alimentación',
        items: [
          {'categoria': 'Alimentación', 'total': 3000000}, // Bs. 30.000
          {'categoria': 'Higiene', 'total': 2000000},      // Bs. 20.000
        ],
      );

      // Gasto 2: En Dólares ($10.00 pagados en efectivo o chat, tasa registrada ese día: 850 -> Bs. 8.500, paridad 1:1 en USDT)
      helper.seedGasto(
        id: 2,
        fecha: '2026-10-03',
        moneda: 'USD',
        totalOriginal: 1000,   // $10.00
        totalUsd: 1000,        // $10.00
        totalUsdt: 1000,       // 10.00 USDT
        tasaCambio: 850.0,
        categoria: 'Transporte',
        items: [
          {'categoria': 'Transporte', 'total': 1000}, // $10.00
        ],
      );

      // Gasto 3: En Bolívares sin desglose de ítems (Pago de servicios Bs. 5.960,47 a tasa 851.49 -> $7.00, fallback totalUsdt = 700)
      helper.seedGasto(
        id: 3,
        fecha: '2026-10-04',
        moneda: 'VES',
        totalOriginal: 596047, // Bs. 5.960,47
        totalUsd: 700,         // $7.00
        tasaCambio: 851.49,
        categoria: 'Servicios',
        items: [], // Sin ítems detallados
      );
    });

    test('getMonthlyTotals suma exactamente todas las compras en Bs y en USD sin omitir ninguna', () async {
      final totales = await helper.getMonthlyTotals(2026, 10);

      // Total USD = 62.50 + 10.00 + 7.00 = 79.50
      expect(totales['USD'], closeTo(79.50, 0.001));

      // Total VES = 50.000 + 8.500 (de los $10 a 850) + 5.960.47 = 64.460.47
      expect(totales['VES'], closeTo(64460.47, 0.01));

      // Total USDT = 50.00 + 10.00 + 7.00 = 67.00
      expect(totales['USDT'], closeTo(67.00, 0.001));
    });

    test('getCategoryTotals en VES suma exactamente lo mismo que el Total Gastado del mes', () async {
      final monthly = await helper.getMonthlyTotals(2026, 10);
      final categoriesVes = await helper.getCategoryTotals(2026, 10, moneda: 'VES');

      final sumCategories = categoriesVes.values.fold(0.0, (sum, val) => sum + val);

      // La suma de las categorías en Bs debe coincidir exactamente con el Total Gastado en Bs
      expect(sumCategories, closeTo(monthly['VES']!, 0.01));
      expect(sumCategories, closeTo(64460.47, 0.01));

      // Verificamos montos por categoría
      // Alimentación: 60% de Bs. 50.000 = 30.000
      expect(categoriesVes['Alimentación'], closeTo(30000.0, 0.01));
      // Higiene: 40% de Bs. 50.000 = 20.000
      expect(categoriesVes['Higiene'], closeTo(20000.0, 0.01));
      // Transporte: 100% de $10 * 850 = 8.500
      expect(categoriesVes['Transporte'], closeTo(8500.0, 0.01));
      // Servicios (sin ítems): 100% = 5.960,47
      expect(categoriesVes['Servicios'], closeTo(5960.47, 0.01));
    });

    test('getCategoryTotals en USD suma exactamente lo mismo que el Total Gastado en USD', () async {
      final monthly = await helper.getMonthlyTotals(2026, 10);
      final categoriesUsd = await helper.getCategoryTotals(2026, 10, moneda: 'USD');

      final sumCategories = categoriesUsd.values.fold(0.0, (sum, val) => sum + val);

      expect(sumCategories, closeTo(monthly['USD']!, 0.001));
      expect(sumCategories, closeTo(79.50, 0.001));
    });

    test('getCategoryTotals en USDT suma exactamente lo mismo que el Total Gastado en USDT y refleja lente P2P', () async {
      final monthly = await helper.getMonthlyTotals(2026, 10);
      final categoriesUsdt = await helper.getCategoryTotals(2026, 10, moneda: 'USDT');

      final sumCategories = categoriesUsdt.values.fold(0.0, (sum, val) => sum + val);

      expect(sumCategories, closeTo(monthly['USDT']!, 0.001));
      expect(sumCategories, closeTo(67.00, 0.001));

      // Alimentación: 60% de 50.00 USDT = 30.00 USDT
      expect(categoriesUsdt['Alimentación'], closeTo(30.00, 0.01));
      // Higiene: 40% de 50.00 USDT = 20.00 USDT
      expect(categoriesUsdt['Higiene'], closeTo(20.00, 0.01));
      // Transporte: 100% de $10 USD = 10.00 USDT (paridad 1:1)
      expect(categoriesUsdt['Transporte'], closeTo(10.00, 0.01));
      // Servicios: 100% de 7.00 USDT = 7.00 USDT
      expect(categoriesUsdt['Servicios'], closeTo(7.00, 0.01));
    });
  });
}
