# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Lote 3 (Sincronización Cloud/Offline y SQLite):** CI en verde confirmado (Build 561, commit `4f3823a`). Estado: `Pendiente de validación 🧪` en dispositivo físico (*Rinde Más Dev*).
- **Lote 4 (Auditoría Argon — UI/UX y Resiliencia en Bs):** Siguiente lote técnico a implementar/validar en CI.
- **Fase 5 (Google Play):** Closed Testing activo con evaluadores (período de 14 días).
- **Marketing:** Video #1 publicado en Instagram Reels y TikTok (`@rindemas.app`). Canal de WhatsApp con 15 suscriptores orgánicos.

## Decisiones Técnicas y de Negocio Recientes
- Lote 3 cerrado en CI: serialización pura con `GastoFirestoreMapper`, reemplazo atómico en SQLite v18, política Borrado Gana, bloqueo durable por UID ante fallo de reemplazo (`sync_pending_replace_<uid>`) y normalización canónica en `PresupuestoRemotoModel`.
- Lote 4 por aplicar: virtualización con `ListView.builder` en historial de gastos, protección `RenderFlex` con `FittedBox` en cifras millonarias en Bs. y eliminación del directorio duplicado `cloudflare_worker/`.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true` para acceso a la API de GitHub.

## Próximo Paso Inmediato
- Notificar a César el éxito de CI Build 561 (Lote 3) y acordar inicio de Lote 4 o validación en dispositivo físico.
