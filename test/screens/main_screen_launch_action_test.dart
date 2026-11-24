import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/repositories/gasto_repository.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/services/connectivity_service.dart';
import 'package:gastoscan_ai/services/notification_service.dart';
import 'package:gastoscan_ai/services/sync_coordinator.dart';
import 'package:gastoscan_ai/services/sync_service.dart';
import 'package:gastoscan_ai/ui/screens/currency_calculator_screen.dart';
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
  int refreshRequestedCount = 0;

  FakeSettingsProviderForMainScreenIntent()
      : super(
          autoLoad: false,
          connectivityService: ConnectivityService(testConnected: false),
          enableConnectivityListener: false,
        );

  @override
  Future<void> loadSettings() async {}

  @override
  Future<bool> actualizarTasaAutomatica({http.Client? client}) async => false;

  @override
  Future<bool> refrescarTasasSiDesactualizadas({
    http.Client? client,
    bool bypassCooldown = false,
  }) async {
    refreshRequestedCount++;
    return false;
  }
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
      SharedPreferences.setMockInitialValues({});
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
      scanQueueProvider.dispose();
      gastoProvider.dispose();
      settingsProvider.dispose();
      notificationService.clearPendingAction();
      NotificationService.instance = NotificationService.test();
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
      // Disparar postFrameCallback
      await tester.pump();
      // Procesar microtasks de scanQueue.ready y showSnackBar
      await tester.pump();
      // Animar la entrada del SnackBar
      await tester.pump(const Duration(milliseconds: 500));

      // Debe mostrar el SnackBar de que no hay comprobantes pendientes
      expect(find.text('No hay comprobantes pendientes por revisar.'), findsOneWidget);

      // La intención en la bandeja debe quedar completamente atendida (null)
      expect(notificationService.pendingAction, isNull);

      // Permitir que el SnackBar complete su temporizador de 3s para cerrar limpiamente
      await tester.pumpAndSettle();
    });

    testWidgets('arranque con daily_rates abre la Calculadora de divisas y limpia la intención', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      notificationService.enqueueAction(AppConstants.payloadDailyRates, 'fcm_launch');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(CurrencyCalculatorScreen), findsOneWidget);
      expect(notificationService.pendingAction, isNull);
      expect(notificationService.selectedPayloadNotifier.value, isNull);
      expect(settingsProvider.refreshRequestedCount, greaterThanOrEqualTo(1));
    });

    testWidgets('toque en notificación daily_rates con la app abierta navega a Calculadora sin doble disparo', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(CurrencyCalculatorScreen), findsNothing);

      notificationService.enqueueAction(AppConstants.payloadDailyRates, 'fcm_tap');
      await tester.pumpAndSettle();

      expect(find.byType(CurrencyCalculatorScreen), findsOneWidget);
      expect(notificationService.pendingAction, isNull);
      expect(notificationService.selectedPayloadNotifier.value, isNull);
      expect(settingsProvider.refreshRequestedCount, equals(1));
    });
  });
}
