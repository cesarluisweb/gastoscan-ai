# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 7 (Arquitectura de Producción), Fase 4 (UX Cola Offline) y Fase 5 (Lanzamiento).
- **Últimos hitos:** Rediseño integral de la UX de la cola de escaneo offline. Banner único global (`GlobalScanQueueBanner`) en `MainScreen` con eliminación de duplicidad en `DashboardScreen`. Estados empáticos ("Guardada sin conexión") sin quemar reintentos en SQLite por desconexión. Auto-reanudación transparente mediante `connectivity_plus` y observador de ciclo de vida (`AppLifecycleState.resumed`).

## Decisiones Técnicas y de Negocio Recientes
- **Banner Único Global:** Desacoplado en `MainScreen` flotante superior; eliminado del cuerpo de `DashboardScreen` para evitar contradicciones visuales.
- **Diferenciación de Errores de Red:** Desconexiones (`SocketException`, `unavailable`) no incrementan `attemptCount` en la cola y activan estado `isWaitingForConnection` con mensaje tranquilizador.
- **Aislamiento en Tests:** `ConnectivityService` detecta entorno de test automáticamente para evitar llamadas a canales nativos sin mocks.
- **Invariante FTS5:** Búsqueda profunda en facturas es una optimización no crítica; si el motor del teléfono carece de FTS5, se degrada a `LIKE`.
- **Monetización:** Anuncios intersticiales únicamente tras guardar factura (transición natural); nunca al abrir ni en captura de fotos.
- **Framework de Creador Integrado:** Adoptadas directrices de 60 días (AristiDevs): impacto de negocio sobre complejidad técnica, datos como producto, corner cases locales, funnel de 7 etapas y monetización como producto independiente.


## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- En R8 ProGuard, añadir `-dontwarn` para alfabetos no usados (`chinese`, `devanagari`, `japanese`, `korean`) de `google_mlkit_text_recognition`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Prohibido caer en bucles de `view_file` sobre el mismo bloque; tras 2 lecturas, pasar directamente a editar o ejecutar.

## Próximo Paso Inmediato
- Verificación de CI (compilación y suite de pruebas) tras push y validación en vivo del APK.
