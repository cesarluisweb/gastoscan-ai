import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/main_screen.dart';

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
  group('MainScreen Navigation Tests', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProvider gastoProvider;
    late FakeSettingsProvider settingsProvider;

    setUp(() {
      fakeDb = FakeDatabaseHelper();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      gastoProvider = FakeGastoProvider();
      settingsProvider = FakeSettingsProvider();
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: const MaterialApp(
          home: MainScreen(),
        ),
      );
    }

    testWidgets('renders 4 navigation destinations and center FAB', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Gastos'), findsOneWidget);
      expect(find.text('Análisis'), findsOneWidget);
      expect(find.text('Más'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.descendant(of: find.byType(FloatingActionButton), matching: find.byIcon(Icons.add)), findsOneWidget);
    });

    testWidgets('switching tabs changes current active screen', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Initial tab is Inicio
      expect(find.text('Rinde Más'), findsOneWidget);

      // Tap Gastos tab
      await tester.tap(find.text('Gastos'));
      await tester.pumpAndSettle();
      expect(find.text('Gastos'), findsWidgets);

      // Tap Análisis tab
      await tester.tap(find.text('Análisis'));
      await tester.pumpAndSettle();
      expect(find.text('Análisis'), findsWidgets);

      // Tap Más tab
      await tester.tap(find.text('Más'));
      await tester.pumpAndSettle();
      expect(find.text('Más'), findsWidgets);
      expect(find.text('Respaldo en la Nube'), findsOneWidget);
      expect(find.text('Lista de Compras'), findsOneWidget);
      expect(find.text('Asistente IA'), findsWidgets);
    });

    testWidgets('tapping center FAB opens bottom sheet with 4 add options', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Selecciona una opción'), findsOneWidget);
      expect(find.text('Registrar gasto'), findsOneWidget);
      expect(find.text('Escanear factura (IA)'), findsOneWidget);
      expect(find.text('Subir comprobante (IA)'), findsOneWidget);
      expect(find.text('Dictar gasto (Voz)'), findsOneWidget);
    });

    testWidgets('tapping AI chat button on Inicio navigates to Chat keeping bottom navigation and back returns to Inicio', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dashboard_ai_chat_button')));
      await tester.pumpAndSettle();

      // Bottom bar is still visible
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Gastos'), findsOneWidget);
      expect(find.text('Análisis'), findsOneWidget);
      expect(find.text('Más'), findsOneWidget);

      // We are in ChatScreen with placeholder
      expect(find.text('Pregunta o pídeme algo...'), findsOneWidget);
      expect(find.text('Asistente IA'), findsOneWidget);

      // Tapping back returns directly to Inicio
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Rinde Más'), findsOneWidget);
    });

    testWidgets('tapping Asistente IA in Mas and pressing back returns to Mas hub', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Navigate to Mas tab
      await tester.tap(find.text('Más'));
      await tester.pumpAndSettle();

      // Tap Asistente IA
      await tester.tap(find.byKey(const Key('more_menu_chat_ai')));
      await tester.pumpAndSettle();

      expect(find.text('Asistente IA'), findsOneWidget);

      // Tapping back returns to Mas hub
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Más'), findsWidgets);
      expect(find.text('Respaldo en la Nube'), findsOneWidget);
    });
  });
}
