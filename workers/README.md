# Gateway Serverless de IA (Cloudflare Workers) - Rinde Más

Worker de Cloudflare (`rindemas-gateway`) que actúa como proxy seguro y resiliente entre la aplicación Rinde Más y la API de Google Gemini.

## Características de Seguridad
- **Validación Criptográfica de Tokens:** Valida el Firebase ID Token contra las claves públicas JWKS de Google usando Web Crypto nativo (`crypto.subtle`).
- **Control de Tasa (Rate Limiting):** Límite estricto de 30 solicitudes/minuto por usuario (`uid`) para la cuota del sistema y 60 solicitudes/minuto para BYOK.
- **Manejo Seguro de Secretos:** La clave `GEMINI_API_KEY` reside en los secretos cifrados de Cloudflare (`wrangler secret put`).
- **Exclusividad Flash-Lite:** Fallback automático entre `gemini-3.1-flash-lite` y `gemini-3.5-flash-lite` ante errores 429/503.
- **Sanitización de Credenciales:** Claves sanitizadas con `.trim().replace(/[\r\n\t ]+/g, "")` antes de enviarse a Google.

## Estructura de Archivos
- `src/index.js`: Código fuente principal del gateway (`/analyze-receipt`, `/chat-analyst`, `/tasas`, `/health` y `scheduled`).
- `src/daily_rates_push.js`: Envío programado (lunes a viernes 8:30 AM VET / `30 12 * * 1-5`) de la tasa del día al topic FCM `tasa_diaria` con deduplicación en D1.
- `wrangler.toml`: Configuración de despliegue, cron triggers, observabilidad y variables de entorno.
- `package.json`: Definición del proyecto y scripts de despliegue/pruebas (`npm test`).

## Despliegue a Producción

```bash
cd workers
npx wrangler deploy
```

O especificando la configuración desde la raíz del proyecto:
```bash
npx wrangler deploy --config workers/wrangler.toml
```

Para configurar las claves secretas en Cloudflare:
```bash
npx wrangler secret put GEMINI_API_KEY --config workers/wrangler.toml
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON --config workers/wrangler.toml
```
