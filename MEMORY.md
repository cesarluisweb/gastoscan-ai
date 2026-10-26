# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Auditoría Argon (Lotes 1, 2, 3 y 4):** Todos los 4 lotes cerrados y marcados como `Completada ✅` tras aprobación explícita de César.
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **Fase 6.2 (Roadmap):** Próximas iniciativas funcionales y de arquitectura listas para priorizar.

## Decisiones Técnicas y de Negocio Recientes
- Lote 3 completado: serialización pura Firestore, reemplazo atómico SQLite v18, política Borrado Gana, bloqueo durable por UID, retención de fotos físicas.
- Lote 4 completado: virtualización `ListView.builder` en historial, escáner documental ML Kit en `+`, blindaje `RenderFlex` 360dp con `FittedBox` y eliminación de `cloudflare_worker/`.
- Aprendizajes graduados en `AGENTS.md` y `.agents/rules/flutter-desarrollo.md` vía `/learn`: lectura UTF-8 en PowerShell 5.1 y normas de maquetación 360dp.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.

## Próximo Paso Inmediato
- Seleccionar y abordar la siguiente tarea de la Fase 6.2 del Roadmap (`UI-06`, `FIN-15`, `BACKUP-01`, `UX-13` o `AI-06`).
