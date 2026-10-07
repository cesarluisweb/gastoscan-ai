# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Finalizadas Fases 1 a 6 (Estabilidad IA, Comprobantes persistentes, Reportes Privacidad, Mejoras UI Tasas).
- **Últimos hitos:** 
  1. **Chips Dinámicos por Fecha:** En `ReviewExpenseScreen`, los chips (USD, EUR, USDT) cargan y aplican las tasas históricas de la fecha del gasto (`_selectedFecha`), y el campo muestra la etiqueta limpia "Tasa de Cambio".
  2. **Resiliencia de IA (Fase 1 y 2):** Errores de Gemini (429, 503, red) en `ScanQueueProvider` y `GeminiService` reescritos sin jerga técnica ("El servicio de IA no está disponible en este momento. Tu comprobante está seguro...").
  3. **Cola Recuperable:** Añadido `retryItem` y botón "Reintentar" (refresh) en `global_scan_queue_banner.dart` para reanudar tickets estancados en "error".
  4. **Comprobantes Manuales (Fase 3 y 4):** Refactorizado `ReviewExpenseScreen` con `image_picker`. "Adjuntar comprobante" en nuevos gastos y "Cambiar/Eliminar" en existentes. MVP con `rutaFotoLocal`.
  5. **Auditoría y Privacidad (Fase 5, 6 y 7):** Artefactos técnicos creados sobre viabilidad de cuota individual de Gemini y Backup de Privacidad (.zip local exportable).
  6. **Gate Estricto de CI:** `flutter analyze --fatal-warnings` y suite completa de pruebas unitarias/widgets activas en verde.
  7. **Voz Editable y Micrófono Inteligente:** `VoiceExpenseSheet` editable con teclado y botón limpiar; `ChatScreen` detiene el micrófono automáticamente al interactuar con el teclado, scroll o salir; botón "Ver / Editar gasto" en chat.

## Decisiones Técnicas y de Negocio Recientes
- **Mocks con `noSuchMethod` para Plugins:** En tests, clases de dependencias externas como `SpeechToText` se simulan extendiendo `Fake` y delegando llamadas dinámicas en `noSuchMethod` para evitar roturas de compilación por parámetros nombrados entre versiones de CI.
- **Transparencia en Errores de Gemini:** El gateway ya no agrupa 404, 503 y 429 en un solo mensaje genérico. Cada estado reporta su causa real sin enmascarar modelos muertos como límites de cuota.
- **Compresión Eficiente para Visión:** 1200x1600 con calidad 82 preserva al 100% la nitidez OCR y reduce el payload un 80%, evitando timeouts y exceso de TPM.
- **Presupuestos sin Escrituras Fantasmas:** En meses vacíos, `GastoProvider` adopta en memoria el presupuesto del mes previo sin escribir en SQLite ni alterar timestamps de sincronización.
- **Rutas Calientes O(1) e Índices:** `softDeleteGasto` no recarga toda la BD; consultas de gastos e ítems usan hidratación en lotes con `WHERE gasto_id IN (...)` e índices dedicados (DB v15).
- **Mutadores con Estado y Feedback Real:** `guardarTodoElPresupuesto`, `setPresupuestoGeneral`, etc., retornan `Future<bool>`, limpian `_errorMessage` al iniciar y mapean excepciones a mensajes amigables para el usuario.
- **Protección contra Compras de $0.00:** Dictado por voz lanza excepción explícita si no se detecta monto, impidiendo registros fantasmas.
- **Tasas sin invenciones (Punto 7):** `getAllTodayRates({client})` inyectable para tests; `esReferencia=true` sin tocar timestamp cuando no hay dato en vivo; `SettingsProvider.tasasSonReferencia` gobierna el badge.
- **Parser VE centralizado (Punto 1):** `tryParseAmount(raw, {isPrice})` en `core/utils/amount_parser.dart`; formularios usan `isPrice:false`.
- **Distribución fail-closed:** paso FTP sin `continue-on-error` + verificación HEAD post-subida; paso de artefactos eliminado.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- No replicar manualmente firmas complejas de paquetes de terceros en fakes de test; delegar en `noSuchMethod`.

## Próximo Paso Inmediato
- Probar en dispositivo y verificar CI de GitHub Actions.
