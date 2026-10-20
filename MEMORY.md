# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Corrección de colapso de pantalla en blanco en `ReviewExpenseScreen` (`bottomNavigationBar` con `Center` vertical sin cota sustituido por `Align(heightFactor: 1.0)`) y desbordamiento de `RenderFlex` en filas de tasas corregido con `Wrap`.
- **Estado de CI:** Build 528 confirmado en verde (`conclusion: success`, commit `515c45e`).
- **Estado General:** Listo para prueba manual en dispositivo por César.

## Decisiones Técnicas y de Negocio Recientes
- En `Scaffold.bottomNavigationBar`, no usar `Center` sin `heightFactor: 1.0` porque `Scaffold` otorga altura suelta y `Center` consume toda la pantalla, colapsando el `body` a altura cero.
- En tarjetas de liquidación de compras en bolívares, usar `Wrap` en vez de `Row` para la leyenda de tasas para evitar desbordamientos horizontales en dispositivos móviles compactos (< 400dp).
- Edge-to-Edge nativo y ancho máximo de 600dp centrado implementados en pantallas principales.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Validación en dispositivo del formulario de registro de gastos y avance en tareas planificadas (`UI-02` contraste en Más, `UI-04` botón de presupuestos, `UI-06` orden canónico de monedas).
