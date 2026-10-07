# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Finalizadas Fases 1 a 6 (Estabilidad IA, Comprobantes persistentes, Reportes Privacidad, Mejoras UI Tasas).
- **Últimos hitos:** 
  1. **Gateway y Functions Gemini con Flash-Lite Predeterminado:** Jerarquía estandarizada con prioridad a `gemini-flash-lite-latest` y `gemini-3.5-flash-lite`, y Flash estándar como fallback. Modelos de frontera/pro descartados por cuotas bajas (2-5 RPM) y alta latencia. Verificado en producción con endpoint `/health` (200 OK).
  2. **API Key Propia (BYOK Gemini) con Sincronización en Nube:** Soporte en Cloudflare Worker con cabecera `x-custom-gemini-key`, rate limit ampliado (60 rpm) y aislamiento de errores. En Flutter, validación en vivo contra Google AI Studio, almacenamiento seguro en Keystore (`FlutterSecureStorage`), sincronización bidireccional automática con Firestore bajo la cuenta de Google vinculada (`users/{uid}/presupuestos/user_settings`), enlace de apertura directa en navegador y tarjeta interactiva en "Más" debajo de Almacenamiento y Fotos (`DOC_BYOK_GEMINI.md`).
  3. **Chips Dinámicos por Fecha:** En `ReviewExpenseScreen`, los chips (USD, EUR, USDT) cargan y aplican las tasas históricas de la fecha del gasto (`_selectedFecha`), y el campo muestra la etiqueta limpia "Tasa de Cambio".
  4. **Resiliencia de IA (Fase 1 y 2):** Errores de Gemini (429, 503, red) en `ScanQueueProvider` y `GeminiService` reescritos sin jerga técnica ("El servicio de IA no está disponible en este momento. Tu comprobante está seguro...").
  5. **Cola Recuperable:** Añadido `retryItem` y botón "Reintentar" (refresh) en `global_scan_queue_banner.dart` para reanudar tickets estancados en "error".
  6. **Comprobantes Manuales (Fase 3 y 4):** Refactorizado `ReviewExpenseScreen` con `image_picker`. "Adjuntar comprobante" en nuevos gastos y "Cambiar/Eliminar" en existentes. MVP con `rutaFotoLocal`.
  7. **Auditoría y Privacidad (Fase 5, 6 y 7):** Artefactos técnicos creados sobre viabilidad de cuota individual de Gemini y Backup de Privacidad (.zip local exportable).
  8. **Gate Estricto de CI:** `flutter analyze --fatal-warnings` y suite completa de pruebas unitarias/widgets activas en verde.

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
- **Cache-Buster en APKs OTA:** BanaHosting está bajo Cloudflare (`max-age=14400`). Toda URL de descarga (`apkUrl`) y verificación de APK DEBE llevar `?b=$BUILD_NUM` para evitar que usuarios descarguen versiones obsoletas cacheadas.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- No replicar manualmente firmas complejas de paquetes de terceros en fakes de test; delegar en `noSuchMethod`.

## Próximo Paso Inmediato
- Probar en dispositivo la actualización limpia con build 351 y verificar que el bucle desapareció.
