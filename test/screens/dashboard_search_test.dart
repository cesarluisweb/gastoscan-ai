import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
  List<GastoModel> _customGastos;

  FakeGastoProvider({List<GastoModel>? initialGastos})
      : _customGastos = initialGastos ?? [];

  void setGastos(List<GastoModel> gastos) {
    _customGastos = gastos;
    notifyListeners();
  }

  @override
  List<GastoModel> get gastos => _customGastos;

  @override
  Future<void> cargarDatos() async {}
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

void main() {
  group('DashboardScreen Search Tests (R2)', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProvider gastoProvider;
    late FakeSettingsProvider settingsProvider;

    final gastoCafe = GastoModel(
      id: 1,
      uuid: 'uuid-1',
      fecha: '2026-09-15',
      comercio: 'CafÃ© Venezuela',
      moneda: 'USD',
      totalOriginal: 500,
      totalUsd: 500,
      categoria: 'AlimentaciÃ³n',
      creadoEn: '2026-09-15T10:00:00',
      items: [
        ItemGastoModel(
          id: 101,
          gastoId: 1,
          descripcion: 'Espresso Doble',
          cantidad: 2.0,
          precioUnitario: 250,
          total: 500,
        ),
      ],
    );

    final gastoFarmacia = GastoModel(
      id: 2,
      uuid: 'uuid-2',
      fecha: '2026-09-14',
      comercio: 'Farmatodo',
      moneda: 'USD',
      totalOriginal: 850,
      totalUsd: 850,
      categoria: 'Salud',
      creadoEn: '2026-09-14T15:30:00',
      items: [
        ItemGastoModel(
          id: 102,
          gastoId: 2,
          descripcion: 'CafÃ© Molido 500g',
          cantidad: 1.0,
          precioUnitario: 350,
          total: 350,
        ),
        ItemGastoModel(
          id: 103,
          gastoId: 2,
          descripcion: 'Aspirina 500mg',
          cantidad: 1.0,
          precioUnitario: 500,
          total: 500,
        ),
      ],
    );

    final gastoSupermercado = GastoModel(
      id: 3,
      uuid: 'uuid-3',
      fecha: '2026-09-13',
      comercio: 'Automercados Plaza',
      moneda: 'USD',
      totalOriginal: 1200,
      totalUsd: 1200,
      categoria: 'AlimentaciÃ³n',
      creadoEn: '2026-09-13T12:00:00',
      items: [
        ItemGastoModel(
          id: 104,
          gastoId: 3,
          descripcion: 'Arroz Diana 1kg',
          cantidad: 2.0,
          precioUnitario: 150,
          total: 300,
        ),
        ItemGastoModel(
          id: 105,
          gastoId: 3,
          descripcion: 'Aceite Mazeite 1L',
          cantidad: 1.0,
          precioUnitario: 900,
          total: 900,
        ),
      ],
    );

    setUp(() {
      final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.physicalSizeTestValue = const Size(1080, 4000);
      binding.window.devicePixelRatioTestValue = 1.0;

      fakeDb = FakeDatabaseHelper();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      gastoProvider = FakeGastoProvider(
        initialGastos: [gastoCafe, gastoFarmacia, gastoSupermercado],
      );
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

    testWidgets('tapping search icon reveals search text field with hint', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Initially app title is shown, search field is not shown
      expect(find.text('Rinde MÃ¡s'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_search_field')), findsNothing);
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Tap search icon
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Search field is revealed with hint text and close icon is present
      expect(find.byKey(const Key('dashboard_search_field')), findsOneWidget);
      expect(find.text('Buscar por comercio o producto...'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Rinde MÃ¡s'), findsNothing);
    });

    testWidgets('entering search query immediately filters out non-matching expenses', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // All 3 expenses visible initially
      expect(find.text('CafÃ© Venezuela'), findsOneWidget);
      expect(find.text('Farmatodo'), findsOneWidget);
      expect(find.text('Automercados Plaza'), findsOneWidget);

      // Open search and enter query
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('dashboard_search_field')), 'Cafe');
      await tester.pumpAndSettle();

      // Matches CafÃ© Venezuela (commerce) and Farmatodo (product 'CafÃ© Molido 500g')
      expect(find.text('CafÃ© Venezuela'), findsOneWidget);
      expect(find.text('Farmatodo'), findsOneWidget);
      // Automercados Plaza does not match
      expect(find.text('Automercados Plaza'), findsNothing);
    });

    testWidgets('expenses matching by commerce are included', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('dashboard_search_field')), 'Venezuela');
      await tester.pumpAndSettle();

      expect(find.text('CafÃ© Venezuela'), findsOneWidget);
      expect(find.text('Farmatodo'), findsNothing);
      expect(find.text('Automercados Plaza'), findsNothing);
    });

    testWidgets('expenses matching by product name are included', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Search for product 'Aspirina' sold at Farmatodo
      await tester.enterText(find.byKey(const Key('dashboard_search_field')), 'Aspirina');
      await tester.pumpAndSettle();

      expect(find.text('Farmatodo'), findsOneWidget);
      expect(find.text('CafÃ© Venezuela'), findsNothing);
      expect(find.text('Automercados Plaza'), findsNothing);

      // Search for product 'Arroz' sold at Automercados Plaza
      await tester.enterText(find.byKey(const Key('dashboard_search_field')), 'Arroz');
      await tester.pumpAndSettle();

      expect(find.text('Automercados Plaza'), findsOneWidget);
      expect(find.text('Farmatodo'), findsNothing);
      expect(find.text('CafÃ© Venezuela'), findsNothing);
    });

    testWidgets('clearing search query via close button restores all expenses', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('dashboard_search_field')), 'Arroz');
      await tester.pumpAndSettle();

      expect(find.text('Automercados Plaza'), findsOneWidget);
      expect(find.text('Farmatodo'), findsNothing);

      // Tap close button in AppBar
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Search field closed, all expenses restored
      expect(find.byKey(const Key('dashboard_search_field')), findsNothing);
      expect(find.text('CafÃ© Venezuela'), findsOneWidget);
      expect(find.text('Farmatodo'), findsOneWidget);
      expect(find.text('Automercados Plaza'), findsOneWidget);
    });

    testWidgets('clearing search text restores all expenses while keeping search open', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('dashboard_search_field')), 'Arroz');
      await tester.pumpAndSettle();

      expect(find.text('Automercados Plaza'), findsOneWidget);
      expect(find.text('Farmatodo'), findsNothing);

      // Clear text
      await tester.enterText(find.byKey(const Key('dashboard_search_field')), '');
      await tester.pumpAndSettle();

      // All expenses restored
      expect(find.text('CafÃ© Venezuela'), findsOneWidget);
      expect(find.text('Farmatodo'), findsOneWidget);
      expect(find.text('Automercados Plaza'), findsOneWidget);
    });

    testWidgets('displays friendly empty state message when search yields 0 matches', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('dashboard_search_field')),
        'ProductoInexistente999',
      );
      await tester.pumpAndSettle();

      expect(find.text('CafÃ© Venezuela'), findsNothing);
      expect(find.text('Farmatodo'), findsNothing);
      expect(find.text('Automercados Plaza'), findsNothing);

      // Friendly empty state is displayed
      expect(find.byKey(const Key('empty_search_state')), findsOneWidget);
      expect(find.text('No se encontraron gastos'), findsOneWidget);
      expect(find.textContaining('No hay resultados para "ProductoInexistente999"'), findsOneWidget);
    });

    testWidgets('case-insensitive and diacritic-insensitive search works', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Uppercase CAFE
      await tester.enterText(find.byKey(const Key('dashboard_search_field')), 'CAFE');
      await tester.pumpAndSettle();

      expect(find.text('CafÃ© Venezuela'), findsOneWidget);
      expect(find.text('Farmatodo'), findsOneWidget);
      expect(find.text('Automercados Plaza'), findsNothing);

      // Accented cafÃ©
      await tester.enterText(find.byKey(const Key('dashboard_search_field')), 'cafÃ©');
      await tester.pumpAndSettle();

      expect(find.text('CafÃ© Venezuela'), findsOneWidget);
      expect(find.text('Farmatodo'), findsOneWidget);
      expect(find.text('Automercados Plaza'), findsNothing);
    });
  });
}
