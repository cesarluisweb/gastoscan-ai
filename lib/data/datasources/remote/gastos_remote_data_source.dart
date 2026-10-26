import '../../models/gasto_model.dart';

class RemoteGasto {
  final String id;
  final Map<String, dynamic> data;

  const RemoteGasto({required this.id, required this.data});
}

class RemotePresupuesto {
  final String id;
  final Map<String, dynamic> data;

  const RemotePresupuesto({required this.id, required this.data});
}

/// Contrato abstracto para la persistencia remota de gastos y presupuestos.
/// Permite inyectar fakes en pruebas unitarias para validar orquestación sin Firebase real.
abstract class GastosRemoteDataSource {
  Future<List<RemoteGasto>> fetchAllGastos(String uid);
  Future<List<RemotePresupuesto>> fetchAllPresupuestos(String uid);
  Future<void> upsertGasto(String uid, GastoModel gasto);
  Future<void> softDeleteGasto(String uid, String uuid, String timestamp);
  Future<void> upsertPresupuesto(String uid, String docId, Map<String, dynamic> data);
}
