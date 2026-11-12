import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/currency_calculator_screen.dart';

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
  Future<int> clearPendingScanQueueItems() async => 0;

  @override
  Future<void> limpiarBaseDatosLocal() async {}
}

class FakeGastoProvider extends GastoProvider {
  FakeGastoProvider() : super(autoLoad: false);

  final List<GastoModel> _gastos = [];

  @override
  List<GastoModel> get gastos => _gastos;

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}

  @override
  Future<Map<String, dynamic>?> buscarPrecioAnterior(String descripcion, {int? excludeGastoId}) async => null;
}

class FakeSettingsProvider extends SettingsProvider {
  FakeSettingsProvider() : super(autoLoad: false);

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

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    fakeDb = FakeDatabaseHelper();
    scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
    gastoProvider = FakeGastoProvider();
    settingsProvider = FakeSettingsProvider();
  });

  tearDown(() {
    scanQueueProvider.dispose();
    settingsProvider.dispose();
    gastoProvider.dispose();
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
      ],
      child: const MaterialApp(
        home: CurrencyCalculatorScreen(showBackButton: true),
      ),
    );
  }

  group('CurrencyCalculatorScreen Tests', () {
    testWidgets('renders all initial fields, chips and comparison rows', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Calculadora Cambiaria'), findsOneWidget);
      expect(find.byKey(const Key('calc_divisa_input')), findsOneWidget);
      expect(find.byKey(const Key('calc_ves_input')), findsOneWidget);
      expect(find.byKey(const Key('calc_chip_dolar_bcv')), findsOneWidget);
      expect(find.byKey(const Key('calc_chip_euro_bcv')), findsOneWidget);
      expect(find.byKey(const Key('calc_chip_usdt')), findsOneWidget);
      expect(find.byKey(const Key('calc_chip_custom')), findsOneWidget);

      expect(find.byKey(const Key('calc_copy_ves_button')), findsOneWidget);
      expect(find.byKey(const Key('calc_register_expense_button')), findsOneWidget);

      // Initial state is clean/empty: no premature clear button or pre-populated 1
      final divisaField = tester.widget<TextField>(find.byKey(const Key('calc_divisa_input')));
      expect(divisaField.controller?.text, isEmpty);
      final vesField = tester.widget<TextField>(find.byKey(const Key('calc_ves_input')));
      expect(vesField.controller?.text, isEmpty);
    });

    testWidgets('typing in divisa field updates bolivares field in real time', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter 10 in divisa
      await tester.enterText(find.byKey(const Key('calc_divisa_input')), '10');
      await tester.pumpAndSettle();

      final vesField = tester.widget<TextField>(find.byKey(const Key('calc_ves_input')));
      expect(vesField.controller?.text, '450.00');
    });

    testWidgets('typing in ves field updates divisa field in real time', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter 90 in VES field (90 / 45 = 2)
      await tester.enterText(find.byKey(const Key('calc_ves_input')), '90');
      await tester.pumpAndSettle();

      final divisaField = tester.widget<TextField>(find.byKey(const Key('calc_divisa_input')));
      expect(divisaField.controller?.text, '2.00');
    });

    testWidgets('selecting Euro BCV chip recalculates with EUR rate', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Set 10 in divisa
      await tester.enterText(find.byKey(const Key('calc_divisa_input')), '10');
      await tester.pumpAndSettle();

      // Tap Euro chip (rate = 49.0)
      await tester.tap(find.byKey(const Key('calc_chip_euro_bcv')));
      await tester.pumpAndSettle();

      final vesField = tester.widget<TextField>(find.byKey(const Key('calc_ves_input')));
      expect(vesField.controller?.text, '490.00');
    });

    testWidgets('selecting custom rate chip allows entering custom rate', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter 10 in divisa
      await tester.enterText(find.byKey(const Key('calc_divisa_input')), '10');
      await tester.pumpAndSettle();

      // Tap Custom rate chip
      await tester.tap(find.byKey(const Key('calc_chip_custom')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calc_custom_rate_input')), findsOneWidget);

      // Enter custom rate: 50.0
      await tester.enterText(find.byKey(const Key('calc_custom_rate_input')), '50');
      await tester.pumpAndSettle();

      final vesField = tester.widget<TextField>(find.byKey(const Key('calc_ves_input')));
      expect(vesField.controller?.text, '500.00');
    });

    testWidgets('tapping copiar Bs. button copies amount to clipboard and shows snackbar', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('calc_ves_input')), '150');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calc_copy_ves_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Monto en Bs. copiado:'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('tapping swap pill button swaps fields, changes copy button to divisa, and recalculates properly', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calc_swap_button')), findsOneWidget);
      expect(find.byKey(const Key('calc_copy_ves_button')), findsOneWidget);
      expect(find.text('Copiar Bs.'), findsOneWidget);

      // Tap swap button
      await tester.tap(find.byKey(const Key('calc_swap_button')));
      await tester.pumpAndSettle();

      // Copy button switched to divisa
      expect(find.byKey(const Key('calc_copy_divisa_button')), findsOneWidget);
      expect(find.text('Copiar USD'), findsOneWidget);

      // Enter 180 in VES field (at rate 45.0 -> 4.00 USD)
      await tester.enterText(find.byKey(const Key('calc_ves_input')), '180');
      await tester.pumpAndSettle();

      final divisaField = tester.widget<TextField>(find.byKey(const Key('calc_divisa_input')));
      expect(divisaField.controller?.text, '4.00');

      // Tap copy divisa button
      await tester.tap(find.byKey(const Key('calc_copy_divisa_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Monto en USD copiado:'), findsOneWidget);
      await tester.pumpAndSettle();

      // Swap back
      await tester.tap(find.byKey(const Key('calc_swap_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calc_copy_ves_button')), findsOneWidget);
      expect(find.text('Copiar Bs.'), findsOneWidget);
    });

    testWidgets('registrar gasto button is present and enabled with valid input', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final registerBtnFinder = find.byKey(const Key('calc_register_expense_button'));
      expect(registerBtnFinder, findsOneWidget);

      // Set 100 in VES
      await tester.enterText(find.byKey(const Key('calc_ves_input')), '100');
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(registerBtnFinder).enabled, isTrue);
    });

    testWidgets('renders BCV legal disclaimer card and official source link', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final disclaimerCard = find.byKey(const Key('calc_bcv_disclaimer_card'));
      expect(disclaimerCard, findsOneWidget);
      expect(find.byKey(const Key('calc_bcv_source_link')), findsOneWidget);
      expect(find.textContaining('Aviso legal sobre tasas oficiales'), findsOneWidget);
      expect(find.textContaining('www.bcv.org.ve'), findsOneWidget);
    });

    testWidgets('tapping clear icon clears divisa input field', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('calc_divisa_input')), '25');
      await tester.pumpAndSettle();

      final clearIconFinder = find.byIcon(Icons.clear);
      expect(clearIconFinder, findsWidgets);

      await tester.tap(clearIconFinder.first);
      await tester.pumpAndSettle();

      final divisaField = tester.widget<TextField>(find.byKey(const Key('calc_divisa_input')));
      expect(divisaField.controller?.text, isEmpty);
    });

    testWidgets('tapping swap button preserves EditableTextState focus on divisa TextField', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('calc_divisa_input')), '12');
      await tester.pumpAndSettle();

      final editableBefore = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('calc_divisa_input')),
          matching: find.byType(EditableText),
        ),
      );
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byKey(const Key('calc_swap_button')));
      await tester.pumpAndSettle();

      final editableAfter = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('calc_divisa_input')),
          matching: find.byType(EditableText),
        ),
      );
      expect(identical(editableBefore, editableAfter), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('tapping register when conversion rate is zero shows snackbar instead of throwing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calc_chip_custom')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('calc_ves_input')), '100');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('calc_register_expense_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calc_register_expense_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Ingresa o actualiza una tasa válida para convertir este monto.'),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });
  });
}

