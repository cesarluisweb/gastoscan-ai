# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (working tree con correcciones completas de R-01, B-02, M-05, M-08, NEW-3b en GastoProvider y N-09; listo para 7.ª reauditoría; sin commit ni push).
- **Acceso a Producción Google Play:** Solicitud enviada el 04/11/2026. En revisión por Google.
- **RM-03 Fase 0A (E0-02):** Parche completo corregido y blindado frente a regresiones estructurales (R-01 revalidación selectiva sin bypass, B-02 sin doble conteo y con test de mapa completo, M-05 con pruebas no vacuas, M-08 probado, 126 tests en suite monetaria). Documentado en `docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md` y `estado-actual.md`.
- **ROADMAP.md:** Fase 0 (RM-03) registrada; E0-02 en estado `Implementada 🔧`.
- **Prioridad 2 (Arranque y Datos Local-First):** Implementado desacoplamiento de cold start en `main.dart`, `SyncCoordinator` con cerrojo/debounce 2s/throttle 5m y bandeja de intenciones en `NotificationService` con `ScanQueueProvider.ready`. Documentado en `docs/DOC_ARRANQUE_LOCAL_FIRST.md` (13 tests dedicados).
- **Próximo Paso Inmediato:** Validar con César para proceder a commit/push y monitoreo de CI en GitHub Actions.

## Decisiones Técnicas y de Negocio Recientes
- Higiene Git P3 completada: stash@{0} descartado, 2.115 archivos de node_modules y test_results.txt desvinculados; _convertBudgetToLens diferido a E0-03.
- La ausencia de tasa no se sustituye por 850.0; requiere estado explícito de «sin tasa» (0.0).
- La marca de purga solo es válida si el disco quedó depurado físicamente (_pendingPurgeOperations).
- Tasa manual global persiste al reiniciar sobre caché antigua y se actualiza ante tasa viva (D-05).
- Los fakes de prueba reproducen TypeError por tipo incorrecto en getters de SharedPreferences.
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido hacer commit o push sin autorización expresa de César.
