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
  Future<List<GeminiExtractionResult>> parseVoiceExpense(String spokenText) async {
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

    test('normaliza "X y medio" o "X y media" a ".50"', () {
      expect(
        GeminiService.normalizeVoiceText('Pagué 12 y medio de pasaje'),
        equals('Pagué 12.50 de pasaje'),
      );
      expect(
        GeminiService.normalizeVoiceText('Fueron 4 y media manzanas'),
        equals('Fueron 4.50 manzanas'),
      );
    });

    test('normaliza "X coma Y" a "X.Y"', () {
      expect(
        GeminiService.normalizeVoiceText('El refresco costó 2 coma 25'),
        equals('El refresco costó 2.25'),
      );
    });
  });
}
