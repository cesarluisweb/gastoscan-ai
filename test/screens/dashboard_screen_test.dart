import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/dashboard_screen.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  final List<Map<String, dynamic>> pending = [];
  final List<Map<String, dynamic>> ready = [];

  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => List.from(pending);

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => List.from(ready);
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
  group('DashboardScreen Scan Queue Banners Tests', () {
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
          home: DashboardScreen(),
        ),
      );
    }

    testWidgets('displays yellow processing banner when queue has pending items', (tester) async {
      scanQueueProvider.setPendingItems([
        {'id': 1, 'image_path': '/img/factura1.jpg'},
        {'id': 2, 'image_path': '/img/factura2.jpg'},
      ]);
      scanQueueProvider.setProcessing(true);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Verify yellow processing banner is visible
      expect(find.byKey(const Key('processing_queue_banner')), findsOneWidget);
      expect(find.textContaining('Procesando 2 facturas en cola...'), findsOneWidget);
      expect(find.text('Extrayendo datos en segundo plano'), findsOneWidget);
    });

    testWidgets('displays single item text properly in processing banner', (tester) async {
      scanQueueProvider.setPendingItems([
        {'id': 1, 'image_path': '/img/factura1.jpg'},
      ]);
      scanQueueProvider.setProcessing(true);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('processing_queue_banner')), findsOneWidget);
      expect(find.textContaining('Procesando 1 factura en cola...'), findsOneWidget);
    });

    testWidgets('hides processing banner when queue is empty and not processing', (tester) async {
      scanQueueProvider.setPendingItems([]);
      scanQueueProvider.setProcessing(false);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('processing_queue_banner')), findsNothing);
    });

    testWidgets('displays ready queue banner when items are ready for review', (tester) async {
      scanQueueProvider.setReadyItems([
        {
          'id': 1,
          'image_path': '/img/factura1.jpg',
          'extracted_data': '{"comercio": "Central Madeirense", "fecha": "2026-09-15", "moneda": "USD", "totalOriginal": 25.5, "items": []}',
        },
      ]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('ready_queue_banner')), findsOneWidget);
      expect(find.textContaining('Tienes 1 factura(s) en cola listas para revisar.'), findsOneWidget);
    });
  });
}
