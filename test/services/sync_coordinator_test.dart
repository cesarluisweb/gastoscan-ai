import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/repositories/gasto_repository.dart';
import 'package:gastoscan_ai/services/connectivity_service.dart';
import 'package:gastoscan_ai/services/sync_coordinator.dart';
import 'package:gastoscan_ai/services/sync_service.dart';

class MockUser extends Fake implements User {
  final String _uid;
  final bool _isAnonymous;

  MockUser({String uid = 'test-user', bool isAnonymous = false})
      : _uid = uid,
        _isAnonymous = isAnonymous;

  @override
  String get uid => _uid;

  @override
  bool get isAnonymous => _isAnonymous;
}

class MockSyncService extends Fake implements SyncService {
  User? customUser;
  int syncBidirectionalCalls = 0;
  int retryPendingReplaceCalls = 0;
  bool pendingReplaceActive = false;
  Completer<void>? syncCompleter;
  String? retryReplaceError;

  MockSyncService({this.customUser});

  @override
  User? get currentUser => customUser;

  @override
  Future<bool> isPendingReplaceActive([String? uid]) async {
    return pendingReplaceActive;
  }

  @override
  Future<String?> retryPendingReplace() async {
    retryPendingReplaceCalls++;
    return retryReplaceError;
  }

  @override
  Future<void> syncBidirectional({bool dryRun = false}) async {
    syncBidirectionalCalls++;
    if (syncCompleter != null) {
      await syncCompleter!.future;
    }
  }
}

class MockGastoRepository extends Fake implements GastoRepository {
  List<GastoModel> unsynced = [];

  @override
  Future<List<GastoModel>> obtenerGastosNoSincronizados() async {
    return unsynced;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncService mockSync;
  late MockGastoRepository mockRepo;
  late StreamController<bool> connectivityController;
  late ConnectivityService connectivityService;
  late DateTime currentTime;

  setUp(() {
    currentTime = DateTime(2026, 11, 4, 12, 0, 0);
    mockSync = MockSyncService(customUser: MockUser());
    mockRepo = MockGastoRepository();
    connectivityController = StreamController<bool>.broadcast();
    connectivityService = ConnectivityService(
      testController: connectivityController,
      testConnected: true,
    );
  });

  tearDown(() {
    connectivityController.close();
  });

  group('SyncCoordinator Concurrency and Debounce Tests', () {
    test('1. Cerrojo de concurrencia: peticiones concurrentes ejecutan exactamente 1 inicial y 1 repetición', () async {
      mockSync.syncCompleter = Completer<void>();

      final coordinator = SyncCoordinator(
        syncService: mockSync,
        repository: mockRepo,
        connectivityService: connectivityService,
        debounceDuration: const Duration(milliseconds: 50),
        nowProvider: () => currentTime,
      );

      // Iniciar la primera sincronización (se queda esperando el completer)
      final f1 = coordinator.request(SyncTrigger.manual, forzar: true);
      expect(coordinator.isSyncing, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(mockSync.syncBidirectionalCalls, equals(1));

      // Disparar 3 peticiones adicionales mientras está en curso
      final f2 = coordinator.request(SyncTrigger.escritura);
      final f3 = coordinator.request(SyncTrigger.escritura);
      final f4 = coordinator.request(SyncTrigger.manual);

      // No deben haber incrementado llamadas mientras la primera corre
      expect(mockSync.syncBidirectionalCalls, equals(1));

      // Liberar la primera sincronización
      mockSync.syncCompleter!.complete();
      await f1;
      await f2;
      await f3;
      await f4;

      // Esperar microtasks para que el rerun secuencial se complete
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Debe haber exactamente 2 ejecuciones totales (la inicial y 1 rerun que consolidó las 3 peticiones intermedias)
      expect(mockSync.syncBidirectionalCalls, equals(2));
      expect(coordinator.isSyncing, isFalse);
      expect(coordinator.state.status, equals(SyncStatus.completada));
    });

    test('2. Debounce de 2 segundos: ráfaga de escrituras produce una única ejecución tras el tiempo de espera', () async {
      final coordinator = SyncCoordinator(
        syncService: mockSync,
        repository: mockRepo,
        connectivityService: connectivityService,
        debounceDuration: const Duration(milliseconds: 100),
        nowProvider: () => currentTime,
      );

      // 4 escrituras consecutivas
      coordinator.notifyLocalChange();
      expect(coordinator.state.status, equals(SyncStatus.programada));

      await Future<void>.delayed(const Duration(milliseconds: 30));
      coordinator.notifyLocalChange();

      await Future<void>.delayed(const Duration(milliseconds: 30));
      coordinator.notifyLocalChange();

      await Future<void>.delayed(const Duration(milliseconds: 30));
      coordinator.notifyLocalChange();

      // Durante el debounce no se ha llamado a sync
      expect(mockSync.syncBidirectionalCalls, equals(0));

      // Esperar a que expire el temporizador de 100 ms
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Ahora debe haberse ejecutado exactamente una vez
      expect(mockSync.syncBidirectionalCalls, equals(1));
      expect(coordinator.state.status, equals(SyncStatus.completada));
    });
  });

  group('SyncCoordinator Throttle and Guards Tests', () {
    test('3. Throttle de 5 min: arranque rutinario se omite si se sincronizó recientemente y no hay pendientes', () async {
      final coordinator = SyncCoordinator(
        syncService: mockSync,
        repository: mockRepo,
        connectivityService: connectivityService,
        minRoutineInterval: const Duration(minutes: 5),
        nowProvider: () => currentTime,
      );

      // Primera sincronización rutinaria
      await coordinator.request(SyncTrigger.arranque);
      expect(mockSync.syncBidirectionalCalls, equals(1));

      // Avanzar el reloj 2 minutos (menor al throttle de 5 min)
      currentTime = currentTime.add(const Duration(minutes: 2));

      // Segunda sincronización rutinaria sin cambios locales pendientes
      mockRepo.unsynced = [];
      await coordinator.request(SyncTrigger.arranque);

      // Se debió haber omitido por throttle
      expect(mockSync.syncBidirectionalCalls, equals(1));

      // Si ahora hay cambios locales pendientes, sí debe ejecutarse aunque esté dentro de los 5 min
      mockRepo.unsynced = [
        GastoModel(
          id: 1,
          uuid: 'gasto-1',
          comercio: 'Panadería',
          fecha: '2026-11-04',
          moneda: 'USD',
          totalOriginal: 1000,
          totalUsd: 1000,
          categoria: 'Alimentos',
          creadoEn: '2026-11-04T12:00:00',
          synced: 0,
        ),
      ];
      await coordinator.request(SyncTrigger.arranque);
      expect(mockSync.syncBidirectionalCalls, equals(2));
    });

    test('4. forzar: true en sincronización manual bypasses el throttle de 5 min', () async {
      final coordinator = SyncCoordinator(
        syncService: mockSync,
        repository: mockRepo,
        connectivityService: connectivityService,
        minRoutineInterval: const Duration(minutes: 5),
        nowProvider: () => currentTime,
      );

      await coordinator.request(SyncTrigger.arranque);
      expect(mockSync.syncBidirectionalCalls, equals(1));

      // 1 minuto después, pull-to-refresh manual con forzar: true
      currentTime = currentTime.add(const Duration(minutes: 1));
      mockRepo.unsynced = [];
      await coordinator.request(SyncTrigger.manual, forzar: true);

      expect(mockSync.syncBidirectionalCalls, equals(2));
    });

    test('5. Protección de privacidad: usuarios anónimos o sin sesión no sincronizan con Firestore', () async {
      mockSync.customUser = MockUser(isAnonymous: true);

      final coordinator = SyncCoordinator(
        syncService: mockSync,
        repository: mockRepo,
        connectivityService: connectivityService,
        nowProvider: () => currentTime,
      );

      await coordinator.request(SyncTrigger.manual, forzar: true);
      expect(mockSync.syncBidirectionalCalls, equals(0));
      expect(coordinator.state.status, equals(SyncStatus.inactiva));

      mockSync.customUser = null;
      await coordinator.request(SyncTrigger.arranque);
      expect(mockSync.syncBidirectionalCalls, equals(0));
      expect(coordinator.state.status, equals(SyncStatus.inactiva));
    });

    test('6. Reemplazo pendiente: ejecuta retryPendingReplace antes de la sincronización', () async {
      mockSync.pendingReplaceActive = true;

      final coordinator = SyncCoordinator(
        syncService: mockSync,
        repository: mockRepo,
        connectivityService: connectivityService,
        nowProvider: () => currentTime,
      );

      await coordinator.request(SyncTrigger.manual, forzar: true);
      expect(mockSync.retryPendingReplaceCalls, equals(1));
      expect(mockSync.syncBidirectionalCalls, equals(1));
    });

    test('7. Desconexión de red: aborta y registra estado de error sin llamar a syncBidirectional', () async {
      final offlineService = ConnectivityService(testConnected: false);

      final coordinator = SyncCoordinator(
        syncService: mockSync,
        repository: mockRepo,
        connectivityService: offlineService,
        nowProvider: () => currentTime,
      );

      await coordinator.request(SyncTrigger.manual, forzar: true);
      expect(mockSync.syncBidirectionalCalls, equals(0));
      expect(coordinator.state.status, equals(SyncStatus.error));
      expect(coordinator.state.errorMessage, contains('Sin conexión'));
    });
  });
}
