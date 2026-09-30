import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/datasources/remote/gemini_service.dart';
import 'package:gastoscan_ai/data/models/shopping_item_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/chat_screen.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  final List<ShoppingItemModel> items = [];
  FakeDatabaseHelper() : super.test();

  @override
  Future<List<ShoppingItemModel>> getAllShoppingItems() async => List.from(items);
}

class FakeGastoProvider extends GastoProvider {
  @override
  Future<void> cargarDatos() async {}
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

class FakeGeminiService extends GeminiService {
  int callCount = 0;
  String? lastUserMessage;

  @override
  Future<Map<String, dynamic>> chatWithAnalyst({
    required List<Map<String, String>> messages,
    required Map<String, dynamic> contextData,
  }) async {
    callCount++;
    if (messages.isNotEmpty) {
      lastUserMessage = messages.last['text'];
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

    setUp(() {
      fakeDb = FakeDatabaseHelper();
      fakeGastoProvider = FakeGastoProvider();
      fakeSettingsProvider = FakeSettingsProvider();
      fakeGeminiService = FakeGeminiService();
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
          ),
        ),
      );
    }

    testWidgets('renders all 5 predefined chat suggestions in horizontal bar', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      for (int i = 0; i < 5; i++) {
        expect(find.byKey(Key('chat_suggestion_chip_$i')), findsOneWidget);
      }

      expect(find.text('¿Cuánto he gastado este mes?'), findsOneWidget);
      expect(find.text('¿En qué categoría he gastado más?'), findsOneWidget);
      expect(find.text('¿Qué tengo en mi lista de compras?'), findsOneWidget);
      expect(find.text('¿Cómo voy con mi presupuesto?'), findsOneWidget);
      expect(find.text('Dame un resumen de mis gastos'), findsOneWidget);
    });

    testWidgets('tapping a suggestion chip sends it immediately as a user message', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final firstSuggestionFinder = find.byKey(const Key('chat_suggestion_chip_0'));
      expect(firstSuggestionFinder, findsOneWidget);

      await tester.tap(firstSuggestionFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeGeminiService.callCount, 1);
      expect(fakeGeminiService.lastUserMessage, '¿Cuánto he gastado este mes?');

      expect(find.text('Respuesta simulada para: ¿Cuánto he gastado este mes?'), findsOneWidget);
    });

    testWidgets('tapping shopping list suggestion chip sends request directly', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final shoppingSuggestionFinder = find.byKey(const Key('chat_suggestion_chip_2'));
      expect(shoppingSuggestionFinder, findsOneWidget);

      await tester.tap(shoppingSuggestionFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeGeminiService.callCount, 1);
      expect(fakeGeminiService.lastUserMessage, '¿Qué tengo en mi lista de compras?');
      expect(find.text('Respuesta simulada para: ¿Qué tengo en mi lista de compras?'), findsOneWidget);
    });
  });
}
