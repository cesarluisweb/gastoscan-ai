import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/core/constants/app_colors.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/dashboard_screen.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];
}

class FakeGastoProvider extends GastoProvider {
  List<GastoModel> _customGastos = [];
  Map<String, double> _customTotales = {};
  Map<String, double> _customPresupuestos = {};
  double _customTotalUsd = 0.0;
  double _customTotalVes = 0.0;

  FakeGastoProvider({
    List<GastoModel>? initialGastos,
    Map<String, double>? initialTotales,
    Map<String, double>? initialPresupuestos,
  }) {
    if (initialGastos != null) _customGastos = initialGastos;
    if (initialTotales != null) {
      _customTotales = initialTotales;
      _customTotalUsd = initialTotales.values.fold(0.0, (a, b) => a + b);
    }
    if (initialPresupuestos != null) _customPresupuestos = initialPresupuestos;
  }

  void setGastos(List<GastoModel> gastos) {
    _customGastos = gastos;
    notifyListeners();
  }

  void setTotalesPorCategoria(Map<String, double> totales) {
    _customTotales = Map.from(totales);
    _customTotalUsd = totales.values.fold(0.0, (a, b) => a + b);
    notifyListeners();
  }

  void setPresupuestosPorCategoria(Map<String, double> presupuestos) {
    _customPresupuestos = Map.from(presupuestos);
    notifyListeners();
  }

  @override
  List<GastoModel> get gastos => _customGastos;

  @override
  Map<String, double> get totalesPorCategoria => _customTotales;

  @override
  Map<String, double> get presupuestosPorCategoria => _customPresupuestos;

  @override
  double get totalMesUsd => _customTotalUsd;

  @override
  double get totalMesVes => _customTotalVes;

  @override
  Future<void> setPresupuestoCategoria(String categoria, double presupuesto) async {
    _customPresupuestos[categoria] = presupuesto;
    notifyListeners();
  }

  @override
  double getPresupuestoCategoria(String categoria) {
    if (_customPresupuestos.containsKey(categoria)) {
      return _customPresupuestos[categoria]!;
    }
    for (final entry in _customPresupuestos.entries) {
      if (entry.key.toLowerCase().trim() == categoria.toLowerCase().trim()) {
        return entry.value;
      }
    }
    return 0.0;
  }

  @override
  double getSpentForCategory(String categoria) {
    if (_customTotales.containsKey(categoria)) {
      return _customTotales[categoria]!;
    }
    for (final entry in _customTotales.entries) {
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

class FakeSettingsProvider extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

void main() {
  group('DashboardScreen Category Budget & Red Excess Alert Tests (R3)', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProvider gastoProvider;
    late FakeSettingsProvider settingsProvider;

    final gastoComida60 = GastoModel(
      id: 1,
      uuid: 'uuid-comida-60',
      fecha: '2026-09-15',
      comercio: 'Restaurante Central',
      moneda: 'USD',
      totalOriginal: 6000,
      totalUsd: 6000,
      categoria: 'Comida',
      creadoEn: '2026-09-15T13:00:00',
      items: [
        ItemGastoModel(
          id: 1,
          gastoId: 1,
          descripcion: 'Almuerzo Familiar',
          cantidad: 1.0,
          precioUnitario: 6000,
          total: 6000,
        ),
      ],
    );

    setUp(() {
      final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.physicalSizeTestValue = const Size(1080, 4000);
      binding.window.devicePixelRatioTestValue = 1.0;

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

    testWidgets(
        'R3 Acceptance Criteria: Asignar \$50 a Comida, y registrar un gasto de \$60 en Comida hace que se dibuje un indicador visual de exceso (color rojo) en la UI de esa categorÃ­a',
        (tester) async {
      // 1. Asignar $50 a Comida
      gastoProvider.setPresupuestosPorCategoria({'Comida': 50.0});

      // 2. Registrar un gasto de $60 en Comida
      gastoProvider.setGastos([gastoComida60]);
      gastoProvider.setTotalesPorCategoria({'Comida': 60.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verificar que la categorÃ­a Comida estÃ© presente en la UI
      expect(find.text('Comida'), findsWidgets);

      // Verificar que se muestre el monto gastado y el presupuesto: $60.00 / $50.00
      expect(find.text('\$60.00 / \$50.00'), findsOneWidget);

      // Verificar que se dibuje el indicador visual de exceso (Key: excess_alert_Comida)
      final excessAlertFinder = find.byKey(const Key('excess_alert_Comida'));
      expect(excessAlertFinder, findsOneWidget);

      // Verificar el texto de la alerta de exceso
      expect(find.textContaining('Presupuesto superado por \$10.00'), findsOneWidget);

      // Verificar que el indicador visual de exceso tenga color rojo (AppColors.error)
      final excessAlertWidget = tester.widget<Container>(excessAlertFinder);
      final boxDecoration = excessAlertWidget.decoration as BoxDecoration;
      expect(boxDecoration.border?.top.color, AppColors.error);

      // Verificar que la barra de progreso de la categorÃ­a Comida sea roja (AppColors.error)
      final progressFinder = find.byKey(const Key('category_progress_Comida'));
      expect(progressFinder, findsOneWidget);
      final progressBar = tester.widget<LinearProgressIndicator>(progressFinder);
      expect(progressBar.color, AppColors.error);
    });

    testWidgets('Category within budget does NOT render the red excess alert', (tester) async {
      // Budget $50 on Comida, but spent is only $30
      gastoProvider.setPresupuestosPorCategoria({'Comida': 50.0});
      gastoProvider.setTotalesPorCategoria({'Comida': 30.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify category is shown
      expect(find.text('Comida'), findsWidgets);
      expect(find.text('\$30.00 / \$50.00'), findsOneWidget);

      // Excess alert should NOT be present
      expect(find.byKey(const Key('excess_alert_Comida')), findsNothing);
      expect(find.textContaining('Presupuesto superado'), findsNothing);

      // Progress bar should NOT be red (AppColors.error)
      final progressFinder = find.byKey(const Key('category_progress_Comida'));
      expect(progressFinder, findsOneWidget);
      final progressBar = tester.widget<LinearProgressIndicator>(progressFinder);
      expect(progressBar.color, isNot(AppColors.error));
    });

    testWidgets('Initial empty state displays category chart silhouette and CategoryChart allows adding budget',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Initial silhouette card should be visible
      expect(find.byKey(const Key('category_chart_silhouette')), findsOneWidget);
      expect(find.text('DistribuciÃ³n por CategorÃ­as'), findsOneWidget);

      // When a category is present, CategoryChart displays and allows setting a budget
      gastoProvider.setTotalesPorCategoria({'Comida': 20.0});
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_category_budget_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('add_category_budget_button')));
      await tester.pumpAndSettle();

      // Verify dialog opened
      expect(find.text('Definir Presupuesto'), findsOneWidget);
      expect(find.byKey(const Key('input_categoria_nombre')), findsOneWidget);
      expect(find.byKey(const Key('input_presupuesto_monto')), findsOneWidget);

      // Enter category name and amount
      await tester.enterText(find.byKey(const Key('input_categoria_nombre')), 'Comida');
      await tester.enterText(find.byKey(const Key('input_presupuesto_monto')), '50');
      await tester.pumpAndSettle();

      // Tap Guardar button
      await tester.tap(find.byKey(const Key('btn_guardar_presupuesto')));
      await tester.pumpAndSettle();

      // Verify budget was registered in provider
      expect(gastoProvider.presupuestosPorCategoria['Comida'], 50.0);
    });

    testWidgets('Editing budget to amount greater than expense clears red excess alert',
        (tester) async {
      // Start with exceeded state: $60 spent vs $50 budget
      gastoProvider.setPresupuestosPorCategoria({'Comida': 50.0});
      gastoProvider.setTotalesPorCategoria({'Comida': 60.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify initial excess alert is present
      expect(find.byKey(const Key('excess_alert_Comida')), findsOneWidget);

      // Tap edit button on Comida item
      final editBtnFinder = find.byKey(const Key('edit_budget_Comida'));
      expect(editBtnFinder, findsOneWidget);
      await tester.tap(editBtnFinder);
      await tester.pumpAndSettle();

      // Verify edit dialog opened for Comida
      expect(find.text('Presupuesto: Comida'), findsOneWidget);

      // Change budget to $80
      await tester.enterText(find.byKey(const Key('input_presupuesto_monto')), '80');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_guardar_presupuesto')));
      await tester.pumpAndSettle();

      // Budget is now $80, spent is $60 ($60 <= $80)
      expect(gastoProvider.presupuestosPorCategoria['Comida'], 80.0);
      expect(find.text('\$60.00 / \$80.00'), findsOneWidget);

      // Red excess alert must no longer be present!
      expect(find.byKey(const Key('excess_alert_Comida')), findsNothing);
    });
  });
}
