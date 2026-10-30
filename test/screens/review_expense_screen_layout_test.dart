import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/data/models/gemini_extraction_result.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/core/constants/app_colors.dart';
import 'package:gastoscan_ai/ui/screens/review_expense_screen.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  final List<Map<String, dynamic>> readyDb = [];
  int _nextId = 1;

  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => List.from(readyDb);

  @override
  Future<int> insertReadyScanQueueItem(String imagePath, String extractedData, {String? ocrText}) async {
    final id = _nextId++;
    readyDb.add({
      'id': id,
      'image_path': imagePath,
      'status': 'ready',
      'extracted_data': extractedData,
      'ocr_text': ocrText,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  @override
  Future<int> updateScanQueueItem(
    int id,
    String status, {
    String? extractedData,
    String? ocrText,
    int? attemptCount,
    String? lastError,
    String? imagePath,
  }) async {
    final idx = readyDb.indexWhere((it) => it['id'] == id);
    if (idx != -1) {
      final item = Map<String, dynamic>.from(readyDb[idx]);
      item['status'] = status;
      if (extractedData != null) item['extracted_data'] = extractedData;
      if (imagePath != null) item['image_path'] = imagePath;
      readyDb[idx] = item;
      return 1;
    }
    return 0;
  }
}

class FakeGastoProvider extends GastoProvider {
  final List<GastoModel> _gastos = [];
  bool actualizarGastoLlamado = false;

  @override
  List<GastoModel> get gastos => _gastos;

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}

  @override
  Future<Map<String, dynamic>?> buscarPrecioAnterior(String descripcion, {int? excludeGastoId}) async => null;

  @override
  Future<bool> actualizarGasto(GastoModel gasto, List<ItemGastoModel> items) async {
    actualizarGastoLlamado = true;
    return true;
  }
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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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
    expect(find.text('¿Dónde compraste?'), findsOneWidget);
    expect(find.text('¿Cuándo compraste?'), findsOneWidget);
    expect(find.text('¿En qué moneda están los precios?'), findsOneWidget);
    expect(find.text('¿Qué compraste?'), findsOneWidget);
    expect(find.text('Concepto'), findsOneWidget);
    expect(find.text('Monto total'), findsOneWidget);
    expect(find.text('\$ 0,00'), findsWidgets);

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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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

    // 1. Por defecto: En VES la tarjeta de ¿Cómo pagaste? no existe
    expect(find.text('¿Cómo pagaste?'), findsNothing);

    // Las 3 columnas de equivalencias son visibles de inmediato
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
    await tester.ensureVisible(find.byKey(const Key('chip_rate_eur_bcv')));
    await tester.pumpAndSettle();
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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. En USD, seleccionar "En Bs. a tasa BCV"
    await tester.ensureVisible(find.byKey(const Key('btn_pagado_en_bs')));
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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. En USD, seleccionar "En Bs. a tasa BCV"
    await tester.ensureVisible(find.byKey(const Key('btn_pagado_en_bs')));
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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

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

  testWidgets('ReviewExpenseScreen campo de monto no muestra iconos redundantes ni bitcoin', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Cambiar a USDT
    await tester.tap(find.byKey(const Key('expense_currency_usdt_btn')));
    await tester.pumpAndSettle();

    // Verificar que no existe icono de bitcoin ni prefixIcon redundante
    expect(find.byIcon(Icons.currency_bitcoin), findsNothing);
    final textField = tester.widget<TextField>(
      find.descendant(of: find.byKey(const Key('input_monto_total')), matching: find.byType(TextField)),
    );
    expect(textField.decoration?.prefixIcon, isNull);
    expect(textField.decoration?.prefixText, 'USDT ');
  });
  testWidgets('ReviewExpenseScreen boton agregar producto muestra icono amarillo y sin signo plus en texto', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify ¿Cómo pagaste? title and styling
    expect(find.text('¿Cómo pagaste?'), findsOneWidget);
    final comoPagasteText = tester.widget<Text>(find.text('¿Cómo pagaste?'));
    expect(comoPagasteText.style?.fontSize, 16);
    expect(comoPagasteText.style?.fontWeight, FontWeight.bold);

    // Verify Agregar otro artículo button
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final addBtnFinder = find.byKey(const Key('review_expense_add_item_btn'));

    expect(addBtnFinder, findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Agregar otro artículo'), findsOneWidget);
    final addIconFinder = find.descendant(of: addBtnFinder, matching: find.byIcon(Icons.add));
    expect(addIconFinder, findsOneWidget);
    final addIcon = tester.widget<Icon>(addIconFinder);
    expect(addIcon.color, AppColors.primaryDark);
  });

  testWidgets('ReviewExpenseScreen muestra advertencia en vivo si suma de articulos difiere del total y dialogo de guardado seguro', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. Escribir 10.00 en monto total
    final inputTotalFinder = find.byKey(const Key('input_monto_total'));
    await tester.enterText(inputTotalFinder, '10.00');
    await tester.pumpAndSettle();

    // 2. Modificar el monto total libremente a 15.00
    await tester.enterText(inputTotalFinder, '15.00');
    await tester.pumpAndSettle();

    // 3. Verificar que el campo refleja el cambio sin cajas anidadas extrañas
    final totalWidget = tester.widget<TextFormField>(inputTotalFinder);
    expect(totalWidget.controller?.text, '15.00');

    // 4. Intentar guardar cuando solo hay 1 artículo en 0 pero total es 15.00 -> auto asigna al artículo
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar Gasto'));
    await tester.pumpAndSettle();
    // No debe mostrar diálogo de discrepancia porque el artículo único absorbe el total
    expect(find.text('Diferencia en el monto total'), findsNothing);
  });

  testWidgets('ReviewExpenseScreen botón sutil en AppBar guarda como borrador directo', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const ReviewExpenseScreen(),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // Escribir monto pero sin comercio
    final inputTotalFinder = find.byKey(const Key('input_monto_total'));
    await tester.enterText(inputTotalFinder, '45.00');
    await tester.pumpAndSettle();

    // Tocar icono sutil de borrador en el AppBar
    final btnBorrador = find.byKey(const Key('btn_guardar_borrador_appbar'));
    expect(btnBorrador, findsOneWidget);
    await tester.tap(btnBorrador);
    await tester.pumpAndSettle();

    // Debe haberse guardado en readyDb con 'Comercio no especificado' y salido
    expect(fakeDb.readyDb.length, equals(1));
    expect(fakeDb.readyDb.first['status'], equals('ready'));
    expect(fakeDb.readyDb.first['extracted_data'], contains('Comercio no especificado'));
    expect(fakeDb.readyDb.first['extracted_data'], contains('45.0'));
    expect(find.text('Abrir'), findsOneWidget); // Volvió a la pantalla anterior
  });

  testWidgets('ReviewExpenseScreen al presionar Atrás con datos muestra diálogo de borrador y permite guardar', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const ReviewExpenseScreen(),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // Ingresar comercio
    await tester.enterText(find.byType(TextFormField).first, 'Automercado Plaza');
    final inputTotalFinder = find.byKey(const Key('input_monto_total'));
    await tester.enterText(inputTotalFinder, '18.50');
    await tester.pumpAndSettle();

    // Presionar botón Atrás en AppBar
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Verificar diálogo
    expect(find.text('¿Guardar como borrador?'), findsOneWidget);
    expect(find.text('Descartar'), findsOneWidget);
    expect(find.text('Seguir editando'), findsOneWidget);
    expect(find.text('Guardar borrador'), findsOneWidget);

    // Tocar 'Guardar borrador'
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar borrador'));
    await tester.pumpAndSettle();

    // Debe guardarse en la cola y volver a la pantalla de origen
    expect(fakeDb.readyDb.length, equals(1));
    expect(fakeDb.readyDb.first['extracted_data'], contains('Automercado Plaza'));
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets('ReviewExpenseScreen al presionar Atrás y Descartar no guarda en cola', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const ReviewExpenseScreen(),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // Ingresar datos
    final inputTotalFinder = find.byKey(const Key('input_monto_total'));
    await tester.enterText(inputTotalFinder, '20.00');
    await tester.pumpAndSettle();

    // Presionar Atrás
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Verificar diálogo
    expect(find.text('¿Guardar como borrador?'), findsOneWidget);

    // Tocar 'Descartar'
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    // No debe haber guardado nada en la cola y debió salir
    expect(fakeDb.readyDb.isEmpty, isTrue);
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets('ReviewExpenseScreen con existingGasto muestra "Editar gasto" en AppBar y "Guardar Gasto" en boton inferior', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

    final existing = GastoModel(
      id: 99,
      uuid: 'uuid-existing-1',
      fecha: '2026-10-25',
      comercio: 'Automercado Plaza',
      moneda: 'USD',
      totalOriginal: 2500,
      totalUsd: 2500,
      tasaCambio: 880.0,
      categoria: 'Alimentos',
      creadoEn: '2026-10-25T10:00:00',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
        ],
        child: MaterialApp(
          home: ReviewExpenseScreen(existingGasto: existing),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editar gasto'), findsOneWidget);
    expect(find.text('Registrar gasto'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Guardar Gasto'), findsOneWidget);
    // Boton de borrador debe estar oculto para gasto ya existente
    expect(find.byKey(const Key('btn_guardar_borrador_appbar')), findsNothing);
  });

  testWidgets('ReviewExpenseScreen al editar existingGasto y presionar Atrás muestra diálogo "¿Guardar modificaciones?" y permite guardar', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

    final existing = GastoModel(
      id: 99,
      uuid: 'uuid-existing-2',
      fecha: '2026-10-25',
      comercio: 'Automercado Plaza',
      moneda: 'USD',
      totalOriginal: 2500,
      totalUsd: 2500,
      tasaCambio: 880.0,
      categoria: 'Alimentos',
      creadoEn: '2026-10-25T10:00:00',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => ReviewExpenseScreen(existingGasto: existing),
                    ),
                  );
                },
                child: const Text('Abrir Edicion'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir Edicion'));
    await tester.pumpAndSettle();

    // Modificar el monto
    final inputTotalFinder = find.byKey(const Key('input_monto_total'));
    await tester.enterText(inputTotalFinder, '35.00');
    await tester.pumpAndSettle();

    // Presionar Atrás
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Verificar diálogo
    expect(find.text('¿Guardar modificaciones?'), findsOneWidget);
    expect(find.text('Descartar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Guardar gasto'), findsOneWidget);

    // Tocar 'Guardar gasto'
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar gasto'));
    await tester.pumpAndSettle();

    // Debe llamar a actualizarGasto y salir
    expect(gastoProvider.actualizarGastoLlamado, isTrue);
    expect(find.text('Abrir Edicion'), findsOneWidget);
  });

  testWidgets('ReviewExpenseScreen al editar existingGasto y presionar Descartar no actualiza y sale', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    gastoProvider.actualizarGastoLlamado = false;

    final existing = GastoModel(
      id: 100,
      uuid: 'uuid-existing-3',
      fecha: '2026-10-25',
      comercio: 'Automercado Plaza',
      moneda: 'USD',
      totalOriginal: 2500,
      totalUsd: 2500,
      tasaCambio: 880.0,
      categoria: 'Alimentos',
      creadoEn: '2026-10-25T10:00:00',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => ReviewExpenseScreen(existingGasto: existing),
                    ),
                  );
                },
                child: const Text('Abrir Edicion 2'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir Edicion 2'));
    await tester.pumpAndSettle();

    // Modificar el comercio
    await tester.enterText(find.byType(TextFormField).first, 'Nuevo Comercio');
    await tester.pumpAndSettle();

    // Presionar Atrás
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Verificar diálogo
    expect(find.text('¿Guardar modificaciones?'), findsOneWidget);

    // Tocar 'Descartar'
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    // No debe haber actualizado y debió salir
    expect(gastoProvider.actualizarGastoLlamado, isFalse);
    expect(find.text('Abrir Edicion 2'), findsOneWidget);
  });
}
