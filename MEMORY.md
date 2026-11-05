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
- **Rediseño Selector de Mes en AppBar (Cápsula Unificada y Acciones Circulares):** `Pendiente de validación 🧪`. CI verde (Android build 657, commit `7ffede5`, run 41947798579). Cápsula única con micro-flechas circulares internas `#F1F5F9`, y botones de Lupa e IA en círculos de 34 dp con fondo blanco y borde fino.
- **Artefacto para pruebas en teléfono:** Descargar `rindemas-dev-apk` desde el run de CI 41947798579 (*Rinde Más Dev*).
- **Próximo Paso Inmediato:** César valida en *Rinde Más Dev* (build 657) la experiencia de la cápsula unificada y botones circulares en AppBar.

## Decisiones Técnicas y de Negocio Recientes
- AppBarMonthSelector y Acciones: Cápsula unificada de 34 dp con micro-círculos de flechas internos `#F1F5F9`, y botones de acción (Lupa e IA) con `IconButton.styleFrom` circular blanco con borde de 1 px.
- `_inicializarServiciosSegundoPlano()` post-frame corre desacoplado sin bloquear el despacho de intenciones.
- Pruebas con `SnackBar` en Flutter requieren pump incremental de microtasks y animación antes del cierre con `pumpAndSettle()`.
- Pruebas que toquen notificaciones o preferencias deben inicializar `SharedPreferences.setMockInitialValues({})`.
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido marcar Tareas Críticas como `Completada ✅` sin visto bueno explícito de César en *Rinde Más Dev*.
