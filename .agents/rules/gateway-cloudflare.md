---
trigger: glob
globs: "{cloudflare_worker/**,workers/**}"
description: "Estándares de seguridad, validación de JWT, observabilidad y cuotas en Cloudflare Workers (rindemas-gateway)."
---

# Gateway Serverless de IA (Cloudflare Workers)

## 1. Arquitectura de Seguridad y Autenticación
- **Validación Criptográfica de Tokens (JWT):** Todo endpoint privado (`/analyze-receipt`, `/chat-analyst`) debe validar la firma del Firebase ID Token usando Web Crypto nativo (`crypto.subtle`) contra las claves públicas JWKS de Google (`https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com`).
- **Control de Tasa y Cuota Diaria (Rate Limiting):** Limitar las peticiones privadas a un máximo de 30 solicitudes por minuto y un tope de seguridad diario invisible de 50 solicitudes/día por `uid` para la clave compartida (con bypass para claves personalizadas BYOK), retornando HTTP 429 con `dailyLimitReached: true`. En rutas públicas frecuentes (`/tasas`), aplicar límite de tasa estricto por IP de origen (máximo 60 peticiones/minuto).
- **Protección contra Cargas Excesivas (Payload Size Caps):** Todo endpoint debe validar de forma defensiva la cabecera `content-length` y limitar el cuerpo leído (`readJsonBodyWithLimit`) antes de parsear JSON (máximo 8 MB en análisis de imágenes/recibos y 512 KB en endpoints de texto/chat). Si se supera el límite, rechazar inmediatamente con HTTP 413.
- **Gestión de Secretos:** La clave `GEMINI_API_KEY` reside exclusivamente en los secretos de Cloudflare Workers (`npx wrangler secret put GEMINI_API_KEY`). Prohibido escribir claves literales en código, repositorios o variables no cifradas.

## 2. Integración con Google Gemini API
- **Exclusividad Flash-Lite:** La cadena de fallback `FALLBACK_MODELS` debe limitarse estrictamente a versiones ligeras explícitas: `gemini-3.1-flash-lite` y `gemini-3.5-flash-lite`. Prohibido incluir modelos pesados (3.8 Flash, Pro) o alias `latest` en la cadena para evitar bloqueos por cuotas mínimas y proteger los costes operativos.
- **Autenticación con Encabezado `x-goog-api-key`:** Las peticiones a `generativelanguage.googleapis.com` (tanto en Cloudflare Workers como en validaciones directas de cliente) deben autenticarse exclusivamente mediante la cabecera HTTP `x-goog-api-key: <KEY>`. Queda prohibido enviar la clave en la URL (`?key=`) o en cabeceras `Authorization: Bearer` (para evitar registro de claves en URLs y el error `401 UNAUTHENTICATED`).
- **Sanitización Estricta de Credenciales:** Toda clave leída de `env` o de cabeceras entrantes (`x-custom-gemini-key`) DEBE sanitizarse con `.trim().replace(/[\r\n\t ]+/g, "")` antes de enviarse a Google para evitar rechazos por saltos de línea invisibles o espacios.

## 3. Observabilidad, Diagnóstico y Despliegue
- **Observabilidad Declarativa en `wrangler.toml`:** `wrangler.toml` DEBE incluir siempre:
  ```toml
  [observability]
  enabled = true
  head_sampling_rate = 1
  ```
  Esto garantiza la captura de métricas, errores y latencias automáticamente en cada despliegue.
- **Blindaje del Endpoint `/health`:** El endpoint `/health` debe ser estrictamente pasivo (retornando solo estado estático y modelos). Prohibido exponer prefijos de claves (`key_prefix`) o permitir parámetros de consulta no autenticados (`?test=...`) que ejecuten llamadas reales a Google consumiendo cuota.
- **Telemetría y Cabeceras de Respuesta:** El Worker debe registrar en telemetría el modo de escaneo (`texto` vs `vision`), tokens y latencia, y exponer las cabeceras HTTP `x-receipt-mode` y `x-receipt-image-kb`.
- **Contexto de Ejecución de Wrangler:** Al desplegar el worker (`npx wrangler deploy`), el comando DEBE ejecutarse con directorio de trabajo en `workers/` (o `cloudflare_worker/`) o especificar explícitamente el flag `--config workers/wrangler.toml`.
