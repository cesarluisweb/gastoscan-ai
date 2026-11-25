import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/datasources/remote/gemini_service.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/services/ai_insight_service.dart';
import 'package:gastoscan_ai/services/sync_coordinator.dart';
import 'package:gastoscan_ai/ui/screens/dashboard_screen.dart';
import 'package:gastoscan_ai/ui/widgets/category_chart.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  final List<Map<String, dynamic>> pending = [];
  final List<Map<String, dynamic>> ready = [];
  List<GastoModel> prevMonthGastos = const [];
  Map<String, PriceHistory> mockPriceHistory = const {};

  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => List.from(pending);

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => List.from(ready);

  @override
  Future<List<GastoModel>> getGastosByMonth(int year, int month) async => prevMonthGastos;

  @override
  Future<Map<String, PriceHistory>> findPriceHistory(
    List<String> descripcionesNormalizadas, {
    int? excludeGastoId,
    String? comercioActual,
    int diasVentana = 60,
    DateTime? referenceDate,
  }) async =>
      mockPriceHistory;
}

class FakeGeminiServiceForDashboard extends GeminiService {
  int callCount = 0;
  String nextRawText = '';
  Future<Map<String, dynamic>> Function(int callIndex, Map<String, dynamic> contextData)?
      customHandler;

  @override
  Future<Map<String, dynamic>> chatWithAnalyst({
    required List<Map<String, String>> messages,
    required Map<String, dynamic> contextData,
    String? modo,
  }) async {
    callCount++;
    final currentCall = callCount;
    if (customHandler != null) {
      return customHandler!(currentCall, contextData);
    }
    return {'text': nextRawText};
  }
}

class FakeGastoProvider extends GastoProvider {
  FakeGastoProvider() : super(autoLoad: false);

  List<GastoModel> _customGastos = const [];
  int _customSelectedYear = DateTime.now().year;
  int _customSelectedMonth = DateTime.now().month;
  double _customTotalMesUsd = 0.0;
  double _customTotalMesUsdt = 0.0;
  double _customMetaAhorro = 0.0;
  bool _customIsLoading = false;
  Map<String, double> _customTotales = {};
  Map<String, double> _customTotalesVes = {};
  Map<String, double> _customPresupuestos = {};
  double _customPresupuestoGeneral = 0.0;
  String _customMonedaPresupuesto = 'USD';
  final ValueNotifier<SyncState> fakeSyncNotifier =
      ValueNotifier<SyncState>(const SyncState.inactiva());

  @override
  SyncState get syncState => fakeSyncNotifier.value;

  @override
  ValueNotifier<SyncState> get syncStateListenable => fakeSyncNotifier;

  void setGastosState({
    required List<GastoModel> gastos,
    required int year,
    required int month,
    required double totalMesUsd,
    double totalMesUsdt = 0.0,
    double presupuestoGeneral = 0.0,
    double metaAhorro = 0.0,
    Map<String, double>? totalesPorCategoria,
    bool isLoading = false,
  }) {
    _customGastos = gastos;
    _customSelectedYear = year;
    _customSelectedMonth = month;
    _customTotalMesUsd = totalMesUsd;
    _customTotalMesUsdt = totalMesUsdt;
    _customPresupuestoGeneral = presupuestoGeneral;
    _customMetaAhorro = metaAhorro;
    if (totalesPorCategoria != null) {
      _customTotales = totalesPorCategoria;
    }
    _customIsLoading = isLoading;
    notifyListeners();
  }

  @override
  List<GastoModel> get gastos => _customGastos;

  @override
  int get selectedYear => _customSelectedYear;

  @override
  int get selectedMonth => _customSelectedMonth;

  @override
  double get totalMesUsd => _customTotalMesUsd;

  @override
  double get totalMesUsdt => _customTotalMesUsdt;

  @override
  double get metaAhorro => _customMetaAhorro;

  @override
  bool get isLoading => _customIsLoading;

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

  @override
  void dispose() {
    fakeSyncNotifier.dispose();
    super.dispose();
  }
}

class FakeSettingsProvider extends SettingsProvider {
  FakeSettingsProvider()
      : super(autoLoad: false, enableConnectivityListener: false);

  String _customMoneda = 'USD';
  double _customTasa = 40.0;

  @override
  Future<void> setMonedaPrincipal(String m) async {
    _customMoneda = m;
    notifyListeners();
  }

  void setTestTasaCambioVesUsd(double t) {
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
      SharedPreferences.setMockInitialValues({});
      AiInsightService.resetInFlightStateForTesting();
      fakeDb = FakeDatabaseHelper();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      gastoProvider = FakeGastoProvider();
      settingsProvider = FakeSettingsProvider();
    });

    tearDown(() {
      scanQueueProvider.dispose();
      gastoProvider.dispose();
      settingsProvider.dispose();
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
      settingsProvider.setTestTasaCambioVesUsd(40.0);
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
      settingsProvider.setTestTasaCambioVesUsd(40.0);
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

    testWidgets('Sync banner stays hidden on 1st generic error and appears on 2nd failure or permission-denied', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // 1.er fallo genérico: banner oculto
      gastoProvider.fakeSyncNotifier.value = const SyncState.error(
        message: 'No se pudo sincronizar con la nube.',
        errorCode: 'unknown',
        consecutiveFailures: 1,
      );
      await tester.pump();
      expect(find.byKey(const Key('dashboard_sync_error_banner')), findsNothing);

      // 2.º fallo consecutivo: banner visible con botón Reintentar
      gastoProvider.fakeSyncNotifier.value = const SyncState.error(
        message: 'No se pudo sincronizar con la nube.',
        errorCode: 'unknown',
        consecutiveFailures: 2,
      );
      await tester.pump();
      expect(find.byKey(const Key('dashboard_sync_error_banner')), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      // Ocultar el banner del fallo genérico
      await tester.tap(find.byKey(const Key('dashboard_sync_error_dismiss')));
      await tester.pump();
      expect(find.byKey(const Key('dashboard_sync_error_banner')), findsNothing);

      // permission-denied (consecutiveFailures == 1) debe volver a mostrar el banner aunque antes se ocultó otro error
      gastoProvider.fakeSyncNotifier.value = const SyncState.error(
        message: 'Actualiza Rinde Más desde Google Play para seguir respaldando tus gastos.',
        errorCode: 'permission-denied',
        consecutiveFailures: 1,
      );
      await tester.pump();
      expect(find.byKey(const Key('dashboard_sync_error_banner')), findsOneWidget);
      expect(find.text('Ir a Google Play'), findsOneWidget);
    });
  });

  group('DashboardScreen AiInsightCard Cache Invalidation & Debounce Tests', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProvider gastoProvider;
    late FakeSettingsProvider settingsProvider;
    late FakeGeminiServiceForDashboard fakeGemini;

    final DateTime fixedDate = DateTime(2026, 11, 15);

    List<GastoModel> buildBaseExpenses({bool includeHigh = false, int extraCount = 0}) {
      final list = <GastoModel>[
        GastoModel(
          id: 1,
          uuid: 'u-base-1',
          fecha: '2026-11-05',
          comercio: 'Farmatodo',
          moneda: 'USD',
          totalOriginal: 2000,
          totalUsd: 2000,
          categoria: 'Alimentación',
          creadoEn: '2026-11-05T10:00:00',
          items: [
            ItemGastoModel(
              descripcion: 'Café Molido',
              cantidad: 1,
              precioUnitario: 2000,
              total: 2000,
              categoria: 'Alimentación',
            ),
          ],
        ),
        GastoModel(
          id: 2,
          uuid: 'u-base-2',
          fecha: '2026-11-08',
          comercio: 'Unicasa',
          moneda: 'USD',
          totalOriginal: 2000,
          totalUsd: 2000,
          categoria: 'Alimentación',
          creadoEn: '2026-11-08T10:00:00',
        ),
        GastoModel(
          id: 3,
          uuid: 'u-base-3',
          fecha: '2026-11-12',
          comercio: 'Panadería Central',
          moneda: 'USD',
          totalOriginal: 2000,
          totalUsd: 2000,
          categoria: 'Alimentación',
          creadoEn: '2026-11-12T10:00:00',
        ),
      ];
      if (includeHigh) {
        list.insert(
          0,
          GastoModel(
            id: 99,
            uuid: 'u-high-500',
            fecha: '2026-11-15',
            comercio: 'Tienda Lujo',
            moneda: 'USD',
            totalOriginal: 50000,
            totalUsd: 50000,
            categoria: 'Otros',
            creadoEn: '2026-11-15T09:00:00',
          ),
        );
      }
      for (int i = 0; i < extraCount; i++) {
        list.add(
          GastoModel(
            id: 200 + i,
            uuid: 'u-extra-$i',
            fecha: '2026-11-14',
            comercio: 'Abasto Local $i',
            moneda: 'USD',
            totalOriginal: 1000,
            totalUsd: 1000,
            categoria: 'Otros',
            creadoEn: '2026-11-14T12:00:00',
          ),
        );
      }
      return list;
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AiInsightService.resetInFlightStateForTesting();
      fakeDb = FakeDatabaseHelper();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      gastoProvider = FakeGastoProvider();
      settingsProvider = FakeSettingsProvider();
      fakeGemini = FakeGeminiServiceForDashboard();
    });

    tearDown(() {
      scanQueueProvider.dispose();
      gastoProvider.dispose();
      settingsProvider.dispose();
      fakeGemini.close();
    });

    Widget buildDashboardUnderTest() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: MaterialApp(
          home: DashboardScreen(
            geminiService: fakeGemini,
            dbHelper: fakeDb,
            currentDate: fixedDate,
          ),
        ),
      );
    }

    Finder insightCardText(String fragment) {
      return find.descendant(
        of: find.byKey(const Key('ai_insight_card')),
        matching: find.textContaining(fragment, findRichText: true),
      );
    }

    testWidgets('deleting high expense clears stale Gemini tip in the same frame and regenerates after 3s debounce', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final gastosWithHigh = buildBaseExpenses(includeHigh: true);
      gastoProvider.setGastosState(
        gastos: gastosWithHigh,
        year: 2026,
        month: 11,
        totalMesUsd: 560.0,
        presupuestoGeneral: 1000.0,
        totalesPorCategoria: {'Alimentación': 60.0, 'Otros': 500.0},
      );
      fakeGemini.nextRawText =
          '{"consejo": "El gasto alto de **\$ 500,00** en **Tienda Lujo** impulsó tu semana."}';

      await tester.pumpWidget(buildDashboardUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fakeGemini.callCount, 1);
      expect(insightCardText('Tienda Lujo'), findsOneWidget);

      // Borrar el gasto alto: en el MISMO frame desaparece el consejo obsoleto
      fakeGemini.nextRawText =
          '{"consejo": "Tus compras en **Farmatodo** mantienen un ritmo estable este mes."}';
      gastoProvider.setGastosState(
        gastos: buildBaseExpenses(includeHigh: false),
        year: 2026,
        month: 11,
        totalMesUsd: 60.0,
        presupuestoGeneral: 1000.0,
        totalesPorCategoria: {'Alimentación': 60.0},
      );

      await tester.pump();
      expect(insightCardText('Tienda Lujo'), findsNothing);
      expect(fakeGemini.callCount, 1);

      // Antes de 3 s de debounce no llama a Gemini todavía
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 2));
      expect(fakeGemini.callCount, 1);

      // Al completar los 3 s regenera con los datos limpios
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fakeGemini.callCount, 2);
      expect(insightCardText('Farmatodo'), findsOneWidget);
      expect(insightCardText('Tienda Lujo'), findsNothing);
    });

    testWidgets('rapid edits within 3s debounce coalesce into one Gemini call and dispose cancels pending timer', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      gastoProvider.setGastosState(
        gastos: buildBaseExpenses(),
        year: 2026,
        month: 11,
        totalMesUsd: 60.0,
        presupuestoGeneral: 1000.0,
        totalesPorCategoria: {'Alimentación': 60.0},
      );
      fakeGemini.nextRawText =
          '{"consejo": "Consejo inicial frío de prueba para verificar debounce en Inicio."}';

      await tester.pumpWidget(buildDashboardUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(fakeGemini.callCount, 1);

      // 3 cambios rápidos en menos de 3 s -> se agrupan en una sola llamada
      fakeGemini.nextRawText =
          '{"consejo": "Consejo consolidado tras ráfaga de ediciones rápidas en el mes."}';
      for (int i = 1; i <= 3; i++) {
        gastoProvider.setGastosState(
          gastos: buildBaseExpenses(extraCount: i),
          year: 2026,
          month: 11,
          totalMesUsd: 60.0 + (i * 10.0),
          presupuestoGeneral: 1000.0,
          totalesPorCategoria: {'Alimentación': 60.0, 'Otros': i * 10.0},
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
      expect(fakeGemini.callCount, 1);

      // Al pasar 3 s desde el último cambio -> 1 sola llamada
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fakeGemini.callCount, 2);
      expect(insightCardText('consolidado'), findsOneWidget);

      // Otro cambio inicia timer y desmontar el widget lo cancela sin fallar ni llamar
      gastoProvider.setGastosState(
        gastos: buildBaseExpenses(extraCount: 4),
        year: 2026,
        month: 11,
        totalMesUsd: 100.0,
        presupuestoGeneral: 1000.0,
        totalesPorCategoria: {'Alimentación': 60.0, 'Otros': 40.0},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
      expect(fakeGemini.callCount, 2);
    });

    testWidgets('deleting expense after 3/day cap removes stale tip and stays on live local fallback', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final gastosWithHigh = buildBaseExpenses(includeHigh: true);
      final sigWithHigh = AiInsightService.buildExpenseSignature(
        year: 2026,
        month: 11,
        gastos: gastosWithHigh,
        totalMesUsd: 560.0,
      );
      SharedPreferences.setMockInitialValues({
        AiInsightService.prefTextKey:
            'El gasto alto de **\$ 500,00** en **Tienda Lujo** elevó tus compras del mes.',
        AiInsightService.prefSignatureKey: sigWithHigh,
        AiInsightService.prefYearMonthKey: '2026_11',
        AiInsightService.prefCachedDateKey: '2026-11-15',
        AiInsightService.prefLastFetchDateKey: '2026-11-15',
        AiInsightService.prefFetchCountKey: 3,
      });

      gastoProvider.setGastosState(
        gastos: gastosWithHigh,
        year: 2026,
        month: 11,
        totalMesUsd: 560.0,
        presupuestoGeneral: 1000.0,
        totalesPorCategoria: {'Alimentación': 60.0, 'Otros': 500.0},
      );

      await tester.pumpWidget(buildDashboardUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Hit de caché válida con firma coincidente (0 llamadas)
      expect(fakeGemini.callCount, 0);
      expect(insightCardText('Tienda Lujo'), findsOneWidget);

      // Borrar el gasto alto con cupo 3/3 agotado -> desaparece el texto viejo y permanece respaldo local
      gastoProvider.setGastosState(
        gastos: buildBaseExpenses(includeHigh: false),
        year: 2026,
        month: 11,
        totalMesUsd: 60.0,
        presupuestoGeneral: 1000.0,
        totalesPorCategoria: {'Alimentación': 60.0},
      );

      await tester.pump();
      expect(insightCardText('Tienda Lujo'), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fakeGemini.callCount, 0);
      expect(insightCardText('Tienda Lujo'), findsNothing);
      expect(find.byKey(const Key('ai_insight_card')), findsOneWidget);
    });

    testWidgets('stale in-flight Gemini response is ignored by requestId after expense deletion', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firstCallCompleter = Completer<Map<String, dynamic>>();
      fakeGemini.customHandler = (callIndex, _) {
        if (callIndex == 1) return firstCallCompleter.future;
        return Future.value({
          'text': '{"consejo": "Consejo fresco para tus compras reales en **Unicasa**."}',
        });
      };

      gastoProvider.setGastosState(
        gastos: buildBaseExpenses(includeHigh: true),
        year: 2026,
        month: 11,
        totalMesUsd: 560.0,
        presupuestoGeneral: 1000.0,
        totalesPorCategoria: {'Alimentación': 60.0, 'Otros': 500.0},
      );

      await tester.pumpWidget(buildDashboardUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(fakeGemini.callCount, 1);

      // Antes de que responda la petición 1, el usuario borra el gasto alto
      gastoProvider.setGastosState(
        gastos: buildBaseExpenses(includeHigh: false),
        year: 2026,
        month: 11,
        totalMesUsd: 60.0,
        presupuestoGeneral: 1000.0,
        totalesPorCategoria: {'Alimentación': 60.0},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Ahora resuelve tarde la petición 1 sobre el gasto borrado -> debe ignorarse
      firstCallCompleter.complete({
        'text': '{"consejo": "Respuesta tardía sobre **Tienda Lujo** que no debe mostrarse."}',
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(insightCardText('Tienda Lujo'), findsNothing);

      // Tras el debounce de 3 s entra la petición 2 y muestra el consejo limpio
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fakeGemini.callCount, 2);
      expect(insightCardText('Unicasa'), findsOneWidget);
      expect(insightCardText('Tienda Lujo'), findsNothing);
    });
  });
}
