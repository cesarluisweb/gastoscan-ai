import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/repositories/gasto_repository.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';

enum SyncTrigger {
  escritura,
  arranque,
  reanudacion,
  manual,
  vinculacion,
}

enum SyncStatus {
  inactiva,
  programada,
  enCurso,
  completada,
  error,
}

class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncTime;
  final String? errorMessage;
  final String? errorCode;
  final int consecutiveFailures;
  final int docsProcessed;

  const SyncState({
    required this.status,
    this.lastSyncTime,
    this.errorMessage,
    this.errorCode,
    this.consecutiveFailures = 0,
    this.docsProcessed = 0,
  });

  const SyncState.inactiva({DateTime? lastSync})
      : status = SyncStatus.inactiva,
        lastSyncTime = lastSync,
        errorMessage = null,
        errorCode = null,
        consecutiveFailures = 0,
        docsProcessed = 0;

  const SyncState.programada({DateTime? lastSync})
      : status = SyncStatus.programada,
        lastSyncTime = lastSync,
        errorMessage = null,
        errorCode = null,
        consecutiveFailures = 0,
        docsProcessed = 0;

  const SyncState.enCurso({DateTime? lastSync})
      : status = SyncStatus.enCurso,
        lastSyncTime = lastSync,
        errorMessage = null,
        errorCode = null,
        consecutiveFailures = 0,
        docsProcessed = 0;

  const SyncState.completada({required DateTime lastSync, int docs = 0})
      : status = SyncStatus.completada,
        lastSyncTime = lastSync,
        errorMessage = null,
        errorCode = null,
        consecutiveFailures = 0,
        docsProcessed = docs;

  const SyncState.error({
    required String message,
    DateTime? lastSync,
    this.errorCode,
    this.consecutiveFailures = 1,
  })  : status = SyncStatus.error,
        lastSyncTime = lastSync,
        errorMessage = message,
        docsProcessed = 0;

  bool get isPermissionDenied => errorCode == 'permission-denied';
  bool get isOfflineError => errorCode == 'offline';

  /// El banner de Dashboard solo se muestra ante fallo persistente (>= 2 fallos seguidos)
  /// o de inmediato ante `permission-denied` (requiere actualizar desde Google Play).
  bool get shouldShowBanner =>
      status == SyncStatus.error &&
      !isOfflineError &&
      (isPermissionDenied || consecutiveFailures >= 2);

  @override
  String toString() =>
      'SyncState(status: $status, lastSync: $lastSyncTime, code: $errorCode, failures: $consecutiveFailures, error: $errorMessage)';
}

/// Coordinador central de sincronización con Cloud Firestore.
///
/// Implementa:
/// 1. Cerrojo de concurrencia: una sola sincronización activa a la vez.
/// 2. Bandera de repetición (`_hasPendingRerun`): si llegan peticiones mientras
///    se sincroniza, se ejecuta un nuevo ciclo secuencial al finalizar.
/// 3. Debouncing de 2 segundos para escrituras locales.
/// 4. Límite de frecuencia (throttle de 5 minutos) en arranques y reanudaciones rutinarias
///    si no hay cambios locales pendientes (`synced = 0`).
/// 5. Protección de privacidad: omite sincronización para usuarios anónimos o sin sesión.
/// 6. Integración con resolución de reemplazo pendiente (`retryPendingReplace`).
class SyncCoordinator {
  static SyncCoordinator _instance = SyncCoordinator._internal();
  static SyncCoordinator get instance => _instance;

  @visibleForTesting
  static set instance(SyncCoordinator coordinator) => _instance = coordinator;

  final SyncService _syncService;
  final GastoRepository _repository;
  final ConnectivityService _connectivityService;
  final Duration debounceDuration;
  final Duration minRoutineInterval;
  final DateTime Function() _now;

  Timer? _debounceTimer;
  bool _isSyncing = false;
  bool _hasPendingRerun = false;
  DateTime? _lastSuccessfulSync;
  int _consecutiveFailures = 0;

  final ValueNotifier<SyncState> stateNotifier =
      ValueNotifier<SyncState>(const SyncState.inactiva());

  SyncState get state => stateNotifier.value;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;

  SyncCoordinator({
    SyncService? syncService,
    GastoRepository? repository,
    ConnectivityService? connectivityService,
    this.debounceDuration = const Duration(seconds: 2),
    this.minRoutineInterval = const Duration(minutes: 5),
    DateTime Function()? nowProvider,
  })  : _syncService = syncService ?? SyncService(),
        _repository = repository ?? GastoRepository(),
        _connectivityService = connectivityService ?? ConnectivityService.instance,
        _now = nowProvider ?? DateTime.now;

  SyncCoordinator._internal()
      : _syncService = SyncService(),
        _repository = GastoRepository(),
        _connectivityService = ConnectivityService.instance,
        debounceDuration = const Duration(seconds: 2),
        minRoutineInterval = const Duration(minutes: 5),
        _now = DateTime.now;

  /// Notifica una mutación local (guardar, actualizar o eliminar gasto/presupuesto).
  /// Aplica debouncing de 2 segundos antes de disparar la sincronización.
  void notifyLocalChange() {
    requestDebounced(SyncTrigger.escritura);
  }

  /// Programa una petición con debouncing.
  void requestDebounced([SyncTrigger trigger = SyncTrigger.escritura]) {
    _debounceTimer?.cancel();
    stateNotifier.value = SyncState.programada(lastSync: _lastSuccessfulSync);

    _debounceTimer = Timer(debounceDuration, () {
      request(trigger);
    });
  }

  /// Cancela cualquier debounce programado.
  void cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (stateNotifier.value.status == SyncStatus.programada) {
      stateNotifier.value = SyncState.inactiva(lastSync: _lastSuccessfulSync);
    }
  }

  /// Solicita una sincronización inmediata respetando cerrojo, guardas y throttle.
  Future<void> request(SyncTrigger trigger, {bool forzar = false}) async {
    // Si ya hay una en curso, registrar necesidad de repetición secuencial
    if (_isSyncing) {
      _hasPendingRerun = true;
      debugPrint('[SyncCoordinator] Sincronización en curso. Se agenda repetición secuencial.');
      return;
    }

    _isSyncing = true;
    _hasPendingRerun = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    try {
      final user = _syncService.currentUser;
      // Guardas de privacidad y sesión: anónimos o sin usuario no sincronizan
      if (user == null || user.isAnonymous) {
        stateNotifier.value = SyncState.inactiva(lastSync: _lastSuccessfulSync);
        return;
      }

      // Comprobar conectividad
      final hasNet = await _connectivityService.isConnected();
      if (!hasNet) {
        stateNotifier.value = SyncState.error(
          message: 'Sin conexión a internet.',
          errorCode: 'offline',
          consecutiveFailures: 1,
          lastSync: _lastSuccessfulSync,
        );
        return;
      }

      // Throttle de 5 minutos en arranques y reanudaciones salvo forzado explícito
      if (!forzar && (trigger == SyncTrigger.arranque || trigger == SyncTrigger.reanudacion)) {
        if (_lastSuccessfulSync != null) {
          final elapsed = _now().difference(_lastSuccessfulSync!);
          if (elapsed < minRoutineInterval) {
            try {
              final unsynced = await _repository.obtenerGastosNoSincronizados();
              if (unsynced.isEmpty) {
                debugPrint('[SyncCoordinator] Throttle activo ($elapsed < $minRoutineInterval) y sin cambios locales pendientes.');
                return;
              }
            } catch (e) {
              debugPrint('[SyncCoordinator] Error consultando no sincronizados en throttle: $e');
            }
          }
        }
      }

      await _executeSync();
    } finally {
      _isSyncing = false;

      // Si entraron nuevas peticiones durante la ejecución, disparar repetición secuencial limpia
      if (_hasPendingRerun) {
        _hasPendingRerun = false;
        debugPrint('[SyncCoordinator] Ejecutando repetición secuencial por cambios pendientes.');
        scheduleMicrotask(() => request(SyncTrigger.escritura, forzar: true));
      }
    }
  }

  Future<void> _executeSync() async {
    stateNotifier.value = SyncState.enCurso(lastSync: _lastSuccessfulSync);

    final startTime = _now();
    try {
      final user = _syncService.currentUser;
      if (user == null || user.isAnonymous) {
        stateNotifier.value = SyncState.inactiva(lastSync: _lastSuccessfulSync);
        return;
      }

      // 1. Manejo prioritario de reemplazo pendiente
      final isPendingReplace = await _syncService.isPendingReplaceActive(user.uid);
      if (isPendingReplace) {
        debugPrint('[SyncCoordinator] Detectado reemplazo pendiente. Ejecutando retryPendingReplace...');
        final err = await _syncService.retryPendingReplace();
        if (err != null) {
          stateNotifier.value = SyncState.error(
            message: err,
            lastSync: _lastSuccessfulSync,
          );
          return;
        }
      }

      // 2. Ejecutar sincronización bidireccional y evaluar el reporte real
      final report = await _syncService.syncBidirectional();
      if (report.hasErrors) {
        _consecutiveFailures++;
        final humanMessage = _mapReportToHumanMessage(report);
        stateNotifier.value = SyncState.error(
          message: humanMessage,
          errorCode: report.primaryErrorCode,
          consecutiveFailures: _consecutiveFailures,
          lastSync: _lastSuccessfulSync,
        );
        debugPrint(
          '[SyncCoordinator] Sincronización con errores (${report.totalErrors}, code: ${report.primaryErrorCode}, seguidos: $_consecutiveFailures).',
        );
        return;
      }

      _consecutiveFailures = 0;
      _lastSuccessfulSync = _now();
      stateNotifier.value = SyncState.completada(
        lastSync: _lastSuccessfulSync!,
        docs: report.totalProcessed,
      );
      final duration = _now().difference(startTime);
      debugPrint('[SyncCoordinator] Sincronización exitosa en ${duration.inMilliseconds} ms.');
    } catch (e) {
      _consecutiveFailures++;
      debugPrint('[SyncCoordinator] Error en sincronización: $e');
      final lower = e.toString().toLowerCase();
      final String? code = lower.contains('permission-denied') || lower.contains('permission_denied')
          ? 'permission-denied'
          : (lower.contains('unauthenticated')
              ? 'unauthenticated'
              : (lower.contains('unavailable') || lower.contains('network')
                  ? 'unavailable'
                  : 'unknown'));
      stateNotifier.value = SyncState.error(
        message: _mapCodeToHumanMessage(code),
        errorCode: code,
        consecutiveFailures: _consecutiveFailures,
        lastSync: _lastSuccessfulSync,
      );
    }
  }

  String _mapReportToHumanMessage(SyncRunReport report) {
    if (report.isPermissionDenied) {
      return 'Actualiza Rinde Más desde Google Play para seguir respaldando tus gastos.';
    }
    if (report.primaryErrorCode == 'unauthenticated') {
      return 'Tu sesión venció. Inicia sesión nuevamente con Google en Más.';
    }
    if (report.primaryErrorCode == 'unavailable') {
      return 'Sin conexión estable. Tus gastos siguen seguros en este teléfono.';
    }
    if (report.isPartialError) {
      final n = report.totalErrors;
      return n == 1
          ? '1 registro no se pudo respaldar en la nube. Toca Reintentar.'
          : '$n registros no se pudieron respaldar en la nube. Toca Reintentar.';
    }
    return 'No se pudo sincronizar con la nube. Tus gastos siguen seguros en este teléfono.';
  }

  String _mapCodeToHumanMessage(String? code) {
    switch (code) {
      case 'permission-denied':
        return 'Actualiza Rinde Más desde Google Play para seguir respaldando tus gastos.';
      case 'unauthenticated':
        return 'Tu sesión venció. Inicia sesión nuevamente con Google en Más.';
      case 'unavailable':
        return 'Sin conexión estable. Tus gastos siguen seguros en este teléfono.';
      default:
        return 'No se pudo sincronizar con la nube. Tus gastos siguen seguros en este teléfono.';
    }
  }

  @visibleForTesting
  void reset() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _isSyncing = false;
    _hasPendingRerun = false;
    _lastSuccessfulSync = null;
    _consecutiveFailures = 0;
    stateNotifier.value = const SyncState.inactiva();
  }
}
