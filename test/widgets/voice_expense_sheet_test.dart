import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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

  @override
  Future<Map<String, PriceHistory>> buscarHistorialPrecios(
    List<String> descripcionesNormalizadas, {
    int? excludeGastoId,
    String? comercioActual,
    int diasVentana = 60,
    DateTime? referenceDate,
  }) async => const {};
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

class FakeSpeechRecognitionResult extends Fake implements SpeechRecognitionResult {
  @override
  final String recognizedWords;

  @override
  final bool finalResult;

  FakeSpeechRecognitionResult(this.recognizedWords, {this.finalResult = false});
}

class FakeSpeechToText extends Fake implements stt.SpeechToText {
  void Function(SpeechRecognitionResult)? onResultCallback;
  void Function(String)? onStatusCallback;
  bool isListeningValue = false;
  int stopCallCount = 0;
  int listenCallCount = 0;

  @override
  bool get isListening => isListeningValue;

  @override
  Future<void> stop() async {
    stopCallCount++;
    isListeningValue = false;
  }

  @override
  Future<void> cancel() async {
    stopCallCount++;
    isListeningValue = false;
  }

  void emitResult(String words, {bool finalResult = false}) {
    onResultCallback?.call(FakeSpeechRecognitionResult(words, finalResult: finalResult));
  }

  void emitStatus(String status) {
    onStatusCallback?.call(status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) {
      onStatusCallback = invocation.namedArguments[#onStatus] as void Function(String)?;
      return Future.value(true);
    }
    if (invocation.memberName == #locales) {
      return Future.value(<stt.LocaleName>[stt.LocaleName('es_ES', 'Spanish')]);
    }
    if (invocation.memberName == #listen) {
      listenCallCount++;
      isListeningValue = true;
      onResultCallback = invocation.namedArguments[#onResult] as void Function(SpeechRecognitionResult)?;
      return Future.value(true);
    }
    return super.noSuchMethod(invocation);
  }
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

  group('VoiceExpenseSheet Continuous Dictation & Date Resolution Tests', () {
    test('shouldCommitPreviousSpeechSegment distingue expansión en vivo de nuevo segmento tras pausa', () {
      // Misma frase creciendo en vivo: NO debe consolidar aún
      expect(
        VoiceExpenseSheet.shouldCommitPreviousSpeechSegment(
          'Compré medio',
          'Compré medio kilo de queso',
          wasFinalized: false,
        ),
        isFalse,
      );

      // Segmento previo finalizado por el motor: SÍ debe consolidar
      expect(
        VoiceExpenseSheet.shouldCommitPreviousSpeechSegment(
          'Compré medio kilo de queso',
          'por cuatro dólares',
          wasFinalized: true,
        ),
        isTrue,
      );

      // Reinicio de búfer tras pausa sin finalResult previo (2+ palabras previas, nueva palabra inicial)
      expect(
        VoiceExpenseSheet.shouldCommitPreviousSpeechSegment(
          'Compré arroz',
          'y caraotas en el mercado',
          wasFinalized: false,
        ),
        isTrue,
      );

      // Corrección fonética temprana de una sola palabra similar sin pausa: NO consolidar
      expect(
        VoiceExpenseSheet.shouldCommitPreviousSpeechSegment(
          'Compro',
          'Compré',
          wasFinalized: false,
          gap: const Duration(milliseconds: 120),
        ),
        isFalse,
      );
    });

    testWidgets('preserva texto transcrito cuando el motor reinicia palabras tras una pausa breve', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeGemini = FakeGeminiVoiceService();
      final fakeDb = FakeDatabaseHelper();
      final queueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      final fakeGasto = FakeGastoProvider();
      final fakeSettings = FakeSettingsProvider();
      final fakeSpeech = FakeSpeechToText();
      addTearDown(queueProvider.dispose);
      addTearDown(fakeGasto.dispose);
      addTearDown(fakeSettings.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ScanQueueProvider>.value(value: queueProvider),
            ChangeNotifierProvider<GastoProvider>.value(value: fakeGasto),
            ChangeNotifierProvider<SettingsProvider>.value(value: fakeSettings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VoiceExpenseSheet(
                geminiService: fakeGemini,
                speechToText: fakeSpeech,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('voice_expense_input_field'));
      TextField field() => tester.widget<TextField>(inputFinder);

      fakeSpeech.emitResult('Compré medio kilo');
      await tester.pump();
      expect(field().controller!.text, equals('Compré medio kilo'));

      fakeSpeech.emitResult('Compré medio kilo de queso', finalResult: true);
      await tester.pump();
      expect(field().controller!.text, equals('Compré medio kilo de queso'));

      // Pausa breve: motor emite vacío y luego nuevo segmento desde cero
      fakeSpeech.emitResult('');
      await tester.pump();
      expect(field().controller!.text, equals('Compré medio kilo de queso'));

      fakeSpeech.emitResult('por cuatro dólares');
      await tester.pump();
      expect(field().controller!.text, equals('Compré medio kilo de queso por cuatro dólares'));

      // Segunda pausa sin finalResult previo (reinicio de búfer)
      fakeSpeech.emitResult('en el automercado');
      await tester.pump();
      expect(
        field().controller!.text,
        equals('Compré medio kilo de queso por cuatro dólares en el automercado'),
      );

      // Si el usuario detiene manualmente el micrófono, resultados tardíos se ignoran
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      fakeSpeech.emitResult('ruido tardío');
      await tester.pump();
      expect(
        field().controller!.text,
        equals('Compré medio kilo de queso por cuatro dólares en el automercado'),
      );
    });

    test('resolveSpokenExpenseDate neutraliza fechas alucinadas y resuelve expresiones relativas', () {
      final refDate = DateTime(2026, 11, 13);

      // Sin mención temporal: ignora fecha alucinada por Gemini
      expect(
        GeminiService.resolveSpokenExpenseDate(
          'Compré queso por 4 dólares en el mercado',
          '2024-03-15',
          currentDate: refDate,
        ),
        equals('2026-11-13'),
      );

      // Expresiones relativas
      expect(
        GeminiService.resolveSpokenExpenseDate(
          'Ayer compré pan por 2 dólares',
          '2024-01-01',
          currentDate: refDate,
        ),
        equals('2026-11-12'),
      );
      expect(
        GeminiService.resolveSpokenExpenseDate(
          'Antier pagué 10 dólares de internet',
          null,
          currentDate: refDate,
        ),
        equals('2026-11-11'),
      );
      expect(
        GeminiService.resolveSpokenExpenseDate(
          'Hace 3 días compré café',
          null,
          currentDate: refDate,
        ),
        equals('2026-11-10'),
      );

      // Fecha explícita sin año: adopta el año actual
      expect(
        GeminiService.resolveSpokenExpenseDate(
          'Compré el 5 de octubre una medicina',
          '2024-10-05',
          currentDate: refDate,
        ),
        equals('2026-10-05'),
      );

      // Fecha explícita con año: respeta el año dictado
      expect(
        GeminiService.resolveSpokenExpenseDate(
          'Compré el 5 de octubre de 2025 una medicina',
          '2025-10-05',
          currentDate: refDate,
        ),
        equals('2025-10-05'),
      );
    });
  });
}
