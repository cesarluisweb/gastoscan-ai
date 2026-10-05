# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 7 (Arquitectura de Producción / Gateway Serverless) y Fase 5 (Lanzamiento).
- **Últimos hitos:** 
  1. **Consistencia Matemática en Bs. (Fase 0):** Corrección determinista de totales en Bolívares (`totalMesVes` y `categoryTotals` fijos por fecha de compra, sin fluctuación por tasa diaria, inclusión de compras sin ítems en categorías y reparación de tasas históricas).
  2. Versión `1.0.3` (Build 307) desplegada y verificada en CI.
  3. Gateway en **Cloudflare Workers** activo y Firebase en Spark 100% gratuito.

## Decisiones Técnicas y de Negocio Recientes
- **Exactitud en Bolívares:** Los gastos en VES conservan su `total_original` inmutable. Los gastos en USD usan `total_usd * tasa_cambio` de la fecha de registro. El Total Gastado y la Distribución de Gastos cuadran al centavo en Bs. y en USD.
- **Incremento de Versión Semántica:** `pubspec.yaml` debe actualizarse manualmente al cambiar de versión (`1.0.2` -> `1.0.3`) para que el modal y `version.json` reflejen el cambio.
- **Gateway Cloudflare Worker:** Proxy seguro con validación JWT de Firebase Auth y rate limiting.
- **Distribución de APK en BanaHosting:** El CI sube `rindemas.apk` directamente por FTP.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- En cPanel multidominio, el Document Root es `/home/user/dominio.com/`, no siempre `public_html/`.

## Próximo Paso Inmediato
- Monitorear CI hasta confirmar `success` para la corrección de totales en Bolívares.
- Proceder con el selector multimoneda (Fase 1: Dólar BCV, Euro BCV, USDT Binance).
