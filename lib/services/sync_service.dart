import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants/app_constants.dart';
import '../data/models/gasto_model.dart';
import '../data/models/item_gasto_model.dart';
import '../data/repositories/gasto_repository.dart';

class SyncService {
  final GastoRepository _repository;

  SyncService({GastoRepository? repository}) : _repository = repository ?? GastoRepository();

  Future<void> syncBidirectional() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;

      await syncToFirestore(user);
      await syncFromFirestore(user);
      await syncPresupuestosToFirestore(user);
      await syncPresupuestosFromFirestore(user);

      // Sincronizar API Key personalizada de Gemini con la cuenta de Google
      await syncApiKeyBidireccional(user);
    } catch (e) {
      debugPrint("Error en sincronización bidireccional: $e");
    }
  }

  Future<void> syncApiKeyBidireccional(User user) async {
    try {
      if (user.isAnonymous) return;
      const secureStorage = FlutterSecureStorage();
      final localKey = await secureStorage.read(key: AppConstants.prefApiKey);
      final remoteKey = await syncSettingsFromFirestore(user);

      if (remoteKey != null && remoteKey.trim().isNotEmpty) {
        if (localKey != remoteKey.trim()) {
          await secureStorage.write(key: AppConstants.prefApiKey, value: remoteKey.trim());
        }
      } else if (localKey != null && localKey.trim().isNotEmpty) {
        await syncSettingsToFirestore(user, apiKey: localKey.trim());
      }
    } catch (e) {
      debugPrint("Error sincronizando API Key de Gemini: $e");
    }
  }

  Future<void> syncSettingsToFirestore(User user, {required String apiKey}) async {
    try {
      if (user.isAnonymous) return;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('presupuestos')
          .doc('user_settings');

      await docRef.set({
        'gemini_api_key': apiKey.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error guardando settings en Firestore: $e");
    }
  }

  Future<String?> syncSettingsFromFirestore(User user) async {
    try {
      if (user.isAnonymous) return null;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('presupuestos')
          .doc('user_settings');

      final doc = await docRef.get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return data['gemini_api_key'] as String?;
    } catch (e) {
      debugPrint("Error leyendo settings de Firestore: $e");
      return null;
    }
  }

  Future<void> syncToFirestore(User user) async {
    final unsyncedGastos = await _repository.obtenerGastosNoSincronizados();
    
    for (var gasto in unsyncedGastos) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('gastos')
          .doc(gasto.uuid); 
          
      if (gasto.eliminadoEn != null) {
        await docRef.delete();
        if (gasto.id != null) {
          await _repository.eliminarGastoFisico(gasto.id!);
        }
      } else {
        final data = gasto.toMap();
        data['items'] = gasto.items.map((item) => item.toMap()).toList();
        
        await docRef.set(data, SetOptions(merge: true));
        
        final syncedGasto = gasto.copyWith(firestoreId: docRef.id, synced: 1);
        await _repository.actualizarGastoSyncStatus(syncedGasto);
      }
    }
  }

  Future<void> syncFromFirestore(User user) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('gastos')
        .get();

    if (snapshot.docs.isEmpty) return;

    final localGastos = await _repository.obtenerTodosLosGastosConBorrados();
    final localMap = {for (var g in localGastos) g.uuid: g};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final firestoreUuid = doc.id; 

      final itemsRaw = data['items'] as List<dynamic>? ?? [];
      final items = itemsRaw
          .map((itemMap) => ItemGastoModel.fromMap(Map<String, dynamic>.from(itemMap as Map)))
          .toList();

      final gastoRemoto = GastoModel.fromMap(data, items: items).copyWith(
        id: null,
        uuid: firestoreUuid,
        firestoreId: doc.id,
        synced: 1,
      );

      final localGasto = localMap[firestoreUuid];

      if (localGasto == null) {
        if (gastoRemoto.eliminadoEn == null) {
          await _repository.guardarGasto(gastoRemoto, items);
        }
      } else {
        final remoteTime = DateTime.tryParse(gastoRemoto.actualizadoEn ?? gastoRemoto.creadoEn) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final localTime = DateTime.tryParse(localGasto.actualizadoEn ?? localGasto.creadoEn) ?? DateTime.fromMillisecondsSinceEpoch(0);

        if (remoteTime.isAfter(localTime)) {
          if (gastoRemoto.eliminadoEn != null) {
            await _repository.eliminarGastoFisico(localGasto.id!);
          } else {
            await _repository.actualizarGasto(gastoRemoto.copyWith(id: localGasto.id, synced: 1), items);
          }
        }
      }
    }
  }

  Future<void> syncPresupuestosToFirestore(User user) async {
    final presupuestos = await _repository.obtenerTodosLosPresupuestosMensuales();
    for (var pres in presupuestos) {
      final anio = pres['anio'] as int;
      final mes = pres['mes'] as int;
      final general = (pres['presupuesto_general'] as num?)?.toDouble() ?? 0.0;
      final moneda = (pres['moneda'] as String?) ?? 'USD';
      final categorias = (pres['categorias'] as Map<String, dynamic>?) ?? {};
      final actualizadoEn = pres['actualizado_en'] as String? ?? DateTime.now().toIso8601String();

      if (general <= 0 && categorias.isEmpty) continue;

      final docId = '${anio}_${mes.toString().padLeft(2, '0')}';
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('presupuestos')
          .doc(docId);

      final snapshot = await docRef.get();
      if (snapshot.exists) {
        final remoteData = snapshot.data();
        if (remoteData != null && remoteData['actualizado_en'] != null) {
          final remoteTime = DateTime.tryParse(remoteData['actualizado_en'].toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final localTime = DateTime.tryParse(actualizadoEn) ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (remoteTime.isAfter(localTime)) {
            continue;
          }
        }
      }

      await docRef.set({
        'anio': anio,
        'mes': mes,
        'presupuesto_general': general,
        'meta_ahorro': (pres['meta_ahorro'] as num?)?.toDouble() ?? 0.0,
        'moneda': moneda,
        'categorias': categorias,
        'actualizado_en': actualizadoEn,
      }, SetOptions(merge: true));
    }
  }

  Future<void> syncPresupuestosFromFirestore(User user) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('presupuestos')
        .get();

    if (snapshot.docs.isEmpty) return;

    final localPresupuestos = await _repository.obtenerTodosLosPresupuestosMensuales();
    final Map<String, Map<String, dynamic>> localMap = {};
    for (var p in localPresupuestos) {
      final anio = p['anio'] as int;
      final mes = p['mes'] as int;
      localMap['${anio}_${mes.toString().padLeft(2, '0')}'] = p;
    }

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final anio = (data['anio'] as num?)?.toInt() ?? 0;
      final mes = (data['mes'] as num?)?.toInt() ?? 0;
      if (anio == 0 || mes == 0) continue;

      final docId = '${anio}_${mes.toString().padLeft(2, '0')}';
      final remoteGeneral = (data['presupuesto_general'] as num?)?.toDouble() ?? 0.0;
      final remoteMetaAhorro = (data['meta_ahorro'] as num?)?.toDouble() ?? 0.0;
      final remoteMoneda = (data['moneda'] as String?) ?? 'USD';
      final remoteCatsRaw = data['categorias'] as Map<String, dynamic>? ?? {};
      final Map<String, double> remoteCats = {};
      remoteCatsRaw.forEach((k, v) {
        if (v is num && v.toDouble() > 0) {
          remoteCats[k] = v.toDouble();
        }
      });
      final remoteActualizadoEn = data['actualizado_en'] as String? ?? DateTime.now().toIso8601String();

      final localP = localMap[docId];
      if (localP == null) {
        await _repository.guardarPresupuestoMensualCompleto(
          anio: anio,
          mes: mes,
          general: remoteGeneral,
          moneda: remoteMoneda,
          categorias: remoteCats,
          metaAhorro: remoteMetaAhorro,
          actualizadoEn: remoteActualizadoEn,
        );
      } else {
        final localActualizadoEn = localP['actualizado_en'] as String?;
        final localTime = DateTime.tryParse(localActualizadoEn ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final remoteTime = DateTime.tryParse(remoteActualizadoEn) ?? DateTime.fromMillisecondsSinceEpoch(0);

        if (remoteTime.isAfter(localTime)) {
          await _repository.guardarPresupuestoMensualCompleto(
            anio: anio,
            mes: mes,
            general: remoteGeneral,
            moneda: remoteMoneda,
            categorias: remoteCats,
            metaAhorro: remoteMetaAhorro,
            actualizadoEn: remoteActualizadoEn,
          );
        }
      }
    }
  }

  Future<void> intentarLoginSilencioso() async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      if (currentUser != null && !currentUser.isAnonymous) {
        return;
      }

      final googleSignIn = GoogleSignIn(
        serverClientId: '758679432067-p4lll1b5vfia32fndd68gjif6bmfmvel.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await auth.signInWithCredential(credential);
      final activeUser = userCred.user ?? auth.currentUser;
      if (activeUser != null) {
        await activeUser.updateProfile(
          displayName: googleUser.displayName,
          photoURL: googleUser.photoUrl,
        );
        await activeUser.reload();
      }
      await syncBidirectional();
    } catch (e) {
      debugPrint("Fallo al autenticar silenciosamente con Google: $e");
    }
  }

  /// Cierra sesión en Firebase y Google, vacía la base de datos local (SQLite)
  /// e inicia una sesión anónima fresca para un aislamiento total.
  Future<void> cerrarSesion() async {
    try {
      final auth = FirebaseAuth.instance;

      try {
        final googleSignIn = GoogleSignIn(
          serverClientId: '758679432067-p4lll1b5vfia32fndd68gjif6bmfmvel.apps.googleusercontent.com',
        );
        await googleSignIn.signOut();
      } catch (_) {}

      await auth.signOut();
      await _repository.limpiarDatosLocales();
      await auth.signInAnonymously();
    } catch (e) {
      debugPrint("Error al cerrar sesión y limpiar datos locales: $e");
      rethrow;
    }
  }

  Future<String?> vincularCuentaGoogle({bool descartarDatosLocales = false}) async {
    try {
      final auth = FirebaseAuth.instance;

      final googleSignIn = GoogleSignIn(
        serverClientId: '758679432067-p4lll1b5vfia32fndd68gjif6bmfmvel.apps.googleusercontent.com',
      );

      // Limpiar sesión previa para garantizar que siempre se muestre el selector de cuentas
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // El usuario canceló la selección de cuenta
        return 'CANCELLED';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final user = auth.currentUser;
      if (user == null) {
        if (descartarDatosLocales) {
          await _repository.limpiarDatosLocales();
        }
        final userCred = await auth.signInWithCredential(credential);
        if (userCred.user != null) {
          await userCred.user?.updateProfile(
            displayName: googleUser.displayName,
            photoURL: googleUser.photoUrl,
          );
          await userCred.user?.reload();
        }
        await syncBidirectional();
        return null;
      }

      if (user.isAnonymous) {
        try {
          if (descartarDatosLocales) {
            await _repository.limpiarDatosLocales();
          }
          final userCred = await user.linkWithCredential(credential);
          final activeUser = userCred.user ?? auth.currentUser ?? user;
          await activeUser.updateProfile(displayName: googleUser.displayName, photoURL: googleUser.photoUrl);
          await activeUser.reload();
          await syncBidirectional();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use' ||
              e.code == 'account-exists-with-different-credential') {
            if (descartarDatosLocales) {
              await _repository.limpiarDatosLocales();
            }
            final userCred = await auth.signInWithCredential(credential);
            final activeUser = userCred.user ?? auth.currentUser;
            if (activeUser != null) {
              await activeUser.updateProfile(displayName: googleUser.displayName, photoURL: googleUser.photoUrl);
              await activeUser.reload();
            }

            if (!descartarDatosLocales) {
              final gastos = await _repository.obtenerGastos();
              for (var g in gastos) {
                await _repository.actualizarGastoSyncStatus(g.copyWith(synced: 0));
              }
            }
            await syncBidirectional();
          } else {
            return _mapearErrorFirebaseAuth(e);
          }
        }
      } else {
        await user.updateProfile(displayName: googleUser.displayName, photoURL: googleUser.photoUrl);
        await user.reload();
        await syncBidirectional();
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint("Error de plataforma al vincular Google: ${e.code} - ${e.message}");
      if (e.message != null && e.message!.contains('10')) {
        return "Error 10 (Configuración): Falta la huella digital SHA en Firebase Console o la clave Web Client ID no coincide.";
      }
      if (e.message != null && e.message!.contains('12500')) {
        return "Error 12500: Fallo de autenticación en Google Play Services. Verifica correo de soporte en Firebase.";
      }
      return e.message ?? e.toString();
    } catch (e) {
      debugPrint("Error al vincular Google: $e");
      return e.toString();
    }
  }

  String _mapearErrorFirebaseAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta registrada con este correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return 'Este correo ya está registrado con otra cuenta.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'operation-not-allowed':
        return 'El método de inicio de sesión no está habilitado en la consola de Firebase.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intenta más tarde.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Verifica tu red.';
      default:
        return e.message ?? 'Error de autenticación: ${e.code}';
    }
  }

  Future<String?> vincularConEmail(String email, String password, {bool descartarDatosLocales = false}) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return 'Ingresa un correo electrónico válido.';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    try {
      final auth = FirebaseAuth.instance;
      final credential = EmailAuthProvider.credential(
        email: cleanEmail,
        password: password,
      );

      final user = auth.currentUser;
      if (user == null) {
        if (descartarDatosLocales) {
          await _repository.limpiarDatosLocales();
        }
        try {
          await auth.signInWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
            await auth.createUserWithEmailAndPassword(
              email: cleanEmail,
              password: password,
            );
          } else {
            return _mapearErrorFirebaseAuth(e);
          }
        }
        await syncBidirectional();
        return null;
      }

      if (user.isAnonymous) {
        try {
          if (descartarDatosLocales) {
            await _repository.limpiarDatosLocales();
          }
          final userCred = await user.linkWithCredential(credential);
          final activeUser = userCred.user ?? auth.currentUser ?? user;
          await activeUser.reload();
          await syncBidirectional();
          return null;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use' ||
              e.code == 'account-exists-with-different-credential') {
            if (descartarDatosLocales) {
              await _repository.limpiarDatosLocales();
            }
            final userCred = await auth.signInWithCredential(credential);
            final activeUser = userCred.user ?? auth.currentUser;
            if (activeUser != null) {
              await activeUser.reload();
            }

            if (!descartarDatosLocales) {
              final gastos = await _repository.obtenerGastos();
              for (var g in gastos) {
                await _repository.actualizarGastoSyncStatus(g.copyWith(synced: 0));
              }
            }
            await syncBidirectional();
            return null;
          } else {
            return _mapearErrorFirebaseAuth(e);
          }
        }
      } else {
        try {
          await user.linkWithCredential(credential);
          await user.reload();
          await syncBidirectional();
          return null;
        } on FirebaseAuthException catch (e) {
          return _mapearErrorFirebaseAuth(e);
        }
      }
    } on FirebaseAuthException catch (e) {
      return _mapearErrorFirebaseAuth(e);
    } catch (e) {
      debugPrint("Error al vincular con email: $e");
      return e.toString();
    }
  }

  Future<String?> iniciarSesionConEmail(String email, String password, {bool descartarDatosLocales = true}) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return 'Ingresa un correo electrónico válido.';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    try {
      final auth = FirebaseAuth.instance;
      if (descartarDatosLocales) {
        await _repository.limpiarDatosLocales();
      }
      final userCred = await auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final activeUser = userCred.user ?? auth.currentUser;
      if (activeUser != null) {
        await activeUser.reload();
      }

      if (!descartarDatosLocales) {
        final gastos = await _repository.obtenerGastos();
        for (var g in gastos) {
          await _repository.actualizarGastoSyncStatus(g.copyWith(synced: 0));
        }
      }
      await syncBidirectional();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapearErrorFirebaseAuth(e);
    } catch (e) {
      debugPrint("Error al iniciar sesión con email: $e");
      return e.toString();
    }
  }
}
