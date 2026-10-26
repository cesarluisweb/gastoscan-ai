import '../data/models/gasto_model.dart';

enum AccionReconciliacion {
  mantenerLocal,              // Local es más reciente o idéntico; no se altera SQLite
  actualizarLocalDesdeRemoto, // Remoto es más reciente; actualiza SQLite preservando foto local
  eliminarLocalFisico,        // Remoto tiene borrado; purga SQLite (foto se conserva en disco)
  crearLocalDesdeRemoto,      // Documento nuevo en la nube; se inserta en SQLite con synced=1
  descartarRemotoBorrado,     // Remoto borrado y no existe en local; no-op
  subirLocalANube,            // Local tiene cambios que deben subirse a Firestore (Pull encola con synced=0)
}

/// Función pura que resuelve conflictos entre el registro local de SQLite y el remoto de Firestore.
/// Aplica estrictamente la política "Borrado Gana" (Delete Wins):
/// 1. Si el remoto está borrado (eliminadoEn != null), gana siempre: purga local.
/// 2. Si el local está borrado (eliminadoEn != null), gana siempre: programa propagación softDelete.
/// 3. Si ambos están activos, se comparan timestamps (LWW solo para ediciones activas).
AccionReconciliacion resolverConflicto(GastoModel? local, GastoModel? remoto) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);

  // 1. Si no existe en la nube
  if (remoto == null) {
    if (local != null && local.synced == 0) {
      return AccionReconciliacion.subirLocalANube;
    }
    return AccionReconciliacion.mantenerLocal;
  }

  // 2. Si la nube lo tiene borrado: el borrado remoto gana SIEMPRE
  if (remoto.eliminadoEn != null) {
    if (local != null) {
      return AccionReconciliacion.eliminarLocalFisico;
    }
    return AccionReconciliacion.descartarRemotoBorrado;
  }

  // 3. Remoto activo, pero no existe localmente
  if (local == null) {
    return AccionReconciliacion.crearLocalDesdeRemoto;
  }

  // 4. Si el local fue borrado: el borrado local gana SIEMPRE
  if (local.eliminadoEn != null) {
    return AccionReconciliacion.subirLocalANube;
  }

  // 5. Ambos están activos: gana el timestamp más reciente (LWW para ediciones)
  final tRemoto = DateTime.tryParse(remoto.actualizadoEn ?? remoto.creadoEn) ?? epoch;
  final tLocal = DateTime.tryParse(local.actualizadoEn ?? local.creadoEn) ?? epoch;

  if (tRemoto.isAfter(tLocal)) {
    return AccionReconciliacion.actualizarLocalDesdeRemoto;
  } else if (tLocal.isAfter(tRemoto)) {
    return AccionReconciliacion.subirLocalANube;
  }

  // Empate exacto de marcas de tiempo
  if (local.synced == 0) {
    return AccionReconciliacion.subirLocalANube;
  }
  return AccionReconciliacion.mantenerLocal;
}
