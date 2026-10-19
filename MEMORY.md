# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Rediseño y enriquecimiento de la pantalla de Análisis (UX-12): eliminación de pestañas superiores, selector compacto compartido `CurrencyLensDropdown` en Tarjeta 1, Evolución Diaria con `LineChart`, tarjetas desacopladas (Dona + Presupuestos por Categoría), Radiografía por Moneda de Origen, Radiografía de Compras (hormiga/medias/fuertes) y padding seguro de 100dp.
- **Estado de CI:** Build 520 confirmado en verde (`conclusion: success`, 310 tests aprobados, commit `c4df139`).
- **Estado UX-12:** `Pendiente de validación 🧪` para verificación en dispositivo físico.

## Decisiones Técnicas y de Negocio Recientes
- Extracción de `CurrencyLensDropdown` a componente modular compartido (`lib/ui/widgets/currency_lens_dropdown.dart`) para reutilización directa en Inicio y Análisis.
- Parámetro `separateCards: true` en `CategoryChart` para desacoplar visualmente la Dona de los Presupuestos por Categoría manteniendo 100% de compatibilidad con Inicio y tests previos.
- Clasificación de Radiografía de Compras normalizada con umbrales equivalentes a USD (<$5, $5-$25, >$25) y formateada en la moneda activa del selector.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Validación en dispositivo físico por César para graduar `SYNC-01` y `UX-12` a `Completada ✅`.
