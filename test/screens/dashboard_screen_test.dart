import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/dashboard_screen.dart';
import 'package:gastoscan_ai/ui/widgets/category_chart.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  final List<Map<String, dynamic>> pending = [];
  final List<Map<String, dynamic>> ready = [];

  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => List.from(pending);

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => List.from(ready);
}

class FakeGastoProvider extends GastoProvider {
  Map<String, double> _customTotales = {};
  Map<String, double> _customTotalesVes = {};
  Map<String, double> _customPresupuestos = {};
  double _customPresupuestoGeneral = 0.0;
  String _customMonedaPresupuesto = 'USD';

  void setTotales(Map<String, double> totales) {
    _customTotales = totales;
    notifyListeners();
  }

  void setTotalesVes(Map<String, double> totales) {
    _customTotalesVes = totales;
    notifyListeners();
  }

  void setPresupuestos(Map<String, double> presupuestos) {
    _customPresupuestos = presupuestos;
    notifyListeners();
  }

  void setPresupuestoGeneralVal(double val) {
    _customPresupuestoGeneral = val;
    notifyListeners();
  }

  void setMonedaPresupuestoVal(String moneda) {
    _customMonedaPresupuesto = moneda;
    notifyListeners();
  }

  @override
  Map<String, double> get totalesPorCategoria => _customTotales;

  @override
  Map<String, double> get totalesPorCategoriaVes =>
      _customTotalesVes.isNotEmpty ? _customTotalesVes : _customTotales;

  @override
  Map<String, double> get presupuestosPorCategoria => _customPresupuestos;

  @override
  double get presupuestoGeneral => _customPresupuestoGeneral;

  @override
  String get monedaPresupuesto => _customMonedaPresupuesto;

  @override
  double getSpentForCategory(String categoria, {String? moneda}) {
    final isVes = (moneda?.toUpperCase() == 'VES');
    final map = isVes ? totalesPorCategoriaVes : _customTotales;
    return map[categoria] ?? 0.0;
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

class FakeSettingsProvider extends SettingsProvider {
  String _customMoneda = 'USD';
  double _customTasa = 40.0;

  void setMonedaPrincipal(String m) {
    _customMoneda = m;
    notifyListeners();
  }

  void setTasaCambioVesUsd(double t) {
    _customTasa = t;
    notifyListeners();
  }

  @override
  String get monedaPrincipal => _customMoneda;

  @override
  double get tasaCambioVesUsd => _customTasa;

  @override
  Future<void> loadSettings() async {}
}

void main() {
  group('DashboardScreen Scan Queue Banners Tests', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProvider gastoProvider;
    late FakeSettingsProvider settingsProvider;

    setUp(() {
      fakeDb = FakeDatabaseHelper();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      gastoProvider = FakeGastoProvider();
      settingsProvider = FakeSettingsProvider();
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      );
    }

    testWidgets('does not show local processing banner in DashboardScreen (delegated to GlobalScanQueueBanner)', (tester) async {
      scanQueueProvider.setPendingItems([
        {'id': 1, 'image_path': '/img/factura1.jpg'},
        {'id': 2, 'image_path': '/img/factura2.jpg'},
      ]);
      scanQueueProvider.setProcessing(true);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Confirma que DashboardScreen no duplica el banner
      expect(find.byKey(const Key('processing_queue_banner')), findsNothing);
    });

    testWidgets('displays ready queue item card when items are ready for review', (tester) async {
      scanQueueProvider.setReadyItems([
        {
          'id': 1,
          'image_path': '/img/factura1.jpg',
          'extracted_data': '{"comercio": "Central Madeirense", "fecha": "2026-09-15", "moneda": "USD", "totalOriginal": 25.5, "items": []}',
        },
      ]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('pending_1')), findsOneWidget);
      expect(find.textContaining('Central Madeirense'), findsOneWidget);
    });

    testWidgets('displays "Por revisar" badge when pending item has zero total', (tester) async {
      scanQueueProvider.setReadyItems([
        {
          'id': 2,
          'image_path': '/img/factura2.jpg',
          'extracted_data': '{"comercio": "Panaderia El Trigo", "fecha": "2026-09-15", "moneda": "USD", "totalOriginal": 0.0, "items": []}',
        },
      ]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('pending_2')), findsOneWidget);
      expect(find.text('Por revisar'), findsWidgets);
    });

    testWidgets('CategoryChart in Dashboard expresses budgets in VES when viewing in VES', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1200, 3000);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() {
        tester.binding.window.clearPhysicalSizeTestValue();
        tester.binding.window.clearDevicePixelRatioTestValue();
      });

      settingsProvider.setMonedaPrincipal('VES');
      settingsProvider.setTasaCambioVesUsd(40.0);
      gastoProvider.setMonedaPresupuestoVal('USD');
      gastoProvider.setPresupuestos({'Alimentacion': 50.0});
      gastoProvider.setPresupuestoGeneralVal(100.0);
      gastoProvider.setTotales({'Alimentacion': 25.0});
      gastoProvider.setTotalesVes({'Alimentacion': 1000.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final chartFinder = find.byType(CategoryChart);
      expect(chartFinder, findsOneWidget);
      final CategoryChart chart = tester.widget(chartFinder);

      expect(chart.monedaPrincipal, 'VES');
      expect(chart.categoryBudgets['Alimentacion'], 2000.0);
      expect(chart.presupuestoGeneral, 4000.0);
      expect(chart.categoryTotals['Alimentacion'], 1000.0);
    });

    testWidgets('CategoryChart in Dashboard keeps USD when viewing in USD', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1200, 3000);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() {
        tester.binding.window.clearPhysicalSizeTestValue();
        tester.binding.window.clearDevicePixelRatioTestValue();
      });

      settingsProvider.setMonedaPrincipal('USD');
      settingsProvider.setTasaCambioVesUsd(40.0);
      gastoProvider.setMonedaPresupuestoVal('USD');
      gastoProvider.setPresupuestos({'Alimentacion': 50.0});
      gastoProvider.setPresupuestoGeneralVal(100.0);
      gastoProvider.setTotales({'Alimentacion': 25.0});
      gastoProvider.setTotalesVes({'Alimentacion': 1000.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final chartFinder = find.byType(CategoryChart);
      expect(chartFinder, findsOneWidget);
      final CategoryChart chart = tester.widget(chartFinder);

      expect(chart.monedaPrincipal, 'USD');
      expect(chart.categoryBudgets['Alimentacion'], 50.0);
      expect(chart.presupuestoGeneral, 100.0);
      expect(chart.categoryTotals['Alimentacion'], 25.0);
    });
  });
}
