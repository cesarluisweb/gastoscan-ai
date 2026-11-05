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
- **Rediseño Selector de Mes en AppBar (Cápsula Simplificada en Actions):** `Pendiente de validación 🧪`. CI verde (Android build 660, commit `c626480`, run 41959188863). Cápsula compacta en `actions`: formato abreviado 3 letras ('Nov' en año en curso, 'Nov 25' en año distinto), sin caret inferior ni icono calendario, flechas sutiles ‹ y ›, diálogo de 12 meses accesible tocando el texto central.
- **Artefacto para pruebas en teléfono:** Descargar `rindemas-dev-apk` desde el run de CI 41959188863 (*Rinde Más Dev*).
- **Próximo Paso Inmediato:** César valida en *Rinde Más Dev* (build 660) la cápsula compacta y la navegación mensual.

## Decisiones Técnicas y de Negocio Recientes
- AppBarMonthSelector: Formato compacto `Nov` (año en curso) y `Nov 25` (años distintos), reduciendo ancho de cápsula a ~94 dp y liberando espacio para títulos y acciones.
- Navegación mensual simplificada: Flechas directas de mes anterior/siguiente integradas en la cápsula y diálogo de selección completo al pulsar el texto central.
- `_inicializarServiciosSegundoPlano()` post-frame corre desacoplado sin bloquear el despacho de intenciones.
- Pruebas con `SnackBar` en Flutter requieren pump incremental de microtasks y animación antes del cierre con `pumpAndSettle()`.
- Pruebas que toquen notificaciones o preferencias deben inicializar `SharedPreferences.setMockInitialValues({})`.
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido marcar Tareas Críticas como `Completada ✅` sin visto bueno explícito de César en *Rinde Más Dev*.
