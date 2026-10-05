# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Lanzamiento / Preparación Google Play) y Fase 6.1.
- **Últimos hitos:** 
  1. **Actualizaciones Inteligentes (Semánticas + Críticas):** Soporte para detección por versión semántica (`isVersionHigher`), evitando falsos positivos de builds internos. Soporte para bandera `isMajor` / `is_major_release: true` con aviso directo al iniciar la app.
  2. **Sistema Multimoneda y Selector de Tasas:** Soporte en toda la app para USD, VES, EUR y USDT. Tarjeta de 3 tasas en "Más", chips de tasa en Revisar Gasto, presupuestos dinámicos.
  3. **Gateway Cloudflare Workers + BanaHosting:** Operación serverless 100% gratuita y distribución de APK por FTP.

## Decisiones Técnicas y de Negocio Recientes
- **Estrategia de Actualizaciones:**
  - Actualización Menor: Notificación silenciosa en "Más -> Buscar" cuando hay nueva versión.
  - Actualización Mayor / Crítica (`isMajor: true`): Diálogo modal obligatorio al abrir la app.
  - La app compara versiones semánticas (`remote > current`), ignorando incrementos de compilaciones de CI del mismo release.
- **Gateway Cloudflare Worker:** Proxy seguro con validación JWT de Firebase Auth y rate limiting.
- **Distribución de APK en BanaHosting:** El CI sube `rindemas.apk` directamente por FTP.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- En cPanel multidominio, el Document Root es `/home/user/dominio.com/`, no siempre `public_html/`.

## Próximo Paso Inmediato
- Confirmar pipeline en CI y proceder con el paquete de Google Play Console (AAB + 20 testers).
