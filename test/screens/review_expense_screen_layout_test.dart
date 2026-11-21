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
  GastoModel? ultimoGastoGuardado;
  List<ItemGastoModel>? ultimosItemsGuardados;
  Map<String, PriceHistory> mockPriceHistories = const {};

  @override
  List<GastoModel> get gastos => _gastos;

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}

  @override
  Future<Map<String, PriceHistory>> buscarHistorialPrecios(
    List<String> descripcionesNormalizadas, {
    int? excludeGastoId,
    String? comercioActual,
    int diasVentana = 60,
    DateTime? referenceDate,
  }) async {
    if (mockPriceHistories.isEmpty) return const {};
    final out = <String, PriceHistory>{};
    for (final d in descripcionesNormalizadas) {
      final h = mockPriceHistories[d];
      if (h != null) out[d] = h;
    }
    return out;
  }

  @override
  Future<Map<String, dynamic>?> buscarPrecioAnterior(String descripcion, {int? excludeGastoId}) async => null;

  @override
  Future<bool> actualizarGasto(GastoModel gasto, List<ItemGastoModel> items) async {
    actualizarGastoLlamado = true;
    ultimoGastoGuardado = gasto;
    ultimosItemsGuardados = items;
    return true;
  }

  @override
  Future<bool> agregarGasto(GastoModel gasto, List<ItemGastoModel> items, {List<int>? shoppingItemIds}) async {
    ultimoGastoGuardado = gasto;
    ultimosItemsGuardados = items;
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
  bool get avisoGaleriaMostrado => true;

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
    expect(find.text('¿Dónde gastaste? (opcional)'), findsOneWidget);
    expect(find.text('¿Cuándo gastaste?'), findsOneWidget);
    expect(find.text('¿En qué moneda están los precios?'), findsOneWidget);
    expect(find.text('¿En qué gastaste?'), findsOneWidget);
    expect(find.text('Concepto'), findsOneWidget);
    expect(find.text('Monto total'), findsOneWidget);
    expect(find.text('\$ 0,00'), findsWidgets);

    // Verify TextCapitalization on store and concept fields
    final storeField = tester.widget<TextField>(
      find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == '¿Dónde gastaste? (opcional)'),
    );
    expect(storeField.textCapitalization, TextCapitalization.words);

    final conceptField = tester.widget<TextField>(
      find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Concepto'),
    );
    expect(conceptField.textCapitalization, TextCapitalization.sentences);

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
    expect(find.byKey(const Key('btn_pagado_en_bs_usdt')), findsNothing);
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
    await tester.pump(const Duration(milliseconds: 300));

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

  testWidgets('ReviewExpenseScreen al presionar Atrás sin datos sale directamente sin mostrar diálogo de borrador', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    // No se escribe ningún comercio, monto ni artículo. Presionar Atrás directamente
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // No debe aparecer diálogo de borrador ni de descartar
    expect(find.text('¿Guardar como borrador?'), findsNothing);
    expect(find.text('Descartar'), findsNothing);
    // Debe haber vuelto directamente a la pantalla de origen
    expect(find.text('Abrir'), findsOneWidget);
    expect(fakeDb.readyDb, isEmpty);
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

    if (find.text('¿Confirmas el cambio de monto?').evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Actualizar monto'));
      await tester.pumpAndSettle();
    }

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

  testWidgets('ReviewExpenseScreen autocategoriza concepto, actualiza entre categorias y respeta seleccion manual', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Localizar el campo Concepto
    final conceptFinder = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Concepto',
    );
    expect(conceptFinder, findsOneWidget);

    // Inicialmente está en Otros
    expect(find.text('Otros'), findsWidgets);

    // 1. Escribir 'Harina PAN' -> Se reclasifica automáticamente a Alimentación
    await tester.enterText(conceptFinder, 'Harina PAN');
    await tester.pumpAndSettle();
    expect(find.text('Alimentación'), findsWidgets);

    // 2. Cambiar concepto a 'Carrera de taxi' -> Cambia automáticamente a Transporte (no se queda atrapado)
    await tester.enterText(conceptFinder, 'Carrera de taxi');
    await tester.pumpAndSettle();
    expect(find.text('Transporte'), findsWidgets);

    // 3. Borrar el concepto -> Regresa automáticamente a Otros
    await tester.enterText(conceptFinder, '');
    await tester.pumpAndSettle();
    expect(find.text('Otros'), findsWidgets);

    // 4. Escribir 'Medicina' -> Cambia a Salud
    await tester.enterText(conceptFinder, 'Medicina');
    await tester.pumpAndSettle();
    expect(find.text('Salud'), findsWidgets);

    // 5. Seleccionar manualmente 'Hogar' en el Dropdown
    final dropdownFinder = find.byType(DropdownButton<String>).first;
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // Tocar la opción 'Hogar' en el menú abierto
    final hogarItemFinder = find.widgetWithText(DropdownMenuItem<String>, 'Hogar').last;
    await tester.tap(hogarItemFinder);
    await tester.pumpAndSettle();
    expect(find.text('Hogar'), findsWidgets);

    // 6. Cambiar concepto a 'Pollo beneficiado' -> Como fue manual, DEBE PERMANECER en Hogar
    await tester.enterText(conceptFinder, 'Pollo beneficiado');
    await tester.pumpAndSettle();
    expect(find.text('Hogar'), findsWidgets);
    expect(find.text('Alimentación'), findsNothing);
  });

  group('Sprint Teléfono - Pruebas Obligatorias ReviewExpenseScreen', () {
    testWidgets('1. Inicialización con moneda principal distinta de USD', (tester) async {
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
      expect(find.text('Precios en Bs.'), findsOneWidget);
      expect(find.text('Equiv. USD (BCV)'), findsWidgets);
    });

    testWidgets('2. Re-selección de la moneda activa sin efectos secundarios', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final totalInput = find.widgetWithText(TextFormField, r'Monto total ($)');
      await tester.enterText(totalInput, '120');
      await tester.pumpAndSettle();

      expect(find.text('120'), findsWidgets);

      await tester.tap(find.byKey(const Key('expense_currency_usd_btn')));
      await tester.pumpAndSettle();

      expect(find.text('120'), findsWidgets);
      expect(find.byKey(const Key('cintillo_divisa_info')), findsOneWidget);
    });

    testWidgets('3. Cambio USD a VES sin conversión del importe escrito', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final totalInput = find.widgetWithText(TextFormField, r'Monto total ($)');
      await tester.enterText(totalInput, '150');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('expense_currency_ves_btn')));
      await tester.pumpAndSettle();

      final totalInputVes = find.widgetWithText(TextFormField, 'Monto total (Bs.)');
      expect(totalInputVes, findsOneWidget);
      final formField = tester.widget<TextFormField>(totalInputVes);
      expect(formField.controller?.text, equals('150'));
    });

    testWidgets('4. Cambio VES a EUR sin conversión de artículos', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      settingsProvider.monedaPref = 'VES';
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final precioFinder = find.widgetWithText(TextFormField, 'Precio');
      await tester.enterText(precioFinder, '75');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('expense_currency_eur_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Precios en €'), findsOneWidget);
      expect(find.text('75'), findsWidgets);
    });

    testWidgets('5. Conservación del importe original después de cambiar moneda', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final totalInput = find.widgetWithText(TextFormField, r'Monto total ($)');
      await tester.enterText(totalInput, '300');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('expense_currency_ves_btn')));
      await tester.pumpAndSettle();
      final vesField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Monto total (Bs.)'));
      expect(vesField.controller?.text, equals('300'));

      await tester.tap(find.byKey(const Key('expense_currency_eur_btn')));
      await tester.pumpAndSettle();
      final eurField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Monto total (€)'));
      expect(eurField.controller?.text, equals('300'));

      await tester.tap(find.byKey(const Key('expense_currency_usdt_btn')));
      await tester.pumpAndSettle();
      final usdtField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Monto total (USDT)'));
      expect(usdtField.controller?.text, equals('300'));
    });

    testWidgets('6. Cambio de fecha en un gasto indexado sin perder el importe pagado', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final gastoIndexado = GastoModel(
        id: 12,
        uuid: 'gasto-indexado-uuid',
        fecha: '2026-02-10',
        creadoEn: '2026-02-10T12:00:00Z',
        comercio: 'Automercado Indexado',
        moneda: 'VES',
        totalOriginal: 400000,
        totalUsd: 10000,
        tasaCambio: 40.0,
        fuenteTasaCambio: 'BCV (Pago en Bs. indexado a USD)',
        categoria: 'Alimentación',
        items: [
          ItemGastoModel(
            descripcion: 'Compra semanal',
            cantidad: 1.0,
            precioUnitario: 400000,
            total: 400000,
            categoria: 'Alimentación',
          ),
        ],
      );

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
        ],
        child: MaterialApp(
          home: ReviewExpenseScreen(
            existingGasto: gastoIndexado,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final bsManualInput = find.byKey(const Key('input_total_bs_manual'));
      expect(bsManualInput, findsOneWidget);
      final bsField = tester.widget<TextFormField>(bsManualInput);
      expect(bsField.controller?.text, equals('4000.00'));

      await tester.tap(find.text('¿Cuándo gastaste?'));
      await tester.pumpAndSettle();

      final okButton = find.text('OK');
      if (okButton.evaluate().isNotEmpty) {
        await tester.tap(okButton);
        await tester.pumpAndSettle();
      }

      final bsFieldAfter = tester.widget<TextFormField>(bsManualInput);
      expect(bsFieldAfter.controller?.text, equals('4000.00'));
    });

    testWidgets('7. Conservación de la tasa manual al volver a seleccionar la moneda activa', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      settingsProvider.monedaPref = 'VES';
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_ajustar_tasas_ves')));
      await tester.pumpAndSettle();

      final tasaInput = find.byKey(const Key('input_tasa_ves'));
      await tester.enterText(tasaInput, '88.50');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('expense_currency_ves_btn')));
      await tester.pumpAndSettle();

      final tasaField = tester.widget<TextFormField>(find.byKey(const Key('input_tasa_ves')));
      expect(tasaField.controller?.text, equals('88.50'));
    });

    testWidgets('8. Valores correctos en el objeto o comando final enviado al guardado', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final storeField = find.widgetWithText(TextFormField, '¿Dónde gastaste? (opcional)');
      await tester.enterText(storeField, 'Panadería El Sol');
      await tester.pumpAndSettle();

      final conceptField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Concepto',
      );
      await tester.enterText(conceptField, 'Pan de jamón');
      await tester.pumpAndSettle();

      final totalInput = find.widgetWithText(TextFormField, r'Monto total ($)');
      await tester.enterText(totalInput, '25.00');
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(ElevatedButton, 'Guardar Gasto');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(gastoProvider.ultimoGastoGuardado, isNotNull);
      final guardado = gastoProvider.ultimoGastoGuardado!;
      expect(guardado.comercio, equals('Panadería El Sol'));
      expect(guardado.moneda, equals('USD'));
      expect(guardado.totalOriginal, equals(2500));
      expect(guardado.totalUsd, equals(2500));
      expect(gastoProvider.ultimosItemsGuardados, isNotNull);
      expect(gastoProvider.ultimosItemsGuardados!.first.descripcion, equals('Pan de jamón'));
    });

    testWidgets('9. Muestra bloque de guardado al final del scroll cuando el teclado esta abierto', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inline_keyboard_save_section')), findsNothing);
      expect(find.byKey(const Key('btn_guardar_gasto')), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inline_keyboard_save_section')), findsOneWidget);
      expect(find.byKey(const Key('btn_guardar_gasto')), findsOneWidget);

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inline_keyboard_save_section')), findsNothing);
      expect(find.byKey(const Key('btn_guardar_gasto')), findsOneWidget);
    });

    testWidgets('10. Tarjetas de items: sin numeracion, con etiqueta Concepto, categoria en caja y deshacer al eliminar', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final extractedWithTwoItems = GeminiExtractionResult(
        comercio: 'Automercado Plaza',
        fecha: '2026-11-18',
        moneda: 'USD',
        totalOriginal: 20.0,
        impuestoIva: 0.0,
        items: [
          ItemGastoModel(
            descripcion: 'Patilla (E)',
            cantidad: 2.0,
            precioUnitario: 500,
            total: 1000,
            categoria: 'Alimentación',
          ),
          ItemGastoModel(
            descripcion: 'Bolsas de basura (G)',
            cantidad: 1.0,
            precioUnitario: 1000,
            total: 1000,
            categoria: 'Hogar',
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ],
          child: MaterialApp(
            home: ReviewExpenseScreen(extractedData: extractedWithTwoItems),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Sin insignia numérica; cada tarjeta muestra la etiqueta 'Concepto' y no hay icono de lápiz
      expect(find.text('Concepto'), findsNWidgets(2));
      expect(find.byIcon(Icons.edit_outlined), findsNothing);

      // 2. Tarjetas con color cardLighter y sin borde
      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);
      final firstCard = tester.widget<Card>(cardFinders.first);
      expect(firstCard.color, equals(AppColors.cardLighter));

      // 3. Categoría como caja con etiqueta, alineada con los demás campos
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      expect(find.text('Categoría'), findsNWidgets(2));

      // 4. Eliminar el primer ítem
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.first);
      await tester.pump(); // Inicia animación del SnackBar
      await tester.pump(const Duration(milliseconds: 350)); // Completa animación de entrada del SnackBar

      // Verificar que el SnackBar aparece con 'Artículo eliminado' y 'Deshacer'
      expect(find.text('Artículo eliminado'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);

      // Ahora solo queda 1 ítem en pantalla
      expect(find.text('Patilla (E)'), findsNothing);
      expect(find.text('Bolsas de basura (G)'), findsOneWidget);

      // 5. Tocar 'Deshacer'
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();

      // El ítem eliminado se restauró
      expect(find.text('Patilla (E)'), findsOneWidget);
      expect(find.text('Bolsas de basura (G)'), findsOneWidget);
    });

    testWidgets('AI-06 B-2: muestra precio sin IVA y Con IVA debajo, oculta badges en exentos y no sobrescribe Monto total al editar', (tester) async {
      tester.view.physicalSize = const Size(360, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final extractedImputado = GeminiExtractionResult.fromJson({
        'comercio': 'Automercado Plaza',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 410.00,
        'impuesto_iva': 41.38,
        'items': [
          {
            'descripcion': 'Detergente Líquido',
            'cantidad': 1,
            'precio_unitario': 258.62,
            'categoria': 'Hogar',
            'alicuota_fiscal': 'G',
          },
          {
            'descripcion': 'Harina PAN 1kg',
            'cantidad': 1,
            'precio_unitario': 110.00,
            'categoria': 'Alimentación',
            'alicuota_fiscal': 'E',
          },
        ],
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ],
          child: MaterialApp(
            home: ReviewExpenseScreen(extractedData: extractedImputado),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Nombres limpios sin (G)/(E); gravado muestra Precio (sin IVA), Total sin IVA, badge G · 16% ▾ y franja Con IVA 16%
      expect(find.text('Detergente Líquido'), findsOneWidget);
      expect(find.text('Harina PAN 1kg'), findsOneWidget);
      expect(find.text('Precio (sin IVA)'), findsOneWidget);
      expect(find.text('Total sin IVA'), findsOneWidget);
      expect(find.text('G · 16% ▾'), findsOneWidget);
      expect(find.textContaining('Con IVA 16%: Bs. 300'), findsOneWidget);
      // Sin símbolo de aproximación ni textos repetidos por fila ni pastilla en el artículo exento sin editar
      expect(find.textContaining('≈'), findsNothing);
      expect(find.textContaining('sin cuadrar con ticket'), findsNothing);
      expect(find.text('Exento ▾'), findsNothing);

      // 2. Pie fiscal muestra Subtotal sin IVA, IVA de la factura, Cuadra con la factura y botón Ajustar IVA · 1 gravado
      expect(find.byKey(const Key('fiscal_summary_footer')), findsOneWidget);
      expect(find.text('Subtotal sin IVA'), findsOneWidget);
      expect(find.text('IVA de la factura'), findsOneWidget);
      expect(find.text('Cuadra con la factura'), findsOneWidget);
      expect(find.text('Ajustar IVA · 1 gravado'), findsOneWidget);

      // 3. Editar Precio (sin IVA) del artículo gravado conserva foco/teclado, mantiene G · 16% ▾ y NO sobrescribe Monto total (410)
      final firstKey = extractedImputado.items.first.clientKey;
      final cardFinder = find.byKey(ValueKey('item_card_$firstKey'));
      final precioField = find.descendant(
        of: cardFinder,
        matching: find.widgetWithText(TextFormField, '258.62'),
      );
      expect(precioField, findsOneWidget);
      await tester.tap(precioField);
      await tester.pump();
      final editableBefore = tester.state<EditableTextState>(
        find.descendant(of: precioField, matching: find.byType(EditableText)),
      );
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.enterText(precioField, '200');
      await tester.pumpAndSettle();

      // Conserva foco, conserva badge G · 16% ▾ y Monto total permanece intacto en 410
      final precioFieldAfter = find.descendant(
        of: cardFinder,
        matching: find.widgetWithText(TextFormField, '200'),
      );
      expect(precioFieldAfter, findsOneWidget);
      final editableAfter = tester.state<EditableTextState>(
        find.descendant(of: precioFieldAfter, matching: find.byType(EditableText)),
      );
      expect(identical(editableBefore, editableAfter), isTrue);
      expect(find.text('G · 16% ▾'), findsOneWidget);
      final totalCtrlText = tester
          .widget<TextFormField>(find.byKey(const Key('input_monto_total')))
          .controller
          ?.text;
      expect(totalCtrlText, equals('410'));
      expect(find.text('Cuadra con la factura'), findsNothing);
      expect(find.textContaining('IVA no cuadra'), findsOneWidget);
    });

    testWidgets('AI-06 B-2: factura homogénea 100% gravada oculta badges en tarjetas y conserva Ajustar IVA', (tester) async {
      tester.view.physicalSize = const Size(360, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final homogenea = GeminiExtractionResult.fromJson({
        'comercio': 'Farmatodo',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 348.00,
        'impuesto_iva': 48.00,
        'items': [
          {'descripcion': 'Shampoo', 'cantidad': 1, 'precio_unitario': 180.00, 'categoria': 'Cuidado Personal', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Desodorante', 'cantidad': 1, 'precio_unitario': 120.00, 'categoria': 'Cuidado Personal', 'alicuota_fiscal': 'G'},
        ],
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ],
          child: MaterialApp(
            home: ReviewExpenseScreen(extractedData: homogenea),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('G · 16% ▾'), findsNothing);
      expect(find.textContaining('Con IVA 16%:'), findsNWidgets(2));
      expect(find.text('Ajustar IVA · 2 gravados'), findsOneWidget);
      expect(find.text('Cuadra con la factura'), findsOneWidget);
    });

    testWidgets('AI-06 B-2: tocar badge G · 16% ▾ abre hojita de 3 opciones, conserva chip Exento ▾, pausa comparador y permite Deshacer o Corregir', (tester) async {
      tester.view.physicalSize = const Size(360, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Historial previo del detergente a ~Bs. 300 ($0.34018 a tasa 881.88) para validar pausa del comparador
      gastoProvider.mockPriceHistories = {
        DatabaseHelper.normalizeProductText('Detergente Líquido'): const PriceHistory(
          descripcionNorm: 'detergente liquido',
          registros: 2,
          mismoComercio: UnitPriceRef(
            precioUsd: 0.34018,
            fecha: '2026-11-10',
            comercio: 'Automercado Plaza',
            comercioNorm: 'automercado plaza',
            cantidad: 1.0,
          ),
          mejorPrecio: UnitPriceRef(
            precioUsd: 0.34018,
            fecha: '2026-11-10',
            comercio: 'Automercado Plaza',
            comercioNorm: 'automercado plaza',
            cantidad: 1.0,
          ),
        ),
      };

      final extracted = GeminiExtractionResult.fromJson({
        'comercio': 'Automercado Plaza',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 410.00,
        'impuesto_iva': 41.38,
        'items': [
          {'descripcion': 'Detergente Líquido', 'cantidad': 1, 'precio_unitario': 258.62, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Harina PAN 1kg', 'cantidad': 1, 'precio_unitario': 110.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
        ],
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ],
          child: MaterialApp(
            home: ReviewExpenseScreen(
              extractedData: extracted,
              currentDate: DateTime(2026, 11, 20),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstKey = extracted.items.first.clientKey;
      final badgeFinder = find.byKey(ValueKey('item_tax_badge_$firstKey'));
      final priceComparisonFinder = find.byKey(ValueKey('price_comparison_$firstKey'));
      expect(badgeFinder, findsOneWidget);
      // Con el IVA cuadrado, la línea de comparación de precios es visible
      expect(priceComparisonFinder, findsOneWidget);

      // 1. Tocar G · 16% ▾ abre la hojita '¿Este artículo paga IVA?' sin alterar todavía la factura
      await tester.tap(badgeFinder);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sheet_selector_iva_item')), findsOneWidget);
      expect(find.text('¿Este artículo paga IVA?'), findsOneWidget);

      // 2. Elegir Exento (E): conserva chip sutil 'Exento ▾' en esa tarjeta, oculta comparador y muestra Deshacer
      await tester.tap(find.byKey(const Key('opt_iva_item_0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('G · 16% ▾'), findsNothing);
      expect(find.text('Exento ▾'), findsOneWidget);
      expect(find.text('Sin IVA'), findsOneWidget);
      expect(find.text('Ajustar IVA · 0 gravados'), findsOneWidget);
      // El comparador se oculta mientras el pie marca 'IVA no cuadra' (evita falso '14% más económico')
      expect(priceComparisonFinder, findsNothing);
      expect(find.textContaining('más económico'), findsNothing);
      expect(find.byKey(const Key('fiscal_suggestion_banner')), findsOneWidget);
      expect(find.byKey(const Key('btn_deshacer_cambio_iva')), findsOneWidget);

      // Monto total nunca se sobrescribió
      final totalCtrlText = tester
          .widget<TextFormField>(find.byKey(const Key('input_monto_total')))
          .controller
          ?.text;
      expect(totalCtrlText, equals('410'));

      // 3. Tocar 'Deshacer' en el SnackBar revierte a G · 16% ▾ y reaparece el comparador
      await tester.tap(find.byKey(const Key('btn_deshacer_cambio_iva')));
      await tester.pumpAndSettle();

      expect(find.text('G · 16% ▾'), findsOneWidget);
      expect(find.text('Exento ▾'), findsNothing);
      expect(find.text('Cuadra con la factura'), findsOneWidget);
      expect(priceComparisonFinder, findsOneWidget);

      // 4. Volver a pasarlo a Exento y usar 'Corregir' del banner también restaura el cuadre
      await tester.tap(badgeFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('opt_iva_item_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fiscal_suggestion_banner')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('btn_aplicar_sugerencia_fiscal')));
      await tester.tap(find.byKey(const Key('btn_aplicar_sugerencia_fiscal')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fiscal_suggestion_banner')), findsNothing);
      expect(find.text('Cuadra con la factura'), findsOneWidget);
      expect(find.text('G · 16% ▾'), findsOneWidget);
      expect(find.text('Ajustar IVA · 1 gravado'), findsOneWidget);
      expect(priceComparisonFinder, findsOneWidget);
    });

    testWidgets('AI-06 B-2: editar Monto total invalida el ancla y Guardar con descuadre exige confirmación antes del fallback con IVA aparte', (tester) async {
      tester.view.physicalSize = const Size(360, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final extracted = GeminiExtractionResult.fromJson({
        'comercio': 'Automercado Plaza',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 410.00,
        'impuesto_iva': 41.38,
        'items': [
          {'descripcion': 'Detergente Líquido', 'cantidad': 1, 'precio_unitario': 258.62, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Harina PAN 1kg', 'cantidad': 1, 'precio_unitario': 110.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
        ],
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ],
          child: MaterialApp(
            home: ReviewExpenseScreen(extractedData: extracted),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Editar Monto total invalida el ancla del ticket
      await tester.enterText(find.byKey(const Key('input_monto_total')), '450');
      await tester.pumpAndSettle();

      expect(find.text('IVA de la factura'), findsNothing);
      expect(find.text('IVA calculado'), findsOneWidget);
      expect(find.text('Cuadra con la factura'), findsNothing);

      // 2. Pulsar Guardar con descuadre abre confirmación (nunca guarda imputado en rojo)
      await tester.tap(find.byKey(const Key('btn_guardar_gasto')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog_fiscal_fallback_confirm')), findsOneWidget);

      // 3. Pulsar Corregir cancela el guardado
      await tester.tap(find.byKey(const Key('btn_fallback_corregir')));
      await tester.pumpAndSettle();
      expect(gastoProvider.ultimoGastoGuardado, isNull);

      // 4. Pulsar Guardar y confirmar 'Guardar así' guarda en fallback seguro con (G)/(E) + Impuesto IVA en categoría dominante
      await tester.tap(find.byKey(const Key('btn_guardar_gasto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_fallback_guardar_asi')));
      await tester.pumpAndSettle();

      expect(gastoProvider.ultimoGastoGuardado, isNotNull);
      final savedItems = gastoProvider.ultimosItemsGuardados!;
      expect(savedItems.length, equals(3));
      expect(savedItems[0].descripcion, equals('Detergente Líquido (G)'));
      expect(savedItems[0].total, equals(25862));
      expect(savedItems[1].descripcion, equals('Harina PAN 1kg (E)'));
      expect(savedItems[1].total, equals(11000));
      expect(savedItems[2].descripcion, equals('Impuesto IVA'));
      expect(savedItems[2].total, equals(4138));
      expect(savedItems[2].categoria, equals('Hogar'));
    });

    testWidgets('AI-06 B-2: recupera error OCR real (renglonSeparado), corrige en 1 toque y guarda imputado con nombres limpios', (tester) async {
      tester.view.physicalSize = const Size(360, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Factura donde Gemini marcó por error Detergente como E en lugar de G -> fromJson cae a renglonSeparado
      final extractedConErrorOcr = GeminiExtractionResult.fromJson({
        'comercio': 'Automercado Plaza',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 410.00,
        'impuesto_iva': 41.38,
        'items': [
          {'descripcion': 'Detergente Líquido', 'cantidad': 1, 'precio_unitario': 258.62, 'categoria': 'Hogar', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Harina PAN 1kg', 'cantidad': 1, 'precio_unitario': 110.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
        ],
      });
      expect(extractedConErrorOcr.ivaModo, equals(IvaModo.renglonSeparado));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ],
          child: MaterialApp(
            home: ReviewExpenseScreen(extractedData: extractedConErrorOcr),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Aparece inmediatamente el banner de sugerencia única
      expect(find.byKey(const Key('fiscal_suggestion_banner')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_aplicar_sugerencia_fiscal')));
      await tester.pumpAndSettle();

      expect(find.text('Cuadra con la factura'), findsOneWidget);

      // Guardar persiste precios brutos con IVA en cada categoría, nombres limpios y sin renglón Impuesto IVA
      await tester.tap(find.byKey(const Key('btn_guardar_gasto')));
      await tester.pumpAndSettle();

      expect(gastoProvider.ultimoGastoGuardado, isNotNull);
      final savedItems = gastoProvider.ultimosItemsGuardados!;
      expect(savedItems.length, equals(2));
      expect(savedItems[0].descripcion, equals('Detergente Líquido'));
      expect(savedItems[0].total, equals(30000));
      expect(savedItems[0].categoria, equals('Hogar'));
      expect(savedItems[1].descripcion, equals('Harina PAN 1kg'));
      expect(savedItems[1].total, equals(11000));
      expect(savedItems[1].categoria, equals('Alimentación'));
    });

    testWidgets('AI-06 B-2: ticket largo de 12 artículos (9 exentos, 3 gravados con decimal y 8%) y hoja Ajustar IVA a 360 dp', (tester) async {
      tester.view.physicalSize = const Size(360, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // 9 exentos (base 974.00) + 2 al 16% (80.17 + 200.00 = 280.17) + 1 al 8% (210.63)
      // IVA exacto = round((28017 * 16 + 21063 * 8) / 100) = round(616776 / 100) = 6168 cents (Bs. 61.68)
      // Total = 974.00 + 280.17 + 210.63 + 61.68 = 1526.48
      final ticket12 = GeminiExtractionResult.fromJson({
        'comercio': 'Automercado 12',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 1526.48,
        'impuesto_iva': 61.68,
        'items': [
          {'descripcion': 'Harina PAN 1kg', 'cantidad': 2, 'precio_unitario': 110.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Arroz Mary 1kg', 'cantidad': 1, 'precio_unitario': 95.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Pasta Primor 500g', 'cantidad': 2, 'precio_unitario': 72.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Pollo entero', 'cantidad': 1.45, 'precio_unitario': 120.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Queso blanco', 'cantidad': 0.5, 'precio_unitario': 180.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Plátanos maduros', 'cantidad': 1, 'precio_unitario': 65.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Tomates', 'cantidad': 0.8, 'precio_unitario': 70.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Cebolla blanca', 'cantidad': 0.5, 'precio_unitario': 60.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Huevos cartón 15u', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Detergente a granel', 'cantidad': 0.31, 'precio_unitario': 258.62, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Refresco 2L', 'cantidad': 1, 'precio_unitario': 200.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Panadería especial', 'cantidad': 1, 'precio_unitario': 210.63, 'categoria': 'Alimentación', 'alicuota_fiscal': 'R'},
        ],
      });
      expect(ticket12.ivaModo, equals(IvaModo.imputado));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ],
          child: MaterialApp(
            home: ReviewExpenseScreen(extractedData: ticket12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Solo 2 badges G · 16% ▾ y 1 badge R · 8% ▾; las 9 filas exentas no muestran ninguna pastilla ni franja Con IVA
      expect(find.text('G · 16% ▾'), findsNWidgets(2));
      expect(find.text('R · 8% ▾'), findsOneWidget);
      expect(find.text('Exento ▾'), findsNothing);
      expect(find.textContaining('Con IVA 16%:'), findsNWidgets(2));
      expect(find.textContaining('Con IVA 8%:'), findsOneWidget);
      expect(find.text('Ajustar IVA · 3 gravados'), findsOneWidget);
      expect(find.text('Cuadra con la factura'), findsOneWidget);

      // Abrir hoja Ajustar IVA y alternar Harina PAN (exento) a 16% y de vuelta a Exento
      await tester.tap(find.byKey(const Key('btn_ajustar_iva_footer')));
      await tester.pumpAndSettle();
      expect(find.text('Ajustar IVA por artículo'), findsOneWidget);

      final harinaKey = ticket12.items.first.clientKey;
      await tester.tap(find.byKey(ValueKey('sheet_iva_${harinaKey}_16')));
      await tester.pumpAndSettle();
      expect(find.text('Ajustar IVA · 4 gravados'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('sheet_iva_${harinaKey}_0')));
      await tester.pumpAndSettle();
      expect(find.text('Ajustar IVA · 3 gravados'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_cerrar_hoja_ajustar_iva')));
      await tester.pumpAndSettle();
      expect(find.text('Cuadra con la factura'), findsOneWidget);
    });
  });
}
