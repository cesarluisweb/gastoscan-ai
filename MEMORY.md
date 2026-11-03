# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (Trabajo de UI-15 en proceso de validación CI).
- **Fase A & Fase 5:** Integradas en `main`; Closed Testing activo en Google Play.
- **UI-15 (Tanque que se Vacía en Medidores de Presupuesto):** `Implementada 🔧`
  - Invertidas barras de presupuesto en `SummaryCard`, `AnalysisScreen`, `CategoryChart` y `panel.astro` (escala `100% -> 0%`).
  - Divisor vertical de ahorro a la izquierda (`meta / presupuesto`).
  - Semáforo físico de batería (`#16A34A` verde -> `#D97706` ámbar al quedar <=15% -> `#DC2626` rojo).
  - Al invadir el ahorro, reserva teñida en rojo suave (`#FEE2E2`) con saldo vivo en rojo fuerte. Al agotarse, carril completo rojo suave.
  - En `CategoryChart`, barras conservan color propio en estado normal y microcopy dual `X% consumido · Queda $Y` en `FittedBox`.
  - Tokens semánticos en `AppColors` y `Semantics` de accesibilidad. Build de Astro verificado limpio en local.
  - Documentación en `DOC_BARRA_TANQUE_PRESUPUESTO.md`.
- **Sprint Teléfono (ReviewExpenseScreen & Selectores):** `Pendiente de validación 🧪` (CI build 633, commit `00c8f1c`).
- **Artefacto para pruebas:** Descargar `rindemas-dev-apk` desde el run de CI 41661857244 (*Rinde Más Dev*).

## Decisiones Técnicas y de Negocio Recientes
- Tanque de presupuesto: `isCaution` depende exclusivamente del nivel físico (<=15% del límite), desacoplando `enRiesgo`.
- ReviewExpenseScreen: `_userTouchedCurrency` evita sobrescribir preferencia cuando el usuario interactúa manualmente.
- `_buildLiquidacionPill` y selector de divisas no mutan estado si la opción pulsada ya está activa.
- Coexistencia de revisión en teléfono: `com.cesarluis.rindemas.dev` (*Rinde Más Dev*), preservando app oficial.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido hacer commit o push sin autorización expresa de César.
