# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 7 (Arquitectura de Producción), Fase 4 (UX Cola Offline) y Fase 5 (Lanzamiento).
- **Últimos hitos:** Auditoría y optimización integral de notificaciones. Recordatorio de inactividad ampliado a 7 días con tono sobrio sobre presupuesto. Soporte cold start y deep-link para facturas pendientes. Reubicación de banner flotante bajo AppBar con icono de proceso IA y feedback háptico. Interruptor en Ajustes para silenciar notificaciones y corrección de contraste en SnackBars de error.

## Decisiones Técnicas y de Negocio Recientes
- **Notificaciones Útiles y No Invasivas:** Inactividad pasa a 7 días y solo notifica si están activadas en Ajustes (`recordatorios_activos`). Sin alertas push de presupuesto redundantes (se ven en Inicio).
- **Deep-linking Robusto:** `NotificationService` registra payload vía `getNotificationAppLaunchDetails()` y `onDidReceiveNotificationResponse`, permitiendo navegar a `ReviewExpenseScreen` aún con la app cerrada.
- **Banner Flotante Despejado:** `topOffset` suma `kToolbarHeight` para nunca tapar el título ni el icono del asistente IA en el AppBar.
- **Feedback de Captura:** `HapticFeedback.mediumImpact()` al encolar y eliminación del SnackBar redundante inferior para evitar competencia visual con el banner superior.
- **Banner Único Global:** Desacoplado en `MainScreen` flotante superior; eliminado del cuerpo de `DashboardScreen` para evitar contradicciones visuales.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- En R8 ProGuard, añadir `-dontwarn` para alfabetos no usados (`chinese`, `devanagari`, `japanese`, `korean`) de `google_mlkit_text_recognition`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Prohibido caer en bucles de `view_file` sobre el mismo bloque; tras 2 lecturas, pasar directamente a editar o ejecutar.

## Próximo Paso Inmediato
- Git commit, git push y verificación de CI (compilación y suite de pruebas) vía API de GitHub.
