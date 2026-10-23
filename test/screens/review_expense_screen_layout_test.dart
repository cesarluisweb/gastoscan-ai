import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/gemini_extraction_result.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/review_expense_screen.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];
}

class FakeGastoProvider extends GastoProvider {
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
  double tasaUsd = 881.88;
  double tasaEur = 950.0;
  double tasaUsdt = 900.0;

  @override
  double get tasaCambioVesUsd => tasaUsd;

  @override
  double get tasaCambioVesEur => tasaEur;

  @override
  double get tasaCambioVesUsdt => tasaUsdt;

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
    SharedPreferences.setMockInitialValues({
      'cached_rate_usd': 881.88,
      'cached_rate_eur': 950.0,
      'cached_rate_usdt': 900.0,
    });
    fakeDb = FakeDatabaseHelper();
    scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
    gastoProvider = FakeGastoProvider();
    settingsProvider = FakeSettingsProvider();
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
      ],
      child: const MaterialApp(
        home: ReviewExpenseScreen(),
      ),
    );
  }

  testWidgets('ReviewExpenseScreen renders form and does not collapse body due to bottomNavigationBar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    // Verify AppBar
    expect(find.text('Registrar gasto'), findsOneWidget);

    // Verify bottom action button exists
    expect(find.text('Guardar Gasto'), findsOneWidget);

    // Verify body form fields are visible and rendered
    expect(find.text('Información General'), findsOneWidget);
    expect(find.text('Comercio o Beneficiario (opcional)'), findsOneWidget);

    // Ensure the ListView in body has non-zero height
    final listViewFinder = find.byType(ListView);
    expect(listViewFinder, findsOneWidget);
    final Size listViewSize = tester.getSize(listViewFinder);
    expect(listViewSize.height, greaterThan(300));

    // Ensure the bottom navigation bar has a compact height, not taking over the screen
    final buttonFinder = find.widgetWithText(ElevatedButton, 'Guardar Gasto');
    expect(buttonFinder, findsOneWidget);
    final Size buttonSize = tester.getSize(buttonFinder);
    expect(buttonSize.height, inInclusiveRange(40, 60));
  });

  testWidgets('ReviewExpenseScreen en USD y EUR selecciona En divisa por defecto y en primera posicion', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. Verificar que los 3 botones de forma de pago existen y que 'En divisa' está en primer lugar a la izquierda
    final divisaPos = tester.getTopLeft(find.byKey(const Key('btn_pagado_en_divisa')));
    final bsBcvPos = tester.getTopLeft(find.byKey(const Key('btn_pagado_en_bs')));
    final bsUsdtPos = tester.getTopLeft(find.byKey(const Key('btn_pagado_en_bs_usdt')));
    expect(divisaPos.dx, lessThan(bsBcvPos.dx));
    expect(bsBcvPos.dx, lessThan(bsUsdtPos.dx));

    // 2. En USD por defecto está activo 'En divisa': muestra cintillo_divisa_info y oculta input_total_bs_manual
    expect(find.byKey(const Key('cintillo_divisa_info')), findsOneWidget);
    expect(find.byKey(const Key('input_total_bs_manual')), findsNothing);
    expect(find.textContaining('Se guardará en USD'), findsOneWidget);

    // 3. Al cambiar a EUR en gasto nuevo, 'En divisa' sigue siendo la opción por defecto
    await tester.tap(find.byKey(const Key('expense_currency_eur_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cintillo_divisa_info')), findsOneWidget);
    expect(find.byKey(const Key('input_total_bs_manual')), findsNothing);
    expect(find.textContaining('Se guardará en EUR'), findsOneWidget);
  });

  testWidgets('ReviewExpenseScreen uses historical BCV rate (< 50.0) for 2023 dates and calculates VES properly', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'cached_rate_usd': 881.88,
      'cached_rate_eur': 950.0,
      'cached_rate_usdt': 900.0,
      'cached_rate_USD_2023-10-20': 34.86,
      'cached_rate_EUR_2023-10-20': 36.86,
      'cached_rate_USDT_2023-10-20': 34.86,
    });

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
      ],
      child: MaterialApp(
        home: ReviewExpenseScreen(
          extractedData: GeminiExtractionResult(
            comercio: 'Automercado 2023',
            fecha: '2023-10-20',
            moneda: 'USD',
            totalOriginal: 100.0,
            impuestoIva: 0.0,
            items: const [],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Asegurar scroll visible hasta el botón de forma de pago
    await tester.ensureVisible(find.byKey(const Key('btn_pagado_en_bs')));
    await tester.pumpAndSettle();

    // Seleccionar explícitamente "En Bs. a tasa BCV" (2.ª opción)
    await tester.tap(find.byKey(const Key('btn_pagado_en_bs')));
    await tester.pumpAndSettle();

    // Scroll hasta los campos resultantes
    await tester.ensureVisible(find.byKey(const Key('input_total_bs_manual')));
    await tester.pumpAndSettle();

    // Verify rate is 34.86, NOT today's rate 881.88
    expect(find.text('Tasa BCV: Bs. 34.86'), findsOneWidget);
    expect(find.text('Tasa BCV: Bs. 881.88'), findsNothing);

    // Verify Bolivares finales matches 100 * 34.86 = 3486.00 (not 88188.00)
    final bsManualField = tester.widget<TextFormField>(find.byKey(const Key('input_total_bs_manual')));
    expect(bsManualField.controller?.text, '3486.00');
  });

  testWidgets('ReviewExpenseScreen en VES aplica divulgacion progresiva: muestra 3 columnas y despliega chips al tocar Ajustar tasas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'cached_rate_usd': 881.88,
      'cached_rate_eur': 950.0,
      'cached_rate_usdt': 900.0,
    });

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
      ],
      child: MaterialApp(
        home: ReviewExpenseScreen(
          extractedData: GeminiExtractionResult(
            comercio: 'Abasto Central',
            fecha: DateTime.now().toIso8601String().substring(0, 10),
            moneda: 'VES',
            totalOriginal: 9000.0, // Bs. 9.000
            impuestoIva: 0.0,
            items: const [],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Por defecto (estado colapsado): Las 3 columnas de equivalencias son visibles de inmediato
    expect(find.text('Equiv. USD (BCV)'), findsOneWidget);
    expect(find.text('Equiv. EUR (BCV)'), findsOneWidget);
    expect(find.text('Equiv. USDT (P2P)'), findsOneWidget);
    expect(find.textContaining('\$'), findsWidgets);
    expect(find.textContaining('€'), findsWidgets);
    expect(find.textContaining('USDT'), findsWidgets);

    // Los chips y el campo manual de tasa están ocultos por defecto
    expect(find.byKey(const Key('chip_rate_usd_bcv')), findsNothing);
    expect(find.byKey(const Key('chip_rate_eur_bcv')), findsNothing);
    expect(find.byKey(const Key('input_tasa_ves')), findsNothing);

    // 2. Al tocar el botón 'Ajustar tasas ▾' se despliegan los 3 chips y la caja de edición de tasa
    expect(find.byKey(const Key('btn_ajustar_tasas_ves')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('btn_ajustar_tasas_ves')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_ajustar_tasas_ves')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chip_rate_usd_bcv')), findsOneWidget);
    expect(find.byKey(const Key('chip_rate_eur_bcv')), findsOneWidget);
    expect(find.byKey(const Key('chip_rate_usdt_binance')), findsOneWidget);
    expect(find.byKey(const Key('input_tasa_ves')), findsOneWidget);

    // 3. Al tocar el chip 'Euro BCV' y editar manualmente la tasa, aparece el botón Icons.restart_alt
    await tester.tap(find.byKey(const Key('chip_rate_eur_bcv')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('input_tasa_ves')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('input_tasa_ves')), '1000.00');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    expect(find.text('Tasa personalizada activa'), findsOneWidget);

    // Al tocar restaurar, vuelve a la tasa oficial (950.00)
    await tester.ensureVisible(find.byKey(const Key('btn_restore_official_rate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_restore_official_rate')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.restart_alt), findsNothing);
  });

  testWidgets('ReviewExpenseScreen en USDT muestra cintillo informativo multimoneda limpio', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
      ],
      child: MaterialApp(
        home: ReviewExpenseScreen(
          extractedData: GeminiExtractionResult(
            comercio: 'Recarga Binance',
            fecha: DateTime.now().toIso8601String().substring(0, 10),
            moneda: 'USDT',
            totalOriginal: 10.0,
            impuestoIva: 0.0,
            items: const [],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cintillo_usdt_info')), findsOneWidget);
    expect(find.textContaining('Se guardará en USDT'), findsOneWidget);
    expect(find.textContaining('USD 1:1'), findsOneWidget);
  });
}
