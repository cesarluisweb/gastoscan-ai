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

  @override
  Future<GeminiExtractionResult> parseVoiceExpense(String spokenText) async {
    parseCount++;
    parsedText = spokenText;
    return GeminiExtractionResult(
      comercio: 'Automercado',
      fecha: '2026-09-30',
      moneda: 'USD',
      totalOriginal: 25.0,
      tasaCambioDetectada: null,
      impuestoIva: 0.0,
      items: [],
    );
  }
}

class FakeDatabaseHelper extends DatabaseHelper {
  FakeDatabaseHelper() : super.test();
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
  });
}
