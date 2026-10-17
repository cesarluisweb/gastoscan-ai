# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y restauración a Build 470 (1.0.4).
- **Acción Reciente:** Instrumentada observabilidad visual en botón de actualizar tasas (SnackBar con estado HTTP/excepción exacta y botón de copiado).
- **Respaldo:** El trabajo y diagnóstico previo de FIN-12 queda salvaguardado en la rama `backup/pre-regreso-build-470`.
- **Preservación:** Documentación técnica (`DOC_*.md`), scripts operativos (`scripts/wait_ci.ps1`) y reglas se mantienen intactos.

## Decisiones Técnicas y de Negocio Recientes
- La restauración del código a Build 470 devolvió la consulta de tasas a su implementación base (DolarAPI + Yadio simple).
- Se agregó diagnóstico explícito en `ExchangeRateService` y `SettingsProvider` para capturar la causa exacta del fallo de red en APK sideloaded.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- CI confirmado en verde (`CI 39061021055 | success | build 495 | 43c3ffe`). César valida en su teléfono usando el botón de actualizar tasas para ver el diagnóstico.
