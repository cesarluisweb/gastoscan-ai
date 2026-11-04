# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Acceso a Producción Google Play:** Solicitud enviada el 04/11/2026 (07:42 AM). En revisión por Google (7 días o menos). 14 días cumplidos ininterrumpidos con 12 evaluadores activos. Registro completo en `DOC_CUESTIONARIO_PRODUCCION.md`.
- **P0 Detener commits automáticos CI:** `Completada ✅`. Integrado en `main` con CI verde (Build 641, commit `b5c4603`, run 41713145770). Cero commits automáticos generados en `origin/main`.
- **Depuración de Roadmap:** `Completada ✅`. Archivados en `ROADMAP_HISTORICO.md` todos los hitos completados y los 10 ítems validados por César. `ROADMAP.md` quedó limpio con las 5 tareas en validación activa y las iniciativas pendientes.
- **UI-15 (Tanque que se Vacía en Medidores de Presupuesto):** `Pendiente de validación 🧪`. CI verde (Android build 641, commit `b5c4603`). Despliegue web verificado en producción HTTP 200 (`rindemas.cesarluis.com/panel`). Documentación en `DOC_BARRA_TANQUE_PRESUPUESTO.md`.
- **UX-14 (Estado Vacío Inteligente y Ciclo de Vida Temporal):** `Pendiente de validación 🧪`. CI verde (Android build 645, commit `d86e777`, run 41849026245). Botón directo al último mes con compras en estados vacíos, botón de regreso a hoy y reseteo automático al reanudar tras inactividad. Pruebas en `smart_empty_state_and_lifecycle_test.dart`.
- **Triple Escudo Fechas Factura & DatePicker:** `Pendiente de validación 🧪`. CI verde (Android build 640, commit `b40ce3d`, 587 pruebas pasando). Gateway desplegado en producción en Cloudflare Workers (`rindemas-gateway`).
- **Artefacto para pruebas en teléfono:** Descargar `rindemas-dev-apk` desde el run de CI 41849026245 (*Rinde Más Dev*).

## Decisiones Técnicas y de Negocio Recientes
- Fechas OCR y DatePicker: Triple escudo para fechas `DD/MM/YYYY` (Worker prompt + Gateway sanitizador + `GeminiExtractionResult.parseExtractionDate`).
- DatePicker: Día actual con número negro (`Colors.black`) y relleno amarillo suave (`AppColors.primaryLight` inactivo / `primary` activo).
- Tanque de presupuesto: `isCaution` depende exclusivamente del nivel físico (<=15% del límite), desacoplando `enRiesgo`.
- ReviewExpenseScreen: `_userTouchedCurrency` evita sobrescribir preferencia cuando el usuario interactúa manualmente.
- `_buildLiquidacionPill` y selector de divisas no mutan estado si la opción pulsada ya está activa.
- Coexistencia de revisión en teléfono: `com.cesarluis.rindemas.dev` (*Rinde Más Dev*), preservando app oficial.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido hacer commit o push sin autorización expresa de César.
