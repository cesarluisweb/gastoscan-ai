# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (commit de saneamiento E0-02 y specs documentadas; push y monitoreo CI en curso).
- **Acceso a Producción Google Play:** Solicitud enviada el 04/11/2026. En revisión por Google.
- **RM-03 Fase 0A (E0-02):** Saneamiento inicial commiteado (D-01/D-08, 0.0 en proveedores, purga A-07, B3-OBS). Especificación técnica consolidada documentada en `docs/rm-03/especificacion-consolidada-u1-u2.md`.
- **ROADMAP.md:** Actualizado con Fase 0 (RM-03), E0-02 vinculada a su especificación técnica y archivo histórico en ROADMAP_HISTORICO.md.
- **Próximo Paso Inmediato:** Validar CI en verde y planificar implementación de MonetaryPrefsCoordinator para sexta reauditoría.

## Decisiones Técnicas y de Negocio Recientes
- La ausencia de tasa no se sustituye por 850.0; requiere estado explícito de «sin tasa» (0.0).
- La marca de purga solo es válida si el disco quedó depurado físicamente (_pendingPurgeOperations).
- Tasa manual global persiste al reiniciar sobre caché antigua y se actualiza ante tasa viva (D-05).
- Los fakes de prueba reproducen TypeError por tipo incorrecto en getters de SharedPreferences.
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido hacer commit o push sin autorización expresa de César.
