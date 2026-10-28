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
import 'package:gastoscan_ai/core/constants/app_colors.dart';
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
  String monedaPref = 'USD';

  @override
  double get tasaCambioVesUsd => tasaUsd;

  @override
  double get tasaCambioVesEur => tasaEur;

  @override
  double get tasaCambioVesUsdt => tasaUsdt;

  @override
  String get monedaPrincipal => monedaPref;

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
    expect(find.text('¿Dónde compraste? (opcional)'), findsOneWidget);

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

    // Verify ¿Cómo pagaste? title and styling
    expect(find.text('¿Cómo pagaste?'), findsOneWidget);
    final comoPagasteText = tester.widget<Text>(find.text('¿Cómo pagaste?'));
    expect(comoPagasteText.style?.fontSize, 16);
    expect(comoPagasteText.style?.fontWeight, FontWeight.bold);

    // Verify Agregar producto button (without +) and icon color
    await tester.ensureVisible(find.byKey(const Key('review_expense_add_item_btn')));
    await tester.pumpAndSettle();
    final addBtnFinder = find.byKey(const Key('review_expense_add_item_btn'));
    expect(addBtnFinder, findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Agregar producto'), findsOneWidget);
    final addIconFinder = find.descendant(of: addBtnFinder, matching: find.byIcon(Icons.add));
    expect(addIconFinder, findsOneWidget);
    final addIcon = tester.widget<Icon>(addIconFinder);
    expect(addIcon.color, AppColors.primaryDark);
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
    expect(find.textContaining('Tasa BCV: Bs. 34.86'), findsOneWidget);
    expect(find.textContaining('Tasa BCV: Bs. 881.88'), findsNothing);

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
    expect(find.text('Equiv. USD (BCV)'), findsWidgets);
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

  testWidgets('ReviewExpenseScreen selecciona monedaPrincipal de Settings para nuevo gasto manual', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    settingsProvider.monedaPref = 'VES';

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Monto total (Bs.)'), findsOneWidget);
    expect(find.text('Equiv. USD (BCV)'), findsWidgets);
  });

  testWidgets('ReviewExpenseScreen preserva moneda de GeminiExtractionResult sobre monedaPrincipal', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    settingsProvider.monedaPref = 'VES';

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
      ],
      child: MaterialApp(
        home: ReviewExpenseScreen(
          extractedData: GeminiExtractionResult(
            comercio: 'Café Paris',
            fecha: DateTime.now().toIso8601String().substring(0, 10),
            moneda: 'EUR',
            totalOriginal: 25.0,
            impuestoIva: 0.0,
            items: const [],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Se guardará en EUR'), findsOneWidget);
    expect(find.text('Monto total (Bs.)'), findsNothing);
    expect(find.text('Monto total (€)'), findsOneWidget);
  });

  testWidgets('ReviewExpenseScreen re-tap en moneda activa es un no-op idempotente', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. En USD, seleccionar "En Bs. a tasa BCV"
    await tester.tap(find.byKey(const Key('btn_pagado_en_bs')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('input_total_bs_manual')), findsOneWidget);

    // 2. Modificar el campo de bolívares finales
    await tester.enterText(find.byKey(const Key('input_total_bs_manual')), '750.50');
    await tester.pumpAndSettle();

    // 3. Volver a pulsar el botón de moneda activa (USD)
    await tester.tap(find.byKey(const Key('expense_currency_usd_btn')));
    await tester.pumpAndSettle();

    // 4. Verificar que no se restableció el método de pago ni se borraron los bolívares
    expect(find.byKey(const Key('input_total_bs_manual')), findsOneWidget);
    final bsManualField = tester.widget<TextFormField>(find.byKey(const Key('input_total_bs_manual')));
    expect(bsManualField.controller?.text, '750.50');
  });

  testWidgets('ReviewExpenseScreen alternar entre USD y EUR conserva el metodo de liquidacion seleccionado', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. En USD, seleccionar "En Bs. a tasa BCV"
    await tester.tap(find.byKey(const Key('btn_pagado_en_bs')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('input_total_bs_manual')), findsOneWidget);

    // 2. Cambiar moneda a EUR
    await tester.tap(find.byKey(const Key('expense_currency_eur_btn')));
    await tester.pumpAndSettle();

    // 3. En EUR debe seguir activo "En Bs. a tasa BCV" (no restablecer a "En divisa")
    expect(find.byKey(const Key('input_total_bs_manual')), findsOneWidget);
    expect(find.byKey(const Key('cintillo_divisa_info')), findsNothing);
  });

  testWidgets('ReviewExpenseScreen conserva el valor nominal introducido al cambiar de moneda', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. Escribir 100 en el campo de monto total en USD
    final inputTotalFinder = find.byKey(const Key('input_monto_total'));
    expect(inputTotalFinder, findsOneWidget);
    await tester.enterText(inputTotalFinder, '100.00');
    await tester.pumpAndSettle();

    // 2. Cambiar a VES
    await tester.tap(find.byKey(const Key('expense_currency_ves_btn')));
    await tester.pumpAndSettle();

    // 3. El valor nominal sigue siendo 100.00, no convertido a 100 * tasa
    expect(inputTotalFinder, findsOneWidget);
    final vesField = tester.widget<TextFormField>(inputTotalFinder);
    expect(vesField.controller?.text, '100.00');
    expect(find.text('Monto total (Bs.)'), findsOneWidget);
  });

  testWidgets('ReviewExpenseScreen formulario vacio no escribe 0.00 en controladores derivados', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final inputTotalFinder = find.byKey(const Key('input_monto_total'));
    expect(inputTotalFinder, findsOneWidget);
    final totalField = tester.widget<TextFormField>(inputTotalFinder);
    expect(totalField.controller?.text, isEmpty);
    expect(totalField.controller?.text, isNot('0.00'));
  });

  testWidgets('ReviewExpenseScreen gasto indexado existente preserva bolivares reales cobrados', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final gastoIndexado = GastoModel(
      id: 99,
      uuid: 'test-uuid-indexed-99',
      comercio: 'Supermercado Central',
      categoria: 'Alimentación',
      totalOriginal: 50000, // 500.00 Bs
      totalUsd: 1000,      // 10.00 USD
      tasaCambio: 50.0,
      fuenteTasaCambio: 'BCV (Pago en Bs. indexado a USD)',
      moneda: 'VES',
      fecha: '2024-05-10',
      creadoEn: '2024-05-10T10:00:00Z',
      items: const [],
    );

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
      ],
      child: MaterialApp(
        home: ReviewExpenseScreen(existingGasto: gastoIndexado),
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Comprobar que carga 10.00 en monto total y 500.00 en Bs finales
    final inputTotal = tester.widget<TextFormField>(find.byKey(const Key('input_monto_total')));
    expect(inputTotal.controller?.text, '10');
    final bsField = tester.widget<TextFormField>(find.byKey(const Key('input_total_bs_manual')));
    expect(bsField.controller?.text, '500.00');

    // 2. Alternar a VES
    await tester.tap(find.byKey(const Key('expense_currency_ves_btn')));
    await tester.pumpAndSettle();

    // En VES el monto nominal sigue siendo 10.00 (nunca se sobreescribe al cambiar de moneda)
    final vesTotal = tester.widget<TextFormField>(find.byKey(const Key('input_monto_total')));
    expect(vesTotal.controller?.text, '10');

    // 3. Volver a USD
    await tester.tap(find.byKey(const Key('expense_currency_usd_btn')));
    await tester.pumpAndSettle();

    // En USD mantiene los 10.00 y conserva los 500.00 Bs cobrados en su campo
    final bsFieldRestored = tester.widget<TextFormField>(find.byKey(const Key('input_total_bs_manual')));
    expect(bsFieldRestored.controller?.text, '500.00');
  });

  testWidgets('ReviewExpenseScreen bloquea guardado si tasa en bolivares no es valida', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'cached_rate_usd': 0.0,
      'cached_rate_eur': 0.0,
      'cached_rate_usdt': 0.0,
    });

    settingsProvider.tasaUsd = 0.0;
    settingsProvider.monedaPref = 'VES';

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Escribir monto 500 Bs
    final inputVesFinder = find.byKey(const Key('input_monto_total'));
    await tester.enterText(inputVesFinder, '500.00');
    await tester.pumpAndSettle();

    // Ajustar tasa a 1.0 (invalida para VES)
    await tester.ensureVisible(find.byKey(const Key('btn_ajustar_tasas_ves')));
    await tester.tap(find.byKey(const Key('btn_ajustar_tasas_ves')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('input_tasa_ves')));
    await tester.enterText(find.byKey(const Key('input_tasa_ves')), '1.0');
    await tester.pumpAndSettle();

    // Tocar Guardar Gasto
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar Gasto'));
    await tester.pump();

    // Verificar que aparece el SnackBar de error
    expect(find.textContaining('No hay una tasa de cambio válida'), findsOneWidget);
  });

  testWidgets('ReviewExpenseScreen en USD pagado en Bs permite ajuste bidireccional entre tasa cobrada y monto en Bs', (tester) async {
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

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. Escribir 10.00 en monto total (USD)
    final inputTotalFinder = find.byKey(const Key('input_monto_total'));
    await tester.enterText(inputTotalFinder, '10.00');
    await tester.pumpAndSettle();

    // 2. Seleccionar forma de pago "En Bs. a tasa BCV"
    await tester.ensureVisible(find.byKey(const Key('btn_pagado_en_bs')));
    await tester.tap(find.byKey(const Key('btn_pagado_en_bs')));
    await tester.pumpAndSettle();

    // 3. Verificar que por defecto calcula 10 * 881.88 = 8818.80
    final bsManualFieldFinder = find.byKey(const Key('input_total_bs_manual'));
    expect(bsManualFieldFinder, findsOneWidget);
    var bsField = tester.widget<TextFormField>(bsManualFieldFinder);
    expect(bsField.controller?.text, '8818.80');

    // 4. El campo de ajuste de tasa está oculto por defecto
    expect(find.byKey(const Key('input_tasa_liquidacion')), findsNothing);

    // 5. Tocar el botón "Ajustar tasa ▾"
    await tester.ensureVisible(find.byKey(const Key('btn_ajustar_tasa_liquidacion')));
    await tester.tap(find.byKey(const Key('btn_ajustar_tasa_liquidacion')));
    await tester.pumpAndSettle();

    // 6. El campo input_tasa_liquidacion se despliega con la tasa oficial
    final rateFieldFinder = find.byKey(const Key('input_tasa_liquidacion'));
    expect(rateFieldFinder, findsOneWidget);
    var rateField = tester.widget<TextFormField>(rateFieldFinder);
    expect(rateField.controller?.text, '881.88');

    // 7. Modificar tasa cobrada en caja a 900.00 -> el monto en Bs se actualiza a 9000.00
    await tester.enterText(rateFieldFinder, '900.00');
    await tester.pumpAndSettle();
    bsField = tester.widget<TextFormField>(bsManualFieldFinder);
    expect(bsField.controller?.text, '9000.00');

    // 8. Modificar monto en Bs directamente a 8500.00 -> la tasa cobrada se recalcula a 850.00 (8500 / 10)
    await tester.enterText(bsManualFieldFinder, '8500.00');
    await tester.pumpAndSettle();
    rateField = tester.widget<TextFormField>(rateFieldFinder);
    expect(rateField.controller?.text, '850.00');

    // 9. Restaurar tasa oficial con el botón Icons.restart_alt
    final restoreBtnFinder = find.byKey(const Key('btn_restore_official_liquidation_rate'));
    expect(restoreBtnFinder, findsOneWidget);
    await tester.tap(restoreBtnFinder);
    await tester.pumpAndSettle();

    // 10. La tasa vuelve a 881.88 y el monto en Bs a 8818.80
    rateField = tester.widget<TextFormField>(rateFieldFinder);
    expect(rateField.controller?.text, '881.88');
    bsField = tester.widget<TextFormField>(bsManualFieldFinder);
    expect(bsField.controller?.text, '8818.80');
  });

  testWidgets('ReviewExpenseScreen muestra icono de billetera para USDT y no bitcoin', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Cambiar a USDT
    await tester.tap(find.byKey(const Key('expense_currency_usdt_btn')));
    await tester.pumpAndSettle();

    // Verificar que no existe icono de bitcoin y existe account_balance_wallet_outlined
    expect(find.byIcon(Icons.currency_bitcoin), findsNothing);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsWidgets);
  });
}
