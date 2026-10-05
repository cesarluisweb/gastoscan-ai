import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/ui/widgets/global_scan_queue_banner.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];
}

void main() {
  group('GlobalScanQueueBanner Tests', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;

    setUp(() {
      fakeDb = FakeDatabaseHelper();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                GlobalScanQueueBanner(),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('renders nothing when queue is empty and idle', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('global_scan_processing_banner')), findsNothing);
      expect(find.byKey(const Key('global_scan_offline_banner')), findsNothing);
      expect(find.byKey(const Key('global_scan_ready_banner')), findsNothing);
      expect(find.byKey(const Key('global_scan_error_banner')), findsNothing);
    });

    testWidgets('renders processing banner with spinner when isProcessing is true', (tester) async {
      scanQueueProvider.setPendingItems([
        {'id': 1, 'image_path': '/img/factura1.jpg'},
      ]);
      scanQueueProvider.setProcessing(true);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('global_scan_processing_banner')), findsOneWidget);
      expect(find.text('Procesando 1 factura con IA...'), findsOneWidget);
      expect(find.text('Extrayendo datos en segundo plano'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('renders offline banner when items are waiting for connection', (tester) async {
      scanQueueProvider.setPendingItems([
        {'id': 1, 'image_path': '/img/factura1.jpg'},
      ]);
      scanQueueProvider.setProcessing(false);
      scanQueueProvider.setWaitingForConnection(true);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('global_scan_offline_banner')), findsOneWidget);
      expect(find.text('1 factura guardada sin conexión'), findsOneWidget);
      expect(find.text('Se procesará automáticamente al reconectar.'), findsOneWidget);
      // No spinner giratorio en modo offline
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('renders plural text for multiple items offline', (tester) async {
      scanQueueProvider.setPendingItems([
        {'id': 1, 'image_path': '/img/factura1.jpg'},
        {'id': 2, 'image_path': '/img/factura2.jpg'},
      ]);
      scanQueueProvider.setProcessing(false);
      scanQueueProvider.setWaitingForConnection(true);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('global_scan_offline_banner')), findsOneWidget);
      expect(find.text('2 facturas guardadas sin conexión'), findsOneWidget);
    });

    testWidgets('renders error banner when item failed with real non-network error', (tester) async {
      scanQueueProvider.setPendingItems([
        {'id': 1, 'image_path': '/img/factura1.jpg'},
      ]);
      scanQueueProvider.setProcessing(false);
      scanQueueProvider.setWaitingForConnection(false);
      scanQueueProvider.setLastError('Imagen ilegible o dañada.');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('global_scan_error_banner')), findsOneWidget);
      expect(find.text('Pausado: 1 factura'), findsOneWidget);
      expect(find.text('Imagen ilegible o dañada.'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders ready banner when items are ready for review', (tester) async {
      scanQueueProvider.setReadyItems([
        {
          'id': 1,
          'image_path': '/img/factura1.jpg',
          'extracted_data': '{"comercio": "Central Madeirense", "fecha": "2026-09-15", "moneda": "USD", "totalOriginal": 25.5, "items": []}',
        },
      ]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('global_scan_ready_banner')), findsOneWidget);
      expect(find.text('Factura lista para revisar'), findsOneWidget);
    });

    testWidgets('stacks ready and processing banners when both states coexist', (tester) async {
      scanQueueProvider.setReadyItems([
        {
          'id': 1,
          'image_path': '/img/factura1.jpg',
          'extracted_data': '{"comercio": "Central Madeirense", "fecha": "2026-09-15", "moneda": "USD", "totalOriginal": 25.5, "items": []}',
        },
      ]);
      scanQueueProvider.setPendingItems([
        {'id': 2, 'image_path': '/img/factura2.jpg'},
      ]);
      scanQueueProvider.setProcessing(true);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final readyFinder = find.byKey(const Key('global_scan_ready_banner'));
      final processingFinder = find.byKey(const Key('global_scan_processing_banner'));
      expect(readyFinder, findsOneWidget);
      expect(processingFinder, findsOneWidget);
      expect(find.text('Procesando 1 factura con IA...'), findsOneWidget);

      // El banner de procesamiento queda debajo del de "lista para revisar", sin superponerse
      final readyRect = tester.getRect(readyFinder);
      final processingRect = tester.getRect(processingFinder);
      expect(processingRect.top, greaterThanOrEqualTo(readyRect.bottom));
    });
  });
}
