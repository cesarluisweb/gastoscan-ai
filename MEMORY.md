# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Corrección de escala de decimales en OCR y registro de gastos (`AI-07`): corrección de inversión en `GeminiExtractionResult`, soporte de miles con puntos múltiples en `tryParseAmount`, suma exacta de centavos en `_recalcularTotal` y refuerzo de regla decimal en prompts de Cloudflare Worker. Documentado en `DOC_CORRECCION_DECIMALES_OCR.md`.
- **Estado de CI:** Build 521 confirmado en verde (`conclusion: success`, 316 tests aprobados, commit `e6ced04`).
- **Estado AI-07 / UX-12:** `Pendiente de validación 🧪` para verificación en dispositivo físico.

## Decisiones Técnicas y de Negocio Recientes
- Extracción de `CurrencyLensDropdown` a componente modular compartido (`lib/ui/widgets/currency_lens_dropdown.dart`) para reutilización directa en Inicio y Análisis.
- Parámetro `separateCards: true` en `CategoryChart` para desacoplar visualmente la Dona de los Presupuestos por Categoría manteniendo 100% de compatibilidad con Inicio y tests previos.
- Clasificación de Radiografía de Compras normalizada con umbrales equivalentes a USD (<$5, $5-$25, >$25) y formateada en la moneda activa del selector.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Validación en dispositivo físico por César para graduar `AI-07`, `SYNC-01` y `UX-12` a `Completada ✅`.
