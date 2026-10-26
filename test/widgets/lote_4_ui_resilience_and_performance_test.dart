import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/data/models/shopping_item_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/services/local_ocr_service.dart';
import 'package:gastoscan_ai/ui/widgets/summary_card.dart';
import 'package:gastoscan_ai/ui/screens/analysis_screen.dart';
import 'package:gastoscan_ai/ui/widgets/category_chart.dart';
import 'package:gastoscan_ai/ui/widgets/pending_expense_card.dart';
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

  @override
  Future<List<ShoppingItemModel>> getPendingShoppingItems() async => [];
}

class FakeGastoProvider extends GastoProvider {
  final List<GastoModel> _mockGastos;

  FakeGastoProvider(this._mockGastos);

  @override
  List<GastoModel> get gastos => _mockGastos;

  @override
  double get totalMesUsd => 300.0;

  @override
  double get totalMesVes => 15850420.00;

  @override
  double get totalMesUsdt => 300.0;

  @override
  double get presupuestoGeneral => 20000000.00;

  @override
  double get metaAhorro => 5000000.00;

  @override
  int get selectedMonth => 10;

  @override
  int get selectedYear => 2026;

  @override
  bool get isLoading => false;

  @override
  Map<String, double> get totalesPorCategoriaVes => {
    'Alimentación': 10000000.00,
    'Transporte': 5850420.00,
  };

  @override
  Map<String, double> get presupuestosPorCategoria => {
    'Alimentación': 12000000.00,
    'Transporte': 8000000.00,
  };

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<List<GastoModel>> obtenerTodosLosGastos() async => _mockGastos;
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  double get tasaCambioVesUsd => 50.0;

  @override
  double get tasaCambioVesEur => 55.0;

  @override
  double get tasaCambioVesUsdt => 51.0;

  @override
  String get monedaPrincipal => 'VES';

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
      uuid: 'uuid-ves-1',
      comercio: 'Automercados Plaza San Antonio',
      fecha: '2026-10-26',
      moneda: 'VES',
      totalOriginal: 1585042000, // 15.850.420,00 Bs.
      totalUsd: 31700,
      tasaCambio: 50.0,
      categoria: 'Alimentación',
      creadoEn: '2026-10-26T10:00:00',
      rutaFotoLocal: '/path/to/recibo.jpg',
      items: [
        ItemGastoModel(descripcion: 'Mercado Quincenal Completo', cantidad: 1.0, precioUnitario: 1585042000, total: 1585042000, categoria: 'Alimentación'),
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

  group('Lote 4: UI Resilience & Performance Tests', () {
    testWidgets('SummaryCard resists 360dp width with million Bolivares amounts without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SummaryCard(
                totalUsd: 317.00,
                totalVes: 15850420.00,
                periodo: 'Octubre 2026',
                monedaPrincipal: 'VES',
                tasaCambio: 50.0,
                presupuestoGeneral: 20000000.00,
                metaAhorro: 5000000.00,
                mes: 10,
                anio: 2026,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SummaryCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AnalysisScreen analytical box resists 360dp width with million Bolivares amounts', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ],
          child: const MaterialApp(
            home: AnalysisScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('general_budget_card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CategoryChart category budget rows resist 360dp width with million Bolivares amounts', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryChart(
                categoryTotals: {
                  'Alimentación': 15850420.00,
                  'Transporte': 8250000.00,
                },
                categoryBudgets: {
                  'Alimentación': 20000000.00,
                  'Transporte': 10000000.00,
                },
                monedaPrincipal: 'VES',
                presupuestoGeneral: 30000000.00,
                totalGastadoMes: 24100420.00,
                showBudgetBars: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CategoryChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PendingExpenseCard date and amount row resists 360dp width with million Bolivares', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PendingExpenseCard(
              gasto: mockGastos.first,
              monedaPrincipal: 'VES',
              tasaCambio: 50.0,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PendingExpenseCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ExpenseHistoryScreen virtualizes list with ListView.builder and shows summary strip at 360dp', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ],
          child: const MaterialApp(
            home: ExpenseHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find ListView
      expect(find.byType(ListView), findsWidgets);
      expect(find.byKey(const Key('expense_history_monthly_summary_strip')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('LocalOcrService.evaluateRawText unifies OCR evaluation for text pipeline', () {
      final ocrService = LocalOcrService();
      const mockInvoiceText = '''
        AUTOMERCADOS PLAZA C.A.
        RIF J-12345678-9
        FECHA: 26/10/2026
        HARINA PAN 1KG 120,50 BS
        ARROZ PRIMOR 1KG 95,00 BS
        SUBTOTAL 215,50 BS
        TOTAL A PAGAR 215,50 BS
      ''';

      final score = ocrService.evaluateRawText(mockInvoiceText);
      expect(score.hasAmounts, isTrue);
      expect(score.hasTotalKeyword, isTrue);
      expect(score.hasCurrency, isTrue);
      expect(score.hasDate, isTrue);
      expect(score.hasMerchantOrRif, isTrue);
      expect(score.hasSufficientLines, isTrue);
      expect(score.totalScore >= 6, isTrue);
    });
  });
}
