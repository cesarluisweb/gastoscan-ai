# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Validación y aprobación final en dispositivo físico por César de 10 tareas críticas y de interfaz: `AI-07`, `REL-01`, `UI-03`, `UX-08`, `UX-10`, `SYNC-01`, `UX-12`, `FIN-09`, `FIN-11` y `FIN-12`, graduadas oficialmente a `Completada ✅`.
- **Estado de CI:** Build 521 confirmado en verde (`conclusion: success`, 316 tests aprobados, commit `e6ced04`).
- **Estado General:** Bloques UX y financiero al día sin tareas pendientes de validación.

## Decisiones Técnicas y de Negocio Recientes
- Extracción de `CurrencyLensDropdown` a componente modular compartido (`lib/ui/widgets/currency_lens_dropdown.dart`) para reutilización directa en Inicio y Análisis.
- Parámetro `separateCards: true` en `CategoryChart` para desacoplar visualmente la Dona de los Presupuestos por Categoría manteniendo 100% de compatibilidad con Inicio y tests previos.
- Clasificación de Radiografía de Compras normalizada con umbrales equivalentes a USD (<$5, $5-$25, >$25) y formateada en la moneda activa del selector.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Coordinación de Closed Testing (Fase 5) o avance en tareas planificadas de UI (`UI-02` contraste en Más, `UI-04` botón de presupuestos, `UI-06` orden canónico de monedas).
