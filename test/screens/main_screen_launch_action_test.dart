import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/services/notification_service.dart';
import 'package:gastoscan_ai/ui/screens/main_screen.dart';

class FakeDatabaseHelperForMainScreenIntent extends DatabaseHelper {
  final List<Map<String, dynamic>> readyDb = [];

  FakeDatabaseHelperForMainScreenIntent() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => List.from(readyDb);
}

class FakeGastoProviderForMainScreenIntent extends GastoProvider {
  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}
}

class FakeSettingsProviderForMainScreenIntent extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

void main() {
  group('MainScreen Launch Action (Intent Tray) Tests', () {
    late FakeDatabaseHelperForMainScreenIntent fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProviderForMainScreenIntent gastoProvider;
    late FakeSettingsProviderForMainScreenIntent settingsProvider;
    late NotificationService notificationService;

    setUp(() {
      fakeDb = FakeDatabaseHelperForMainScreenIntent();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: true);
      gastoProvider = FakeGastoProviderForMainScreenIntent();
      settingsProvider = FakeSettingsProviderForMainScreenIntent();
      notificationService = NotificationService.test();
      NotificationService.instance = notificationService;
      notificationService.clearPendingAction();
    });

    tearDown(() {
      notificationService.clearPendingAction();
      NotificationService.instance = NotificationService();
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

    testWidgets('arranque con pending_reviews sin comprobantes pendientes muestra SnackBar y limpia intención', (tester) async {
      notificationService.enqueueAction('pending_reviews', 'local_launch');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Debe mostrar el SnackBar de que no hay comprobantes pendientes
      expect(find.text('No hay comprobantes pendientes por revisar.'), findsOneWidget);

      // La intención en la bandeja debe quedar completamente atendida (null)
      expect(notificationService.pendingAction, isNull);
    });
  });
}
