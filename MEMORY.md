# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Semántica de color separada y escala física en barra de `SummaryCard` (UX-08): verde exclusivo para `Disponible para gastar`, barra de progreso en pizarra oscuro (`#1E293B`) sobre fondo gris claro (`#F1F5F9`) en estado normal, ámbar (`#F59E0B`) en precaución (>85% o meta en riesgo) y rojo (`#DC2626`) al exceder límite cruzando el marcador vertical de ahorro.
- **Estado de CI:** CI build 512 en verde (`success` en commit `d4fc9dc`), pruebas aprobadas, APK build 516 listo. `UX-08` en `Pendiente de validación 🧪`.

## Decisiones Técnicas y de Negocio Recientes
- La barra de progreso de `SummaryCard` escala sobre el presupuesto total (`budgetInLens`) para que el marcador vertical en `limite / presupuesto` separe físicamente el gasto de la meta de ahorro, y la barra lo cruce al excederse.
- El color verde queda reservado estrictamente para el saldo positivo disponible, eliminando ambigüedad visual con el monto gastado.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Validación en dispositivo físico por César para graduar `UX-08` a `Completada ✅`.
- Abordar `UI-06`: unificar orden canónico (USD -> VES -> USDT -> EUR) en vistas secundarias (`analysis_screen.dart`, `more_screen.dart`, `panel.astro`).
