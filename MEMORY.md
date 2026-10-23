# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y preparación de lanzamiento.
- **CI Móvil Reciente:** Build 542 en verde (`CI 39980220022 | success | 83ab331`). Elevación y respiro seguro completados en `VoiceExpenseSheet`, `BudgetBottomSheet`, `AuthModalSheet` y `ReviewExpenseScreen` (Edge-to-Edge). Artefactos `rindemas-dev-apk` y `app-release-aab` generados con éxito.
- **Acción Reciente (Lote 1 Argon):** Ejecutado Lote 1 de seguridad crítica:
  1. Sanitización XSS (`escapeHtml`) en `landing/src/pages/panel.astro` (categorías, facturas, notas, ítems y modales) y validación de `metaAhorro > general`.
  2. Eliminada sincronización en texto plano de `gemini_api_key` hacia/desde Firestore (`presupuestos/user_settings`) en `SyncService` y `SettingsProvider` (reside solo en `FlutterSecureStorage`).
  3. Envío de clave Gemini vía cabecera `x-goog-api-key` (sin `?key=` en URL) en `GeminiService.validateGeminiApiKey` y en `workers/src/index.js`.
  4. Sanitización contra CSV Injection (`=`, `+`, `-`, `@`) en `ExportService.sanitizeCsvCell`.
  5. Límite de tamaño de cuerpo HTTP (`413 Payload Too Large`) y rate limit por IP en `/tasas` dentro de `workers/src/index.js`.
- **Lote 2 Argon:** Completado previamente (`f70e1e6`, CI verde).

## Decisiones Técnicas y de Negocio Recientes
- `deploy_web.yml` descarga el `version.json` vivo de `https://rindemas.cesarluis.com/version.json` antes de compilar Astro.
- En `_effectiveBcvRate`, la validación de tasa debe ser `> 0` y no `> 50.0` (tasas 2023 entre 17 y 36 Bs/USD).
- La clave BYOK (`gemini_api_key`) nunca debe abandonar el dispositivo hacia Firestore.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Confirmar CI en verde para Lote 1 (`build_apk.yml` y `deploy_web.yml`) y continuar con Lote 3 (`SyncService`, SQLite `N+1` e integridad offline) y Lote 4 (UI/UX).
