import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gastoscan_ai/data/datasources/remote/gastos_remote_data_source.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/data/models/presupuesto_remoto_model.dart';
import 'package:gastoscan_ai/data/repositories/gasto_repository.dart';
import 'package:gastoscan_ai/services/sync_service.dart';

class FakeRemoteDataSource implements GastosRemoteDataSource {
  List<RemoteGasto> remoteGastos = [];
  List<RemotePresupuesto> remotePresupuestos = [];

  bool throwOnFetchGastos = false;
  bool throwOnFetchPresupuestos = false;

  final List<String> softDeletedUuids = [];
  final List<GastoModel> upsertedGastos = [];
  final List<Map<String, dynamic>> upsertedPresupuestos = [];

  @override
  Future<List<RemoteGasto>> fetchAllGastos(String uid) async {
    if (throwOnFetchGastos) throw Exception('Network error fetching gastos');
    return remoteGastos;
  }

  @override
  Future<List<RemotePresupuesto>> fetchAllPresupuestos(String uid) async {
    if (throwOnFetchPresupuestos) throw Exception('Network error fetching presupuestos');
    return remotePresupuestos;
  }

  @override
  Future<void> upsertGasto(String uid, GastoModel gasto) async {
    upsertedGastos.add(gasto);
  }

  @override
  Future<void> softDeleteGasto(String uid, String uuid, String timestamp) async {
    softDeletedUuids.add(uuid);
  }

  @override
  Future<void> upsertPresupuesto(String uid, String docId, Map<String, dynamic> data) async {
    upsertedPresupuestos.add({'docId': docId, ...data});
  }
}

class FakeGastoRepository extends Fake implements GastoRepository {
  List<GastoModel> localGastos = [];
  List<Map<String, dynamic>> localPresupuestos = [];

  final List<int> markedPendingIds = [];
  final List<int> physicallyDeletedIds = [];
  final Map<int, String> repairedFirestoreIds = {};
  bool reemplazarDatosLocalesCalled = false;
  List<GastoModel>? replacedGastos;
  List<PresupuestoRemotoModel>? replacedPresupuestos;

  @override
  Future<List<GastoModel>> obtenerTodosLosGastosConBorrados() async {
    return List.from(localGastos);
  }

  @override
  Future<void> marcarComoPendiente(int id) async {
    markedPendingIds.add(id);
    final idx = localGastos.indexWhere((g) => g.id == id);
    if (idx != -1) {
      localGastos[idx] = localGastos[idx].copyWith(synced: 0);
    }
  }

  @override
  Future<int> eliminarGastoFisico(int id) async {
    physicallyDeletedIds.add(id);
    localGastos.removeWhere((g) => g.id == id);
    return 1;
  }

  @override
  Future<void> repararFirestoreId(int id, String firestoreId) async {
    repairedFirestoreIds[id] = firestoreId;
    final idx = localGastos.indexWhere((g) => g.id == id);
    if (idx != -1) {
      localGastos[idx] = localGastos[idx].copyWith(firestoreId: firestoreId);
    }
  }

  @override
  Future<int> guardarGasto(GastoModel gasto, List<ItemGastoModel> items) async {
    final newId = (localGastos.length + 1);
    localGastos.add(gasto.copyWith(id: newId, items: items));
    return newId;
  }

  @override
  Future<void> actualizarGasto(GastoModel gasto, List<ItemGastoModel> items) async {
    final idx = localGastos.indexWhere((g) => g.id == gasto.id);
    if (idx != -1) {
      localGastos[idx] = gasto.copyWith(items: items);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> obtenerTodosLosPresupuestosMensuales() async {
    return List.from(localPresupuestos);
  }

  @override
  Future<void> guardarPresupuestoGeneralMes(
    int anio,
    int mes,
    double monto, {
    String moneda = 'USD',
    double metaAhorro = 0.0,
  }) async {
    localPresupuestos.add({
      'anio': anio,
      'mes': mes,
      'presupuesto_general': monto,
      'meta_ahorro': metaAhorro,
      'moneda': moneda,
    });
  }

  @override
  Future<void> guardarPresupuestosCategoriasMes(
    int anio,
    int mes,
    Map<String, double> presupuestos, {
    String moneda = 'USD',
  }) async {}

  @override
  Future<void> reemplazarDatosLocales({
    required List<GastoModel> gastos,
    required List<PresupuestoRemotoModel> presupuestos,
  }) async {
    reemplazarDatosLocalesCalled = true;
    replacedGastos = gastos;
    replacedPresupuestos = presupuestos;
  }
}

class FakeUser extends Fake implements User {
  final String _uid;
  final bool _isAnonymous;

  FakeUser({String uid = 'user-123', bool isAnonymous = false})
      : _uid = uid,
        _isAnonymous = isAnonymous;

  @override
  String get uid => _uid;

  @override
  bool get isAnonymous => _isAnonymous;
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? user;

  FakeFirebaseAuth({this.user});

  @override
  User? get currentUser => user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRemoteDataSource fakeRemote;
  late FakeGastoRepository fakeRepo;
  late FakeFirebaseAuth fakeAuth;
  late SyncService syncService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeRemote = FakeRemoteDataSource();
    fakeRepo = FakeGastoRepository();
    fakeAuth = FakeFirebaseAuth(user: FakeUser(uid: 'user-abc', isAnonymous: false));

    syncService = SyncService(
      auth: fakeAuth,
      repository: fakeRepo,
      remoteDataSource: fakeRemote,
    );
  });

  group('SyncService Orchestration Tests', () {
    test('1. Pull error skips push in syncBidirectional', () async {
      fakeRemote.throwOnFetchGastos = true;
      fakeRepo.localGastos = [
        GastoModel(
          id: 1,
          uuid: 'local-uuid-1',
          fecha: '2026-10-26',
          comercio: 'Plaza',
          moneda: 'USD',
          totalOriginal: 1000,
          totalUsd: 1000,
          tasaCambio: 40.0,
          categoria: 'Comida',
          creadoEn: '2026-10-26T10:00:00.000Z',
          synced: 0,
        ),
      ];

      await syncService.syncBidirectional();

      // Push must NOT be executed because Pull failed
      expect(fakeRemote.upsertedGastos, isEmpty);
    });

    test('2. Ghost delete purges locally and makes no remote call', () async {
      // Local gasto is marked deleted but was never pushed (firestoreId is null)
      fakeRepo.localGastos = [
        GastoModel(
          id: 1,
          uuid: 'ghost-uuid-1',
          fecha: '2026-10-26',
          comercio: 'Plaza',
          moneda: 'USD',
          totalOriginal: 1000,
          totalUsd: 1000,
          tasaCambio: 40.0,
          categoria: 'Comida',
          creadoEn: '2026-10-26T10:00:00.000Z',
          eliminadoEn: '2026-10-26T10:00:00.000Z',
          firestoreId: null,
          synced: 0,
        ),
      ];

      await syncService.syncToFirestore(fakeAuth.user!);

      // Should purge locally
      expect(fakeRepo.physicallyDeletedIds, contains(1));
      // Should NOT call remote soft delete
      expect(fakeRemote.softDeletedUuids, isEmpty);
    });

    test('3. Soft delete sends set(merge: true) payload and purges locally on success', () async {
      fakeRepo.localGastos = [
        GastoModel(
          id: 2,
          uuid: 'synced-uuid-2',
          fecha: '2026-10-26',
          comercio: 'Farmatodo',
          moneda: 'USD',
          totalOriginal: 2000,
          totalUsd: 2000,
          tasaCambio: 40.0,
          categoria: 'Salud',
          creadoEn: '2026-10-26T10:00:00.000Z',
          eliminadoEn: '2026-10-26T11:00:00.000Z',
          firestoreId: 'doc-remote-2',
          synced: 0,
        ),
      ];

      await syncService.syncToFirestore(fakeAuth.user!);

      expect(fakeRemote.softDeletedUuids, contains('synced-uuid-2'));
      expect(fakeRepo.physicallyDeletedIds, contains(2));
    });

    test('4. Auto-repair firestoreId when remote exists and local firestoreId is null', () async {
      fakeRepo.localGastos = [
        GastoModel(
          id: 3,
          uuid: 'matching-uuid-3',
          fecha: '2026-10-26',
          comercio: 'Excelsior Gama',
          moneda: 'USD',
          totalOriginal: 3000,
          totalUsd: 3000,
          tasaCambio: 40.0,
          categoria: 'Comida',
          creadoEn: '2026-10-26T10:00:00.000Z',
          firestoreId: null, // Needs healing!
          actualizadoEn: '2026-10-26T10:00:00.000Z',
          synced: 1,
        ),
      ];

      fakeRemote.remoteGastos = [
        const RemoteGasto(
          id: 'doc-remote-3',
          data: {
            'uuid': 'matching-uuid-3',
            'fecha': '2026-10-26',
            'comercio': 'Excelsior Gama',
            'moneda': 'USD',
            'total_original': 30.0,
            'total_usd': 30.0,
            'tasa_cambio': 40.0,
            'categoria': 'Comida',
            'actualizado_en': '2026-10-26T10:00:00.000Z',
          },
        ),
      ];

      await syncService.syncFromFirestore(fakeAuth.user!);

      expect(fakeRepo.repairedFirestoreIds[3], equals('doc-remote-3'));
    });

    test('5. Durable flag blocks syncBidirectional, syncToFirestore, and syncPresupuestosToFirestore', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_pending_replace_user-abc', true);

      fakeRepo.localGastos = [
        GastoModel(
          id: 4,
          uuid: 'pending-uuid-4',
          fecha: '2026-10-26',
          comercio: 'Bio Mercados',
          moneda: 'USD',
          totalOriginal: 1500,
          totalUsd: 1500,
          tasaCambio: 40.0,
          categoria: 'Comida',
          creadoEn: '2026-10-26T10:00:00.000Z',
          synced: 0,
        ),
      ];

      await syncService.syncBidirectional();
      expect(fakeRemote.upsertedGastos, isEmpty);

      await syncService.syncToFirestore(fakeAuth.user!);
      expect(fakeRemote.upsertedGastos, isEmpty);

      await syncService.syncPresupuestosToFirestore(fakeAuth.user!);
      expect(fakeRemote.upsertedPresupuestos, isEmpty);
    });

    test('6. retryPendingReplace executes atomic replace and clears durable flag', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_pending_replace_user-abc', true);

      fakeRemote.remoteGastos = [
        const RemoteGasto(
          id: 'remote-doc-5',
          data: {
            'uuid': 'uuid-remote-5',
            'fecha': '2026-10-26',
            'comercio': 'EPA',
            'moneda': 'USD',
            'total_original': 100.0,
            'total_usd': 100.0,
            'tasa_cambio': 40.0,
            'categoria': 'Hogar',
            'actualizado_en': '2026-10-26T10:00:00.000Z',
          },
        ),
      ];

      fakeRemote.remotePresupuestos = [
        const RemotePresupuesto(
          id: '2026_10',
          data: {
            'anio': 2026,
            'mes': 10,
            'presupuesto_general': 500.0,
            'meta_ahorro': 100.0,
            'moneda': 'USD',
            'actualizado_en': '2026-10-26T10:00:00.000Z',
            'categorias': {'Hogar': 200.0},
          },
        ),
      ];

      final err = await syncService.retryPendingReplace();

      expect(err, isNull);
      expect(fakeRepo.reemplazarDatosLocalesCalled, isTrue);
      expect(fakeRepo.replacedGastos!.length, equals(1));
      expect(fakeRepo.replacedPresupuestos!.length, equals(1));
      expect(prefs.getBool('sync_pending_replace_user-abc'), isNull);
    });
  });
}
