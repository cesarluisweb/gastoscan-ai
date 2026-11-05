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
- **Rediseño Selector de Mes en AppBar (Cápsula Unificada en Actions):** `Pendiente de validación 🧪`. CI verde (Android build 659, commit `a5ccb2e`, run 41953305328). Cápsula ubicada en `actions` con separación exacta de 4 dp respecto a Lupa (y 4 dp entre Lupa e IA), flechas internas tenues y sutiles, y título a la izquierda sin espacios flotantes.
- **Artefacto para pruebas en teléfono:** Descargar `rindemas-dev-apk` desde el run de CI 41953305328 (*Rinde Más Dev*).
- **Próximo Paso Inmediato:** César valida en *Rinde Más Dev* (build 659) la alineación y el estilo sutil de las flechas.

## Decisiones Técnicas y de Negocio Recientes
- AppBarMonthSelector y Acciones: Cápsula unificada en `AppBar.actions` garantizando alineación derecha pegada a Lupa (4 dp) e IA (4 dp). Círculos de navegación con gris tenue `0xFFF1F5F9` al 55% e iconos atenuados al 70%.
- `effectiveMaxWidth` de la cápsula auto-restringido a `screenWidth - 200` (con clamp seguro) para evitar desbordes en cualquier tamaño de pantalla.
- `_inicializarServiciosSegundoPlano()` post-frame corre desacoplado sin bloquear el despacho de intenciones.
- Pruebas con `SnackBar` en Flutter requieren pump incremental de microtasks y animación antes del cierre con `pumpAndSettle()`.
- Pruebas que toquen notificaciones o preferencias deben inicializar `SharedPreferences.setMockInitialValues({})`.
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido marcar Tareas Críticas como `Completada ✅` sin visto bueno explícito de César en *Rinde Más Dev*.
