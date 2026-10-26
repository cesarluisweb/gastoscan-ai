import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/repositories/gasto_repository.dart';
import 'package:gastoscan_ai/services/sync_service.dart';
import 'package:gastoscan_ai/services/image_service.dart';

class FakeUserInfo extends Fake implements UserInfo {
  final String _providerId;
  FakeUserInfo(this._providerId);

  @override
  String get providerId => _providerId;
}

class FakeUser extends Fake implements User {
  final String _uid;
  final bool _isAnonymous;
  final List<UserInfo> _providerData;
  bool deleteCalled = false;
  Exception? errorOnDelete;

  FakeUser({
    String uid = 'test-uid',
    bool isAnonymous = false,
    List<UserInfo> providerData = const [],
    this.errorOnDelete,
  })  : _uid = uid,
        _isAnonymous = isAnonymous,
        _providerData = providerData;

  @override
  String get uid => _uid;

  @override
  bool get isAnonymous => _isAnonymous;

  @override
  List<UserInfo> get providerData => _providerData;

  @override
  Future<void> delete() async {
    if (errorOnDelete != null) {
      throw errorOnDelete!;
    }
    deleteCalled = true;
  }
}

class FakeUserCredential extends Fake implements UserCredential {}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? _currentUser;
  bool signOutCalled = false;
  bool signInAnonymouslyCalled = false;

  FakeFirebaseAuth({User? currentUser}) : _currentUser = currentUser;

  @override
  User? get currentUser => _currentUser;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    _currentUser = null;
  }

  @override
  Future<UserCredential> signInAnonymously() async {
    signInAnonymouslyCalled = true;
    _currentUser = FakeUser(uid: 'fresh-anon-uid', isAnonymous: true);
    return FakeUserCredential();
  }
}

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> storage = {};
  bool deleteAllCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final member = invocation.memberName;
    if (member == #write) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value != null) storage[key] = value;
      return Future<void>.value();
    }
    if (member == #read) {
      final key = invocation.namedArguments[#key] as String;
      return Future<String?>.value(storage[key]);
    }
    if (member == #delete) {
      final key = invocation.namedArguments[#key] as String;
      storage.remove(key);
      return Future<void>.value();
    }
    if (member == #deleteAll) {
      deleteAllCalled = true;
      storage.clear();
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  bool signOutCalled = false;
  GoogleSignInAccount? accountToReturn;

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalled = true;
    return null;
  }

  @override
  Future<GoogleSignInAccount?> signIn() async {
    return accountToReturn;
  }
}

class FakeGastoRepository extends Fake implements GastoRepository {
  bool limpiarDatosLocalesCalled = false;
  bool obtenerRutasCalled = false;
  List<String> fakeRutasArchivos = [];

  @override
  Future<void> limpiarDatosLocales() async {
    limpiarDatosLocalesCalled = true;
  }

  @override
  Future<List<String>> obtenerRutasArchivosApp() async {
    obtenerRutasCalled = true;
    return fakeRutasArchivos;
  }
}

void main() {
  group('SyncService Deletion and Cleanup Tests', () {
    late FakeGastoRepository fakeRepo;
    late FakeFlutterSecureStorage fakeStorage;
    late FakeGoogleSignIn fakeGoogle;

    setUp(() {
      fakeRepo = FakeGastoRepository();
      fakeStorage = FakeFlutterSecureStorage();
      fakeGoogle = FakeGoogleSignIn();
      fakeStorage.storage[AppConstants.prefApiKey] = 'gemini-secret-key-123';
      fakeStorage.storage['otro_plugin_key'] = 'preserve-this';
    });

    test('Caso de exito usuario autenticado: purga Firestore, Auth, Storage y BD local', () async {
      final fakeUser = FakeUser(uid: 'user-auth-123', isAnonymous: false);
      final fakeAuth = FakeFirebaseAuth(currentUser: fakeUser);
      bool purgerCalled = false;

      final syncService = SyncService(
        repository: fakeRepo,
        auth: fakeAuth,
        googleSignIn: fakeGoogle,
        secureStorage: fakeStorage,
        firestorePurger: (uid) async {
          expect(uid, equals('user-auth-123'));
          purgerCalled = true;
        },
      );

      final error = await syncService.eliminarCuentaYDatos();

      expect(error, isNull);
      expect(purgerCalled, isTrue);
      expect(fakeUser.deleteCalled, isTrue);
      expect(fakeRepo.limpiarDatosLocalesCalled, isTrue);
      // Verifica limpieza especifica de la clave de Rinde Mas sin deleteAll ciego
      expect(fakeStorage.storage.containsKey(AppConstants.prefApiKey), isFalse);
      expect(fakeStorage.storage['otro_plugin_key'], equals('preserve-this'));
      expect(fakeStorage.deleteAllCalled, isFalse);
      expect(fakeGoogle.signOutCalled, isTrue);
      expect(fakeAuth.signInAnonymouslyCalled, isTrue);
    });

    test('Caso de error de red en Firestore: no silencia error y no borra datos locales', () async {
      final fakeUser = FakeUser(uid: 'user-auth-123', isAnonymous: false);
      final fakeAuth = FakeFirebaseAuth(currentUser: fakeUser);

      final syncService = SyncService(
        repository: fakeRepo,
        auth: fakeAuth,
        googleSignIn: fakeGoogle,
        secureStorage: fakeStorage,
        firestorePurger: (uid) async {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'The service is currently unavailable.',
          );
        },
      );

      final error = await syncService.eliminarCuentaYDatos();

      expect(error, isNotNull);
      expect(error, contains('Sin conexión a internet'));
      // No debe borrar el usuario en Auth ni vaciar la base local si fallo la nube
      expect(fakeUser.deleteCalled, isFalse);
      expect(fakeRepo.limpiarDatosLocalesCalled, isFalse);
      expect(fakeStorage.storage.containsKey(AppConstants.prefApiKey), isTrue);
    });

    test('Caso de usuario anonimo: purga remoto y local correctamente', () async {
      final fakeAnonUser = FakeUser(uid: 'anon-user-456', isAnonymous: true);
      final fakeAuth = FakeFirebaseAuth(currentUser: fakeAnonUser);
      bool purgerCalled = false;

      final syncService = SyncService(
        repository: fakeRepo,
        auth: fakeAuth,
        googleSignIn: fakeGoogle,
        secureStorage: fakeStorage,
        firestorePurger: (uid) async {
          expect(uid, equals('anon-user-456'));
          purgerCalled = true;
        },
      );

      final error = await syncService.eliminarCuentaYDatos();

      expect(error, isNull);
      expect(purgerCalled, isTrue);
      expect(fakeAnonUser.deleteCalled, isTrue);
      expect(fakeRepo.limpiarDatosLocalesCalled, isTrue);
      expect(fakeStorage.storage.containsKey(AppConstants.prefApiKey), isFalse);
      expect(fakeAuth.signInAnonymouslyCalled, isTrue);
    });

    test('Caso de fallo en Firebase Auth requires-recent-login sin reautenticacion: retorna error y preserva datos locales', () async {
      final fakeUser = FakeUser(
        uid: 'user-expired-789',
        isAnonymous: false,
        providerData: [FakeUserInfo('password')],
        errorOnDelete: FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'This operation is sensitive and requires recent authentication.',
        ),
      );
      final fakeAuth = FakeFirebaseAuth(currentUser: fakeUser);

      final syncService = SyncService(
        repository: fakeRepo,
        auth: fakeAuth,
        googleSignIn: fakeGoogle,
        secureStorage: fakeStorage,
        firestorePurger: (uid) async {},
      );

      final error = await syncService.eliminarCuentaYDatos();

      expect(error, equals('REQUIRES_PASSWORD_REAUTH'));
      expect(fakeRepo.limpiarDatosLocalesCalled, isFalse);
    });

    test('Caso de fallo en Firebase Auth network-request-failed: retorna error y preserva datos locales', () async {
      final fakeUser = FakeUser(
        uid: 'user-net-error',
        isAnonymous: false,
        errorOnDelete: FirebaseAuthException(
          code: 'network-request-failed',
          message: 'A network error occurred.',
        ),
      );
      final fakeAuth = FakeFirebaseAuth(currentUser: fakeUser);

      final syncService = SyncService(
        repository: fakeRepo,
        auth: fakeAuth,
        googleSignIn: fakeGoogle,
        secureStorage: fakeStorage,
        firestorePurger: (uid) async {},
      );

      final error = await syncService.eliminarCuentaYDatos();

      expect(error, isNotNull);
      expect(error, contains('Sin conexión a internet'));
      expect(fakeRepo.limpiarDatosLocalesCalled, isFalse);
    });

    test('GastoModel toFirestoreMap excluye ruta_foto_local mientras toMap lo conserva', () {
      final gasto = GastoModel(
        id: 42,
        uuid: 'test-uuid-999',
        fecha: '2026-10-13',
        comercio: 'Automercado Plaza',
        moneda: 'USD',
        totalOriginal: 2500,
        totalUsd: 2500,
        categoria: 'Alimentación',
        rutaFotoLocal: '/data/user/0/com.cesarluis.rindemas/app_flutter/recibo_123.jpg',
        creadoEn: '2026-10-13T12:00:00Z',
      );

      final mapSqlite = gasto.toMap();
      expect(mapSqlite['ruta_foto_local'], equals('/data/user/0/com.cesarluis.rindemas/app_flutter/recibo_123.jpg'));
      expect(mapSqlite['id'], equals(42));

      final mapFirestore = gasto.toFirestoreMap();
      expect(mapFirestore.containsKey('ruta_foto_local'), isFalse);
      expect(mapFirestore['uuid'], equals('test-uuid-999'));
    });

    test('ImageService limpiarArchivosApp elimina archivos internos sin afectar archivos externos', () async {
      final tempDir = Directory.systemTemp.createTempSync('rindemas_test_');
      final internalReceipt = File('${tempDir.path}/recibo_12345.jpg')..writeAsStringSync('recibo interno');
      final externalUserFile = File('${tempDir.path}/foto_usuario_personal.jpg')..writeAsStringSync('foto externa');

      try {
        expect(internalReceipt.existsSync(), isTrue);
        expect(externalUserFile.existsSync(), isTrue);

        await ImageService.limpiarArchivosApp(rutasConocidas: [
          internalReceipt.path,
          externalUserFile.path,
        ]);

        // El archivo con prefijo recibo_ debe ser eliminado
        expect(internalReceipt.existsSync(), isFalse);
        // El archivo externo sin prefijo recibo_ y fuera de appDir/tempDir estandar no se borra
        expect(externalUserFile.existsSync(), isTrue);
      } finally {
        if (externalUserFile.existsSync()) externalUserFile.deleteSync();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    });

    test('eliminarCuentaYDatos respects eliminarFotos flag', () async {
      final fakeUser = FakeUser(uid: 'user-photos-flag', isAnonymous: false);
      final fakeAuth = FakeFirebaseAuth(currentUser: fakeUser);
      final repo = FakeGastoRepository();

      final syncService = SyncService(
        repository: repo,
        auth: fakeAuth,
        googleSignIn: fakeGoogle,
        secureStorage: fakeStorage,
        firestorePurger: (uid) async {},
      );

      // 1. When false, does NOT query or delete files
      await syncService.eliminarCuentaYDatos(eliminarFotos: false);
      expect(repo.obtenerRutasCalled, isFalse);

      // 2. When true, queries routes and purges
      final repo2 = FakeGastoRepository();
      final syncService2 = SyncService(
        repository: repo2,
        auth: fakeAuth,
        googleSignIn: fakeGoogle,
        secureStorage: fakeStorage,
        firestorePurger: (uid) async {},
      );
      await syncService2.eliminarCuentaYDatos(eliminarFotos: true);
      expect(repo2.obtenerRutasCalled, isTrue);
    });
  });
}
