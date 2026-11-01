import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/datasources/remote/gastos_remote_data_source.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/repositories/gasto_repository.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/services/sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockRecordingDatabaseHelper extends DatabaseHelper {
  MockRecordingDatabaseHelper() : super.test();

  bool updateExecuted = false;
  int recordedCallCount = 0;
  double? lastFallback;
  bool? lastDryRun;

  @override
  Future<int> repararTasasHistoricasIncompletas({
    double tasaFallback = AppConstants.defaultTasaCambio,
    bool dryRun = true,
  }) async {
    recordedCallCount++;
    lastFallback = tasaFallback;
    lastDryRun = dryRun;
    if (!dryRun) {
      updateExecuted = true;
    }
    // Simula 3 registros encontrados que requieren reparación
    return 3;
  }
}

class FakeUserSimple implements User {
  @override
  final String uid;
  @override
  final bool isAnonymous;

  FakeUserSimple({required this.uid, required this.isAnonymous});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthSimple implements FirebaseAuth {
  final User? user;
  FakeAuthSimple({this.user});

  @override
  User? get currentUser => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRemoteDataSourceTracking implements GastosRemoteDataSource {
  final List<GastoModel> upserted = [];

  @override
  Future<List<RemoteGasto>> fetchAllGastos(String uid) async => [];

  @override
  Future<List<RemotePresupuesto>> fetchAllPresupuestos(String uid) async => [];

  @override
  Future<void> upsertGasto(String uid, GastoModel gasto) async {
    upserted.add(gasto);
  }

  @override
  Future<void> softDeleteGasto(String uid, String uuid, String timestamp) async {}

  @override
  Future<void> upsertPresupuesto(String uid, String docId, Map<String, dynamic> data) async {}
}

class FakeGastoRepositoryForSync extends GastoRepository {
  final List<GastoModel> noSynced;
  FakeGastoRepositoryForSync(this.noSynced) : super(dbHelper: DatabaseHelper.test());

  @override
  Future<List<GastoModel>> obtenerGastosNoSincronizados() async => noSynced;

  @override
  Future<void> actualizarGastoSyncStatus(GastoModel gasto) async {}
}

void main() {
  group('E0-05a: Configuración por defecto dryRun = true y bloqueo de escritura', () {
    test('1. GastoRepository.repararTasasHistoricasIncompletas tiene dryRun = true por defecto', () async {
      final mockDb = MockRecordingDatabaseHelper();
      final repo = GastoRepository(dbHelper: mockDb);

      final count = await repo.repararTasasHistoricasIncompletas();

      expect(count, equals(3));
      expect(mockDb.lastDryRun, isTrue);
      expect(mockDb.updateExecuted, isFalse);
    });

    test('2. GastoRepository.repararTasasHistoricasIncompletas permite dryRun = false explícito', () async {
      final mockDb = MockRecordingDatabaseHelper();
      final repo = GastoRepository(dbHelper: mockDb);

      final count = await repo.repararTasasHistoricasIncompletas(dryRun: false);

      expect(count, equals(3));
      expect(mockDb.lastDryRun, isFalse);
      expect(mockDb.updateExecuted, isTrue);
    });

    test('3. GastoProvider.repararTasasHistoricas propaga dryRun = true por defecto y no recarga datos', () async {
      final mockDb = MockRecordingDatabaseHelper();
      final repo = GastoRepository(dbHelper: mockDb);
      final provider = GastoProvider(repository: repo);

      final count = await provider.repararTasasHistoricas();

      expect(count, equals(3));
      expect(mockDb.lastDryRun, isTrue);
      expect(mockDb.updateExecuted, isFalse);
    });

    test('4. SyncService: syncToFirestore con dryRun = true bloquea el push de gastos', () async {
      final gasto = GastoModel(
        id: 1,
        uuid: 'test-uuid-1',
        fecha: '2026-10-26',
        comercio: 'Automercado',
        moneda: 'USD',
        totalOriginal: 1000,
        totalUsd: 1000,
        tasaCambio: 474.0, // tasa sospechosa
        categoria: 'Otros',
        synced: 0,
      );

      final fakeRepo = FakeGastoRepositoryForSync([gasto]);
      final fakeRemote = FakeRemoteDataSourceTracking();
      final fakeAuth = FakeAuthSimple(user: FakeUserSimple(uid: 'user-123', isAnonymous: false));

      final syncService = SyncService(
        repository: fakeRepo,
        remoteDataSource: fakeRemote,
        auth: fakeAuth,
      );

      // Ejecutar sync con dryRun = true
      await syncService.syncToFirestore(fakeAuth.currentUser!, dryRun: true);

      // No debe haberse subido nada
      expect(fakeRemote.upserted, isEmpty);
    });
  });
}
