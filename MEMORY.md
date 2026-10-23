# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y preparación de lanzamiento.
- **Acción Reciente:** Implementada tarea `OPS-03` (`Entorno Paralelo de Pruebas Rinde Más Dev y Aislamiento de Producción`). Se configuró la compilación de `rindemas-dev-apk` (`com.cesarluis.rindemas.dev`) para coexistir en el teléfono de César sin alterar la app de Google Play (preservando los 14 días), se eliminó la subida de APKs a BanaHosting y se enfocó la landing exclusivamente en la lista de espera oficial de WhatsApp y Google Play.
- **CI/CD Reciente:** `build_apk.yml` simplificado para compilar en paralelo `app-release-aab` y `rindemas-dev-apk` como artefactos privados. Sincronizado `google-services.json` con `com.cesarluis.rindemas.dev`.
- **Activos Oficiales Creados:** Gmail (`rindemas.app@gmail.com`), Instagram (`@rindemas.app`), TikTok (`@rindemas.app`), WhatsApp (`channel/0029VbEPwHLDJ6H678QLlN1H`). Clave en Bitwarden de César.
- **Estado de CI:** `build_apk.yml` Build 540 en verde (`CI 39975974283 | success | 071f136`) con `VoiceExpenseSheet` elevado. Artefactos `rindemas-dev-apk` y `app-release-aab` generados.

## Decisiones Técnicas y de Negocio Recientes
- `deploy_web.yml` descarga el `version.json` vivo de `https://rindemas.cesarluis.com/version.json` y parcha el `href` de `#btn-download-apk` en `index.astro` antes de compilar Astro, evitando sobrescribir el `buildNumber` del último APK con el valor estático del repositorio.
- En `_effectiveBcvRate`, la validación de tasa debe ser `> 0` y no `> 50.0`, ya que en 2023 las tasas BCV oficiales se encontraban entre 17 y 36 Bs/USD.
- En `ExchangeRateService.getRateForDate`, se implementó caché en memoria del JSON histórico completo para evitar re-descargas de 113 KB.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Validación en dispositivo físico de `AI-08` (OCR `1156` -> `11.56`, voz coloquial y cantidades múltiples) y de registro de gasto histórico 2023. Continuar con `FIN-14`, `FIN-15` (Cashea), `BACKUP-01`, `BACKUP-02`.
