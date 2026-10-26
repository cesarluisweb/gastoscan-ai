# Documentación Técnica: Sincronización y Resiliencia Offline (Lote 3)

**Fecha:** 26 de octubre de 2026  
**Referencia de Auditoría:** `docs/auditoria_integral_argon.md` (Lote 3)  
**Estado:** `Pendiente de validación 🧪` (Código commiteado, pruebas remotas en CI)  
**Artefactos Afectados:** Móvil Flutter (`lib/data/`, `lib/services/`, `lib/providers/`, `lib/ui/`)

---

## 1. Resumen Ejecutivo
El Lote 3 resuelve los problemas de sincronización bidireccional, resiliencia offline y paridad de datos entre la app móvil Flutter de Rinde Más y Cloud Firestore. 

Principales hitos alcanzados:
1. **Preservación total de ítems de compra (`ItemGastoModel`):** Creación de `GastoFirestoreMapper` para serializar la lista de compras sin campos locales efímeros (`id`, `synced`, `firestore_id`, `ruta_foto_local`) y normalizando categorías con `AppConstants.normalizarCategoria`.
2. **Reemplazo atómico en SQLite (`reemplazarDatosLocales`):** Ejecución en una sola transacción `db.transaction`, validación previa en memoria con `PresupuestoRemotoModel`, compatibilidad tolerante con FTS5 (`gastos_fts`), esquema v18 exacto (`presupuestos_categorias_mensuales`), omisión de tombstones y reseteo de `categorias.presupuesto_mensual = 0.0`.
3. **Mecanismo Pull-encola / Push-consume:** El Pull marca modificaciones pendientes con `marcarComoPendiente(id)` (`synced = 0`), y el Push solo procesa registros con `synced == 0`.
4. **Política "Borrado Gana" (Delete Wins):** Erradica ciclos infinitos de resurrección entre la Web y el Móvil sin depender de que la web escriba `actualizado_en` al borrar.
5. **Bloqueo durable por UID (`sync_pending_replace_<uid>`):** Si la descarga o reemplazo de datos falla durante un flujo con descarte de datos, se bloquea el push en `SharedPreferences`. Se renderiza un banner persistente en `DashboardScreen`, se bloquea la adición de gastos en `MainScreen`, y se expone `retryPendingReplace()` con cerrojo de concurrencia.
6. **Desbloqueo por Fusión (C3):** Si el usuario opta por conservar y sumar sus datos (`descartarDatosLocales == false`) en cualquier inicio de sesión o vinculación, la bandera de bloqueo se elimina de inmediato.
7. **Mitigación de condición de carrera en tasas históricas:** Token monótono `_tasaRequestId` en `ReviewExpenseScreen` para evitar sobrescrituras de red en cambios rápidos de fecha (A $\to$ B $\to$ A).
8. **Ciclo de vida de fotos físicas:** Las fotos de comprobantes permanecen en el almacenamiento del dispositivo por defecto. Solo se eliminan físicamente si el usuario activa explícitamente el interruptor en el diálogo de eliminación de cuenta.

---

## 2. Matriz de Resolución de Conflictos ("Borrado Gana")

Implementada como función pura en `lib/services/sync_conflict_resolver.dart`:

| Estado Local | Estado Remoto | Condición Temporal | Acción Resultante | Justificación |
| :--- | :--- | :--- | :--- | :--- |
| `null` | Activo | N/A | `descargarRemotoALocal` | Nuevo gasto creado en la nube (Web o reinstalación). |
| `null` | Borrado (`eliminado_en != null`) | N/A | `nada` | Gasto ya borrado en la nube que no existe en local. |
| Activo | `null` | N/A | `subirLocalANube` | Gasto creado offline en el móvil, pendiente de subir. |
| Borrado local | `null` | N/A | `eliminarLocalFisico` | **Gasto fantasma:** Creado y borrado localmente sin haberse subido a la nube. Se purga de SQLite de inmediato. |
| Activo | Borrado (`eliminado_en != null`) | Cualquiera | `eliminarLocalFisico` | **Borrado Gana:** La eliminación en la nube prevalece siempre. Evita bucles de resurrección. |
| Borrado local | Activo | Cualquiera | `subirLocalANube` | **Borrado Gana:** La eliminación local prevalece. El Push envía `softDeleteGasto` con `set(merge: true)` y luego purga el registro de SQLite. |
| Borrado local | Borrado | N/A | `eliminarLocalFisico` | Ambos lados reconocen el borrado. Se purga de SQLite. |
| Activo | Activo | Remoto más reciente | `descargarRemotoALocal` | Edición en la web más reciente que en móvil. |
| Activo | Activo | Local más reciente | `subirLocalANube` | Edición móvil más reciente que en la web. |
| Activo | Activo | Tiempos idénticos | `nada` | En perfecta sincronía. |

---

## 3. Bloqueo Durable de Sincronización y Recuperación Segura

### 3.1 Origen del Bloqueo
Cuando un usuario vincula una cuenta (Google o Correo) y selecciona **"Reemplazar"** (`descartarDatosLocales == true`):
1. Firebase Auth vincula la credencial exitosamente.
2. La app intenta descargar los gastos y presupuestos de la nube para reemplazarlos atómicamente en SQLite.
3. Si la descarga o la transacción SQLite fallan (por corte de red o timeout):
   - La sesión en Firebase Auth ya está vinculada y no debe destruirse (destruirla dejaría al usuario sin acceso o desconectado).
   - Se persiste `sync_pending_replace_<uid> = true` en `SharedPreferences`.
   - Se aborta el push automático para evitar subir los datos anónimos sobre la cuenta vinculada.

### 3.2 Guards en `SyncService`
Al inicio de:
- `syncBidirectional()`
- `syncToFirestore()`
- `syncPresupuestosToFirestore()`

Se evalúa:
```dart
final prefs = await SharedPreferences.getInstance();
if (prefs.getBool('sync_pending_replace_${user.uid}') == true) {
  debugPrint("SyncService: Sincronización bloqueada por reemplazo pendiente");
  return;
}
```
Si la bandera es `true`, la sincronización se aborta de inmediato antes de iniciar cualquier operación de lectura o escritura.

### 3.3 Recuperación con `retryPendingReplace()`
Expuesto en `SyncService` y consumido por `GastoProvider`:
- Protegido por el cerrojo en memoria `_isRetryingReplace` para evitar ejecuciones concurrentes.
- Descarga los snapshots de Firestore ignorando la bandera.
- Ejecuta `reemplazarDatosLocales` dentro de una transacción única en SQLite.
- Solo si la transacción es exitosa:
  - Elimina `sync_pending_replace_<uid>` de `SharedPreferences`.
  - Limpia la clave obsoleta `presupuesto_mensual`.
  - Recarga todos los datos con `await cargarDatos()`.
  - Si falla, mantiene la bandera activa y devuelve un mensaje amigable al usuario.

### 3.4 Desbloqueo por Fusión (C3)
Si en cualquier momento el usuario inicia sesión o vincula una cuenta seleccionando **"Conservar y sumar"** (`descartarDatosLocales == false`):
```dart
if (!descartarDatosLocales) {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('sync_pending_replace_${activeUser.uid}');
}
```
La bandera se remueve antes de llamar a `syncBidirectional()`, permitiendo que la fusión proceda sin bloqueos.

---

## 4. UI y Experiencia de Usuario

### 4.1 Banner Ámbar en `DashboardScreen`
- Ubicado justo encima de `SummaryCard`.
- Solo visible si `gastoProvider.hasPendingReplaceBlock == true`.
- Cumple con `DESIGN.md`: fondo ámbar claro con borde `#F59E0B`, texto `#111827`, ícono ámbar oscuro, botón *"Reintentar"* con fondo amarillo primario y texto negro, y botón secundario *"Cerrar sesión"*.

### 4.2 Bloqueo de Mutaciones en `MainScreen`
- Al pulsar el botón flotante `+` o abrir el menú de registro de gastos:
  - Si `hasPendingReplaceBlock` es `true`, el menú no se abre.
  - Se muestra un `SnackBar` informativo indicando que la descarga debe completarse antes de registrar nuevos gastos.

### 4.3 Diálogos en `MoreScreen`
- **Cerrar sesión:**
  - Copy adaptativo: si el usuario es anónimo, advierte que los datos se perderán de forma permanente. Si es vinculado, aclara que sus gastos están a salvo en la nube pero las fotos permanecerán en el teléfono sin vincularse.
  - Limpieza de `ChatProvider.clearConversation()`.
- **Eliminar cuenta y datos:**
  - Incorpora un `CheckboxListTile` para `eliminarFotos` (desactivado por defecto).
  - Si requiere reautenticación por contraseña, el estado del checkbox se preserva.
  - Solo si la cuenta se elimina con éxito en Auth y Firestore, se purgan los archivos físicos si el usuario lo solicitó.

---

## 5. Guía de Pruebas Manuales en Dispositivo Físico (*Rinde Más Dev*)

Para validar la resiliencia en condiciones reales usando el artefacto `rindemas-dev-apk`:

### Prueba 1: Reemplazo Atómico Interrumpido por Modo Avión
1. Iniciar la app sin cuenta registrada y crear 2 gastos locales.
2. Ir a Más $\to$ Respaldo en la Nube $\to$ Iniciar sesión o Vincular con Correo.
3. Ingresar credenciales de una cuenta existente con gastos previos en la nube.
4. En el diálogo "Gastos en este teléfono", seleccionar **"Reemplazar"**.
5. Activar de inmediato el Modo Avión (o cortar WiFi/datos) para forzar un error de red durante la descarga.
6. **Verificación:**
   - La app muestra error de conexión.
   - En Inicio aparece el banner ámbar: *"Sincronización pendiente interrumpida"*.
   - Al tocar el botón `+` para agregar un gasto, aparece el SnackBar bloqueando la acción.
   - Cerrar completamente la app (swipe up) y volver a abrirla: el banner ámbar persiste.
7. Desactivar el Modo Avión y pulsar **"Reintentar"** en el banner.
8. **Verificación:**
   - La descarga se completa.
   - El banner desaparece.
   - Los datos locales son reemplazados por los datos de la nube.
   - El botón `+` vuelve a funcionar con normalidad.

### Prueba 2: Soft-Delete y Purga de Gastos Fantasma
1. Con sesión activa en la nube, activar Modo Avión.
2. Registrar un gasto local ("Gasto Fantasma") y eliminarlo inmediatamente mientras se sigue en Modo Avión.
3. Registrar un segundo gasto ("Gasto Existente") antes del corte y eliminarlo en Modo Avión.
4. Desactivar Modo Avión y deslizar hacia abajo en Inicio para sincronizar.
5. **Verificación:**
   - En Firestore, el "Gasto Fantasma" nunca llegó a crearse ni dejó rastro.
   - El "Gasto Existente" tiene `eliminado_en` y `actualizado_en` actualizados vía `set(merge: true)`.
   - En SQLite local, ambos registros han sido purgados físicamente.

### Prueba 3: Conservación de Fotos al Eliminar Cuenta
1. Registrar un gasto con foto de comprobante desde la cámara.
2. Ir a Más $\to$ Zona de Peligro $\to$ Eliminar cuenta y datos.
3. En el diálogo, dejar el interruptor *"Eliminar también los archivos de fotos..."* **desmarcado**.
4. Confirmar la eliminación.
5. **Verificación:**
   - La cuenta y los datos en Firestore se borran.
   - En el explorador de archivos del teléfono (`Android/data/.../files` o almacenamiento interno), el archivo JPG de la foto sigue existiendo intacto.
