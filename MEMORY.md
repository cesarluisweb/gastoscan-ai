# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Lanzamiento / Preparación Google Play) y Fase 6.1.
- **Últimos hitos:** 
  1. **Tasas por Fecha y Días Hábiles:** `ExchangeRateService.getRateForDate` busca automáticamente la tasa del último día hábil anterior si la factura corresponde a fin de semana o feriado sin cotización oficial BCV.
  2. **Integración Web + Donaciones:** "Visitar sitio web" y "Apoyar el proyecto ☕" en Más; sección `#donar` en landing page.
  3. **Robustez de Cola de Escaneo (Bloques 1 y 1b):** Protección de fotos compartidas, hoja inferior modal en banner para descarte individual de pendientes/error, tests con archivos reales en disco (Directory.systemTemp), y 0 advertencias en analizador.
  4. **Gate Estricto de CI:** `flutter analyze --fatal-warnings --no-fatal-infos` activo en GitHub Actions y pasando en verde al 100%.

## Decisiones Técnicas y de Negocio Recientes
- **Fotos Compartidas en Lotes:** `removeItem` consulta `isImagePathUsedByOtherQueueItems` antes de borrar el archivo físico; `cancelProcessing` valida contra `readyItems` para no romper previews.
- **Descarte Individual en Cola:** Si hay 1 ítem en el banner, confirmación directa; si hay varios, abre hoja inferior con lista, miniatura, error y botón de papelera por ítem.
- **Transición a Error sin Reintentos Inútiles:** Extracción vacía de Gemini transiciona directamente a `error` con motivo explícito, evitando quemar tokens en fotos no reconocibles.
- **Calidad de Código:** Gate de CI con `--fatal-warnings` activo. Código depurado con 0 advertencias del analizador.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- En cPanel multidominio, el Document Root es `/home/user/dominio.com/`, no siempre `public_html/`.
- Mantener `retention-days: 1` en artefactos de CI para no saturar el límite de 500 MB en GitHub Free.

## Próximo Paso Inmediato
- Iniciar Bloque 2: Base de datos y asincronía (Puntos 8, 9 y 10 de auditoría).
