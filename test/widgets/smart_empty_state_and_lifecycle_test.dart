import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/core/utils/date_formatter.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/dashboard_screen.dart';
import 'package:gastoscan_ai/ui/screens/expense_history_screen.dart';

class TestableFakeGastoProvider extends GastoProvider {
  int _mes;
  int _anio;
  List<GastoModel> _listaGastos = [];
  Map<String, int>? _fakeUltimoMes;

  TestableFakeGastoProvider({
    int? mes,
    int? anio,
    List<GastoModel>? gastos,
    Map<String, int>? ultimoMes,
  })  : _mes = mes ?? DateTime.now().month,
        _anio = anio ?? DateTime.now().year,
        _listaGastos = gastos ?? [],
        _fakeUltimoMes = ultimoMes,
        super(autoLoad: false);

  @override
  int get selectedMonth => _mes;

  @override
  int get selectedYear => _anio;

  @override
  List<GastoModel> get gastos => _listaGastos;

  @override
  Map<String, int>? get ultimoMesConGastos => _fakeUltimoMes;

  void setGastos(List<GastoModel> g) {
    _listaGastos = g;
    notifyListeners();
  }

  void setUltimoMes(Map<String, int>? u) {
    _fakeUltimoMes = u;
    notifyListeners();
  }

  @override
  void cambiarMes(int year, int month) {
    _anio = year;
    _mes = month;
    notifyListeners();
  }

  @override
  void resetearAMesActual() {
    final now = DateTime.now();
    _anio = now.year;
    _mes = now.month;
    notifyListeners();
  }

  @override
  void verificarReanudacionMesActual() {
    final now = DateTime.now();
    if (_anio != now.year || _mes != now.month) {
      if (_listaGastos.isEmpty || _anio < now.year) {
        resetearAMesActual();
      }
    }
  }

  @override
  Future<void> cargarDatos() async {}
}

class FakeDatabaseHelperForSmartEmptyState extends DatabaseHelper {
  FakeDatabaseHelperForSmartEmptyState() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];

  @override
  Future<List<GastoModel>> getAllGastos() async => [];
}

void main() {
  group('Smart Empty State & Lifecycle Unit / Widget Tests', () {
    late TestableFakeGastoProvider fakeGastoProvider;
    late ScanQueueProvider scanQueueProvider;
    late SettingsProvider settingsProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final fakeDb = FakeDatabaseHelperForSmartEmptyState();
      fakeGastoProvider = TestableFakeGastoProvider(
        mes: DateTime.now().month,
        anio: DateTime.now().year,
        gastos: [],
        ultimoMes: {'year': 2026, 'month': 10},
      );
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      settingsProvider = SettingsProvider(autoLoad: false);
    });

    tearDown(() {
      scanQueueProvider.dispose();
      settingsProvider.dispose();
      fakeGastoProvider.dispose();
    });

    Widget createDashboardWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: fakeGastoProvider),
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DashboardScreen(),
          ),
        ),
      );
    }

    Widget createExpenseHistoryWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: fakeGastoProvider),
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ExpenseHistoryScreen(),
          ),
        ),
      );
    }

    test('Provider: resetearAMesActual sets to current year and month', () {
      fakeGastoProvider.cambiarMes(2025, 5);
      expect(fakeGastoProvider.selectedYear, equals(2025));
      expect(fakeGastoProvider.selectedMonth, equals(5));

      fakeGastoProvider.resetearAMesActual();
      final now = DateTime.now();
      expect(fakeGastoProvider.selectedYear, equals(now.year));
      expect(fakeGastoProvider.selectedMonth, equals(now.month));
    });

    test('Provider: verificarReanudacionMesActual recovers if in empty past year', () {
      fakeGastoProvider.cambiarMes(2025, 11);
      fakeGastoProvider.verificarReanudacionMesActual();

      final now = DateTime.now();
      expect(fakeGastoProvider.selectedYear, equals(now.year));
      expect(fakeGastoProvider.selectedMonth, equals(now.month));
    });

    testWidgets('Dashboard: shows jump to latest month button when viewing empty current month with prior expenses',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final pastYear = now.month == 1 ? now.year - 1 : now.year;
      final pastMonth = now.month == 1 ? 12 : now.month - 1;
      fakeGastoProvider.cambiarMes(now.year, now.month);
      fakeGastoProvider.setUltimoMes({'year': pastYear, 'month': pastMonth});

      await tester.pumpWidget(createDashboardWidget());
      await tester.pumpAndSettle();

      final jumpBtnFinder = find.byKey(const Key('empty_state_jump_to_latest_btn'));
      expect(jumpBtnFinder, findsOneWidget);
      expect(find.byKey(const Key('empty_state_return_to_current_month_btn')), findsNothing);

      await tester.tap(jumpBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeGastoProvider.selectedYear, equals(pastYear));
      expect(fakeGastoProvider.selectedMonth, equals(pastMonth));
    });

    testWidgets('Dashboard: deduplication - when ultimo is current month and viewing empty historical month, renders exactly 1 main button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      fakeGastoProvider.cambiarMes(2025, 5);
      fakeGastoProvider.setUltimoMes({'year': now.year, 'month': now.month});

      await tester.pumpWidget(createDashboardWidget());
      await tester.pumpAndSettle();

      final returnBtnFinder = find.byKey(const Key('empty_state_return_to_current_month_btn'));
      expect(returnBtnFinder, findsOneWidget);
      expect(find.byKey(const Key('empty_state_jump_to_latest_btn')), findsNothing);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.textContaining('Volver al mes actual'), findsOneWidget);
      expect(find.descendant(of: returnBtnFinder, matching: find.byIcon(Icons.arrow_forward)), findsOneWidget);

      await tester.tap(returnBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeGastoProvider.selectedYear, equals(now.year));
      expect(fakeGastoProvider.selectedMonth, equals(now.month));
    });

    testWidgets('Dashboard: two buttons - when ultimo is different from current month and viewing empty historical month, renders both buttons with OutlinedButton below',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final pastYear = now.month == 1 ? now.year - 1 : now.year;
      final pastMonth = now.month == 1 ? 12 : now.month - 1;
      fakeGastoProvider.cambiarMes(2025, 5);
      fakeGastoProvider.setUltimoMes({'year': pastYear, 'month': pastMonth});

      await tester.pumpWidget(createDashboardWidget());
      await tester.pumpAndSettle();

      final jumpBtnFinder = find.byKey(const Key('empty_state_jump_to_latest_btn'));
      final returnBtnFinder = find.byKey(const Key('empty_state_return_to_current_month_btn'));
      expect(jumpBtnFinder, findsOneWidget);
      expect(returnBtnFinder, findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);

      expect(find.widgetWithText(ElevatedButton, 'Ver gastos de ${DateFormatter.getMonthName(pastMonth)} $pastYear'), findsOneWidget);
      expect(find.descendant(of: jumpBtnFinder, matching: find.byIcon(Icons.arrow_forward)), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Volver a ${DateFormatter.getMonthName(now.month)} ${now.year} (Mes actual)'), findsOneWidget);

      await tester.tap(jumpBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeGastoProvider.selectedYear, equals(pastYear));
      expect(fakeGastoProvider.selectedMonth, equals(pastMonth));
    });

    testWidgets('Dashboard: shows return to current month button when trapped in historical year (2025) with no records',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakeGastoProvider.cambiarMes(2025, 11);
      fakeGastoProvider.setUltimoMes(null); // Sin gastos en ningún mes

      await tester.pumpWidget(createDashboardWidget());
      await tester.pumpAndSettle();

      final returnBtnFinder = find.byKey(const Key('empty_state_return_to_current_month_btn'));
      expect(returnBtnFinder, findsOneWidget);
      expect(find.byKey(const Key('empty_state_jump_to_latest_btn')), findsNothing);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Sin gastos en Noviembre 2025'), findsOneWidget);

      await tester.tap(returnBtnFinder);
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(fakeGastoProvider.selectedYear, equals(now.year));
      expect(fakeGastoProvider.selectedMonth, equals(now.month));
    });

    testWidgets('ExpenseHistory: deduplication - when ultimo is current month and viewing empty historical month, renders 1 button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      fakeGastoProvider.cambiarMes(2025, 5);
      fakeGastoProvider.setUltimoMes({'year': now.year, 'month': now.month});

      await tester.pumpWidget(createExpenseHistoryWidget());
      await tester.pumpAndSettle();

      final returnBtnFinder = find.byKey(const Key('empty_state_return_to_current_month_btn'));
      expect(returnBtnFinder, findsOneWidget);
      expect(find.byKey(const Key('empty_state_jump_to_latest_btn')), findsNothing);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);

      await tester.tap(returnBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeGastoProvider.selectedYear, equals(now.year));
      expect(fakeGastoProvider.selectedMonth, equals(now.month));
    });

    testWidgets('ExpenseHistory: two buttons - when ultimo is different from current month and viewing empty historical month, renders both buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final pastYear = now.month == 1 ? now.year - 1 : now.year;
      final pastMonth = now.month == 1 ? 12 : now.month - 1;
      fakeGastoProvider.cambiarMes(2025, 5);
      fakeGastoProvider.setUltimoMes({'year': pastYear, 'month': pastMonth});

      await tester.pumpWidget(createExpenseHistoryWidget());
      await tester.pumpAndSettle();

      final jumpBtnFinder = find.byKey(const Key('empty_state_jump_to_latest_btn'));
      final returnBtnFinder = find.byKey(const Key('empty_state_return_to_current_month_btn'));
      expect(jumpBtnFinder, findsOneWidget);
      expect(returnBtnFinder, findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);

      await tester.tap(jumpBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeGastoProvider.selectedYear, equals(pastYear));
      expect(fakeGastoProvider.selectedMonth, equals(pastMonth));
    });
  });
}
