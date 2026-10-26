import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/gasto_firestore_mapper.dart';
import '../../models/gasto_model.dart';
import 'gastos_remote_data_source.dart';

class FirestoreGastosRemoteDataSource implements GastosRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirestoreGastosRemoteDataSource(this._firestore);

  @override
  Future<List<RemoteGasto>> fetchAllGastos(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('gastos')
        .get();

    return snapshot.docs
        .map((doc) => RemoteGasto(id: doc.id, data: doc.data()))
        .toList();
  }

  @override
  Future<List<RemotePresupuesto>> fetchAllPresupuestos(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('presupuestos')
        .get();

    return snapshot.docs
        .map((doc) => RemotePresupuesto(id: doc.id, data: doc.data()))
        .toList();
  }

  @override
  Future<void> upsertGasto(String uid, GastoModel gasto) async {
    final payload = GastoFirestoreMapper.toPayload(gasto);
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('gastos')
        .doc(gasto.uuid)
        .set(payload, SetOptions(merge: true));
  }

  @override
  Future<void> softDeleteGasto(String uid, String uuid, String timestamp) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('gastos')
        .doc(uuid)
        .set({
      'uuid': uuid,
      'eliminado_en': timestamp,
      'actualizado_en': timestamp,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> upsertPresupuesto(String uid, String docId, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('presupuestos')
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }
}
