# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Acceso a Producción Google Play:** Solicitud enviada el 04/11/2026 (07:42 AM). En revisión por Google (7 días o menos). 14 días cumplidos ininterrumpidos con 12 evaluadores activos. Registro completo en `DOC_CUESTIONARIO_PRODUCCION.md`.
- **P0 Detener commits automáticos CI:** `Completada ✅`. Integrado en `main` con CI verde (Build 641, commit `b5c4603`, run 41713145770). Cero commits automáticos generados en `origin/main`.
- **Depuración de Roadmap:** `Completada ✅`. Archivados en `ROADMAP_HISTORICO.md` todos los hitos completados (incluidos UI-15, AI-09 y FIN-09 validados por César). `ROADMAP.md` limpio y sincronizado con el tablero de Deuda Técnica (P0-P3) en Fase 7 Bloque A.
- **UX-14 (Estado Vacío Inteligente y Ciclo de Vida Temporal):** `Implementada 🔧` (en ajuste de botones). CI verde previo (Build 645). Deduplicación de botón único y estilo outline en curso.
- **Artefacto para pruebas en teléfono:** Descargar `rindemas-dev-apk` desde el run de CI 41881942689 (*Rinde Más Dev*).

## Decisiones Técnicas y de Negocio Recientes
- Fechas OCR y DatePicker: Triple escudo para fechas `DD/MM/YYYY` (Worker prompt + Gateway sanitizador + `GeminiExtractionResult.parseExtractionDate`).
- DatePicker: Día actual con número negro (`Colors.black`) y relleno amarillo suave (`AppColors.primaryLight` inactivo / `primary` activo).
- Tanque de presupuesto: `isCaution` depende exclusivamente del nivel físico (<=15% del límite), desacoplando `enRiesgo`.
- Tanque V2: `foregroundDecoration` en carril (evita desalinear muesca); banda cubre `min(fillEnd, markerPos)`; "Ahorro en riesgo" es exclusivo de proyección, invasión usa "Ahorro comprometido".
- ReviewExpenseScreen: `_userTouchedCurrency` evita sobrescribir preferencia cuando el usuario interactúa manualmente.
- `_buildLiquidacionPill` y selector de divisas no mutan estado si la opción pulsada ya está activa.
- Coexistencia de revisión en teléfono: `com.cesarluis.rindemas.dev` (*Rinde Más Dev*), preservando app oficial.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido hacer commit o push sin autorización expresa de César.
