# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 7 (Arquitectura de Producción), Fase 4 (UX Cola Offline) y Fase 5 (Lanzamiento).
- **Últimos hitos:** Rediseño del banner de cola como componente en línea integrado (estilo Telegram/WhatsApp). En lugar de flotar sobre el contenido y tapar el selector de mes o el AppBar, se ubica bajo cada AppBar en un `Column` con `AnimatedSize`, empujando suavemente el contenido hacia abajo sin cubrir ningún control.

## Decisiones Técnicas y de Negocio Recientes
- **Banner Integrado y Resiliente:** En línea con `AnimatedSize` bajo el AppBar en las 4 pantallas principales. `GlobalScanQueueBanner` blindado ante ausencia de `ScanQueueProvider` en tests aislados.
- **Deep-linking Robusto:** `NotificationService` registra payload vía `getNotificationAppLaunchDetails()` y `onDidReceiveNotificationResponse`, permitiendo navegar a `ReviewExpenseScreen` aún con la app cerrada.
- **Feedback de Captura:** `HapticFeedback.mediumImpact()` al encolar y eliminación del SnackBar redundante inferior para evitar competencia visual.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- En R8 ProGuard, añadir `-dontwarn` para alfabetos no usados (`chinese`, `devanagari`, `japanese`, `korean`) de `google_mlkit_text_recognition`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Prohibido caer en bucles de `view_file` sobre el mismo bloque; tras 2 lecturas, pasar directamente a editar o ejecutar.

## Próximo Paso Inmediato
- Verificación completa de Google Play Console: reclutamiento de 20-25 testers por 14 días y preparación de assets (512x512, 1024x500, 1080x1920).

