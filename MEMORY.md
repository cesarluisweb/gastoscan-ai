# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y preparación de lanzamiento.
- **Acción Reciente:** Implementada tarea crítica `AI-08` / `FIN-16` (`DOC_CORRECCION_DECIMALES_Y_VOZ.md`). Se incorporó Consenso de Decimales y Residual Match en `GeminiExtractionResult` para corregir ítems descalzados como `1156` -> `11.56`, se eliminó la doble suma de IVA en `SemanticValidator`, se sanitizaron comas térmicas en `LocalOcrService` y se blindó el dictado por voz en `GeminiService` contra expresiones coloquiales y subtotales.
- **CI/CD Reciente:** Desacoplados los pipelines CI/CD de Web (`deploy_web.yml`, ~50 s) y Móvil (`build_apk.yml`, ~13 min) bajo `OPS-02` (commit `af85856`), con preservación automática de `version.json` vivo en producción (`buildNumber: 539`).
- **Activos Oficiales Creados:** Gmail (`rindemas.app@gmail.com`), Instagram (`@rindemas.app`), TikTok (`@rindemas.app`), WhatsApp (`channel/0029VbEPwHLDJ6H678QLlN1H`). Clave en Bitwarden de César.
- **Estado de CI:** `deploy_web.yml` Build 1 en verde (`CI 39876106103 | success | build 1 | af85856`) y `build_apk.yml` Build 535 (`38ce64a`). Producción verificada vía HTTP (`200 OK`, `302 Found`, `version.json` intacto en build 539).

## Decisiones Técnicas y de Negocio Recientes
- `deploy_web.yml` descarga el `version.json` vivo de `https://rindemas.cesarluis.com/version.json` y parcha el `href` de `#btn-download-apk` en `index.astro` antes de compilar Astro, evitando sobrescribir el `buildNumber` del último APK con el valor estático del repositorio.
- En `_effectiveBcvRate`, la validación de tasa debe ser `> 0` y no `> 50.0`, ya que en 2023 las tasas BCV oficiales se encontraban entre 17 y 36 Bs/USD.
- En `ExchangeRateService.getRateForDate`, se implementó caché en memoria del JSON histórico completo para evitar re-descargas de 113 KB.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Validación en dispositivo de registro de gasto histórico con fecha 2023 y avance en tareas planificadas (`AI-08`, `FIN-14`, `FIN-15` [Cashea / Cuotas en `DOC_PLAN_CASHEA.md`], `BACKUP-01`, `BACKUP-02`, `UX-13`, `UI-02`, `UI-04`, `UI-06`).
