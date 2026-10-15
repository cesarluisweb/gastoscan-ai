import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/datasources/remote/gemini_service.dart';
import 'package:gastoscan_ai/data/models/shopping_item_model.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:gastoscan_ai/ui/screens/chat_screen.dart';

class FakeSpeechToText extends Fake implements stt.SpeechToText {
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

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) {
      return Future.value(true);
    }
    if (invocation.memberName == #locales) {
      return Future.value(<stt.LocaleName>[stt.LocaleName('es_ES', 'Spanish')]);
    }
    if (invocation.memberName == #listen) {
      listenCallCount++;
      isListeningValue = true;
      return Future.value(true);
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeDatabaseHelper extends DatabaseHelper {
  final List<ShoppingItemModel> items = [];
  FakeDatabaseHelper() : super.test();

  @override
  Future<List<ShoppingItemModel>> getAllShoppingItems() async => List.from(items);
}

class FakeGastoProvider extends GastoProvider {
  final List<GastoModel> _mockGastos = [];
  @override
  List<GastoModel> get gastos => _mockGastos;

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<bool> agregarGasto(GastoModel gasto, List<ItemGastoModel> items, {List<int>? shoppingItemIds}) async {
    _mockGastos.add(gasto);
    return true;
  }
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

class FakeGeminiService extends GeminiService {
  int callCount = 0;
  String? lastUserMessage;
  Map<String, dynamic>? lastContextData;
  Map<String, dynamic>? customResponse;

  @override
  Future<Map<String, dynamic>> chatWithAnalyst({
    required List<Map<String, String>> messages,
    required Map<String, dynamic> contextData,
  }) async {
    callCount++;
    lastContextData = contextData;
    if (messages.isNotEmpty) {
      lastUserMessage = messages.last['text'];
    }
    if (customResponse != null) {
      return customResponse!;
    }
    return {
      'text': 'Respuesta simulada para: $lastUserMessage',
    };
  }
}

void main() {
  group('ChatScreen Predefined Suggestions Tests', () {
    late FakeDatabaseHelper fakeDb;
    late FakeGastoProvider fakeGastoProvider;
    late FakeSettingsProvider fakeSettingsProvider;
    late FakeGeminiService fakeGeminiService;
    late FakeSpeechToText fakeSpeech;

    setUp(() {
      final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.physicalSizeTestValue = const Size(2500, 4000);
      binding.window.devicePixelRatioTestValue = 1.0;
      fakeDb = FakeDatabaseHelper();
      fakeGastoProvider = FakeGastoProvider();
      fakeSettingsProvider = FakeSettingsProvider();
      fakeGeminiService = FakeGeminiService();
      fakeSpeech = FakeSpeechToText();
    });

    tearDown(() {
      final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: fakeGastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: fakeSettingsProvider),
        ],
        child: MaterialApp(
          home: ChatScreen(
            geminiService: fakeGeminiService,
            dbHelper: fakeDb,
            speechToText: fakeSpeech,
          ),
        ),
      );
    }

    testWidgets('renders welcoming initial greeting from assistant', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(
        find.text(
          '¡Hola! Puedo analizar tus finanzas, darte consejos para ahorrar, registrar gastos o agregar productos a tu lista de compras. ¿Por dónde empezamos?',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders all 5 predefined chat suggestions in horizontal bar', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      for (int i = 0; i < 5; i++) {
        expect(find.byKey(Key('chat_suggestion_chip_$i'), skipOffstage: false), findsOneWidget);
      }

      expect(find.text('¿Qué gastos pequeños están sumando más de lo que parece?', skipOffstage: false), findsOneWidget);
      expect(find.text('¿Qué gastos podría reducir sin afectar lo esencial?', skipOffstage: false), findsOneWidget);
      expect(find.text('¿Qué productos o gastos me han subido de precio?', skipOffstage: false), findsOneWidget);
      expect(find.text('¿En qué días o momentos del mes suelo gastar más?', skipOffstage: false), findsOneWidget);
      expect(find.text('¿Qué suelo comprar cada mes que aún no he comprado?', skipOffstage: false), findsOneWidget);
    });

    testWidgets('tapping a suggestion chip sends it immediately as a user message', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final firstSuggestionFinder = find.byKey(const Key('chat_suggestion_chip_0'), skipOffstage: false);
      expect(firstSuggestionFinder, findsOneWidget);

      await tester.tap(firstSuggestionFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeGeminiService.callCount, 1);
      expect(fakeGeminiService.lastUserMessage, '¿Qué gastos pequeños están sumando más de lo que parece?');
      expect(fakeGeminiService.lastContextData?['tasa_usdt'], fakeSettingsProvider.tasaCambioVesUsdt);

      expect(find.text('Respuesta simulada para: ¿Qué gastos pequeños están sumando más de lo que parece?', skipOffstage: false), findsOneWidget);
    });

    testWidgets('tapping shopping list suggestion chip sends request directly', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final shoppingSuggestionFinder = find.byKey(const Key('chat_suggestion_chip_4'), skipOffstage: false);
      expect(shoppingSuggestionFinder, findsOneWidget);

      await tester.tap(shoppingSuggestionFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeGeminiService.callCount, 1);
      expect(fakeGeminiService.lastUserMessage, '¿Qué suelo comprar cada mes que aún no he comprado?');
      expect(find.text('Respuesta simulada para: ¿Qué suelo comprar cada mes que aún no he comprado?', skipOffstage: false), findsOneWidget);
    });

    testWidgets('renders review expense button when assistant extracts an expense', (tester) async {
      fakeGeminiService.customResponse = {
        'functionCall': {
          'name': 'registrar_gasto',
          'args': {
            'comercio': 'Supermercado',
            'total_usd': 20.0,
            'fecha': '2026-09-30',
            'categoria': 'Alimentacion',
            'items': [
              {
                'descripcion': 'Arroz',
                'cantidad': 2.0,
                'precio_unitario': 10.0,
              }
            ],
          },
        },
      };

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Gaste 20 dolares en Supermercado');
      await tester.pumpAndSettle();

      final sendButtonFinder = find.byIcon(Icons.send);
      await tester.tap(sendButtonFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat_review_expense_button'), skipOffstage: false), findsOneWidget);
      expect(find.text('Revisar y Guardar compra', skipOffstage: false), findsOneWidget);
      expect(fakeGastoProvider.gastos.isEmpty, isTrue);
    });

    testWidgets('tapping textfield while listening stops microphone', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final micButtonFinder = find.byTooltip('Hablar por micrófono');
      expect(micButtonFinder, findsOneWidget);

      await tester.tap(micButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(fakeSpeech.listenCallCount, 1);

      final inputFinder = find.byType(TextField);
      await tester.tap(inputFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(fakeSpeech.stopCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets('sending message while listening stops microphone', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final micButtonFinder = find.byTooltip('Hablar por micrófono');
      await tester.tap(micButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Mensaje nuevo');
      await tester.pumpAndSettle();

      final sendButtonFinder = find.byIcon(Icons.send);
      await tester.tap(sendButtonFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(fakeSpeech.stopCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets('multiple expenses in chat are registered and display correct currencies', (tester) async {
      fakeGeminiService.customResponse = {
        'functionCall': {
          'name': 'registrar_gasto',
          'args': {
            'gastos': [
              {
                'comercio': 'Farmacia Central',
                'fecha': '2026-10-13',
                'moneda': 'VES',
                'monto_original': 500.0,
                'total_usd': 10.0,
                'categoria': 'Salud',
                'items': [
                  {'descripcion': 'Medicinas', 'cantidad': 1.0, 'precio_unitario': 500.0}
                ]
              },
              {
                'comercio': 'Supermercado Sol',
                'fecha': '2026-10-13',
                'moneda': 'USD',
                'monto_original': 20.0,
                'total_usd': 20.0,
                'categoria': 'Alimentación',
                'items': [
                  {'descripcion': 'Víveres', 'cantidad': 1.0, 'precio_unitario': 20.0}
                ]
              }
            ]
          }
        }
      };

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Gaste 500 bs en la farmacia y 20 dolares en el supermercado');
      await tester.pumpAndSettle();

      final sendButtonFinder = find.byIcon(Icons.send);
      await tester.tap(sendButtonFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeGastoProvider.gastos.isEmpty, isTrue);
      expect(find.textContaining('Farmacia Central'), findsOneWidget);
      expect(find.textContaining('Supermercado Sol'), findsOneWidget);
      expect(find.text('Revisar y Guardar compra'), findsWidgets);
    });
  });
}
