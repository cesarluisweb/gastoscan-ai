# Datos Operativos y Configuración del Gateway de IA (Gemini & Cloudflare)

> **Estado:** Migrado desde `AGENTS.md` original el 2026-10-14. Pendiente de verificación en consolas activas.  
> **Nota de Seguridad:** Este documento NO contiene contraseñas, tokens ni API Keys en texto plano. Las credenciales residen exclusivamente en los gestores de secretos de cada plataforma.

---

## 1. Google AI Studio (Proyecto Gemini)

- **Nombre del Proyecto:** `Rinde Mas`
- **ID de Proyecto Google:** `gen-lang-client-0879336234`
- **Nivel de Facturación:** Nivel 1 (Tier 1 - Pay-as-you-go Prepago).
- **Saldo Operativo Reportado:** $5.00 USD inicial (prepago activo).
- **Límite de Gasto Configurado:** $250 USD mensuales (con umbral de protección de $10 USD / 10 min).

### Cuotas Operativas Confirmadas por Modelo (Tier 1)
| Modelo | RPM (Solicitudes/min) | TPM (Tokens/min) | RPD (Solicitudes/día) |
|---|---|---|---|
| `gemini-3.1-flash-lite` | 4.000 | 4.000.000 | 150.000 |
| `gemini-3.5-flash-lite` | 4.000 | 4.000.000 | 150.000 |
| `Antigravity` (Auxiliar) | 30 | 200.000 | 1.000 |

*Restricción de Negocio:* El gateway solo despacha a modelos explícitos Flash-Lite para evitar cobros imprevistos y proteger el saldo prepago.

---

## 2. Cloudflare Workers (`rindemas-gateway`)

- **Nombre del Worker:** `rindemas-gateway`
- **Compatibilidad Runtime:** `2024-09-23`
- **Archivo Principal:** `cloudflare_worker/src/index.js`
- **Configuración (`wrangler.toml`):**
  - Variable de entorno pública: `FIREBASE_PROJECT_ID = "gastoscan-ai"`
  - Observabilidad: `[observability] enabled = true`, `head_sampling_rate = 1`
- **Ubicación de Secretos (Dónde se configuran):**
  - `GEMINI_API_KEY`: Configurado mediante el comando CLI:
    ```bash
    npx wrangler secret put GEMINI_API_KEY
    ```
    *(Nunca versionar esta clave en archivos git ni variables públicas).*

---

## 3. Firebase Auth y JWKS
- **URL de Certificados Públicos de Google:**
  `https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com`
- **Proyecto Firebase:** `gastoscan-ai`
- **Issuer Esperado:** `https://securetoken.google.com/gastoscan-ai`
