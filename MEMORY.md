# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y preparación de lanzamiento.
- **Acción Reciente:** Integración del Canal oficial de WhatsApp (`0029VbEPwHLDJ6H678QLlN1H`) y tarjeta dual en Hero y sección `#descargar` de la landing page.
- **Estado de CI:** Build 531 confirmado en verde (`conclusion: success`, commit `b0204c1`).
- **Estado General:** Landing verificada en vivo en producción (`rindemas.cesarluis.com`) con canal de WhatsApp y APK build 535 activos.

## Decisiones Técnicas y de Negocio Recientes
- En `_effectiveBcvRate`, la validación de tasa debe ser `> 0` y no `> 50.0`, ya que en 2023 las tasas BCV oficiales se encontraban entre 17 y 36 Bs/USD. Descartar `<= 50.0` solo aplica a la tasa del día actual para depurar semillas de prueba obsoletas.
- En `ExchangeRateService.getRateForDate`, se implementó caché en memoria del JSON histórico completo para evitar re-descargas de 113 KB en paralelo o al cambiar de fecha.
- `Scaffold.bottomNavigationBar` usa `Align(heightFactor: 1.0)` y filas informativas usan `Wrap` adaptable.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Integradas en `ROADMAP.md` las tareas derivadas de feedback de Closed Testing: `AI-08` (decimales/comas IA), `FIN-14` (liquidación USDT), `BACKUP-01` (backup local con fotos en zip) y `UX-13` (tags opcionales).
- Validación en dispositivo de registro de gasto histórico con fecha 2023 y avance en tareas planificadas (`UI-02` contraste en Más, `UI-04` botón de presupuestos, `UI-06` orden canónico de monedas).
