# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Rediseño definitivo V3 de `SummaryCard` (UX-08): Saldo Disponible como héroe único de 32sp en verde, selector Binance a la derecha, contexto horizontal `Gastado: $ X` vs `Límite: $ Y ✏️` sobre la barra de 10dp con marcador vertical gris oscuro (#4B5563) de ahorro, pie interactivo de meta protegida/en riesgo, y pedagogía de ritmo diario transferida a `AiInsightCard`.
- **Estado de CI:** CI build 511 en verde (`success` en commit `39839a3`), 301 tests pasando, APK build 515 listo para desplegar. `UX-08` en `Pendiente de validación 🧪`.

## Decisiones Técnicas y de Negocio Recientes
- La etiqueta `Gastado: ` en `SummaryCard` utiliza `Row` con widgets `Text` (no `RichText`) para garantizar compatibilidad con tests y detectabilidad semántica de Flutter.
- El cálculo y recomendación del ritmo sugerido diario (`$ 26,51/día durante los 13 días restantes...`) se delegó a `AiInsightCard` para descongestionar visualmente `SummaryCard`.
- En `SummaryCard`, sin presupuesto definido se ocultan los niveles 2 y 3, mostrando el botón amarillo full-width `+ Definir presupuesto del mes`.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Validación en dispositivo físico por César para graduar `UX-08` a `Completada ✅`.
- Abordar `UI-06`: unificar orden canónico (USD -> VES -> USDT -> EUR) en vistas secundarias (`analysis_screen.dart`, `more_screen.dart`, `panel.astro`).
