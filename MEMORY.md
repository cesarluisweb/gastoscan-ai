# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 7 (Arquitectura de Producción / Gateway Serverless) y Fase 5 (Lanzamiento).
- **Últimos hitos:** Migración del backend proxy de Gemini desde Firebase Cloud Functions a **Cloudflare Workers**. Permite regresar Firebase al plan Spark (100% gratuito sin tarjetas bancarias ni facturación en Google Cloud). Gateway protegido con validación de Firebase ID Token (JWT con Web Crypto y JWKS de Google), Rate Limiting por usuario y secretos en Wrangler.

## Decisiones Técnicas y de Negocio Recientes
- **Gateway Cloudflare Worker:** Reemplaza Cloud Functions para Gemini. Endpoint `/analyze-receipt` y `/chat-analyst` con validación JWT contra `https://securetoken.google.com/gastoscan-ai`.
- **Firebase en Plan Spark:** Firestore, Auth y Hosting se mantienen en Firebase en capa gratuita; Cloud Functions eliminadas para no requerir tarjeta en Google Cloud.
- **Banner Integrado:** En línea con `AnimatedSize` bajo el AppBar en las 4 pantallas principales.
- **Deep-linking Robusto:** `NotificationService` con soporte de apertura en frío hacia `ReviewExpenseScreen`.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Prohibido caer en bucles de `view_file` sobre el mismo bloque.

## Próximo Paso Inmediato
- Desplegar el worker en Cloudflare (`wrangler deploy` y `wrangler secret put GEMINI_API_KEY`).
- Cambiar el plan de Firebase a Spark en la consola y cerrar la cuenta de facturación en Google Cloud.
