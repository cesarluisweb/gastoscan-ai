# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Rediseño integral de `SummaryCard` (UX-08) con arquitectura de 4 bloques (Selector compacto Binance sin símbolo de divisa a la izquierda, Disponible/Te sobraron en verde puro, Barra Allocation con divisor de 2dp e invasión física solo ante exceso real, y Pie en tabla limpia de tres filas).
- **Estado de CI:** CI build 507 en verde (`success` en commit `72e8750`). `UX-08` en `Pendiente de validación 🧪`.

## Decisiones Técnicas y de Negocio Recientes
- En `SummaryCard`, el número principal no lleva símbolo a la izquierda y se alinea con el selector compacto flotante estilo Binance.
- El pie de `SummaryCard` usa `Row` con `Text` y `FittedBox` individual para evitar que cifras largas en Bolívares provoquen desbordamiento horizontal.
- La barra de asignación divide visualmente el gasto de la meta de ahorro con un divisor de `2dp` y ancho de meta acotado entre 12% y 35%.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Validación manual de `SummaryCard` en dispositivo por César para graduar `UX-08` a `Completada ✅`.
- Abordar `UI-06`: unificar orden canónico (USD -> VES -> USDT -> EUR) en vistas secundarias (`analysis_screen.dart`, `more_screen.dart`, `panel.astro`).
