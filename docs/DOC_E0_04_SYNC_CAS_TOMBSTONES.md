# Documento Técnico: E0-04 — Sincronización Atómica, Tombstones Remotos y CAS Optimista

**Fecha:** Noviembre de 2026  
**Iniciativa:** RM-03 (Fase 0A / Hito `E0-04`)  
**Estado:** Completada ✅ (CI Build 676/678 en verde; validado por César en *Rinde Más Dev* Build 678)  
**Referencias Normativas:** [`docs/rm-03/contrato-v1.2.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/contrato-v1.2.md) §4, Decisiones [`A-09`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/decisiones.md), [`A-15`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/decisiones.md) y Requerimiento Estructural `S3.2`.

---

## 1. Propósito y Alcance

El hito **`E0-04`** resuelve las deficiencias críticas del motor de sincronización bidireccional entre la base de datos local SQLite y Cloud Firestore, garantizando la preservación incondicional de los datos locales del usuario frente a eliminaciones o modificaciones concurrentes remotas.

### Alcance de la Entrega:
1. **Limpieza Nullable en `GastoModel.copyWith` (`S3.2`):** Permitir explícitamente des-asignar campos nulos (`totalUsdt`, `totalEur`, `tasaEur`, `eliminadoEn`, `rutaFotoLocal`) sin que `param ?? this.param` impida la mutación.
2. **Comparador Canónico de Negocio (`sonContenidoNegocioIdentico`):** Función pura determinista para evaluar idempotencia post-crash entre el registro local y el documento de Firestore.
3. **Reconciliación Defensiva de Tombstones Remotos:** Prohibir la purga física de un gasto local si tiene cambios pendientes de subida (`synced == 0` y `eliminadoEn == null`). Registro del conflicto en lugar de borrado silencioso.
4. **Control de Concurrencia Optimista (CAS):** Detección de divergencias concurrentes cuando `local.synced == 0` y `remoto.actualizadoEn > local.actualizadoEn`, preservando la versión local sin sobrescritura.
5. **Transaccionalidad Atómica en SQLite:** Ejecutar la reconciliación y mutación de gastos e ítems dentro de una única transacción SQLite (`txn`).
6. **Allowlist de Metadatos en Panel Web (`A-09`):** Restringir las mutaciones de `panel.astro` para que la edición de campos descriptivos (`comercio`, `categoria`, `notas`) no recalcule ni altere importes monetarios ni tasas históricas.
7. **Confirmación Explícita de Cambio de Monto (`A-15`):** Diálogo con motivo (`IntencionCambioImporte`) en interfaces móvil y web al alterar intencionalmente el monto pagado o la moneda.

---

## 2. Diagnóstico de Vulnerabilidades en el Código Actual

### P1. Purga Ciega ante Tombstone Remoto (`lib/services/sync_conflict_resolver.dart:L28-L34`)
- **Código actual:**
  ```dart
  if (remoto.eliminadoEn != null) {
    if (local != null) return AccionReconciliacion.eliminarLocalFisico;
    return AccionReconciliacion.descartarRemotoBorrado;
  }
  ```
- **Impacto:** Si un usuario edita un gasto sin conexión (`synced = 0`), y concurrentemente ese gasto fue eliminado en la web u otro cliente (`remoto.eliminadoEn != null`), el ciclo de pull ejecuta `eliminarLocalFisico`, purgando permanentemente la edición local sin advertencia ni respaldo.

### P2. Falta de Transacciones Atómicas en Reconciliación (`lib/services/sync_service.dart:L234-L260`)
- **Código actual:** Cada llamada a `actualizarGasto`, `guardarGasto` o `eliminarGastoFisico` se ejecuta como una operación SQL independiente fuera de un bloque transaccional unificado.
- **Impacto:** Si la aplicación se detiene o pierde energía a mitad del procesamiento de una lista de 50 documentos remotos, la base de datos queda en un estado parcialmente sincronizado e inconsistente.

### P3. Imposibilidad de Limpiar Campos Nulos en `GastoModel.copyWith` (`lib/data/models/gasto_model.dart:L150-L175`)
- **Código actual:**
  ```dart
  totalEur: totalEur ?? this.totalEur,
  tasaEur: tasaEur ?? this.tasaEur,
  eliminadoEn: eliminadoEn ?? this.eliminadoEn,
  ```
- **Impacto:** El patrón `?? this.campo` hace imposible establecer un campo a `null`. Si una operación de sincronización o desvinculación requiere limpiar una tasa o revertir un soft delete, `copyWith` preserva el valor anterior.

### P4. Falta de Idempotencia Post-Crash
- Si la app realiza un `push` a Firestore exitoso pero crashea o se interrumpe antes de ejecutar `actualizarGastoSyncStatus(synced: 1)`, en el siguiente ciclo la fila local sigue teniendo `synced = 0`. Al descargar el documento remoto, se detecta erróneamente un conflicto en lugar de reconocer que el contenido ya es idéntico y únicamente requiere marcar `synced = 1`.

---

## 3. Especificación Técnica de la Solución

### 3.1 Soporte de Limpieza Nullable en `GastoModel.copyWith` (`S3.2`)
Para permitir el paso de valores nulos intencionales sin romper la compatibilidad con llamadas existentes, se utiliza el patrón de sentinela estático constante o `ValueGetter<T?>`:

```dart
const Object _unsetSentinel = Object();

// En GastoModel:
GastoModel copyWith({
  int? id,
  String? uuid,
  String? fecha,
  String? comercio,
  String? moneda,
  int? totalOriginal,
  int? totalUsd,
  Object? totalUsdt = _unsetSentinel,
  Object? totalEur = _unsetSentinel,
  double? tasaCambio,
  Object? tasaUsdt = _unsetSentinel,
  Object? tasaEur = _unsetSentinel,
  Object? fuenteTasaCambio = _unsetSentinel,
  Object? fechaTasaCambio = _unsetSentinel,
  String? categoria,
  Object? rutaFotoLocal = _unsetSentinel,
  String? creadoEn,
  String? actualizadoEn,
  Object? eliminadoEn = _unsetSentinel,
  List<ItemGastoModel>? items,
  Object? firestoreId = _unsetSentinel,
  int? synced,
  Object? ocrText = _unsetSentinel,
}) {
  return GastoModel(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    fecha: fecha ?? this.fecha,
    comercio: comercio ?? this.comercio,
    moneda: moneda ?? this.moneda,
    totalOriginal: totalOriginal ?? this.totalOriginal,
    totalUsd: totalUsd ?? this.totalUsd,
    totalUsdt: identical(totalUsdt, _unsetSentinel) ? this.totalUsdt : totalUsdt as int?,
    totalEur: identical(totalEur, _unsetSentinel) ? this.totalEur : totalEur as int?,
    tasaCambio: tasaCambio ?? this.tasaCambio,
    tasaUsdt: identical(tasaUsdt, _unsetSentinel) ? this.tasaUsdt : tasaUsdt as double?,
    tasaEur: identical(tasaEur, _unsetSentinel) ? this.tasaEur : tasaEur as double?,
    fuenteTasaCambio: identical(fuenteTasaCambio, _unsetSentinel) ? this.fuenteTasaCambio : fuenteTasaCambio as String?,
    fechaTasaCambio: identical(fechaTasaCambio, _unsetSentinel) ? this.fechaTasaCambio : fechaTasaCambio as String?,
    categoria: categoria ?? this.categoria,
    rutaFotoLocal: identical(rutaFotoLocal, _unsetSentinel) ? this.rutaFotoLocal : rutaFotoLocal as String?,
    creadoEn: creadoEn ?? this.creadoEn,
    actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    eliminadoEn: identical(eliminadoEn, _unsetSentinel) ? this.eliminadoEn : eliminadoEn as String?,
    items: items ?? this.items,
    firestoreId: identical(firestoreId, _unsetSentinel) ? this.firestoreId : firestoreId as String?,
    synced: synced ?? this.synced,
    ocrText: identical(ocrText, _unsetSentinel) ? this.ocrText : ocrText as String?,
  );
}
```

### 3.2 Comparador Determinista de Negocio (`sonContenidoNegocioIdentico`)
Ubicación: `lib/domain/monetary/monetary_resolution.dart` o `lib/services/sync_conflict_resolver.dart`.

```dart
bool sonContenidoNegocioIdentico(GastoModel a, GastoModel b) {
  if (a.uuid != b.uuid) return false;
  if (a.fecha != b.fecha) return false;
  if (a.comercio.trim().toLowerCase() != b.comercio.trim().toLowerCase()) return false;
  if (a.moneda.toUpperCase().trim() != b.moneda.toUpperCase().trim()) return false;
  if (a.totalOriginal != b.totalOriginal) return false;
  if (a.totalUsd != b.totalUsd) return false;
  if (a.totalUsdt != b.totalUsdt) return false;
  if (a.totalEur != b.totalEur) return false;
  if ((a.tasaCambio - b.tasaCambio).abs() > 0.0001) return false;
  if ((a.tasaUsdt ?? 0.0) != (b.tasaUsdt ?? 0.0)) return false;
  if ((a.tasaEur ?? 0.0) != (b.tasaEur ?? 0.0)) return false;
  if (a.categoria.trim().toLowerCase() != b.categoria.trim().toLowerCase()) return false;
  if (a.eliminadoEn != b.eliminadoEn) return false;
  
  // Comparación de ítems
  final itemsA = a.items;
  final itemsB = b.items;
  if (itemsA.length != itemsB.length) return false;
  for (int i = 0; i < itemsA.length; i++) {
    final itA = itemsA[i];
    final itB = itemsB[i];
    if (itA.descripcion.trim().toLowerCase() != itB.descripcion.trim().toLowerCase()) return false;
    if (itA.cantidad != itB.cantidad) return false;
    if (itA.precioUnitario != itB.precioUnitario) return false;
    if (itA.total != itB.total) return false;
    if (itA.categoria != itB.categoria) return false;
  }
  return true;
}
```

### 3.3 Modelo de Reconciliación Transaccional (`contrato-v1.2.md` §4)

```dart
enum ResultadoSincronizacionFila {
  insertada,
  actualizada,
  eliminada,
  idempotenteMarcadaSynced,
  conflictoTombstoneRegistrado,
  conflictoConcurrenteRegistrado,
  ignorada,
}

Future<ResultadoSincronizacionFila> reconciliarFilaRemotaEnTxn({
  required Transaction txn,
  required DatabaseHelper db,
  required GastoModel? localActual,
  required GastoModel remoto,
}) async {
  // 1. Tombstone Remoto
  if (remoto.eliminadoEn != null) {
    if (localActual == null) {
      return ResultadoSincronizacionFila.ignorada;
    }
    if (localActual.synced == 1) {
      // Local limpio: aplicar borrado físico en SQLite
      await db.eliminarGastoFisicoEnTxn(txn, localActual.id!);
      return ResultadoSincronizacionFila.eliminada;
    }
    // localActual.synced == 0 && localActual.eliminadoEn == null:
    // PROHIBIDO borrar. Registrar conflicto de tombstone remoto.
    await db.registrarConflictoSyncEnTxn(
      txn,
      uuid: localActual.uuid,
      tipo: 'tombstone_remoto',
      localJson: jsonEncode(localActual.toMap()),
      remotoJson: jsonEncode(remoto.toMap()),
      fecha: DateTime.now().toIso8601String(),
    );
    return ResultadoSincronizacionFila.conflictoTombstoneRegistrado;
  }

  // 2. Inserción de Gasto Remoto Nuevo
  if (localActual == null) {
    await db.insertarGastoCompletoEnTxn(txn, remoto.copyWith(synced: 1), remoto.items);
    return ResultadoSincronizacionFila.insertada;
  }

  // 3. Fila Local con Modificaciones Pendientes (synced == 0)
  if (localActual.synced == 0) {
    if (sonContenidoNegocioIdentico(localActual, remoto)) {
      // Idempotencia post-crash: reconciliar marcando synced = 1
      await db.actualizarGastoSyncStatusEnTxn(
        txn,
        localActual.copyWith(
          actualizadoEn: remoto.actualizadoEn,
          synced: 1,
        ),
      );
      return ResultadoSincronizacionFila.idempotenteMarcadaSynced;
    }
    
    final tRemoto = DateTime.tryParse(remoto.actualizadoEn ?? remoto.creadoEn) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tLocal = DateTime.tryParse(localActual.actualizadoEn ?? localActual.creadoEn) ?? DateTime.fromMillisecondsSinceEpoch(0);
    
    if (tRemoto.isAfter(tLocal)) {
      // Divergencia real: conservar fila local (synced = 0) y registrar conflicto concurrente
      await db.registrarConflictoSyncEnTxn(
        txn,
        uuid: localActual.uuid,
        tipo: 'edicion_concurrente',
        localJson: jsonEncode(localActual.toMap()),
        remotoJson: jsonEncode(remoto.toMap()),
        fecha: DateTime.now().toIso8601String(),
      );
      return ResultadoSincronizacionFila.conflictoConcurrenteRegistrado;
    }
    // tLocal >= tRemoto: mantener local con synced = 0 para subida posterior
    return ResultadoSincronizacionFila.ignorada;
  }

  // 4. Fila Local Limpia (synced == 1): aplicar actualización si remoto es más reciente
  final tRemoto = DateTime.tryParse(remoto.actualizadoEn ?? remoto.creadoEn) ?? DateTime.fromMillisecondsSinceEpoch(0);
  final tLocal = DateTime.tryParse(localActual.actualizadoEn ?? localActual.creadoEn) ?? DateTime.fromMillisecondsSinceEpoch(0);

  if (tRemoto.isAfter(tLocal)) {
    await db.actualizarGastoCompletoEnTxn(
      txn,
      remoto.copyWith(
        id: localActual.id,
        rutaFotoLocal: localActual.rutaFotoLocal,
        synced: 1,
      ),
      remoto.items,
    );
    return ResultadoSincronizacionFila.actualizada;
  }

  return ResultadoSincronizacionFila.ignorada;
}
```

---

## 4. Allowlist de Metadatos en Panel Web (`A-09`)

En `landing/src/pages/panel.astro`, la función de guardado de ediciones ordinarias de metadatos (comercio, notas, categoría) debe aislar estrictamente el payload enviado a Firestore vía `updateDoc`:

```javascript
// Payload estricto de edición ordinaria de metadatos (A-09)
const metadataPayload = {
  comercio: sanitizedComercio,
  categoria: sanitizedCategoria,
  notas: sanitizedNotas,
  actualizado_en: new Date().toISOString(),
};

// PROHIBIDO incluir:
// - total_original, total_usd, total_eur, total_usdt
// - tasa_cambio, tasa_eur, tasa_usdt
// - moneda
```

Si el usuario altera el monto o la moneda en el panel web, se exige la invocación del modal de confirmación de cambio de importe (`A-15`) antes de armar el payload financiero completo.

---

## 5. Confirmación Obligatoria de Cambio de Monto (`A-15`)

Cuando el usuario modifica el campo de monto o moneda en `ReviewExpenseScreen` sobre un `existingGasto`:
1. La aplicación detecta que `totalOriginal != existingGasto.totalOriginal` o `moneda != existingGasto.moneda`.
2. Al pulsar **Guardar Gasto**, se presenta el diálogo modal canónico:
   - **Título:** `¿Confirmas el cambio de monto?`
   - **Mensaje:** `Estás modificando el importe registrado de [Monto Anterior] a [Monto Nuevo]. Esta acción recalculará las equivalencias asociadas.`
   - **Botón Confirmar:** `Actualizar monto`
   - **Botón Cancelar:** `Revisar`
3. Si el usuario cancela, permanece en la pantalla de edición sin alterar SQLite ni Firestore.

---

## 6. Plan de Verificación y Pruebas Obligatorias

### Pruebas Unitarias en Dart (`test/services/sync_conflict_resolver_test.dart`):
1. **Tombstone con `synced == 1`:** Se resuelve como `eliminarLocalFisico`.
2. **Tombstone con `synced == 0` y `eliminadoEn == null`:** Prohíbe el borrado y genera `conflictoTombstoneRegistrado`.
3. **Idempotencia post-crash:** Fila local con `synced == 0` idéntica a la remota se actualiza a `synced = 1`.
4. **Divergencia concurrente con remoto más reciente:** Conserva local `synced = 0` y registra `conflictoConcurrenteRegistrado`.
5. **Local más reciente con `synced == 0`:** Se mantiene local para subida (`subirLocalANube`).

### Pruebas de Modelo (`test/models/gasto_model_copy_with_test.dart`):
1. `copyWith(totalEur: null)` borra efectivamente el valor de `totalEur`.
2. `copyWith(eliminadoEn: null)` restablece el soft delete a `null`.
3. `copyWith()` sin argumentos preserva el 100% de los valores intactos.

### Pruebas de Transaccionalidad SQLite (`test/data/database_helper_atomic_sync_test.dart`):
1. Fallo inducido a mitad de transacción hace rollback completo sin dejar registros huérfanos en `gastos` o `items_gasto`.
2. Inserción de tabla de conflictos `conflictos_sync` en migración SQLite si se persiste localmente.

---

## 7. Compuertas de Aceptación

- [x] **Compilación:** `flutter analyze --fatal-infos --fatal-warnings` sin observaciones en CI Build 676.
- [x] **Pruebas:** 100% de las pruebas unitarias (673 pruebas) pasando en verde en GitHub Actions CI (Build 676, run 42865178416).
- [x] **Web:** Paridad de edición de metadatos y confirmación A-15 en `panel.astro` verificada con build estático y CI Web exitoso (run 42861811435).
- [x] **Validación:** Aprobación explícita de César en *Rinde Más Dev* (Build 678) antes de promover a producción.
