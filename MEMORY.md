# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Implementación de `FIN-13` (Límites de fechas y blindaje de tasas históricas BCV/USDT con enfoque pragmático local-first, corrección de solapamiento `d30d31` en `DailyEvolutionCard` y espaciado de proyección en `AnalysisScreen`).
- **Estado de CI:** Build 524 confirmado en verde (`conclusion: success`, commit `eba23be`).
- **Estado General:** `FIN-13` en `Pendiente de validación 🧪` para pruebas en dispositivo por César.

## Decisiones Técnicas y de Negocio Recientes
- Fecha mínima para registro de gastos acotada al inicio de registros continuos de DolarAPI (`2023-01-03`) y máxima a fecha actual.
- Enfoque pragmático local-first para tasas históricas: sin red se sugiere tasa referencial en caché con aviso visual sin bloquear en cero; USDT previo a feb 2026 sugiere BCV señalando `Referencia BCV (Ajusta la tasa P2P)`.
- Supresión de `d30` en meses de 31 días en `DailyEvolutionCard` para erradicar el solapamiento visual `d30d31`.
- Envoltura `Expanded` en etiqueta de proyección mensual en `AnalysisScreen` para evitar desbordes contra el margen derecho.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Coordinación de Closed Testing (Fase 5) o avance en tareas planificadas de UI (`UI-02` contraste en Más, `UI-04` botón de presupuestos, `UI-06` orden canónico de monedas).
