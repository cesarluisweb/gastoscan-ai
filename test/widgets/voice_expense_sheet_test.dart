import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/datasources/remote/gemini_service.dart';
import 'package:gastoscan_ai/data/models/gemini_extraction_result.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/services/connectivity_service.dart';
import 'package:gastoscan_ai/ui/widgets/voice_expense_sheet.dart';

class FakeGeminiVoiceService extends GeminiService {
  String? parsedText;
  int parseCount = 0;
  List<GeminiExtractionResult>? customResults;
  Exception? errorToThrow;

  @override
  Future<List<GeminiExtractionResult>> parseVoiceExpense(String spokenText, {String monedaPrincipal = 'USD'}) async {
    parseCount++;
    parsedText = spokenText;
    if (errorToThrow != null) throw errorToThrow!;
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

class FakeSpeechRecognitionError extends Fake implements SpeechRecognitionError {
  @override
  final String errorMsg;

  @override
  final bool permanent;

  FakeSpeechRecognitionError(this.errorMsg, {this.permanent = false});
}

class FakeSpeechToText extends Fake implements stt.SpeechToText {
  void Function(SpeechRecognitionResult)? onResultCallback;
  void Function(String)? onStatusCallback;
  void Function(SpeechRecognitionError)? onErrorCallback;
  bool isListeningValue = false;
  int initializeCallCount = 0;
  int stopCallCount = 0;
  int cancelCallCount = 0;
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
    cancelCallCount++;
    isListeningValue = false;
  }

  void emitResult(String words, {bool finalResult = false}) {
    onResultCallback?.call(FakeSpeechRecognitionResult(words, finalResult: finalResult));
  }

  void emitStatus(String status) {
    onStatusCallback?.call(status);
  }

  void emitError(String errorMsg, {bool permanent = false}) {
    onErrorCallback?.call(FakeSpeechRecognitionError(errorMsg, permanent: permanent));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) {
      initializeCallCount++;
      onStatusCallback = invocation.namedArguments[#onStatus] as void Function(String)?;
      onErrorCallback = invocation.namedArguments[#onError] as void Function(SpeechRecognitionError)?;
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

  group('VoiceExpenseSheet - Resiliencia Offline y Errores de Servicio', () {
    late FakeGeminiVoiceService fakeGeminiService;
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProvider fakeGastoProvider;
    late FakeSettingsProvider fakeSettingsProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeGeminiService = FakeGeminiVoiceService();
      fakeDb = FakeDatabaseHelper();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      fakeGastoProvider = FakeGastoProvider();
      fakeSettingsProvider = FakeSettingsProvider();
    });

    tearDown(() {
      scanQueueProvider.dispose();
      fakeGastoProvider.dispose();
      fakeSettingsProvider.dispose();
      ConnectivityService.reset();
    });

    Widget wrapWithProviders(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ChangeNotifierProvider<GastoProvider>.value(value: fakeGastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: fakeSettingsProvider),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('apertura offline muestra vista Sin conexion, no inicializa microfono y oculta caja de texto', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeSpeech = FakeSpeechToText();
      final offlineConn = ConnectivityService(testConnected: false);

      await tester.pumpWidget(
        wrapWithProviders(
          Scaffold(
            body: VoiceExpenseSheet(
              geminiService: fakeGeminiService,
              speechToText: fakeSpeech,
              connectivityService: offlineConn,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voice_offline_title')), findsOneWidget);
      expect(find.text('Dictar gasto necesita internet'), findsOneWidget);
      expect(find.byKey(const Key('voice_offline_manual_button')), findsOneWidget);
      expect(find.byKey(const Key('voice_offline_close_button')), findsOneWidget);
      expect(find.byKey(const Key('voice_expense_input_field')), findsNothing);
      expect(fakeSpeech.initializeCallCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pulsar Escribir gasto en vista offline cierra hoja e invoca onOpenManualExpense', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool manualOpened = false;
      final offlineConn = ConnectivityService(testConnected: false);

      await tester.pumpWidget(
        wrapWithProviders(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  VoiceExpenseSheet.show(
                    context,
                    geminiService: fakeGeminiService,
                    speechToText: FakeSpeechToText(),
                    connectivityService: offlineConn,
                    onOpenManualExpense: () => manualOpened = true,
                  );
                },
                child: const Text('Abrir dictado'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir dictado'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice_offline_manual_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('voice_offline_manual_button')));
      await tester.pumpAndSettle();

      expect(manualOpened, isTrue);
      expect(find.byKey(const Key('sheet_surface_voice')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('transicion offline <-> online controla microfono e ignora resultados rezagados', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final connController = StreamController<bool>.broadcast();
      addTearDown(connController.close);
      final fakeSpeech = FakeSpeechToText();
      final conn = ConnectivityService(
        testController: connController,
        testConnected: false,
      );

      await tester.pumpWidget(
        wrapWithProviders(
          Scaffold(
            body: VoiceExpenseSheet(
              geminiService: fakeGeminiService,
              speechToText: fakeSpeech,
              connectivityService: conn,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice_offline_title')), findsOneWidget);
      expect(fakeSpeech.initializeCallCount, 0);

      // Recupera conexion: entra a vista normal e inicializa microfono
      connController.add(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice_expense_input_field')), findsOneWidget);
      expect(fakeSpeech.initializeCallCount, 1);
      expect(fakeSpeech.listenCallCount, 1);

      // Se cae conexion: cancela microfono y paquetes tardios no reactivan escucha
      connController.add(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice_offline_title')), findsOneWidget);
      expect(fakeSpeech.cancelCallCount, greaterThanOrEqualTo(1));

      fakeSpeech.emitStatus('listening');
      fakeSpeech.emitResult('Texto rezagado que debe ignorarse');
      await tester.pump();
      expect(find.byKey(const Key('voice_offline_title')), findsOneWidget);
    });

    testWidgets('error_network del motor nativo cambia a vista offline', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeSpeech = FakeSpeechToText();
      await tester.pumpWidget(
        wrapWithProviders(
          Scaffold(
            body: VoiceExpenseSheet(
              geminiService: fakeGeminiService,
              speechToText: fakeSpeech,
              connectivityService: ConnectivityService(testConnected: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice_expense_input_field')), findsOneWidget);

      fakeSpeech.emitError('error_network');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice_offline_title')), findsOneWidget);
    });

    testWidgets('VoiceOfflineException muestra vista offline y VoiceServiceException 429 muestra banner sin fingir offline', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Caso 1: VoiceServiceException (cuota 429) -> NO muestra vista offline
      fakeGeminiService.errorToThrow = const VoiceServiceException(
        'El asistente no está disponible en este momento por límites de capacidad. Intenta de nuevo más tarde.',
      );

      await tester.pumpWidget(
        wrapWithProviders(
          Scaffold(
            body: VoiceExpenseSheet(
              geminiService: fakeGeminiService,
              speechToText: FakeSpeechToText(),
              connectivityService: ConnectivityService(testConnected: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('voice_expense_input_field')),
        'Compre pan por 3 dolares',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('voice_expense_process_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voice_offline_title')), findsNothing);
      expect(find.byKey(const Key('voice_service_error_banner')), findsOneWidget);
      expect(find.textContaining('límites de capacidad'), findsOneWidget);
      expect(find.byKey(const Key('voice_error_manual_button')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Caso 2: VoiceOfflineException (corte real / 504) -> cambia a vista offline
      fakeGeminiService.errorToThrow = const VoiceOfflineException();
      await tester.tap(find.byKey(const Key('voice_expense_process_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voice_offline_title')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('GeminiService - parseVoiceExpense con enableLocalVoiceFallback=false', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('lanza VoiceOfflineException ante SocketException y HTTP 504', () async {
      final socketService = GeminiService(
        client: MockClient((_) async => throw const SocketException('No internet')),
        enableLocalVoiceFallback: false,
      );
      await expectLater(
        socketService.parseVoiceExpense('Compre pan por 2 dolares'),
        throwsA(isA<VoiceOfflineException>()),
      );

      final gw504Service = GeminiService(
        client: MockClient((_) async => http.Response('Gateway Timeout', 504)),
        enableLocalVoiceFallback: false,
      );
      await expectLater(
        gw504Service.parseVoiceExpense('Compre pan por 2 dolares'),
        throwsA(isA<VoiceOfflineException>()),
      );
    });

    test('lanza VoiceServiceException ante HTTP 429 y 401 sin fingir falta de red', () async {
      final rateLimitService = GeminiService(
        client: MockClient((_) async => http.Response(
              '{"error":"Cuota diaria alcanzada","dailyLimitReached":true}',
              429,
            )),
        enableLocalVoiceFallback: false,
      );
      await expectLater(
        rateLimitService.parseVoiceExpense('Compre pan por 2 dolares'),
        throwsA(
          isA<VoiceServiceException>().having(
            (e) => e.message,
            'message',
            contains('Cuota diaria alcanzada'),
          ),
        ),
      );

      final unauthService = GeminiService(
        client: MockClient((_) async => http.Response('Unauthorized', 401)),
        enableLocalVoiceFallback: false,
      );
      await expectLater(
        unauthService.parseVoiceExpense('Compre pan por 2 dolares'),
        throwsA(isA<VoiceServiceException>()),
      );
    });

    test('conserva fallback local ante HTTP 200 sin functionCall (compra sin precio)', () async {
      final noFnService = GeminiService(
        client: MockClient((_) async => http.Response('{"text":"Cuanto te costo?"}', 200)),
        enableLocalVoiceFallback: false,
      );

      final results = await noFnService.parseVoiceExpense('Compre 5 kg de queso en New Market');
      expect(results, hasLength(1));
      expect(results.first.comercio, equals('New Market'));
      expect(results.first.totalOriginal, equals(0.0));
    });
  });
}
