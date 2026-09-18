import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    } catch (e) {
      debugPrint("Error en sincronización bidireccional: $e");
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

  Future<String?> vincularCuentaGoogle() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) return "No hay sesión local activa";

      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        serverClientId: '758679432067-p4lll1b5vfia32fndd68gjif6bmfmvel.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      if (user.isAnonymous) {
        try {
          await user.linkWithCredential(credential);
          await user.updateProfile(displayName: googleUser.displayName, photoURL: googleUser.photoUrl);
          await user.reload();
          await syncBidirectional();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            final userCred = await auth.signInWithCredential(credential);
            if (userCred.user != null) {
              await userCred.user?.updateProfile(displayName: googleUser.displayName, photoURL: googleUser.photoUrl);
              await userCred.user?.reload();
            }

            final gastos = await _repository.obtenerGastos();
            for (var g in gastos) {
              await _repository.actualizarGastoSyncStatus(g.copyWith(synced: 0));
            }
            await syncBidirectional();
          } else {
            return e.message ?? e.toString();
          }
        }
      } else {
        await syncBidirectional();
      }
      return null;
    } catch (e) {
      debugPrint("Error al vincular Google: $e");
      return e.toString();
    }
  }
}
