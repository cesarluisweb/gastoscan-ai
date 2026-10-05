# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.1 (Multimoneda y Consistencia de Tasas).
- **Últimos hitos:** 
  1. **Sistema Multimoneda y Selector de Tasas (Fase 1):** Soporte en toda la app para USD, VES, EUR y USDT. Tarjeta de 3 tasas con timestamp y recarga sutil en "Más", chips rápidos de tasa en Revisar Gasto, selector de 4 monedas con conversión matemática en vivo en Presupuestos.
  2. **Consistencia Matemática en Bs. (Fase 0):** Corrección determinista de totales en Bolívares (`totalMesVes` y `categoryTotals` fijos por fecha de compra, sin fluctuación por tasa diaria, inclusión de compras sin ítems en categorías y reparación de tasas históricas).
  3. Eliminación de pantalla huérfana `settings_screen.dart`.
  4. Gateway en **Cloudflare Workers** activo y Firebase en Spark 100% gratuito.

## Decisiones Técnicas y de Negocio Recientes
- **Multimoneda de Referencia:** Soporte para VES, USD, EUR y USDT. Formato determinista y conversión dinámica en presupuestos y formularios sin crear múltiples cuentas contables.
- **Fuentes de Tasas:** DolarAPI Oficial (USD y EUR en vivo e históricos) y Binance P2P / Yadio (USDT en vivo e históricos).
- **Exactitud en Bolívares:** Los gastos en VES conservan su `total_original` inmutable. Los gastos en USD usan `total_usd * tasa_cambio` de la fecha de registro. El Total Gastado y la Distribución de Gastos cuadran al centavo en Bs. y en USD.
- **Gateway Cloudflare Worker:** Proxy seguro con validación JWT de Firebase Auth y rate limiting.
- **Distribución de APK en BanaHosting:** El CI sube `rindemas.apk` directamente por FTP.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- En cPanel multidominio, el Document Root es `/home/user/dominio.com/`, no siempre `public_html/`.

## Próximo Paso Inmediato
- Monitorear CI hasta confirmar `success` para la implementación del selector multimoneda.
