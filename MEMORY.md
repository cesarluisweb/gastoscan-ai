# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 3 / Auditoría Integral Argon (Lote 3 completado en código, pendiente de validación 🧪) y Fase 5 (Closed Testing activa).
- **Hito de Marketing:** Video #1 publicado en Instagram Reels y TikTok (`@rindemas.app`). Canal de WhatsApp: 15 suscriptores orgánicos.
- **Acción Reciente (Lote 3 Auditoría Argon — Sincronización y Resiliencia Offline):**
  1. `GastoFirestoreMapper`: serialización sin campos locales efímeros, items limpios y categorías normalizadas.
  2. `reemplazarDatosLocales`: transacción atómica única SQLite v18 con `PresupuestoRemotoModel` y tolerancia FTS5.
  3. Pull-encola (`marcarComoPendiente`) y Push-consume (`synced == 0`).
  4. Política "Borrado Gana" en `sync_conflict_resolver.dart`, eliminando resurrección infinita.
  5. Bloqueo durable de push por UID (`sync_pending_replace_<uid>`), `retryPendingReplace()`, banner ámbar en Dashboard, bloqueo en botón `+` y desbloqueo por fusión (`descartarDatosLocales == false`).
  6. Token monótono `_tasaRequestId` en `ReviewExpenseScreen` y switch opcional `eliminarFotos` en `MoreScreen`.
  7. Documento técnico de tarea crítica: [docs/DOC_SINCRONIZACION_OFFLINE.md](docs/DOC_SINCRONIZACION_OFFLINE.md). Estado: `Pendiente de validación 🧪`.

## Decisiones Técnicas y de Negocio Recientes
- "Borrado Gana": si el remoto tiene `eliminado_en != null`, purga local siempre. Si local está borrado, soft-delete con `set(merge: true)`.
- Las fotos se mantienen 100% locales en la versión gratuita por privacidad y costos. Solo se borran físicamente si el usuario lo marca explícitamente al eliminar la cuenta.
- El bloqueo durable vive en `SharedPreferences` por UID y aborta `syncBidirectional`, `syncToFirestore` y `syncPresupuestosToFirestore`.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Monitorear CI build de GitHub Actions para Lote 3 y validar en dispositivo físico (*Rinde Más Dev*).
