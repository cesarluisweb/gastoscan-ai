# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Implementación de `FIN-13` (Límites de fechas y blindaje de tasas históricas BCV/USDT, eliminación de fallback a tasa de hoy, corrección de solapamiento `d30d31` en `DailyEvolutionCard` y espaciado de proyección en `AnalysisScreen`).
- **Estado de CI:** Pendiente de push y monitoreo de build para `FIN-13`.
- **Estado General:** Bloque de fechas y tasas históricas blindado según fecha más antigua de DolarAPI (03/01/2023).

## Decisiones Técnicas y de Negocio Recientes
- Fecha mínima para registro de gastos e históricos acotada a `2023-01-03` (`AppConstants.fechaMinimaHistoricoTasas`) y máxima a fecha actual.
- Eliminado fallback a tasa de hoy (`getAllTodayRates()`) para fechas históricas: retorna `0.0` y exige ingreso manual en UI si no hay registro oficial.
- Supresión de `d30` en meses de 31 días en `DailyEvolutionCard` para erradicar el solapamiento visual `d30d31`.
- Envoltura `Expanded` en etiqueta de proyección mensual en `AnalysisScreen` para evitar desbordes contra el margen derecho.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Coordinación de Closed Testing (Fase 5) o avance en tareas planificadas de UI (`UI-02` contraste en Más, `UI-04` botón de presupuestos, `UI-06` orden canónico de monedas).
