# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 7 (Arquitectura de Producción / Gateway Serverless) y Fase 5 (Lanzamiento).
- **Últimos hitos:** 
  1. Gateway en **Cloudflare Workers** desplegado y activo (`https://rindemas-gateway.cesarluispuntocom.workers.dev`). Firebase en plan Spark 100% gratuito sin tarjetas ni cobros en Google Cloud.
  2. Distribución automatizada de APK a BanaHosting vía FTP (`/home/grupohie/public_html/rindemas/rindemas.apk`). Redirecciones en Firebase Hosting activas para descargas directas limpias sin 404 ni restricciones de ejecutables.

## Decisiones Técnicas y de Negocio Recientes
- **Gateway Cloudflare Worker:** Proxy seguro con validación JWT de Firebase Auth y rate limiting.
- **Distribución de APK en BanaHosting:** El CI sube `rindemas.apk` (y `app-release.apk`) directamente por FTP.
- **Redirecciones Firebase:** `/rindemas.apk` y `/app-release.apk` redirigen a `https://cesarluis.com/rindemas/rindemas.apk`.
- **Firebase en Spark:** Auth, Firestore y Hosting operan en nivel gratuito sin datos de pago.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- En cPanel, los archivos públicos deben estar siempre dentro de `public_html/`.

## Próximo Paso Inmediato
- Verificación final de descarga en vivo de `rindemas.apk` desde la landing y avance hacia la publicación en Google Play Console (20 testers).
