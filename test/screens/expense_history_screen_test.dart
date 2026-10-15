import 'package:gastoscan_ai/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/expense_history_screen.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];

  @override
  Future<int> resetStaleProcessingScanQueueItems() async => 0;

  @override
  Future<int> resetFailedScanQueueItems() async => 0;
}

class FakeGastoProvider extends GastoProvider {
  final List<GastoModel> _mockGastos;

  FakeGastoProvider(this._mockGastos);

  @override
  List<GastoModel> get gastos => _mockGastos;

  @override
  double get totalMesUsd => 30.0;

  @override
  double get totalMesVes => 1350.0;

  @override
  int get selectedMonth => 10;

  @override
  int get selectedYear => 2026;

  @override
  bool get isLoading => false;

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}

  @override
  Future<List<GastoModel>> obtenerTodosLosGastos() async => _mockGastos;
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  double get tasaCambioVesUsd => 45.0;

  @override
  double get tasaCambioVesEur => 49.0;

  @override
  double get tasaCambioVesUsdt => 52.0;

  @override
  String get monedaPrincipal => 'USD';

  @override
  Future<void> loadSettings() async {}
}

void main() {
  late FakeDatabaseHelper fakeDb;
  late ScanQueueProvider scanQueueProvider;
  late FakeGastoProvider gastoProvider;
  late FakeSettingsProvider settingsProvider;

  final mockGastos = [
    GastoModel(
      id: 1,
      uuid: 'uuid-1',
      comercio: 'SUPERMERCADO DIA',
      fecha: '2026-10-14',
      moneda: 'USD',
      totalOriginal: 2000,
      totalUsd: 2000,
      tasaCambio: 45.0,
      categoria: 'Alimentación',
      creadoEn: '2026-10-14T10:00:00',
      rutaFotoLocal: '/path/to/recibo.jpg',
      items: [
        ItemGastoModel(descripcion: 'Arroz', cantidad: 2.0, precioUnitario: 500, total: 1000, categoria: 'Alimentación'),
        ItemGastoModel(descripcion: 'Pasta', cantidad: 2.0, precioUnitario: 500, total: 1000, categoria: 'Alimentación'),
      ],
    ),
    GastoModel(
      id: 2,
      uuid: 'uuid-2',
      comercio: 'Farmacia Express',
      fecha: '2026-10-13',
      moneda: 'USD',
      totalOriginal: 1000,
      totalUsd: 1000,
      tasaCambio: 45.0,
      categoria: 'Salud',
      creadoEn: '2026-10-13T10:00:00',
      rutaFotoLocal: null,
      items: [
        ItemGastoModel(descripcion: 'Alcohol', cantidad: 1.0, precioUnitario: 1000, total: 1000, categoria: 'Salud'),
      ],
    ),
  ];

  setUp(() {
    fakeDb = FakeDatabaseHelper();
    scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
    gastoProvider = FakeGastoProvider(mockGastos);
    settingsProvider = FakeSettingsProvider();
  });

  tearDown(() {
    scanQueueProvider.dispose();
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
      ],
      child: const MaterialApp(
        home: ExpenseHistoryScreen(),
      ),
    );
  }

  group('ExpenseHistoryScreen Tests', () {
    testWidgets('renders monthly summary strip and filter chips', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Monthly summary strip is present
      expect(find.byKey(const Key('expense_history_monthly_summary_strip')), findsOneWidget);
      expect(find.textContaining('Total gastado'), findsOneWidget);
      expect(find.textContaining('2 compras'), findsOneWidget);
      expect(find.textContaining(r'$ 30,00', findRichText: true), findsOneWidget);

      // Filter chips are present
      expect(find.byKey(const Key('expense_filter_chip_all')), findsOneWidget);
      expect(find.byKey(const Key('expense_history_receipt_filter_toggle')), findsOneWidget);
      expect(find.byKey(const Key('expense_filter_chip_alimentación')), findsOneWidget);
      expect(find.byKey(const Key('expense_filter_chip_salud')), findsOneWidget);

      // Search toggle button is present
      expect(find.byKey(const Key('expense_history_search_toggle')), findsOneWidget);
    });

    testWidgets('tapping receipt filter chip filters only expenses with photo', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Supermercado Dia'), findsOneWidget);
      expect(find.text('Farmacia Express'), findsOneWidget);

      // Tap receipt chip
      await tester.tap(find.byKey(const Key('expense_history_receipt_filter_toggle')));
      await tester.pumpAndSettle();

      // Only Supermercado Dia has receipt photo
      expect(find.text('Supermercado Dia'), findsOneWidget);
      expect(find.text('Farmacia Express'), findsNothing);

      // Summary updates to 1 compra
      expect(find.textContaining('1 compra'), findsOneWidget);

      // Tap Todos to reset
      await tester.tap(find.byKey(const Key('expense_filter_chip_all')));
      await tester.pumpAndSettle();

      expect(find.text('Supermercado Dia'), findsOneWidget);
      expect(find.text('Farmacia Express'), findsOneWidget);
    });

    testWidgets('tapping category chip filters only expenses in that category', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap Salud chip
      await tester.tap(find.byKey(const Key('expense_filter_chip_salud')));
      await tester.pumpAndSettle();

      expect(find.text('Supermercado Dia'), findsNothing);
      expect(find.text('Farmacia Express'), findsOneWidget);

      // Tap Salud chip again to toggle off
      await tester.tap(find.byKey(const Key('expense_filter_chip_salud')));
      await tester.pumpAndSettle();

      expect(find.text('Supermercado Dia'), findsOneWidget);
      expect(find.text('Farmacia Express'), findsOneWidget);
    });
  });
}
