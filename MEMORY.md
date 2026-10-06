# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Lanzamiento / Preparación Google Play) y Fase 6.1.
- **Últimos hitos:** 
  1. **Tasas por Fecha y Días Hábiles:** `ExchangeRateService.getRateForDate` busca automáticamente la tasa del último día hábil anterior si la factura corresponde a fin de semana o feriado sin cotización oficial BCV.
  2. **Integración Web + Donaciones:** "Visitar sitio web" y "Apoyar el proyecto ☕" en Más; sección `#donar` en landing page.
  3. **Robustez de Cola de Escaneo (Bloques 1 y 1b):** Protección de fotos compartidas en lotes, descarte individual por ID, recuperación de `processing` a `pending`, no reescritura de errores en DB, eliminación de doble catch, `flutter analyze` activo en CI y tests de comportamiento de cola pasando al 100%.

## Decisiones Técnicas y de Negocio Recientes
- **Fotos Compartidas en Lotes:** `removeItem` consulta `isImagePathUsedByOtherQueueItems` antes de borrar el archivo físico; `cancelProcessing` valida contra `readyItems` para no romper previews.
- **Transición a Error sin Reintentos Inútiles:** Extracción vacía de Gemini transiciona directamente a `error` con motivo explícito, evitando quemar tokens en fotos no reconocibles.
- **CI con Análisis Estático:** `flutter analyze --no-fatal-warnings --no-fatal-infos` corre antes de `flutter test` en GitHub Actions.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- En cPanel multidominio, el Document Root es `/home/user/dominio.com/`, no siempre `public_html/`.
- Mantener `retention-days: 1` en artefactos de CI para no saturar el límite de 500 MB en GitHub Free.

## Próximo Paso Inmediato
- Iniciar Bloque 2: Base de datos y asincronía (Puntos 8, 9 y 10 de auditoría).
