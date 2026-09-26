import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/more_screen.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];
}

class FakeGastoProvider extends GastoProvider {
  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

void main() {
  group('MoreScreen Navigation & Hub Tests', () {
    late FakeGastoProvider gastoProvider;
    late FakeSettingsProvider settingsProvider;

    setUp(() {
      gastoProvider = FakeGastoProvider();
      settingsProvider = FakeSettingsProvider();
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: const MaterialApp(
          home: MoreScreen(),
        ),
      );
    }

    testWidgets('renders all hub sections in main view', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Más'), findsOneWidget);
      expect(find.text('Respaldo en la Nube'), findsOneWidget);
      expect(find.text('Lista de Compras'), findsOneWidget);
      expect(find.text('Asistente IA'), findsOneWidget);
      expect(find.text('Tasa de Cambio Automática'), findsOneWidget);
      expect(find.text('Almacenamiento y Fotos'), findsOneWidget);
      expect(find.text('Exportar a Excel (.csv)'), findsOneWidget);
      expect(find.text('Exportar como Texto (.md)'), findsOneWidget);
    });

    testWidgets('tapping shopping list navigates internally and back button returns to hub', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap shopping list
      await tester.tap(find.byKey(const Key('more_menu_shopping_list')));
      await tester.pumpAndSettle();

      // We should be in ShoppingListScreen
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Lista de Compras'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // We should be back in MoreScreen hub
      expect(find.text('Más'), findsOneWidget);
      expect(find.text('Respaldo en la Nube'), findsOneWidget);
    });

    testWidgets('tapping chat navigates internally and back button returns to hub', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap chat
      await tester.tap(find.byKey(const Key('more_menu_chat_ai')));
      await tester.pumpAndSettle();

      // We should be in ChatScreen
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Asistente IA'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // We should be back in MoreScreen hub
      expect(find.text('Más'), findsOneWidget);
      expect(find.text('Respaldo en la Nube'), findsOneWidget);
    });
  });
}
