# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase A & Fase 5:** Integradas en `main`; Closed Testing activo en Google Play.
- **UI-15 (Tanque que se Vacía en Medidores de Presupuesto):** `Implementada 🔧`
  - Invertidas barras de presupuesto en `SummaryCard`, `AnalysisScreen`, `CategoryChart` y `panel.astro` con desgaste de izquierda a derecha.
  - Divisor vertical de ahorro a la derecha (`limiteParaGastar / presupuestoGeneral`).
  - Dinámica: dinero consumido entra por la izquierda como tramo gris/consumido avanzando a la derecha; saldo restante vivo anclado a la derecha en verde/ámbar/rojo.
  - Al invadir el ahorro, el tramo consumido dentro de la reserva se tiñe en rojo suave (`#FEE2E2`) con saldo vivo en rojo fuerte (`#DC2626`). Al agotarse, carril completo rojo suave.
  - En `CategoryChart`, barras conservan color propio en estado normal y microcopy dual `X% consumido · Queda $Y` en `FittedBox`.
  - Tokens semánticos en `AppColors` y `Semantics` de accesibilidad.
  - Documentación en `DOC_BARRA_TANQUE_PRESUPUESTO.md`.
- **Artefacto para pruebas en teléfono:** Descargar `rindemas-dev-apk` desde el run de CI 41683506716 (*Rinde Más Dev*).

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
