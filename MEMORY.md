# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Lanzamiento / Preparación Google Play) y Fase 6.1.
- **Últimos hitos:** 
  1. **Tasas por Fecha y Días Hábiles:** `ExchangeRateService.getRateForDate` ahora busca automáticamente la tasa del último día hábil anterior si la factura corresponde a un fin de semana o feriado sin cotización oficial BCV.
  2. **Integración Web + Sección de Donaciones:** Opciones de "Visitar sitio web" (`rindemas.cesarluis.com`) y "Apoyar el proyecto ☕" agregadas a la pestaña **Más**. Nueva sección de donaciones (`#donar`) agregada a la landing page.
  3. **Actualizaciones Inteligentes (Semánticas + Críticas):** Soporte para detección por versión semántica (`isVersionHigher`) y bandera `isMajor` con aviso directo al iniciar la app.
  4. **Robustez de Cola de Escaneo y Ciclo de Vida (Puntos 4, 5 y 6):** Guarda síncrona en `processPendingItems`, recuperación de `processing` a `pending`, diálogo de confirmación para cancelar/descartar, retención de fotos en fallos, conteo de intentos de red, deshacer en lista de compras, y guardas `_disposed`/`mounted` en Providers y `ChatScreen`.

## Decisiones Técnicas y de Negocio Recientes
- **Concurrencia en Cola de Escaneo:** `_isProcessing` debe setearse síncronamente antes de cualquier `await`. `cancelProcessing` activa flag `_cancelRequested` y no fuerza `_isProcessing = false` prematuramente para no inducir loops dobles.
- **Retención de Comprobantes:** Si Gemini devuelve vacío, el comprobante se transiciona a `error` con incremento de intentos, jamás se borra silenciosamente de disco.
- **Protección contra Falsos Taps en Descarte:** Banners de escaneo requieren confirmación modal (`showDialog`) antes de vaciar la cola.
- **Guardas de Ciclo de Vida:** Todo provider sobreescribe `notifyListeners` con chequeo de `_disposed`. Toda acción asíncrona en `ChatScreen` valida `mounted` antes de `setState`.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- En cPanel multidominio, el Document Root es `/home/user/dominio.com/`, no siempre `public_html/`.
- Mantener `retention-days: 1` en artefactos de CI para no saturar el límite de 500 MB en GitHub Free.

## Próximo Paso Inmediato
- Proceder con Bloque 2: Base de datos y asincronía (Puntos 8, 9 y 10).
