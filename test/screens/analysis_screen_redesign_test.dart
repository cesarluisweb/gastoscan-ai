import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/core/utils/currency_formatter.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/analysis_screen.dart';
import 'package:gastoscan_ai/ui/widgets/currency_lens_dropdown.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];
}

class FakeGastoProvider extends GastoProvider {
  List<GastoModel> _customGastos = [];
  Map<String, double> _customTotalesPorCategoria = {};
  Map<String, double> _customPresupuestosPorCategoria = {};
  double _customPresupuestoGeneral = 0.0;
  double _customMetaAhorro = 0.0;
  int _customMonth = 10;
  int _customYear = 2026;

  @override
  List<GastoModel> get gastos => _customGastos;

  @override
  Map<String, double> get totalesPorCategoria => _customTotalesPorCategoria;

  @override
  Map<String, double> get presupuestosPorCategoria => _customPresupuestosPorCategoria;

  @override
  double get presupuestoGeneral => _customPresupuestoGeneral;

  @override
  double get metaAhorro => _customMetaAhorro;

  @override
  int get selectedMonth => _customMonth;

  @override
  int get selectedYear => _customYear;

  @override
  double get totalMesUsd {
    if (_customTotalesPorCategoria.isNotEmpty) {
      return _customTotalesPorCategoria.values.fold(0.0, (sum, val) => sum + val);
    }
    return _customGastos.fold(0.0, (sum, g) => sum + g.totalUsdDisplay);
  }

  @override
  double get totalMesVes {
    return _customGastos.fold(0.0, (sum, g) => sum + (g.moneda == 'VES' ? g.totalOriginalDisplay : g.totalUsdDisplay * 50.0));
  }

  void setGastos(List<GastoModel> gastos) {
    _customGastos = gastos;
    notifyListeners();
  }

  void setTotalesPorCategoria(Map<String, double> totales) {
    _customTotalesPorCategoria = totales;
    notifyListeners();
  }

  void setPresupuestosPorCategoria(Map<String, double> presupuestos) {
    _customPresupuestosPorCategoria = presupuestos;
    notifyListeners();
  }

  void setPresupuestoGeneralVal(double amount) {
    _customPresupuestoGeneral = amount;
    notifyListeners();
  }

  void setMetaAhorroVal(double amount) {
    _customMetaAhorro = amount;
    notifyListeners();
  }

  void setSelectedDate(int month, int year) {
    _customMonth = month;
    _customYear = year;
    notifyListeners();
  }

  @override
  Future<bool> setPresupuestoCategoria(String categoria, double monto, {String? moneda}) async {
    _customPresupuestosPorCategoria[categoria] = monto;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> setPresupuestoGeneral(double monto, {String moneda = 'USD'}) async {
    _customPresupuestoGeneral = monto;
    notifyListeners();
    return true;
  }

  @override
  Future<void> cargarDatos() async {}
}

class FakeSettingsProvider extends SettingsProvider {
  String _moneda = 'USD';

  @override
  String get monedaPrincipal => _moneda;

  @override
  double get tasaCambioVesUsd => 50.0;

  @override
  double get tasaCambioVesEur => 55.0;

  @override
  double get tasaCambioVesUsdt => 50.0;

  @override
  Future<void> setMonedaPrincipal(String nuevaMoneda) async {
    _moneda = nuevaMoneda;
    notifyListeners();
  }

  @override
  Future<void> loadSettings() async {}
}

void main() {
  group('AnalysisScreen Redesign & Enrichment Tests', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProvider gastoProvider;
    late FakeSettingsProvider settingsProvider;

    final gastoHormiga = GastoModel(
      id: 1,
      uuid: 'uuid-1',
      fecha: '2026-10-05',
      comercio: 'Cafetería El Sol',
      moneda: 'USD',
      totalOriginal: 300,
      totalUsd: 300,
      categoria: 'Alimentación',
      creadoEn: '2026-10-05T09:00:00',
    );

    final gastoMedio = GastoModel(
      id: 2,
      uuid: 'uuid-2',
      fecha: '2026-10-10',
      comercio: 'Farmacia San Juan',
      moneda: 'VES',
      totalOriginal: 75000, // 750 Bs. a tasa 50 = $15
      totalUsd: 1500,
      categoria: 'Salud',
      creadoEn: '2026-10-10T14:00:00',
    );

    final gastoFuerte = GastoModel(
      id: 3,
      uuid: 'uuid-3',
      fecha: '2026-10-15',
      comercio: 'Hipermercado Mayorista',
      moneda: 'USD',
      totalOriginal: 12000,
      totalUsd: 12000,
      categoria: 'Alimentación',
      creadoEn: '2026-10-15T18:00:00',
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
          home: AnalysisScreen(),
        ),
      );
    }

    testWidgets('1. Cabecera global: no tiene pestañas de moneda segmentadas y aloja CurrencyLensDropdown en Tarjeta 1', (tester) async {
      gastoProvider.setPresupuestoGeneralVal(500.0);
      gastoProvider.setGastos([gastoHormiga]);
      gastoProvider.setTotalesPorCategoria({'Alimentación': 3.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Las 4 pestañas de moneda ya NO existen debajo del selector de mes
      expect(find.byKey(const Key('analysis_lens_usd')), findsNothing);
      expect(find.byKey(const Key('analysis_lens_ves')), findsNothing);
      expect(find.byKey(const Key('analysis_lens_usdt')), findsNothing);
      expect(find.byKey(const Key('analysis_lens_eur')), findsNothing);

      // El selector CurrencyLensDropdown está presente dentro de la Tarjeta 1
      final dropdownFinder = find.byType(CurrencyLensDropdown);
      expect(dropdownFinder, findsOneWidget);

      // Cambiar moneda mediante el selector compacto
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lens_switch_ves')));
      await tester.pumpAndSettle();

      expect(settingsProvider.monedaPrincipal, 'VES');
    });

    testWidgets('2. Tarjeta 1: Total gastado en [Mes], límite editable, equivalente secundario y recuadro inferior analítico', (tester) async {
      gastoProvider.setSelectedDate(10, 2026);
      gastoProvider.setPresupuestoGeneralVal(550.0);
      gastoProvider.setMetaAhorroVal(50.0); // Límite = $500, Meta = $50
      gastoProvider.setGastos([gastoHormiga, gastoMedio]); // $3 + $15 = $18
      gastoProvider.setTotalesPorCategoria({'Alimentación': 3.0, 'Salud': 15.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Fila superior: Total gastado en Octubre
      expect(find.text('Total gastado en Octubre'), findsOneWidget);

      // Monto principal y límite en la misma fila: $ 18,00 y de $ 500,00
      expect(
        find.descendant(
          of: find.byKey(const Key('general_budget_card')),
          matching: find.text(CurrencyFormatter.formatUsd(18.0)),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('de ${CurrencyFormatter.formatUsd(500.0)}'), findsOneWidget);
      expect(find.byKey(const Key('analysis_edit_budget_button')), findsOneWidget);

      // Equivalente secundario (tasa 50 -> 18 * 50 = Bs. 900,00)
      expect(find.textContaining('≈ ${CurrencyFormatter.formatVes(900.0)}'), findsOneWidget);

      // Recuadro analítico inferior: 3 filas
      // 1. Presupuesto Total (incluye $ 50,00 de ahorro) -> $ 550,00
      expect(find.textContaining('Presupuesto Total (incluye ${CurrencyFormatter.formatUsd(50.0)} de ahorro)'), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatUsd(550.0)), findsOneWidget);

      // 2. Promedio gastado por día
      expect(find.text('Promedio gastado por día'), findsOneWidget);
      expect(find.textContaining('/ día'), findsOneWidget);

      // 3. Ritmo / Proyección fin de mes
      expect(find.textContaining('Si sigues a este ritmo gastarás en el mes'), findsOneWidget);
    });

    testWidgets('3. Tarjeta 2: Evolución Diaria renderiza curva acumulativa y ritmo dinámico', (tester) async {
      gastoProvider.setPresupuestoGeneralVal(500.0);
      gastoProvider.setGastos([gastoHormiga, gastoMedio, gastoFuerte]);
      gastoProvider.setTotalesPorCategoria({'Alimentación': 123.0, 'Salud': 15.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_daily_evolution')), findsOneWidget);
      expect(find.text('Evolución Diaria'), findsOneWidget);
      expect(find.byKey(const Key('daily_evolution_current_spent')), findsOneWidget);
    });

    testWidgets('4. Tarjeta 3 y Tarjeta 4: Dona y Control de Presupuestos desacoplados en tarjetas independientes', (tester) async {
      gastoProvider.setPresupuestosPorCategoria({'Alimentación': 150.0, 'Salud': 50.0});
      gastoProvider.setGastos([gastoHormiga, gastoMedio]);
      gastoProvider.setTotalesPorCategoria({'Alimentación': 3.0, 'Salud': 15.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tarjeta 3: Distribución por Categorías (Dona)
      expect(find.byKey(const Key('card_category_distribution')), findsOneWidget);
      expect(find.text('Distribución por Categorías'), findsOneWidget);

      // Tarjeta 4: Control de Presupuestos por Categoría (Barras)
      expect(find.byKey(const Key('card_category_budget_control')), findsOneWidget);
      expect(find.text('Control de Presupuestos por Categoría'), findsOneWidget);
      expect(find.byKey(const Key('category_budget_item_Alimentación')), findsOneWidget);
      expect(find.byKey(const Key('category_budget_item_Salud')), findsOneWidget);
    });

    testWidgets('5. Tarjeta 5: ¿En qué moneda se va tu dinero? agrupa por moneda de origen', (tester) async {
      gastoProvider.setPresupuestoGeneralVal(500.0);
      gastoProvider.setGastos([gastoHormiga, gastoMedio, gastoFuerte]);
      gastoProvider.setTotalesPorCategoria({'Alimentación': 123.0, 'Salud': 15.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_currency_radiography')), findsOneWidget);
      expect(find.text('¿En qué moneda se va tu dinero?'), findsOneWidget);
      expect(find.text('Pagado en USD'), findsOneWidget);
      expect(find.text('Pagado en Bolívares (Bs.)'), findsOneWidget);
    });

    testWidgets('6. Tarjeta 6: Radiografía de Compras clasifica hormiga/medias/fuertes y mayor gasto', (tester) async {
      gastoProvider.setPresupuestoGeneralVal(500.0);
      // gastoHormiga = $3, gastoMedio = $15, gastoFuerte = $120
      gastoProvider.setGastos([gastoHormiga, gastoMedio, gastoFuerte]);
      gastoProvider.setTotalesPorCategoria({'Alimentación': 123.0, 'Salud': 15.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_purchase_radiography')), findsOneWidget);
      expect(find.text('Radiografía de Compras'), findsOneWidget);
      expect(find.textContaining('3 registros'), findsOneWidget);

      // Las 3 clasificaciones
      expect(find.text('🐜 Gastos hormiga (menores a \$ 5)'), findsOneWidget);
      expect(find.text('🛒 Compras medias (\$ 5 a \$ 25)'), findsOneWidget);
      expect(find.text('🐘 Gastos fuertes (mayores a \$ 25)'), findsOneWidget);

      // Mayor gasto: Hipermercado Mayorista ($ 120,00 el 15 de Octubre)
      expect(find.byKey(const Key('purchase_radiography_highest_expense')), findsOneWidget);
      expect(find.textContaining('Hipermercado Mayorista'), findsOneWidget);
      expect(find.textContaining(CurrencyFormatter.formatUsd(120.0)), findsOneWidget);
    });

    testWidgets('7. ListView de AnalysisScreen tiene padding inferior seguro de al menos 100dp', (tester) async {
      gastoProvider.setPresupuestoGeneralVal(500.0);
      gastoProvider.setGastos([gastoHormiga]);
      gastoProvider.setTotalesPorCategoria({'Alimentación': 3.0});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget);
      final listView = tester.widget<ListView>(listViewFinder);
      final padding = listView.padding as EdgeInsets;
      expect(padding.bottom, greaterThanOrEqualTo(100.0));
    });
  });
}
