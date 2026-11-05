# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (commit `1c6142e` en verde en CI, Build 656).
- **Acceso a Producción Google Play:** Solicitud enviada el 04/11/2026. En revisión por Google.
- **RM-03 Fase 0A (E0-02):** Aceptada en 7.ª reauditoría adversarial (dictamen en `docs/rm-03/auditorias/septima-reauditoria-u1-u2-deepseek.md` con 126 pruebas validadas). Pendiente de commit/push y CI.
- **Prioridad 2 (Arranque y Datos Local-First):** En verde en CI (`build 656`). Estado: `Pendiente de validación 🧪`.
  - Cold start desacoplado en `main.dart` con `runApp()` inmediato y servicios diferidos post-frame.
  - `SyncCoordinator` con cerrojo de concurrencia, debounce de 2s, throttle de 5 min y re-run secuencial.
  - Bandeja de intenciones (`PendingLaunchAction`) sincronizada con `ScanQueueProvider.ready`.
  - Documentación técnica: `docs/DOC_ARRANQUE_LOCAL_FIRST.md` (13 tests dedicados; total suite: 638 tests en verde).
- **Sincronización Panel Web con App Móvil (Fase 5):** `Implementada 🔧`.
  - Reorganización en 4 tarjetas (General, ¿Qué compraste?, Monto total, ¿Cómo pagaste?) con orden `USD -> VES -> USDT -> EUR`.
  - Módulos puros `expense-money.js` y `category-classifier.js` (11/11 tests en Node 24 en verde, validando paridad al céntimo C1-C6).
  - Eliminación de P2P en EUR, cálculo bidireccional Bs/tasa, protección de total dictado y diálogo accesible de discrepancia.
  - Documentación técnica: `docs/DOC_SINCRONIZACION_PANEL_WEB.md`. Build Astro 100% limpio.
- **Rediseño Selector de Mes en AppBar (Cápsula con Nombre Completo y Flechas Negras):** `Pendiente de validación 🧪`. CI verde (Android build 661, commit `f7ad013`, run 42034176027). Cápsula elegante en `actions`: nombre completo sin año en el presente ('Noviembre'), flechas en negro (19 dp) sin fondo circular, borde resaltado en amarillo activo (`#FACC15`, 1.5px) cuando no es el mes actual, y abreviatura responsiva ('Nov') en pantallas angostas.
- **Artefacto para pruebas en teléfono:** Descargar `rindemas-dev-apk` desde el run de CI 42034176027 (*Rinde Más Dev*).
- **Próximo Paso Inmediato:** César valida en *Rinde Más Dev* (build 661) la apariencia visual de la cápsula y el resaltado en meses pasados.

## Decisiones Técnicas y de Negocio Recientes
- AppBarMonthSelector: Nombre completo del mes sin año ('Noviembre'), conmutación automática a 3 letras ('Nov') ante `effectiveMaxWidth < 145`, flechas negras transparentes (19 dp) y borde amarillo de acento (`AppColors.primaryDark`) fuera del mes actual.
- Navegación mensual: Flechas directas integradas en la cápsula y diálogo de 12 meses accesible al pulsar el texto central.
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido marcar Tareas Críticas como `Completada ✅` sin visto bueno explícito de César en *Rinde Más Dev*.
