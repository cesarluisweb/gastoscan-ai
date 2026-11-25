# Resiliencia y Visibilidad de Sincronización App ↔ Panel Web

> **Estado:** `Pendiente de validación 🧪` (tarea crítica: sincronización Firestore/SQLite y panel web).
> **CI en verde:** Móvil run `45646396832` (`build 740`, SHA `04b7ff4`) · Web run `45645575107` (`build 36`, SHA `46a01f7`) · Reglas Firestore run `45645575133` (`build 9`, SHA `46a01f7`).
> **Reglas de Firestore:** sin cambios (`firestore.rules` se mantiene estricta).

## 1. Diagnóstico
Al editar o crear gastos en la app móvil, los cambios no se reflejaban en el panel web mientras que Web → App sí funcionaba:
1. `SyncService.syncBidirectional` agrupaba `syncFromFirestore` y `syncToFirestore` en el mismo `try/catch (_)`: un solo documento remoto malformado abortaba el push en silencio.
2. `syncToFirestore` y `syncPresupuestosToFirestore` silenciaban errores de Firestore (incluido `permission-denied` en builds anteriores a `58aedc7` / `1.3.0`), por lo que `SyncCoordinator` reportaba éxito siempre.
3. `SyncCoordinator.stateNotifier` no se consumía en la interfaz.
4. `ReviewExpenseScreen` no copiaba `firestoreId` ni `ocrText` al editar un gasto existente.
5. `_concurrentConflicts` en `SyncService` nunca se limpiaba cuando una nueva edición local superaba al timestamp remoto.
6. `upsertPresupuesto` usaba `SetOptions(merge: true)` sobre el mapa `categorias` (no eliminaba categorías borradas en la app) y no normalizaba claves legacy.
7. El panel web (`landing/src/pages/panel.astro`) solo cargaba datos al iniciar sesión o cambiar de mes.

## 2. Cambios Implementados
- **`lib/services/sync_service.dart`:**
  - `SyncRunReport` con contadores por fase, errores y código primario (`permission-denied`, `unauthenticated`, `unavailable`, `unknown`).
  - Se conserva la regla de seguridad anónimo → cuenta: si falla el pull completo (`fetchAllGastos` / `fetchAllPresupuestos`), se omite el push y se reporta error.
  - Aislamiento por documento en `syncFromFirestore` y `syncPresupuestosFromFirestore`: un documento corrupto no bloquea a los demás ni cancela el push.
  - Desbloqueo automático de `_concurrentConflicts` cuando una nueva edición local gana por timestamp (`subirLocalANube`).
  - Normalización de claves de `categorias` en `syncPresupuestosToFirestore` y envío de presupuestos puestos en `0` con `actualizado_en`.
- **`lib/data/datasources/remote/firestore_gastos_remote_data_source.dart`:** `upsertPresupuesto` usa `.set(data)` (reemplazo completo del documento canónico de 7 claves) para borrar categorías eliminadas.
- **`lib/services/sync_coordinator.dart`:** consume `SyncRunReport`, cuenta fallos consecutivos, expone `shouldShowBanner` (≥ 2 fallos seguidos o 1.er `permission-denied`) y traduce códigos a mensajes humanos (sin `e.toString()` ni `PlatformException`).
- **`lib/providers/gasto_provider.dart`:** expone `syncState` y `syncStateListenable`.
- **`lib/ui/screens/review_expense_screen.dart`:** preserva `firestoreId` y `ocrText` al editar un gasto existente.
- **`lib/ui/screens/more_screen.dart`:** primera tarjeta de cuenta vinculada conectada en vivo a `syncStateListenable`, con dos botones circulares parejos (`34×34`: `btn_sincronizar_cuenta` y `btn_ajustes_cuenta`) y caja compacta de error con CTA (`Reintentar` / `Google Play`).
- **`lib/ui/screens/dashboard_screen.dart`:** AppBar intacto; banner `dashboard_sync_error_banner` solo ante fallo persistente o `permission-denied`; `RefreshIndicator` muestra `SnackBar` si falla la sincronización manual.
- **`landing/src/pages/panel.astro`:** botón `Actualizar` (`btn-refresh-dashboard`) junto a `Hoy` y auto-refresco al volver a la pestaña (`visibilitychange`, throttle 30 s) con cola segura `pendingDashboardReload` ante cambios rápidos de mes.

## 3. Guía de Pruebas en Dispositivo (Checklist)
1. **Verificar versión instalada en el teléfono:** abrir **Más → Sobre Rinde Más → "Ver en Google Play"** (`lib/ui/screens/more_screen.dart:1322-1323`). Confirmar que corresponde al build generado por este commit.
2. **Tarjeta de cuenta en `Más` (`lib/ui/screens/more_screen.dart:695-915`):**
   - Con sesión de Google activa, verificar los dos botones circulares parejos (`Sincronizar ahora` y `Ajustes de cuenta`).
   - Tocar el botón circular de sincronizar (`btn_sincronizar_cuenta`): gira el spinner y al terminar aparece el `SnackBar` amarillo con texto negro *"Respaldo al día con la nube"* y la hora de sincronización en la tarjeta.
3. **App → Panel Web (crear, editar y borrar gasto):**
   - Crear un gasto nuevo en la app y editar un gasto existente (`lib/ui/screens/review_expense_screen.dart:1688-1708`).
   - Volver a la pestaña del panel web (`https://rindemas.cesarluis.com/panel`) o pulsar el botón **Actualizar** (`landing/src/pages/panel.astro:170-179`): el cambio debe reflejarse sin recargar con F5.
4. **Presupuestos por categoría:**
   - Eliminar una categoría del presupuesto en la app, sincronizar y pulsar **Actualizar** en el panel web: la categoría eliminada debe desaparecer también en la web.
5. **Resiliencia ante fallo en Inicio (`lib/ui/screens/dashboard_screen.dart:339-465`):**
   - Con el modo avión encendido, hacer pull-to-refresh en Inicio: aparece `SnackBar` *"Sin conexión a internet."* sin mostrar trazas técnicas.
