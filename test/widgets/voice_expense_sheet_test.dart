import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/datasources/remote/gemini_service.dart';
import 'package:gastoscan_ai/data/models/gemini_extraction_result.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/widgets/voice_expense_sheet.dart';

class FakeGeminiVoiceService extends GeminiService {
  String? parsedText;
  int parseCount = 0;
  List<GeminiExtractionResult>? customResults;

  @override
  Future<List<GeminiExtractionResult>> parseVoiceExpense(String spokenText, {String monedaPrincipal = 'USD'}) async {
    parseCount++;
    parsedText = spokenText;
    if (customResults != null) return customResults!;
    return [
      GeminiExtractionResult(
        comercio: 'Automercado',
        fecha: '2026-09-30',
        moneda: 'USD',
        totalOriginal: 25.0,
        tasaCambioDetectada: null,
        impuestoIva: 0.0,
        items: [],
      ),
    ];
  }
}

class FakeDatabaseHelper extends DatabaseHelper {
  final List<Map<String, dynamic>> readyDb = [];
  int _nextId = 1;
  FakeDatabaseHelper() : super.test();

  @override
  Future<int> insertReadyScanQueueItem(String imagePath, String extractedData, {String? ocrText}) async {
    final id = _nextId++;
    readyDb.add({
      'id': id,
      'image_path': imagePath,
      'status': 'ready',
      'extracted_data': extractedData,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async {
    return List.from(readyDb);
  }
}

class FakeGastoProvider extends GastoProvider {
  @override
  Future<void> cargarDatos() async {}
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

void main() {
  group('VoiceExpenseSheet Editable Tests', () {
    late FakeGeminiVoiceService fakeGeminiService;
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProvider fakeGastoProvider;
    late FakeSettingsProvider fakeSettingsProvider;

    setUp(() {
      final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.physicalSizeTestValue = const Size(2500, 4000);
      binding.window.devicePixelRatioTestValue = 1.0;

      fakeGeminiService = FakeGeminiVoiceService();
      fakeDb = FakeDatabaseHelper();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      fakeGastoProvider = FakeGastoProvider();
      fakeSettingsProvider = FakeSettingsProvider();
    });

    tearDown(() {
      final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ChangeNotifierProvider<GastoProvider>.value(value: fakeGastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: fakeSettingsProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VoiceExpenseSheet(
              geminiService: fakeGeminiService,
            ),
          ),
        ),
      );
    }

    testWidgets('renders title, input field, mic button and cancel button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Dictar Gasto'), findsOneWidget);
      expect(find.byKey(const Key('voice_expense_input_field')), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Procesar Gasto'), findsOneWidget);
    });

    testWidgets('allows editing text in TextField and enables process button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('voice_expense_input_field'));
      expect(inputFinder, findsOneWidget);

      await tester.enterText(inputFinder, 'Compre viveres por 25 dolares');
      await tester.pumpAndSettle();

      expect(find.text('Compre viveres por 25 dolares'), findsOneWidget);

      final clearButtonFinder = find.byKey(const Key('voice_expense_clear_button'));
      expect(clearButtonFinder, findsOneWidget);

      final processButtonFinder = find.byKey(const Key('voice_expense_process_button'));
      final ElevatedButton processButton = tester.widget(processButtonFinder);
      expect(processButton.enabled, isTrue);
    });

    testWidgets('clear button removes text and disables process button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('voice_expense_input_field'));
      await tester.enterText(inputFinder, 'Texto a borrar');
      await tester.pumpAndSettle();

      final clearButtonFinder = find.byKey(const Key('voice_expense_clear_button'));
      expect(clearButtonFinder, findsOneWidget);

      await tester.tap(clearButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Texto a borrar'), findsNothing);
      expect(find.byKey(const Key('voice_expense_clear_button')), findsNothing);

      final processButtonFinder = find.byKey(const Key('voice_expense_process_button'));
      final ElevatedButton processButton = tester.widget(processButtonFinder);
      expect(processButton.enabled, isFalse);
    });

    testWidgets('submitting edited text calls parseVoiceExpense with updated content', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('voice_expense_input_field'));
      await tester.enterText(inputFinder, 'Almuerzo ejecutivo 8 dolares');
      await tester.pumpAndSettle();

      final processButtonFinder = find.byKey(const Key('voice_expense_process_button'));
      await tester.tap(processButtonFinder);
      await tester.pump();

      expect(fakeGeminiService.parseCount, 1);
      expect(fakeGeminiService.parsedText, 'Almuerzo ejecutivo 8 dolares');
    });

    testWidgets('multiple voice expenses enqueue into ScanQueueProvider and navigate to ReviewExpenseScreen', (tester) async {
      fakeGeminiService.customResults = [
        GeminiExtractionResult(
          comercio: 'Farmacia',
          fecha: '2026-09-30',
          moneda: 'USD',
          totalOriginal: 5.0,
          tasaCambioDetectada: null,
          impuestoIva: 0.0,
          items: [],
        ),
        GeminiExtractionResult(
          comercio: 'Supermercado',
          fecha: '2026-09-30',
          moneda: 'USD',
          totalOriginal: 20.0,
          tasaCambioDetectada: null,
          impuestoIva: 0.0,
          items: [],
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('voice_expense_input_field'));
      await tester.enterText(inputFinder, 'Farmacia 5 y Supermercado 20');
      await tester.pumpAndSettle();

      final processButtonFinder = find.byKey(const Key('voice_expense_process_button'));
      await tester.tap(processButtonFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeGeminiService.parseCount, 1);
      expect(scanQueueProvider.readyItems.length, 2);
    });
  });

  group('GeminiService.normalizeVoiceText Tests', () {
    test('normaliza decimales venezolanos hablados "X con Y" a formato con punto', () {
      expect(
        GeminiService.normalizeVoiceText('Gasté 11 con 56 en la farmacia'),
        equals('Gasté 11.56 en la farmacia'),
      );
      expect(
        GeminiService.normalizeVoiceText('Compré queso por 3 con 50 dólares'),
        equals('Compré queso por 3.50 dólares'),
      );
    });

    test('normaliza "X y medio" o "X y media" a ".50" sin alterar unidades de peso', () {
      expect(
        GeminiService.normalizeVoiceText('Pagué 12 y medio de pasaje'),
        equals('Pagué 12.50 de pasaje'),
      );
      expect(
        GeminiService.normalizeVoiceText('Fueron 4 y media manzanas'),
        equals('Fueron 4.50 manzanas'),
      );
      // Preserva "medio kilo" intacto para Gemini
      expect(
        GeminiService.normalizeVoiceText('Compré medio kilo de queso'),
        equals('Compré medio kilo de queso'),
      );
      // Preserva "500 gramos" intacto para Gemini
      expect(
        GeminiService.normalizeVoiceText('Compré 500 gramos de jamón'),
        equals('Compré 500 gramos de jamón'),
      );
    });

    test('normaliza "X coma Y" a "X.Y"', () {
      expect(
        GeminiService.normalizeVoiceText('El refresco costó 2 coma 25'),
        equals('El refresco costó 2.25'),
      );
    });
  });

  group('GeminiService Local Fallback Tests', () {
    late GeminiService geminiService;

    setUp(() {
      geminiService = GeminiService();
    });

    test('extrae compra sin precio aislando comercio, producto limpio, cantidad y categoría', () async {
      // Sin API key o corte de red cae al fallback local
      final results = await geminiService.parseVoiceExpense(
        'Compré 5 kg de queso en New Market',
        monedaPrincipal: 'USD',
      );

      expect(results.length, 1);
      final r = results.first;
      expect(r.comercio, equals('New Market'));
      expect(r.moneda, equals('USD'));
      expect(r.totalOriginal, equals(0.0));
      expect(r.items.length, 1);
      expect(r.items.first.descripcion, equals('Queso'));
      expect(r.items.first.cantidad, equals(5.0));
      expect(r.items.first.precioUnitario, equals(0));
      expect(r.items.first.total, equals(0));
      expect(r.items.first.categoria, equals('Alimentación'));
    });

    test('calcula precio unitario por kilo en fracciones de peso (medio kilo en 4 dólares)', () async {
      final results = await geminiService.parseVoiceExpense(
        'Medio kilo de jamón por 4 dólares',
        monedaPrincipal: 'USD',
      );

      expect(results.length, 1);
      final r = results.first;
      expect(r.totalOriginal, equals(4.0));
      expect(r.items.length, 1);
      expect(r.items.first.descripcion, equals('Jamón'));
      expect(r.items.first.cantidad, equals(0.5));
      // 4$ / 0.5 kg = 8$/kg -> 800 centavos
      expect(r.items.first.precioUnitario, equals(800));
      expect(r.items.first.total, equals(400));
      expect(r.items.first.categoria, equals('Alimentación'));
    });

    test('normaliza gramos a decimales de kilo (500 gramos de carne en 3 dólares)', () async {
      final results = await geminiService.parseVoiceExpense(
        'Compré 500 gramos de carne por 3 dólares',
        monedaPrincipal: 'USD',
      );

      expect(results.length, 1);
      final r = results.first;
      expect(r.totalOriginal, equals(3.0));
      expect(r.items.length, 1);
      expect(r.items.first.descripcion, equals('Carne'));
      expect(r.items.first.cantidad, equals(0.5));
      // 3$ / 0.5 kg = 6$/kg -> 600 centavos
      expect(r.items.first.precioUnitario, equals(600));
      expect(r.items.first.total, equals(300));
      expect(r.items.first.categoria, equals('Alimentación'));
    });
  });
}
