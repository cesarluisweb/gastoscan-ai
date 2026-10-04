# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 7 (Arquitectura de Producción / Gateway Serverless) y Fase 5 (Lanzamiento).
- **Últimos hitos:** 
  1. Versión `1.0.3` (Build 307) desplegada y verificada en CI. Modal de actualización ahora muestra correctamente `1.0.3`.
  2. Gateway en **Cloudflare Workers** activo (`rindemas-gateway.cesarluispuntocom.workers.dev`). Firebase en Spark 100% gratuito.
  3. Distribución automatizada de APK a BanaHosting vía FTP (`/home/grupohie/cesarluis.com/rindemas/rindemas.apk`). Redirecciones en Firebase Hosting activas para descargas directas sin restricciones.

## Decisiones Técnicas y de Negocio Recientes
- **Incremento de Versión Semántica:** `pubspec.yaml` debe actualizarse manualmente al cambiar de versión (`1.0.2` -> `1.0.3`) para que el modal y `version.json` reflejen el cambio.
- **Gateway Cloudflare Worker:** Proxy seguro con validación JWT de Firebase Auth y rate limiting.
- **Distribución de APK en BanaHosting:** El CI sube `rindemas.apk` directamente por FTP.
- **Redirecciones Firebase:** `/rindemas.apk` y `/app-release.apk` redirigen a `https://cesarluis.com/rindemas/rindemas.apk`.
- **Firebase en Spark:** Auth, Firestore y Hosting operan en nivel gratuito sin datos de pago.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- En cPanel multidominio, el Document Root es `/home/user/dominio.com/`, no siempre `public_html/`.

## Próximo Paso Inmediato
- Comprobar la detección de actualización desde la app instalada y avanzar hacia la fase de testers en Google Play Console.
