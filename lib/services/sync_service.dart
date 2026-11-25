import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../data/datasources/remote/firestore_gastos_remote_data_source.dart';
import '../data/datasources/remote/gastos_remote_data_source.dart';
import '../data/models/gasto_firestore_mapper.dart';
import '../data/models/presupuesto_remoto_model.dart';
import '../data/repositories/gasto_repository.dart';
import 'connectivity_service.dart';
import 'image_service.dart';
import 'profile_avatar_service.dart';
import 'receipt_photo_registry.dart';
import 'sync_conflict_resolver.dart';

/// Reporte estructurado del resultado de un ciclo de sincronización bidireccional.
class SyncRunReport {
  final int gastosPulled;
  final int gastosPushed;
  final int presupuestosPulled;
  final int presupuestosPushed;
  final int gastosPullErrors;
  final int gastosPushErrors;
  final int presupuestosPullErrors;
  final int presupuestosPushErrors;
  final bool gastosPullAborted;
  final bool presupuestosPullAborted;
  final String? primaryErrorCode;

  const SyncRunReport({
    this.gastosPulled = 0,
    this.gastosPushed = 0,
    this.presupuestosPulled = 0,
    this.presupuestosPushed = 0,
    this.gastosPullErrors = 0,
    this.gastosPushErrors = 0,
    this.presupuestosPullErrors = 0,
    this.presupuestosPushErrors = 0,
    this.gastosPullAborted = false,
    this.presupuestosPullAborted = false,
    this.primaryErrorCode,
  });

  int get totalProcessed =>
      gastosPulled + gastosPushed + presupuestosPulled + presupuestosPushed;

  int get totalErrors =>
      gastosPullErrors +
      gastosPushErrors +
      presupuestosPullErrors +
      presupuestosPushErrors +
      (gastosPullAborted ? 1 : 0) +
      (presupuestosPullAborted ? 1 : 0);

  bool get hasErrors => totalErrors > 0;
  bool get isPermissionDenied => primaryErrorCode == 'permission-denied';
  bool get isPartialError =>
      hasErrors && !gastosPullAborted && !presupuestosPullAborted && !isPermissionDenied;
}

class _SyncPhaseResult {
  final int processed;
  final int errors;
  final String? errorCode;

  const _SyncPhaseResult({
    this.processed = 0,
    this.errors = 0,
    this.errorCode,
  });
}

class SyncService {
  final GastoRepository _repository;
  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;
  final GoogleSignIn? _customGoogleSignIn;
  final FlutterSecureStorage? _customSecureStorage;
  final Future<void> Function(String uid)? _customFirestorePurger;
  final GastosRemoteDataSource? _customRemoteDataSource;

  SyncService({
    GastoRepository? repository,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    FlutterSecureStorage? secureStorage,
    Future<void> Function(String uid)? firestorePurger,
    GastosRemoteDataSource? remoteDataSource,
  })  : _repository = repository ?? GastoRepository(),
        _customAuth = auth,
        _customFirestore = firestore,
        _customGoogleSignIn = googleSignIn,
        _customSecureStorage = secureStorage,
        _customFirestorePurger = firestorePurger,
        _customRemoteDataSource = remoteDataSource;

  User? get currentUser => _auth?.currentUser;

  final Map<String, ConflictoTombstoneRemoto> _tombstoneConflicts = {};
  final Map<String, ConflictoEdicionConcurrente> _concurrentConflicts = {};

  Map<String, ConflictoTombstoneRemoto> get tombstoneConflicts =>
      Map.unmodifiable(_tombstoneConflicts);
  Map<String, ConflictoEdicionConcurrente> get concurrentConflicts =>
      Map.unmodifiable(_concurrentConflicts);

  bool hasConflict(String uuid) =>
      _tombstoneConflicts.containsKey(uuid) || _concurrentConflicts.containsKey(uuid);

  void registrarConflictoTombstone(ConflictoTombstoneRemoto conflicto) {
    _tombstoneConflicts[conflicto.uuid] = conflicto;
  }

  void registrarConflictoConcurrente(ConflictoEdicionConcurrente conflicto) {
    _concurrentConflicts[conflicto.uuid] = conflicto;
  }

  void resolverConflictoTombstone(String uuid) {
    _tombstoneConflicts.remove(uuid);
  }

  void resolverConflictoConcurrente(String uuid) {
    _concurrentConflicts.remove(uuid);
  }

  void limpiarConflictos() {
    _tombstoneConflicts.clear();
    _concurrentConflicts.clear();
  }

  GastosRemoteDataSource? get _remoteDataSource {
    if (_customRemoteDataSource != null) return _customRemoteDataSource;
    final fs = _firestore;
    if (fs != null) return FirestoreGastosRemoteDataSource(fs);
    return null;
  }

  Future<bool> _isPendingReplace(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sync_pending_replace_$uid') == true;
  }

  /// Verifica públicamente si existe una bandera de reemplazo pendiente activa.
  Future<bool> isPendingReplaceActive([String? uid]) async {
    final targetUid = uid ?? _auth?.currentUser?.uid;
    if (targetUid == null) return false;
    return _isPendingReplace(targetUid);
  }

  Future<void> _setPendingReplaceFlag(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_pending_replace_$uid', true);
  }

  Future<void> _clearPendingReplaceFlag(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sync_pending_replace_$uid');
  }

  bool _isRetryingReplace = false;

  /// Reintenta la descarga remota y el reemplazo atómico tras una interrupción previa.
  /// Cuenta con cerrojo para evitar ejecuciones concurrentes y limpia la bandera solo ante éxito.
  Future<String?> retryPendingReplace() async {
    if (_isRetryingReplace) return 'Ya hay un reintento en curso.';
    _isRetryingReplace = true;

    try {
      final user = _auth?.currentUser;
      if (user == null || user.isAnonymous) return 'No hay una sesión activa para sincronizar.';

      final rds = _remoteDataSource;
      if (rds == null) return 'Servicio de sincronización no disponible.';

      final flagActive = await _isPendingReplace(user.uid);
      if (!flagActive) return null;

      final remoteGastos = await rds.fetchAllGastos(user.uid);
      final remotePresupuestos = await rds.fetchAllPresupuestos(user.uid);

      final gastos = remoteGastos
          .map((r) => GastoFirestoreMapper.fromPayload(r.data, r.id))
          .where((g) => g.eliminadoEn == null)
          .toList();

      final presupuestos = remotePresupuestos
          .map((r) => PresupuestoRemotoModel.fromFirestore(r.data, r.id))
          .toList();

      await _repository.reemplazarDatosLocales(
        gastos: gastos,
        presupuestos: presupuestos,
      );

      await _clearPendingReplaceFlag(user.uid);
      return null;
    } catch (_) {
      debugPrint("SyncService: Error al reintentar reemplazo pendiente");
      return 'No se pudo completar la sincronización. Verifica tu conexión e intenta de nuevo.';
    } finally {
      _isRetryingReplace = false;
    }
  }

  FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    if (Firebase.apps.isNotEmpty) return FirebaseAuth.instance;
    return null;
  }

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    if (Firebase.apps.isNotEmpty) return FirebaseFirestore.instance;
    return null;
  }

  GoogleSignIn get _googleSignInInstance =>
      _customGoogleSignIn ?? GoogleSignIn(serverClientId: AppConstants.googleWebClientId);

  FlutterSecureStorage get _secureStorageInstance =>
      _customSecureStorage ?? const FlutterSecureStorage();

  String _extractErrorCode(Object e) {
    if (e is FirebaseException) {
      return e.code;
    }
    final lower = e.toString().toLowerCase();
    if (lower.contains('permission-denied') || lower.contains('permission_denied')) {
      return 'permission-denied';
    }
    if (lower.contains('unauthenticated')) {
      return 'unauthenticated';
    }
    if (lower.contains('unavailable') || lower.contains('network')) {
      return 'unavailable';
    }
    return 'unknown';
  }

  String? _mergeErrorCode(String? current, String? next) {
    if (next == null) return current;
    if (current == null) return next;
    const priority = ['permission-denied', 'unauthenticated', 'unavailable'];
    final pCurrent = priority.indexOf(current);
    final pNext = priority.indexOf(next);
    if (pNext != -1 && (pCurrent == -1 || pNext < pCurrent)) {
      return next;
    }
    return current;
  }

  Future<SyncRunReport> syncBidirectional({bool dryRun = false}) async {
    int gastosPulled = 0;
    int gastosPushed = 0;
    int presupuestosPulled = 0;
    int presupuestosPushed = 0;
    int gastosPullErrors = 0;
    int gastosPushErrors = 0;
    int presupuestosPullErrors = 0;
    int presupuestosPushErrors = 0;
    bool gastosPullAborted = false;
    bool presupuestosPullAborted = false;
    String? primaryErrorCode;

    try {
      final user = _auth?.currentUser;
      if (user == null || user.isAnonymous) return const SyncRunReport();

      if (await _isPendingReplace(user.uid)) {
        debugPrint("SyncService: Sincronización bloqueada por reemplazo pendiente");
        return const SyncRunReport();
      }

      // Fase 1: Gastos (si falla el pull completo, se omite el push por seguridad anónimo->cuenta)
      bool gastosPullCompleted = false;
      try {
        final pullRes = await _syncFromFirestoreWithReport(user);
        gastosPulled = pullRes.processed;
        gastosPullErrors = pullRes.errors;
        primaryErrorCode = _mergeErrorCode(primaryErrorCode, pullRes.errorCode);
        gastosPullCompleted = true;
      } catch (e) {
        gastosPullAborted = true;
        primaryErrorCode = _mergeErrorCode(primaryErrorCode, _extractErrorCode(e));
        debugPrint("SyncService: Error en pull completo de gastos: $e");
      }

      if (gastosPullCompleted) {
        try {
          final pushRes = await _syncToFirestoreWithReport(user, dryRun: dryRun);
          gastosPushed = pushRes.processed;
          gastosPushErrors = pushRes.errors;
          primaryErrorCode = _mergeErrorCode(primaryErrorCode, pushRes.errorCode);
        } catch (e) {
          gastosPushErrors++;
          primaryErrorCode = _mergeErrorCode(primaryErrorCode, _extractErrorCode(e));
          debugPrint("SyncService: Error en push de gastos a Firestore: $e");
        }
      }

      // Fase 2: Presupuestos (mismo aislamiento: pull completo fallido omite push)
      bool presupuestosPullCompleted = false;
      try {
        final pullPresRes = await _syncPresupuestosFromFirestoreWithReport(user);
        presupuestosPulled = pullPresRes.processed;
        presupuestosPullErrors = pullPresRes.errors;
        primaryErrorCode = _mergeErrorCode(primaryErrorCode, pullPresRes.errorCode);
        presupuestosPullCompleted = true;
      } catch (e) {
        presupuestosPullAborted = true;
        primaryErrorCode = _mergeErrorCode(primaryErrorCode, _extractErrorCode(e));
        debugPrint("SyncService: Error en pull completo de presupuestos: $e");
      }

      if (presupuestosPullCompleted && !dryRun) {
        try {
          final pushPresRes = await _syncPresupuestosToFirestoreWithReport(user);
          presupuestosPushed = pushPresRes.processed;
          presupuestosPushErrors = pushPresRes.errors;
          primaryErrorCode = _mergeErrorCode(primaryErrorCode, pushPresRes.errorCode);
        } catch (e) {
          presupuestosPushErrors++;
          primaryErrorCode = _mergeErrorCode(primaryErrorCode, _extractErrorCode(e));
          debugPrint("SyncService: Error en push de presupuestos a Firestore: $e");
        }
      }
    } catch (e) {
      gastosPullAborted = true;
      primaryErrorCode = _mergeErrorCode(primaryErrorCode, _extractErrorCode(e));
      debugPrint("SyncService: Error en sincronización bidireccional: $e");
    }

    return SyncRunReport(
      gastosPulled: gastosPulled,
      gastosPushed: gastosPushed,
      presupuestosPulled: presupuestosPulled,
      presupuestosPushed: presupuestosPushed,
      gastosPullErrors: gastosPullErrors,
      gastosPushErrors: gastosPushErrors,
      presupuestosPullErrors: presupuestosPullErrors,
      presupuestosPushErrors: presupuestosPushErrors,
      gastosPullAborted: gastosPullAborted,
      presupuestosPullAborted: presupuestosPullAborted,
      primaryErrorCode: primaryErrorCode,
    );
  }

  Future<void> syncToFirestore(User user, {bool dryRun = false}) async {
    await _syncToFirestoreWithReport(user, dryRun: dryRun);
  }

  Future<_SyncPhaseResult> _syncToFirestoreWithReport(User user, {bool dryRun = false}) async {
    final rds = _remoteDataSource;
    if (rds == null) return const _SyncPhaseResult();

    if (dryRun) {
      debugPrint("SyncService: Push de gastos a Firestore omitido (dryRun = true)");
      return const _SyncPhaseResult();
    }

    if (await _isPendingReplace(user.uid)) {
      debugPrint("SyncService: Push de gastos bloqueado por reemplazo pendiente");
      return const _SyncPhaseResult();
    }

    final unsyncedGastos = await _repository.obtenerGastosNoSincronizados();
    int processed = 0;
    int errors = 0;
    String? errorCode;

    for (var gasto in unsyncedGastos) {
      if (hasConflict(gasto.uuid)) {
        debugPrint("SyncService: Push omitido para ${gasto.uuid} por conflicto pendiente");
        continue;
      }

      if (gasto.eliminadoEn != null) {
        if (gasto.firestoreId == null) {
          // Gasto fantasma nunca subido a la nube: purga puramente local
          if (gasto.id != null) {
            await _repository.eliminarGastoFisico(gasto.id!);
          }
          processed++;
        } else {
          try {
            await rds.softDeleteGasto(user.uid, gasto.uuid, gasto.eliminadoEn!);
            if (gasto.id != null) {
              await _repository.eliminarGastoFisico(gasto.id!);
            }
            processed++;
          } catch (e) {
            errors++;
            errorCode = _mergeErrorCode(errorCode, _extractErrorCode(e));
            debugPrint("SyncService: Error propagando soft delete de ${gasto.uuid} a Firestore: $e");
          }
        }
      } else {
        try {
          await rds.upsertGasto(user.uid, gasto);
          if (gasto.id != null) {
            final expectedActualizadoEn = gasto.actualizadoEn ?? gasto.creadoEn;
            final updated = await _repository.marcarGastoSincronizadoCondicional(
              gasto.id!,
              expectedActualizadoEn,
              firestoreId: gasto.uuid,
            );
            if (updated == 0) {
              debugPrint("SyncService: Gasto ${gasto.uuid} fue modificado localmente en vuelo; se mantiene synced = 0");
            }
          } else {
            final syncedGasto = gasto.copyWith(firestoreId: gasto.uuid, synced: 1);
            await _repository.actualizarGastoSyncStatus(syncedGasto);
          }
          processed++;
        } catch (e) {
          errors++;
          errorCode = _mergeErrorCode(errorCode, _extractErrorCode(e));
          debugPrint("SyncService: Error subiendo gasto activo ${gasto.uuid} a Firestore: $e");
        }
      }
    }

    return _SyncPhaseResult(processed: processed, errors: errors, errorCode: errorCode);
  }

  Future<void> syncFromFirestore(User user) async {
    await _syncFromFirestoreWithReport(user);
  }

  Future<_SyncPhaseResult> _syncFromFirestoreWithReport(User user) async {
    final rds = _remoteDataSource;
    if (rds == null) return const _SyncPhaseResult();

    // Si falla la descarga completa (red/auth), debe propagarse para bloquear el push
    final remoteDocs = await rds.fetchAllGastos(user.uid);
    if (remoteDocs.isEmpty) return const _SyncPhaseResult();

    final localGastos = await _repository.obtenerTodosLosGastosConBorrados();
    final localMap = {for (var g in localGastos) g.uuid: g};
    int processed = 0;
    int errors = 0;
    String? errorCode;

    for (var remoteDoc in remoteDocs) {
      try {
        final gastoRemoto = GastoFirestoreMapper.fromPayload(remoteDoc.data, remoteDoc.id);
        final localGasto = localMap[gastoRemoto.uuid];

        // Auto-reparación de firestoreId local si el remoto existe
        if (localGasto != null && localGasto.firestoreId == null && localGasto.id != null) {
          await _repository.repararFirestoreId(localGasto.id!, gastoRemoto.firestoreId!);
        }

        final accion = resolverConflicto(localGasto, gastoRemoto);

        switch (accion) {
          case AccionReconciliacion.eliminarLocalFisico:
            if (localGasto?.id != null) {
              await _repository.eliminarGastoFisico(localGasto!.id!);
            }
            resolverConflictoTombstone(gastoRemoto.uuid);
            resolverConflictoConcurrente(gastoRemoto.uuid);
            processed++;
            break;

          case AccionReconciliacion.actualizarLocalDesdeRemoto:
            if (localGasto?.id != null) {
              await _repository.actualizarGasto(
                gastoRemoto.copyWith(
                  id: localGasto!.id,
                  rutaFotoLocal: localGasto.rutaFotoLocal,
                  synced: 1,
                ),
                gastoRemoto.items,
              );
            }
            resolverConflictoConcurrente(gastoRemoto.uuid);
            processed++;
            break;

          case AccionReconciliacion.crearLocalDesdeRemoto:
            await _repository.guardarGasto(
              gastoRemoto.copyWith(synced: 1),
              gastoRemoto.items,
            );
            processed++;
            break;

          case AccionReconciliacion.subirLocalANube:
            if (localGasto != null) {
              // Una nueva edición local cuyo timestamp supera al remoto desbloquea un conflicto concurrente previo
              resolverConflictoConcurrente(localGasto.uuid);
              if (localGasto.synced != 0 && localGasto.id != null) {
                await _repository.marcarComoPendiente(localGasto.id!);
              }
            }
            break;

          case AccionReconciliacion.marcarSynced:
            if (localGasto?.id != null) {
              await _repository.actualizarGastoSyncStatus(
                localGasto!.copyWith(
                  actualizadoEn: gastoRemoto.actualizadoEn,
                  synced: 1,
                ),
              );
              resolverConflictoConcurrente(localGasto.uuid);
            }
            processed++;
            break;

          case AccionReconciliacion.conflictoTombstoneRemoto:
            if (localGasto != null && gastoRemoto.eliminadoEn != null) {
              registrarConflictoTombstone(
                ConflictoTombstoneRemoto(
                  uuid: localGasto.uuid,
                  localSnapshot: localGasto,
                  fechaEliminacionRemota: gastoRemoto.eliminadoEn!,
                ),
              );
            }
            break;

          case AccionReconciliacion.conflictoEdicionConcurrente:
            if (localGasto != null) {
              registrarConflictoConcurrente(
                ConflictoEdicionConcurrente(
                  uuid: localGasto.uuid,
                  local: localGasto,
                  remoto: gastoRemoto,
                ),
              );
            }
            break;

          case AccionReconciliacion.descartarRemotoBorrado:
          case AccionReconciliacion.mantenerLocal:
            break;
        }
      } catch (e) {
        errors++;
        errorCode = _mergeErrorCode(errorCode, _extractErrorCode(e));
        debugPrint("SyncService: Error procesando gasto remoto ${remoteDoc.id}: $e");
      }
    }

    try {
      await ReceiptPhotoRegistry.reconcileMissingPhotos(repository: _repository);
    } catch (e) {
      debugPrint("SyncService: Error reconciliando fotos de comprobantes: $e");
    }

    return _SyncPhaseResult(processed: processed, errors: errors, errorCode: errorCode);
  }

  Future<void> syncPresupuestosToFirestore(User user) async {
    await _syncPresupuestosToFirestoreWithReport(user);
  }

  Future<_SyncPhaseResult> _syncPresupuestosToFirestoreWithReport(User user) async {
    final rds = _remoteDataSource;
    if (rds == null) return const _SyncPhaseResult();

    if (await _isPendingReplace(user.uid)) {
      debugPrint("SyncService: Push de presupuestos bloqueado por reemplazo pendiente");
      return const _SyncPhaseResult();
    }

    final presupuestos = await _repository.obtenerTodosLosPresupuestosMensuales();
    int processed = 0;
    int errors = 0;
    String? errorCode;

    for (var pres in presupuestos) {
      final anio = pres['anio'] as int;
      final mes = pres['mes'] as int;
      final general = (pres['presupuesto_general'] as num?)?.toDouble() ?? 0.0;
      final metaAhorro = (pres['meta_ahorro'] as num?)?.toDouble() ?? 0.0;
      final moneda = AppConstants.normalizarMoneda(pres['moneda'] as String?);
      final Map<String, double> categorias = {};
      if (pres['categorias'] is Map) {
        (pres['categorias'] as Map).forEach((k, v) {
          final monto = (v as num?)?.toDouble() ?? 0.0;
          if (monto > 0) {
            final canon = AppConstants.normalizarCategoria(k.toString());
            categorias[canon] = (categorias[canon] ?? 0.0) + monto;
          }
        });
      }
      final rawActualizado = pres['actualizado_en'] as String?;
      final actualizadoEn = rawActualizado ??
          pres['creado_en'] as String? ??
          DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();

      // Omitir filas vacías sin marca explícita de actualización
      if (general <= 0 && metaAhorro <= 0 && categorias.isEmpty && rawActualizado == null) {
        continue;
      }

      final docId = '${anio}_${mes.toString().padLeft(2, '0')}';
      try {
        await rds.upsertPresupuesto(user.uid, docId, {
          'anio': anio,
          'mes': mes,
          'presupuesto_general': general,
          'meta_ahorro': metaAhorro,
          'moneda': moneda,
          'categorias': categorias,
          'actualizado_en': actualizadoEn,
        });
        processed++;
      } catch (e) {
        errors++;
        errorCode = _mergeErrorCode(errorCode, _extractErrorCode(e));
        debugPrint("SyncService: Error subiendo presupuesto $docId a Firestore: $e");
      }
    }

    return _SyncPhaseResult(processed: processed, errors: errors, errorCode: errorCode);
  }

  Future<void> syncPresupuestosFromFirestore(User user) async {
    await _syncPresupuestosFromFirestoreWithReport(user);
  }

  Future<_SyncPhaseResult> _syncPresupuestosFromFirestoreWithReport(User user) async {
    final rds = _remoteDataSource;
    if (rds == null) return const _SyncPhaseResult();

    // Si falla la descarga completa (red/auth), debe propagarse para bloquear el push
    final remoteDocs = await rds.fetchAllPresupuestos(user.uid);
    if (remoteDocs.isEmpty) return const _SyncPhaseResult();

    final localPresupuestos = await _repository.obtenerTodosLosPresupuestosMensuales();
    final Map<String, Map<String, dynamic>> localMap = {};
    for (var p in localPresupuestos) {
      final anio = p['anio'] as int;
      final mes = p['mes'] as int;
      localMap['${anio}_${mes.toString().padLeft(2, '0')}'] = p;
    }

    int processed = 0;
    int errors = 0;
    String? errorCode;

    for (var doc in remoteDocs) {
      try {
        final presRemoto = PresupuestoRemotoModel.fromFirestore(doc.data, doc.id);
        if (presRemoto.anio == 0 || presRemoto.mes == 0) continue;

        final docId = '${presRemoto.anio}_${presRemoto.mes.toString().padLeft(2, '0')}';
        final localP = localMap[docId];

        if (localP == null) {
          await _repository.guardarPresupuestoMensualCompleto(
            anio: presRemoto.anio,
            mes: presRemoto.mes,
            general: presRemoto.general,
            moneda: presRemoto.moneda,
            categorias: presRemoto.categorias,
            metaAhorro: presRemoto.metaAhorro,
            actualizadoEn: presRemoto.actualizadoEn,
          );
          processed++;
        } else {
          final localActualizadoEn = localP['actualizado_en'] as String?;
          final localTime = DateTime.tryParse(localActualizadoEn ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final remoteTime = DateTime.tryParse(presRemoto.actualizadoEn) ?? DateTime.fromMillisecondsSinceEpoch(0);

          if (remoteTime.isAfter(localTime)) {
            await _repository.guardarPresupuestoMensualCompleto(
              anio: presRemoto.anio,
              mes: presRemoto.mes,
              general: presRemoto.general,
              moneda: presRemoto.moneda,
              categorias: presRemoto.categorias,
              metaAhorro: presRemoto.metaAhorro,
              actualizadoEn: presRemoto.actualizadoEn,
            );
            processed++;
          }
        }
      } catch (e) {
        errors++;
        errorCode = _mergeErrorCode(errorCode, _extractErrorCode(e));
        debugPrint("SyncService: Error procesando presupuesto remoto ${doc.id}: $e");
      }
    }

    return _SyncPhaseResult(processed: processed, errors: errors, errorCode: errorCode);
  }

  Future<User?> intentarLoginSilencioso() async {
    try {
      final auth = _auth;
      if (auth == null) return null;
      final currentUser = auth.currentUser;

      if (currentUser != null && !currentUser.isAnonymous) {
        return currentUser;
      }

      final googleSignIn = _googleSignInInstance;
      final GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await auth.signInWithCredential(credential);
      final activeUser = userCred.user ?? auth.currentUser;
      if (activeUser != null) {
        try {
          await activeUser.updateProfile(
            displayName: googleUser.displayName,
            photoURL: googleUser.photoUrl,
          );
          await activeUser.reload();
        } catch (_) {}
      }
      return activeUser;
    } catch (e) {
      debugPrint("Fallo al autenticar silenciosamente con Google: $e");
      return null;
    }
  }

  /// Cierra sesión en Firebase y Google, vacía la base de datos local (SQLite)
  /// e inicia una sesión anónima fresca para un aislamiento total.
  Future<void> cerrarSesion() async {
    try {
      final user = _auth?.currentUser;
      if (user != null) {
        await _clearPendingReplaceFlag(user.uid);
      }

      try {
        await _googleSignInInstance.signOut();
      } catch (_) {
        debugPrint("SyncService: Error al cerrar sesión de Google Sign-In");
      }

      if (_auth != null) {
        await _auth!.signOut();
      }

      try {
        await _secureStorageInstance.delete(key: AppConstants.prefApiKey);
      } catch (_) {
        debugPrint("SyncService: Error al limpiar claves de SecureStorage en cerrarSesion");
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(AppConstants.prefApiKey);
      } catch (e) {
        debugPrint("SyncService: Error al remover prefApiKey de SharedPreferences: $e");
      }

      try {
        await ProfileAvatarService.instance.clearAvatarCache(uid: user?.uid);
      } catch (e) {
        debugPrint("SyncService: Error al limpiar avatar cacheado en cerrarSesion: $e");
      }

      try {
        final gastosActuales = await _repository.obtenerGastos();
        final mapaFotos = <String, String>{};
        for (final g in gastosActuales) {
          if (g.rutaFotoLocal != null && g.rutaFotoLocal!.isNotEmpty) {
            mapaFotos[g.uuid] = g.rutaFotoLocal!;
          }
        }
        if (mapaFotos.isNotEmpty) {
          await ReceiptPhotoRegistry.registerBatch(mapaFotos);
        }
      } catch (e) {
        debugPrint("SyncService: Error respaldando mapa de comprobantes en cerrarSesion: $e");
      }

      await _repository.limpiarDatosLocales();
      if (_auth != null) {
        await _auth!.signInAnonymously();
      }
    } catch (_) {
      debugPrint("SyncService: Error al cerrar sesión y limpiar datos locales");
      rethrow;
    }
  }

  /// Elimina permanentemente la cuenta en Firebase Auth, borra todos los gastos y presupuestos
  /// asociados en Firestore, limpia la base de datos local (SQLite), opcionalmente elimina las fotos de recibos
  /// si [eliminarFotos] es true, limpia las claves de SecureStorage y recrea una sesión anónima fresca.
  Future<String?> eliminarCuentaYDatos({String? reauthPassword, bool eliminarFotos = false}) async {
    try {
      final isOnline = await ConnectivityService.instance.isConnected();
      if (!isOnline) {
        return 'Sin conexión a internet. Se requiere conexión para eliminar tu cuenta y datos en la nube.';
      }

      final user = _auth?.currentUser;

      if (user != null) {
        final uid = user.uid;

        // 1. Purgar datos remotos en Firestore (gastos y presupuestos)
        try {
          if (_customFirestorePurger != null) {
            await _customFirestorePurger!(uid);
          } else if (_firestore != null) {
            final gastosSnap = await _firestore!
                .collection('users')
                .doc(uid)
                .collection('gastos')
                .get();
            for (final doc in gastosSnap.docs) {
              await doc.reference.delete();
            }

            final presupuestosSnap = await _firestore!
                .collection('users')
                .doc(uid)
                .collection('presupuestos')
                .get();
            for (final doc in presupuestosSnap.docs) {
              await doc.reference.delete();
            }

            final reportesSnap = await _firestore!
                .collection('ai_reports')
                .where('uid', isEqualTo: uid)
                .get();
            for (final doc in reportesSnap.docs) {
              await doc.reference.delete();
            }
          }
        } on FirebaseException catch (e) {
          debugPrint("SyncService: Error al purgar Firestore durante eliminación de cuenta");
          if (e.code == 'unavailable' || e.code == 'network-request-failed') {
            return 'Sin conexión a internet. Verifica tu red para eliminar los datos en la nube.';
          }
          return 'Error al eliminar datos en la nube: ${e.message ?? e.code}';
        } catch (_) {
          debugPrint("SyncService: Error inesperado al purgar Firestore");
          return 'Error al eliminar datos en la nube';
        }

        // 2. Eliminar la cuenta en Firebase Auth (aplica para cuentas vinculadas y anónimas)
        try {
          await user.delete();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
            final isPassword = user.providerData.any((p) => p.providerId == 'password');
            if (isGoogle) {
              try {
                final GoogleSignInAccount? googleUser = await _googleSignInInstance.signIn();
                if (googleUser == null) {
                  return 'Reautenticación cancelada. Se requiere iniciar sesión reciente para eliminar la cuenta.';
                }
                final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
                final credential = GoogleAuthProvider.credential(
                  accessToken: googleAuth.accessToken,
                  idToken: googleAuth.idToken,
                );
                await user.reauthenticateWithCredential(credential);
                await user.delete();
              } catch (reauthErr) {
                debugPrint("SyncService: No se pudo reautenticar con Google para eliminar cuenta");
                if (reauthErr is FirebaseAuthException) {
                  return _mapearErrorFirebaseAuth(reauthErr);
                }
                return 'No se pudo reautenticar para eliminar la cuenta';
              }
            } else if (isPassword) {
              if (reauthPassword != null && reauthPassword.isNotEmpty && user.email != null) {
                try {
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: reauthPassword,
                  );
                  await user.reauthenticateWithCredential(credential);
                  await user.delete();
                } catch (reauthErr) {
                  debugPrint("SyncService: No se pudo reautenticar con email/password");
                  if (reauthErr is FirebaseAuthException) {
                    return _mapearErrorFirebaseAuth(reauthErr);
                  }
                  return 'No se pudo reautenticar para eliminar la cuenta';
                }
              } else {
                return 'REQUIRES_PASSWORD_REAUTH';
              }
            } else {
              return _mapearErrorFirebaseAuth(e);
            }
          } else if (e.code != 'user-not-found') {
            return _mapearErrorFirebaseAuth(e);
          }
        } catch (_) {
          debugPrint("SyncService: Error inesperado al eliminar usuario en FirebaseAuth");
          return 'Error al eliminar usuario en el servidor';
        }
      }

      // 3. Desvincular y cerrar Google Sign-In si aplica
      try {
        await _googleSignInInstance.signOut();
      } catch (_) {
        debugPrint("SyncService: Error al cerrar sesión de Google");
      }

      // 4. Cerrar sesión en Firebase Auth para asegurar desvinculación total
      if (_auth != null) {
        try {
          await _auth!.signOut();
        } catch (_) {
          debugPrint("SyncService: Error al desvincular FirebaseAuth");
        }
      }

      // 5. Limpiar claves de FlutterSecureStorage que pertenezcan a Rinde Más.
      try {
        await _secureStorageInstance.delete(key: AppConstants.prefApiKey);
      } catch (_) {
        debugPrint("SyncService: Error al limpiar claves de SecureStorage");
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(AppConstants.prefApiKey);
        if (user != null) {
          await prefs.remove('sync_pending_replace_${user.uid}');
        }
      } catch (_) {
        debugPrint("SyncService: Error al limpiar SharedPreferences");
      }

      // 5b. Purgar siempre el avatar cacheado de la cuenta eliminada
      try {
        await ProfileAvatarService.instance.clearAvatarCache(uid: user?.uid);
      } catch (e) {
        debugPrint("SyncService: Error al limpiar avatar cacheado en eliminarCuentaYDatos: $e");
      }

      // 6. Eliminar imágenes de recibos solo si el usuario lo autorizó explícitamente
      if (eliminarFotos) {
        try {
          final rutasApp = await _repository.obtenerRutasArchivosApp();
          await ImageService.limpiarArchivosApp(rutasConocidas: rutasApp);
          await ReceiptPhotoRegistry.clearAll();
        } catch (e) {
          debugPrint("SyncService: Error al limpiar imágenes y temporales de la app: $e");
        }
      }

      // 7. Limpiar base de datos local (SQLite)
      await _repository.limpiarDatosLocales();

      // 8. Recrear sesión anónima limpia
      if (_auth != null) {
        try {
          await _auth!.signInAnonymously();
        } catch (_) {
          debugPrint("SyncService: Error al iniciar sesión anónima tras eliminar cuenta");
        }
      }

      return null;
    } catch (_) {
      debugPrint("SyncService: Error al eliminar cuenta y datos");
      return 'No se pudo eliminar la cuenta. Verifica tu conexión.';
    }
  }

  Future<bool> _ejecutarReemplazoAtomico(String uid) async {
    final rds = _remoteDataSource;
    if (rds == null) return false;
    try {
      final remoteGastos = await rds.fetchAllGastos(uid);
      final remotePresupuestos = await rds.fetchAllPresupuestos(uid);

      final gastos = remoteGastos
          .map((r) => GastoFirestoreMapper.fromPayload(r.data, r.id))
          .where((g) => g.eliminadoEn == null)
          .toList();

      final presupuestos = remotePresupuestos
          .map((r) => PresupuestoRemotoModel.fromFirestore(r.data, r.id))
          .toList();

      await _repository.reemplazarDatosLocales(
        gastos: gastos,
        presupuestos: presupuestos,
      );

      await ReceiptPhotoRegistry.reconcileMissingPhotos(repository: _repository);

      await _clearPendingReplaceFlag(uid);
      return true;
    } catch (_) {
      debugPrint("SyncService: Fallo en reemplazo atómico de datos");
      return false;
    }
  }

  Future<String?> vincularCuentaGoogle({bool descartarDatosLocales = false}) async {
    try {
      final auth = _auth;
      if (auth == null) return 'Servicio de autenticación no disponible.';

      final googleSignIn = _googleSignInInstance;

      // Limpiar sesión previa para garantizar que siempre se muestre el selector de cuentas
      try {
        await googleSignIn.signOut();
      } catch (_) {
        debugPrint("SyncService: Error al cerrar sesión previa de Google");
      }

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
        final userCred = await auth.signInWithCredential(credential);
        final activeUser = userCred.user;
        if (activeUser != null) {
          if (descartarDatosLocales) {
            final exito = await _ejecutarReemplazoAtomico(activeUser.uid);
            if (!exito) {
              await _setPendingReplaceFlag(activeUser.uid);
            }
          } else {
            await _clearPendingReplaceFlag(activeUser.uid);
          }
          await activeUser.updateProfile(
            displayName: googleUser.displayName,
            photoURL: googleUser.photoUrl,
          );
          await activeUser.reload();
        }
        await syncBidirectional();
        return null;
      }

      if (user.isAnonymous) {
        try {
          final userCred = await user.linkWithCredential(credential);
          final activeUser = userCred.user ?? auth.currentUser ?? user;
          if (descartarDatosLocales) {
            final exito = await _ejecutarReemplazoAtomico(activeUser.uid);
            if (!exito) {
              await _setPendingReplaceFlag(activeUser.uid);
            }
          } else {
            await _clearPendingReplaceFlag(activeUser.uid);
          }
          await activeUser.updateProfile(displayName: googleUser.displayName, photoURL: googleUser.photoUrl);
          await activeUser.reload();
          await syncBidirectional();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use' ||
              e.code == 'account-exists-with-different-credential') {
            final userCred = await auth.signInWithCredential(credential);
            final activeUser = userCred.user ?? auth.currentUser;
            if (activeUser != null) {
              if (descartarDatosLocales) {
                final exito = await _ejecutarReemplazoAtomico(activeUser.uid);
                if (!exito) {
                  await _setPendingReplaceFlag(activeUser.uid);
                }
              } else {
                await _clearPendingReplaceFlag(activeUser.uid);
                // [E0-05a] Las reparaciones monetarias automáticas (repararGastosTasa474 / repararGastosTasa850)
                // están neutralizadas y configuradas con dryRun = true por defecto, bloqueando cualquier
                // mutación de tasas que pudiera ser propagada a Firestore durante la vinculación de cuentas.
                final gastos = await _repository.obtenerGastos();
                for (var g in gastos) {
                  if (g.id != null) {
                    await _repository.marcarComoPendiente(g.id!);
                  }
                }
              }
              await activeUser.updateProfile(displayName: googleUser.displayName, photoURL: googleUser.photoUrl);
              await activeUser.reload();
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
      debugPrint("SyncService: Error de plataforma al vincular Google");
      if (e.message != null && e.message!.contains('10')) {
        return "Error 10 (Configuración): Falta la huella digital SHA en Firebase Console o la clave Web Client ID no coincide.";
      }
      if (e.message != null && e.message!.contains('12500')) {
        return "Error 12500: Fallo de autenticación en Google Play Services. Verifica correo de soporte en Firebase.";
      }
      return e.message ?? e.toString();
    } catch (_) {
      debugPrint("SyncService: Error al vincular Google");
      return 'Error al vincular con Google';
    }
  }

  String _mapearErrorFirebaseAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
        return 'Por seguridad, debes volver a iniciar sesión antes de eliminar tu cuenta.';
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
      final auth = _auth;
      if (auth == null) return 'Servicio de autenticación no disponible.';
      final credential = EmailAuthProvider.credential(
        email: cleanEmail,
        password: password,
      );

      final user = auth.currentUser;
      if (user == null) {
        UserCredential? userCred;
        try {
          userCred = await auth.signInWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
            userCred = await auth.createUserWithEmailAndPassword(
              email: cleanEmail,
              password: password,
            );
          } else {
            return _mapearErrorFirebaseAuth(e);
          }
        }
        final activeUser = userCred.user;
        if (activeUser != null) {
          if (descartarDatosLocales) {
            final exito = await _ejecutarReemplazoAtomico(activeUser.uid);
            if (!exito) {
              await _setPendingReplaceFlag(activeUser.uid);
            }
          } else {
            await _clearPendingReplaceFlag(activeUser.uid);
          }
        }
        await syncBidirectional();
        return null;
      }

      if (user.isAnonymous) {
        try {
          final userCred = await user.linkWithCredential(credential);
          final activeUser = userCred.user ?? auth.currentUser ?? user;
          if (descartarDatosLocales) {
            final exito = await _ejecutarReemplazoAtomico(activeUser.uid);
            if (!exito) {
              await _setPendingReplaceFlag(activeUser.uid);
            }
          } else {
            await _clearPendingReplaceFlag(activeUser.uid);
          }
          await activeUser.reload();
          await syncBidirectional();
          return null;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use' ||
              e.code == 'account-exists-with-different-credential') {
            final userCred = await auth.signInWithCredential(credential);
            final activeUser = userCred.user ?? auth.currentUser;
            if (activeUser != null) {
              if (descartarDatosLocales) {
                final exito = await _ejecutarReemplazoAtomico(activeUser.uid);
                if (!exito) {
                  await _setPendingReplaceFlag(activeUser.uid);
                }
              } else {
                await _clearPendingReplaceFlag(activeUser.uid);
                // [E0-05a] Las reparaciones monetarias automáticas (repararGastosTasa474 / repararGastosTasa850)
                // están neutralizadas y configuradas con dryRun = true por defecto, bloqueando cualquier
                // mutación de tasas que pudiera ser propagada a Firestore durante la vinculación de cuentas.
                final gastos = await _repository.obtenerGastos();
                for (var g in gastos) {
                  if (g.id != null) {
                    await _repository.marcarComoPendiente(g.id!);
                  }
                }
              }
              await activeUser.reload();
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
    } catch (_) {
      debugPrint("SyncService: Error al vincular con email");
      return 'Error al vincular con correo electrónico';
    }
  }

  Future<String?> iniciarSesionConEmail(String email, String password, {bool descartarDatosLocales = false}) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return 'Ingresa un correo electrónico válido.';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    try {
      final auth = _auth;
      if (auth == null) return 'Servicio de autenticación no disponible.';

      final userCred = await auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final activeUser = userCred.user ?? auth.currentUser;
      if (activeUser != null) {
        await activeUser.reload();
      }

      if (activeUser != null) {
        if (descartarDatosLocales) {
          final exito = await _ejecutarReemplazoAtomico(activeUser.uid);
          if (!exito) {
            debugPrint("SyncService: Error al reemplazar datos en inicio de sesión, aislando sesión");
            try {
              await auth.signOut();
              await auth.signInAnonymously();
            } catch (_) {
              debugPrint("SyncService: Error restaurando sesión anónima tras fallo de login");
            }
            return 'No se pudieron sincronizar los datos de tu cuenta. Tus datos locales se conservan intactos.';
          }
        } else {
          // Fusión: limpiar cualquier flag previo y encolar todo lo local
          await _clearPendingReplaceFlag(activeUser.uid);
          final gastos = await _repository.obtenerGastos();
          for (var g in gastos) {
            if (g.id != null) {
              await _repository.marcarComoPendiente(g.id!);
            }
          }
        }
      }

      await syncBidirectional();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapearErrorFirebaseAuth(e);
    } catch (_) {
      debugPrint("SyncService: Error al iniciar sesión con email");
      return 'Error al iniciar sesión con email';
    }
  }
}
