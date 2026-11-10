import '../data/models/gasto_model.dart';
import '../domain/monetary/monetary_resolution.dart';

enum AccionReconciliacion {
  mantenerLocal,              // Local es más reciente o idéntico; no se altera SQLite
  actualizarLocalDesdeRemoto, // Remoto es más reciente y local limpio (synced=1); actualiza SQLite preservando foto local
  eliminarLocalFisico,        // Remoto tiene borrado y local limpio (synced=1) o ambos borrados; purga SQLite (foto se conserva en disco)
  crearLocalDesdeRemoto,      // Documento nuevo en la nube; se inserta en SQLite con synced=1
  descartarRemotoBorrado,     // Remoto borrado y no existe en local; no-op
  subirLocalANube,            // Local tiene cambios que deben subirse a Firestore (Pull encola con synced=0)
  marcarSynced,               // Idempotencia post-crash: contenido de negocio idéntico, solo actualizar synced=1 y actualizadoEn
  conflictoTombstoneRemoto,   // Remoto borrado pero local tiene cambios no sincronizados (synced=0, eliminadoEn==null): PROHIBIDO borrar
  conflictoEdicionConcurrente,// Ambos modificados concurrentemente y divergen: preservar local synced=0 y registrar conflicto
}

/// Registro inmutable de un conflicto por eliminación remota (tombstone) mientras
/// la fila local conserva ediciones no sincronizadas (`synced = 0`, `eliminadoEn == null`).
class ConflictoTombstoneRemoto {
  final String uuid;
  final GastoModel localSnapshot;
  final String fechaEliminacionRemota;

  const ConflictoTombstoneRemoto({
    required this.uuid,
    required this.localSnapshot,
    required this.fechaEliminacionRemota,
  });
}

/// Registro inmutable de un conflicto de edición concurrente cuando ambos extremos
/// fueron modificados y divergen en contenido de negocio.
class ConflictoEdicionConcurrente {
  final String uuid;
  final GastoModel local;
  final GastoModel remoto;

  const ConflictoEdicionConcurrente({
    required this.uuid,
    required this.local,
    required this.remoto,
  });
}

/// Función pura que resuelve conflictos entre el registro local de SQLite y el remoto de Firestore.
/// Aplica estrictamente las reglas normativas de RM-03 v1.2 §4:
/// 1. Si el remoto está borrado (eliminadoEn != null):
///    - Si local no existe: descartarRemotoBorrado (Caso A).
///    - Si local.synced == 1 o local.eliminadoEn != null: eliminarLocalFisico (Casos B y C).
///    - Si local.synced == 0 y local.eliminadoEn == null: conflictoTombstoneRemoto (Caso D, PROHIBIDO borrar).
/// 2. Si el local está borrado (eliminadoEn != null) y remoto activo: subirLocalANube (Delete Wins local).
/// 3. Si local tiene cambios pendientes (synced == 0):
///    - Si sonContenidoNegocioIdentico(local, remoto): marcarSynced (idempotencia post-crash).
///    - Si tRemoto > tLocal: conflictoEdicionConcurrente (preserva local synced=0).
///    - Si tLocal >= tRemoto: subirLocalANube.
/// 4. Si local limpio (synced == 1):
///    - Si tRemoto > tLocal: actualizarLocalDesdeRemoto.
///    - Si tLocal > tRemoto: subirLocalANube.
///    - En empate: mantenerLocal.
AccionReconciliacion resolverConflicto(GastoModel? local, GastoModel? remoto) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);

  // 1. Si no existe en la nube
  if (remoto == null) {
    if (local != null && local.synced == 0) {
      return AccionReconciliacion.subirLocalANube;
    }
    return AccionReconciliacion.mantenerLocal;
  }

  // 2. Si la nube lo tiene borrado (Tombstone remoto, Contrato v1.2 §4.2)
  if (remoto.eliminadoEn != null) {
    if (local == null) {
      // Caso A
      return AccionReconciliacion.descartarRemotoBorrado;
    }
    if (local.synced == 1) {
      // Caso B: Local limpio sin cambios pendientes -> purgar SQLite
      return AccionReconciliacion.eliminarLocalFisico;
    }
    if (local.eliminadoEn != null) {
      // Caso C: Ambos lados borraron el gasto
      return AccionReconciliacion.eliminarLocalFisico;
    }
    // Caso D: local.synced == 0 && local.eliminadoEn == null:
    // PROHIBIDO ejecutar eliminarLocalFisico. Registrar conflicto de tombstone remoto.
    return AccionReconciliacion.conflictoTombstoneRemoto;
  }

  // 3. Remoto activo, pero no existe localmente
  if (local == null) {
    return AccionReconciliacion.crearLocalDesdeRemoto;
  }

  // 4. Si el local fue borrado: el borrado local gana y debe propagarse a Firestore
  if (local.eliminadoEn != null) {
    return AccionReconciliacion.subirLocalANube;
  }

  // 5. Ambos están activos:
  // Si el local tiene cambios pendientes (synced == 0)
  if (local.synced == 0) {
    if (sonContenidoNegocioIdentico(local, remoto)) {
      // Idempotencia post-crash: el push anterior ya había llegado a Firestore
      // y el contenido de negocio es idéntico. Reconciliar marcando synced = 1.
      return AccionReconciliacion.marcarSynced;
    }

    final tRemoto = DateTime.tryParse(remoto.actualizadoEn ?? remoto.creadoEn) ?? epoch;
    final tLocal = DateTime.tryParse(local.actualizadoEn ?? local.creadoEn) ?? epoch;

    if (tRemoto.isAfter(tLocal)) {
      // Divergencia real: conservar fila local (synced = 0) y registrar conflicto concurrente
      return AccionReconciliacion.conflictoEdicionConcurrente;
    }
    // tLocal >= tRemoto: mantener local con synced = 0 para subida posterior
    return AccionReconciliacion.subirLocalANube;
  }

  // 6. Fila local limpia (synced == 1): aplicar actualización remota si es más reciente
  final tRemoto = DateTime.tryParse(remoto.actualizadoEn ?? remoto.creadoEn) ?? epoch;
  final tLocal = DateTime.tryParse(local.actualizadoEn ?? local.creadoEn) ?? epoch;

  if (tRemoto.isAfter(tLocal)) {
    return AccionReconciliacion.actualizarLocalDesdeRemoto;
  } else if (tLocal.isAfter(tRemoto)) {
    return AccionReconciliacion.subirLocalANube;
  }

  // Empate exacto de marcas de tiempo en fila local limpia
  return AccionReconciliacion.mantenerLocal;
}
