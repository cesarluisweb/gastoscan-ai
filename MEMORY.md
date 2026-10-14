# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Múltiples registros de gastos independientes por voz y en chat con revisión continua completados.
- **Últimos hitos:** 
  1. **Gateway Cloudflare Actualizado:** Prompt de `handleChatAnalyst` y esquema de tool `registrar_gasto` ampliados con array `gastos` para compras en comercios distintos. Desplegado a producción en Cloudflare Workers (`fbf1636a`).
  2. **Servicio Gemini Multigasto:** `parseVoiceExpense` retorna `Future<List<GeminiExtractionResult>>` parseando compras individuales o gasto único retrocompatible con normalización de moneda.
  3. **Encolamiento en ScanQueueProvider:** Nuevo método `enqueueReadyExtractionResults` para persistir compras múltiples en SQLite como `ready` (`image_path: ''`).
  4. **Flujo de Voz Adaptativo en VoiceExpenseSheet:**
     - 1 gasto: abre directo `ReviewExpenseScreen(queueItemId: null)`.
     - 2+ gastos: encola en `ScanQueueProvider` y abre el primer gasto con `queueItemId: id1`.
  5. **Revisión Continua en ReviewExpenseScreen:** Botones "Guardar y revisar siguiente (N más)" y "Guardar y salir al inicio", con título adaptativo "Revisar Gasto (N en cola)" cuando no hay imagen.
  6. **Soporte de Múltiples Gastos en Chat:** `chat_screen.dart` registra cada compra del array `gastos` respetando la moneda de cada una y genera tarjetas con botón de edición individual.
  7. **Suite de Tests y CI en Verde:** Tests unitarios y de widgets actualizados en `voice_expense_sheet_test.dart`, `scan_queue_provider_test.dart` y `chat_screen_test.dart`. Build y release verificados en GitHub Actions (run `38495516616`, conclusión `success`).

## Decisiones Técnicas y de Negocio Recientes
- **Flujo Diferenciado de Dictado:** Si el dictado contiene 1 compra, no se inserta en `scan_queue` (flujo rápido de 1 toque). Si contiene 2+ compras, se encola en `ready` para permitir revisión continua secuencial y persistencia segura en Dashboard si el usuario sale antes.
- **Distinción Semántica en IA:** Varios productos en un mismo comercio van en `items` de un solo gasto; compras en comercios distintos se desglosan en el array `gastos`.
- **Respeto de Moneda por Compra:** En chat y voz, cada gasto respeta su propia moneda extraída (`VES`, `USD`, etc.) formateándose individualmente.

## Errores y Fricciones a Evitar
- `GastoModel` usa `totalOriginalDisplay` para el valor decimal (`totalOriginal / 100.0`), no `totalOriginalDouble`.
- No usar `>` en PowerShell ni `&&` en PowerShell 5.1.
- Contraste estricto en UI (`DESIGN.md`): Texto sobre amarillo SIEMPRE negro; texto sobre blanco SIEMPRE negro o gris, NUNCA amarillo.

## Próximo Paso Inmediato
- Notificar a César con la guía paso a paso para pruebas de dictado múltiple por voz y en chat.
