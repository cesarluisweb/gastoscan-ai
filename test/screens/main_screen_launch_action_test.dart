import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/repositories/gasto_repository.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/services/connectivity_service.dart';
import 'package:gastoscan_ai/services/notification_service.dart';
import 'package:gastoscan_ai/services/sync_coordinator.dart';
import 'package:gastoscan_ai/services/sync_service.dart';
import 'package:gastoscan_ai/ui/screens/main_screen.dart';

class FakeDatabaseHelperForMainScreenIntent extends DatabaseHelper {
  final List<Map<String, dynamic>> readyDb = [];

  FakeDatabaseHelperForMainScreenIntent() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => List.from(readyDb);

  @override
  Future<int> resetStaleProcessingScanQueueItems() async => 0;
}

class FakeGastoProviderForMainScreenIntent extends GastoProvider {
  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}

  @override
  void verificarReanudacionMesActual() {}
}

class FakeSettingsProviderForMainScreenIntent extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

class MockSyncServiceForMainScreenIntent extends Fake implements SyncService {
  @override
  User? get currentUser => null;
}

class MockGastoRepositoryForMainScreenIntent extends Fake implements GastoRepository {}

void main() {
  group('MainScreen Launch Action (Intent Tray) Tests', () {
    late FakeDatabaseHelperForMainScreenIntent fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProviderForMainScreenIntent gastoProvider;
    late FakeSettingsProviderForMainScreenIntent settingsProvider;
    late NotificationService notificationService;
    late SyncCoordinator syncCoordinator;

    setUp(() {
      fakeDb = FakeDatabaseHelperForMainScreenIntent();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      gastoProvider = FakeGastoProviderForMainScreenIntent();
      settingsProvider = FakeSettingsProviderForMainScreenIntent();
      notificationService = NotificationService.test();
      NotificationService.instance = notificationService;
      notificationService.clearPendingAction();

      syncCoordinator = SyncCoordinator(
        syncService: MockSyncServiceForMainScreenIntent(),
        repository: MockGastoRepositoryForMainScreenIntent(),
        connectivityService: ConnectivityService(testConnected: false),
      );
      SyncCoordinator.instance = syncCoordinator;
    });

    tearDown(() {
      notificationService.clearPendingAction();
      NotificationService.instance = NotificationService();
      SyncCoordinator.instance = SyncCoordinator();
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
      // Ejecutar callbacks post-frame y dar tiempo al SnackBar para aparecer
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Debe mostrar el SnackBar de que no hay comprobantes pendientes
      expect(find.text('No hay comprobantes pendientes por revisar.'), findsOneWidget);

      // La intención en la bandeja debe quedar completamente atendida (null)
      expect(notificationService.pendingAction, isNull);

      // Permitir que el SnackBar complete su temporizador de 3s para cerrar limpiamente
      await tester.pumpAndSettle();
    });
  });
}
