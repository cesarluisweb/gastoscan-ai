# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Rediseño compacto V2 de `SummaryCard` (UX-08): Gasto y Límite unificados en una sola línea (`205,31 de $ 550,00`), selector Binance a la derecha, Disponible con horizonte temporal (`Disponible para gastar en 13 días`), barra lineal limpia con marca sutil `┃` de ahorro, y pie interactivo de una sola fila con ícono de alcancía y lápiz de edición.
- **Estado de CI:** CI build 509 en verde (`success` en commit `39221e8`), APK build 513 desplegado a BanaHosting y panel web publicado. `UX-08` en `Pendiente de validación 🧪`.

## Decisiones Técnicas y de Negocio Recientes
- La línea `205,31 de $ 550,00` va envuelta en `FittedBox` con alineación izquierda para asegurar respuesta responsiva perfecta con cifras millonarias en Bolívares.
- Se ampliaron los reintentos de verificación de APK en `build_apk.yml` a 10 intentos (150s) para absorber la latencia de flush en almacenamiento compartido de BanaHosting.
- En `SummaryCard`, si no hay meta se muestra `+ Definir meta de ahorro / inversión` con el lápiz de edición, y sin presupuesto se muestra el botón a todo el ancho.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Validación en dispositivo físico por César para graduar `UX-08` a `Completada ✅`.
- Abordar `UI-06`: unificar orden canónico (USD -> VES -> USDT -> EUR) en vistas secundarias (`analysis_screen.dart`, `more_screen.dart`, `panel.astro`).
