# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Lanzamiento / Preparación Google Play).
- **Últimos hitos:** 
  1. **Integración Web + Sección de Donaciones:** Opciones de "Visitar sitio web" (`rindemas.cesarluis.com`) y "Apoyar el proyecto ☕" agregadas a la pestaña **Más**. Nueva sección de donaciones (`#donar`) agregada a la landing page (PayPal, Binance Pay USDT ID `254881729`, Pago Móvil Banesco).
  2. **Actualizaciones Inteligentes (Semánticas + Críticas):** Soporte para detección por versión semántica (`isVersionHigher`) y bandera `isMajor` / `is_major_release: true` con aviso directo al iniciar la app.
  3. **Gateway Cloudflare Workers + BanaHosting:** Operación serverless 100% gratuita y distribución de APK por FTP.

## Decisiones Técnicas y de Negocio Recientes
- **Cumplimiento Político de Google Play:** Las donaciones no se cobran dentro de la app (para evitar suspensión por bypass de Google Billing). El botón de la app redirige a la web oficial (`rindemas.cesarluis.com/#donar`), cumpliendo 100% las normativas de Play Store.
- **Estrategia de Actualizaciones:** Actualizaciones menores en "Más -> Buscar" y mayores obligatorias al iniciar (`isMajor`).
- **Gateway Cloudflare Worker:** Proxy seguro con validación JWT de Firebase Auth.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- En cPanel multidominio, el Document Root es `/home/user/dominio.com/`, no siempre `public_html/`.

## Próximo Paso Inmediato
- Confirmar pipeline en CI y proceder con el paquete de Google Play Console (AAB + 20 testers).
