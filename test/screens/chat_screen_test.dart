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
import 'package:gastoscan_ai/providers/chat_provider.dart';
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
  List<Map<String, String>>? lastMessages;

  @override
  Future<Map<String, dynamic>> chatWithAnalyst({
    required List<Map<String, String>> messages,
    required Map<String, dynamic> contextData,
    String? modo,
  }) async {
    callCount++;
    lastContextData = contextData;
    lastMessages = messages;
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
      binding.window.physicalSizeTestValue = const Size(4500, 4000);
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

    Widget createWidgetUnderTest({ChatProvider? chatProvider}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: fakeGastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: fakeSettingsProvider),
          if (chatProvider != null)
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider)
          else
            ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
        ],
        child: MaterialApp(
          home: ChatScreen(
            geminiService: fakeGeminiService,
            dbHelper: fakeDb,
            speechToText: fakeSpeech,
            chatProvider: chatProvider,
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

      await tester.ensureVisible(shoppingSuggestionFinder);
      await tester.pumpAndSettle();

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

    testWidgets('sending message while listening stops microphone and clears textfield', (tester) async {
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
      expect((tester.widget(inputFinder) as TextField).controller!.text, isEmpty);
    });

    testWidgets('asking to register purchase without price asks for total cost with clarifying message', (tester) async {
      fakeGeminiService.customResponse = {
        'functionCall': {
          'name': 'registrar_gasto',
          'args': {
            'comercio': 'Unimarket',
            'total_usd': 0.0,
            'items': [
              {'descripcion': 'Queso', 'cantidad': 10.0, 'precio_unitario': 0.0}
            ],
          },
        },
      };

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Compré 10 kilos de queso en Unimarket');
      await tester.pumpAndSettle();

      final sendButtonFinder = find.byIcon(Icons.send);
      await tester.tap(sendButtonFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Entendido, antes de registrar Queso en Unimarket, dime: ¿cuánto te costó en total?', skipOffstage: false), findsOneWidget);
      expect((tester.widget(inputFinder) as TextField).controller!.text, isEmpty);
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

    testWidgets('sends precalculated semantic context and trims messages to sliding window', (tester) async {
      fakeGastoProvider.gastos.add(
        GastoModel(
          id: 1,
          uuid: 'uuid-1',
          fecha: '2026-10-14',
          comercio: 'Automercado',
          moneda: 'USD',
          totalOriginal: 2500,
          totalUsd: 2500,
          categoria: 'Alimentación',
          creadoEn: '2026-10-14T10:00:00Z',
          items: [
            ItemGastoModel(descripcion: 'Harina PAN', cantidad: 3, precioUnitario: 100, total: 300, categoria: 'Alimentación'),
            ItemGastoModel(descripcion: 'Café', cantidad: 1, precioUnitario: 500, total: 500, categoria: 'Alimentación'),
          ],
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, '¿Cuál es el producto que más compré?');
      await tester.pumpAndSettle();

      final sendButtonFinder = find.byIcon(Icons.send);
      await tester.tap(sendButtonFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeGeminiService.callCount, 1);
      final contextData = fakeGeminiService.lastContextData;
      expect(contextData, isNotNull);
      expect(contextData!.containsKey('totales_categoria'), isTrue);
      expect(contextData.containsKey('top_productos_mes'), isTrue);
      expect(contextData.containsKey('ultimas_compras'), isTrue);

      final topProducts = contextData['top_productos_mes'] as List;
      expect(topProducts.isNotEmpty, isTrue);
      expect(topProducts.first['producto'], 'Harina PAN');
      expect(topProducts.first['cantidad'], 3.0);

      // Comprobar que no se envió gastos_mes (que consumía miles de tokens redundantes)
      expect(contextData.containsKey('gastos_mes'), isFalse);

      // Comprobar ventana deslizante de mensajes <= 5
      expect(fakeGeminiService.lastMessages!.length, lessThanOrEqualTo(5));
    });

    testWidgets('preserves chat conversation in ChatProvider across screen rebuilds', (tester) async {
      final sharedChatProvider = ChatProvider();

      // Montar ChatScreen por primera vez
      await tester.pumpWidget(createWidgetUnderTest(chatProvider: sharedChatProvider));
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, '¿Cómo voy este mes?');
      await tester.pumpAndSettle();

      final sendButtonFinder = find.byIcon(Icons.send);
      await tester.tap(sendButtonFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('¿Cómo voy este mes?'), findsOneWidget);
      expect(find.text('Respuesta simulada para: ¿Cómo voy este mes?'), findsOneWidget);

      // Simular que el usuario sale de la pantalla desmontando ChatScreen
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Pantalla Inicio'))));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla Inicio'), findsOneWidget);
      expect(find.text('¿Cómo voy este mes?'), findsNothing);

      // Simular que el usuario vuelve a entrar a ChatScreen con el mismo ChatProvider
      await tester.pumpWidget(createWidgetUnderTest(chatProvider: sharedChatProvider));
      await tester.pumpAndSettle();

      // Comprobar que la conversación previa se conservó intacta en memoria
      expect(find.text('¿Cómo voy este mes?'), findsOneWidget);
      expect(find.text('Respuesta simulada para: ¿Cómo voy este mes?'), findsOneWidget);
    });

    testWidgets('reset conversation dialog cancels without clearing or confirms and clears', (tester) async {
      final sharedChatProvider = ChatProvider();
      await tester.pumpWidget(createWidgetUnderTest(chatProvider: sharedChatProvider));
      await tester.pumpAndSettle();

      // Enviar un mensaje
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Hola asistente');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Hola asistente'), findsOneWidget);

      // Tocar botón de reiniciar conversación en el AppBar
      final resetBtnFinder = find.byKey(const Key('chat_reset_conversation_button'));
      expect(resetBtnFinder, findsOneWidget);
      await tester.tap(resetBtnFinder);
      await tester.pumpAndSettle();

      // Verificar textos del diálogo acordados con César
      expect(find.text('¿Reiniciar conversación?'), findsOneWidget);
      expect(find.text('Se borrará el historial actual del chat y no podrás recuperar la conversación anterior. ¿Deseas empezar de nuevo?'), findsOneWidget);

      // Caso 1: Cancelar
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Hola asistente'), findsOneWidget);

      // Caso 2: Confirmar reinicio
      await tester.tap(resetBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat_confirm_reset_button')));
      await tester.pumpAndSettle();

      // La conversación vuelve al estado inicial
      expect(find.text('Hola asistente'), findsNothing);
      expect(find.text(ChatProvider.initialGreeting), findsOneWidget);
    });

    testWidgets('excludes tax and IVA items from top_productos_mes in semantic context', (tester) async {
      fakeGastoProvider.gastos.add(
        GastoModel(
          id: 1,
          uuid: 'uuid-tax-1',
          fecha: '2026-10-14',
          comercio: 'Supermercado Central',
          moneda: 'USD',
          totalOriginal: 3500,
          totalUsd: 3500,
          categoria: 'Alimentación',
          creadoEn: '2026-10-14T10:00:00Z',
          items: [
            ItemGastoModel(descripcion: 'Arroz Superior', cantidad: 2, precioUnitario: 100, total: 200, categoria: 'Alimentación'),
            ItemGastoModel(descripcion: 'Impuesto IVA', cantidad: 1, precioUnitario: 32, total: 32, categoria: 'Otros'),
            ItemGastoModel(descripcion: 'IVA 16%', cantidad: 1, precioUnitario: 32, total: 32, categoria: 'Otros'),
          ],
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, '¿Qué gastos pequeños tengo?');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      final contextData = fakeGeminiService.lastContextData;
      expect(contextData, isNotNull);
      final topProducts = contextData!['top_productos_mes'] as List;

      // Debe incluir Arroz Superior pero excluir Impuesto IVA y IVA 16%
      final productNames = topProducts.map((p) => p['producto']).toList();
      expect(productNames, contains('Arroz Superior'));
      expect(productNames, isNot(contains('Impuesto IVA')));
      expect(productNames, isNot(contains('IVA 16%')));
    });
  });
}
