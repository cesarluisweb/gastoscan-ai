# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (commit `1c6142e` en verde en CI, Build 656).
- **Acceso a Producción Google Play:** Solicitud enviada el 04/11/2026. En revisión por Google.
- **RM-03 Fase 0A (E0-02):** Parche completo blindado (126 tests en suite monetaria).
- **Prioridad 2 (Arranque y Datos Local-First):** En verde en CI (`build 656`). Estado: `Pendiente de validación 🧪`.
  - Cold start desacoplado en `main.dart` con `runApp()` inmediato y servicios diferidos post-frame.
  - `SyncCoordinator` con cerrojo de concurrencia, debounce de 2s, throttle de 5 min y re-run secuencial.
  - Bandeja de intenciones (`PendingLaunchAction`) sincronizada con `ScanQueueProvider.ready`.
  - Documentación técnica: `docs/DOC_ARRANQUE_LOCAL_FIRST.md` (13 tests dedicados; total suite: 638 tests en verde).
- **Próximo Paso Inmediato:** César valida en *Rinde Más Dev* (build 656) la experiencia en frío, debounce y notificaciones.

## Decisiones Técnicas y de Negocio Recientes
- `_inicializarServiciosSegundoPlano()` post-frame corre desacoplado sin bloquear el despacho de intenciones.
- Pruebas con `SnackBar` en Flutter requieren pump incremental de microtasks y animación antes del cierre con `pumpAndSettle()`.
- Pruebas que toquen notificaciones o preferencias deben inicializar `SharedPreferences.setMockInitialValues({})`.
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido marcar Tareas Críticas como `Completada ✅` sin visto bueno explícito de César en *Rinde Más Dev*.
