# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 3 / Auditoría Integral Argon (Lote 4 completado en código, pendiente de validación 🧪) y Fase 5 (Closed Testing activa).
- **Hito de Marketing:** Video #1 publicado en Instagram Reels y TikTok (`@rindemas.app`). Canal de WhatsApp: 15 suscriptores orgánicos.
- **Acción Reciente (Lote 4 Auditoría Argon — UI/UX, Resiliencia y Rendimiento):**
  1. Resiliencia 360dp: `SummaryCard`, `AnalysisScreen`, `CategoryChart`, `PendingExpenseCard`, `ExpenseHistoryScreen` y `MoreScreen` protegidas con `Flexible`, `Expanded` y `FittedBox` ante cifras millonarias en Bs.
  2. Historial de Gastos: Parseo JSON único en `build()` y virtualización completa con `ListView.builder` mediante `_HistoryRowItem`.
  3. Escáner de Facturas: Integrado `DocumentScannerService` (ML Kit con fallback a cámara) en el botón `+` de `MainScreen`.
  4. Evaluación OCR Unificada: `ScanQueueProvider` utiliza `LocalOcrService.evaluateRawText` eliminando regexes duplicadas.
  5. Limpieza de arquitectura: Directorio redundante `cloudflare_worker/` eliminado, preservando `workers/`.
  6. Suite de pruebas: Creado `test/widgets/lote_4_ui_resilience_and_performance_test.dart`.

## Decisiones Técnicas y de Negocio Recientes
- La virtualización en historial preserva separadores de fecha y soporte para pendientes/borradores de escaneo sin jank.
- El escáner documental aprovecha ML Kit de Google para recorte de perspectiva y cae a cámara convencional de forma transparente.
- Directorio serverless oficial único: `workers/`.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Monitorear CI build de GitHub Actions para Lote 4 y validar en dispositivo físico (*Rinde Más Dev*).
