# Documento Técnico: Arquitectura de Arranque y Datos (Local-First)

**Fecha:** 04-nov-2026 · **Rama:** `main` · **Iniciativa:** Prioridad 2 (Arranque y Datos)  
**Estado:** `Pendiente de validación 🧪` (espera visto bueno de César en *Rinde Más Dev*).

---

## 1. Justificación y Objetivos

En dispositivos móviles en Venezuela, las condiciones de red móvil (2G/3G, intermitencias y bloqueos) hacían que el arranque de la app sufriera de bloqueos perceptibles si se ejecutaban llamadas de red antes de renderizar la interfaz. Asimismo, la falta de un coordinador central de sincronización provocaba descargas redundantes de Cloud Firestore y riesgos de duplicados locales ante escrituras concurrentes.

### Objetivos Alcanzados:
1. **Cold Start instantáneo:** Reducción estricta de `main()` a la Fase 0 (inicialización nativa y Firebase Core). Renderizado inmediato de la interfaz de usuario con `runApp()`.
2. **Coordinador Único (`SyncCoordinator`):** Centralización de todas las sincronizaciones de Firestore con cerrojo de concurrencia, re-ejecución secuencial limpia ante cambios concurrentes, debouncing de 2 segundos en escrituras y límite de 5 minutos en arranques rutinarios.
3. **Bandeja de Intenciones (`PendingLaunchAction` + `ScanQueueProvider.ready`):** Captura robusta de toques en recordatorios de comprobantes pendientes sin carreras de tiempo ni pérdida de payloads al arrancar en frío.

---

## 2. Arquitectura de Fases de Inicialización

```
[ Arranque del Proceso ]
       │
       ▼
[ Fase 0: main() ] ─────────────────────────► WidgetsFlutterBinding, SystemChrome, Firebase.initializeApp()
       │
       ▼
[ runApp() ] ───────────────────────────────► Renderizado instantáneo del primer frame (Local-First)
       │
       ├─────────────────────────────────────► [ Fase 1: Datos Locales ]
       │                                       Apertura de SQLite, GastoProvider, ScanQueueProvider
       │
       └─► [ addPostFrameCallback en MainScreen ]
                 │
                 ├─► [ Fase 2: Captura de Intenciones ]
                 │   NotificationService.initialize(requestPermission: false)
                 │   Bandeja PendingLaunchAction retiene el payload sin descartarlo
                 │
                 ├─► [ Fase 3: Sesión en 2.º plano ]
                 │   Verificación local de currentUser.
                 │   Restauración silenciosa de Google (timeout 10s) o anónimo perezoso.
                 │
                 ├─► [ Fase 4: Sincronización Coordinada ]
                 │   SyncCoordinator.request(SyncTrigger.arranque)
                 │   (Omitida si es anónimo o si ocurrió hace < 5 min sin cambios locales)
                 │
                 ├─► [ Fase 5: Tareas Diferidas ]
                 │   Topic subscription FCM y reprogramación de recordatorios de inactividad
                 │
                 └─► [ Drenaje de Bandeja ]
                     Espera a ScanQueueProvider.ready -> abre ReviewExpenseScreen
```

---

## 3. Especificación Técnica de Componentes

### 3.1 Desacoplamiento de `main.dart`
- Se removieron de `main()` las llamadas bloqueantes:
  - `intentarLoginSilencioso()` (que además disparaba sincronizaciones remotas completas).
  - `signInAnonymously()`.
  - `NotificationService.instance.initialize()` con petición de permisos en frío.
  - `initializeFirebaseMessaging()` con suscripciones a tópicos en red.
  - `recordActivityAndReschedule()`.
- Ahora `main()` se limita a `WidgetsFlutterBinding.ensureInitialized()`, estilos nativos transparentes, `Firebase.initializeApp()` y `runApp()`.

### 3.2 Coordinador Único de Sincronización (`SyncCoordinator`)
Ubicación: `lib/services/sync_coordinator.dart`

- **Cerrojo de Concurrencia (`_isSyncing`):**
  Impide que dos o más llamadas a `syncBidirectional()` se ejecuten simultáneamente. Si entra una nueva petición mientras una está en curso, se activa `_hasPendingRerun = true`. Al finalizar, se lanza una repetición secuencial limpia para procesar los datos recién agregados.
- **Debouncing de 2 segundos tras guardar (`notifyLocalChange`):**
  En `GastoProvider`, todas las mutaciones locales (`agregarGasto`, `actualizarGasto`, `eliminarGasto`, `setPresupuestoGeneral`, etc.) invocan `_syncCoordinator.notifyLocalChange()`. Si el usuario guarda varias compras en ráfaga, se cancela el temporizador previo y se sincroniza una única vez 2 segundos después de la última modificación.
- **Límite de frecuencia (Throttle de 5 minutos):**
  Para `SyncTrigger.arranque` y `SyncTrigger.reanudacion`, si la última sincronización ocurrió hace menos de 5 minutos y no hay registros pendientes en SQLite (`synced = 0`), la llamada a la red se suprime.
  Los flujos manuales (pull-to-refresh en `DashboardScreen` o vinculación de cuenta) utilizan `forzar: true` para ignorar este límite.
- **Aislamiento de Privacidad:**
  Si `currentUser == null` o `currentUser.isAnonymous == true`, la sincronización no se ejecuta (cero consumo de red y cero lecturas a Firestore).
- **Manejo de Reemplazo Pendiente:**
  Si `isPendingReplaceActive` es verdadero, ejecuta de forma prioritaria `retryPendingReplace()`.

### 3.3 Bandeja de Intenciones en Notificaciones
Ubicaciones: `lib/services/notification_service.dart`, `lib/providers/scan_queue_provider.dart`, `lib/ui/screens/main_screen.dart`

- **Modelo `PendingLaunchAction`:**
  Almacena `{ id, payload, origin, receivedAt, isHandled }`. Sustituye el consumo ciego del `ValueNotifier`.
- **Sincronización con `ScanQueueProvider.ready`:**
  `ScanQueueProvider` expone `Future<void> get ready`, que se completa en un bloque `finally` cuando `loadReadyItems()` y `loadPendingItems()` culminan su lectura de SQLite.
- **Consumo Protegido en `MainScreen._drainLaunchActions()`:**
  1. Verifica cerrojo `_isHandlingAction` para evitar doble navegación.
  2. Ante `'pending_reviews'`, espera `await scanQueue.ready.timeout(const Duration(seconds: 8))`.
  3. Si existen comprobantes listos, abre `ReviewExpenseScreen` y marca la intención como atendida (`markActionHandled`).
  4. Si no existen comprobantes listos tras la espera, cambia a la pestaña Gastos, emite un aviso no bloqueante y marca la intención como atendida.

---

## 4. Matriz de Pruebas Automatizadas

| Suite de Pruebas | Archivo | Casos Verificados |
|---|---|---|
| Coordinador de Sincronización | `test/services/sync_coordinator_test.dart` | 7 pruebas: cerrojo de concurrencia, debounce de 2s, throttle de 5 min, bypass con forzar, guardas anónimas, reemplazo pendiente y desconexión de red |
| Bandeja de Intenciones y Cola | `test/services/intent_tray_notification_test.dart` | 5 pruebas: encolado de intención, consumo por ID, resolución de `ready`, resolución con `autoProcess: false` y retención de payload durante la lectura de SQLite |
| Navegación de Intenciones en UI | `test/screens/main_screen_launch_action_test.dart` | Manejo de intención en frío, espera de carga y visualización de aviso contextual |
| Neutralización de Auto-reparación | `test/screens/main_screen_no_auto_repair_test.dart` | Comprobación de que `MainScreen` no ejecuta reparaciones monetarias automáticas |

---

## 5. Guía de Pruebas para César en Dispositivo Físico (*Rinde Más Dev*)

1. **Prueba de Arranque Offline (Modo Avión):**
   - Activar el modo avión en el teléfono.
   - Abrir *Rinde Más Dev*.
   - **Resultado esperado:** La aplicación abre instantáneamente el Dashboard sin pantallas en blanco ni diálogos de error de conexión.

2. **Prueba de Debouncing de Sincronización:**
   - Con conexión activa y cuenta de Google vinculada, registrar 2 gastos seguidos rápidamente en el teléfono.
   - **Resultado esperado:** Ambas compras se guardan de inmediato en la lista local; en Firestore se observa un único paquete de subida tras 2 segundos de reposo.

3. **Prueba de Notificación en Cold Start:**
   - Tomar una foto a un recibo y dejarlo pendiente en la cola de escaneo.
   - Forzar la detención de la aplicación desde Ajustes de Android.
   - Pulsar la notificación de recordatorio ("Tienes comprobantes listos por revisar").
   - **Resultado esperado:** La aplicación arranca y navega de forma limpia a la pantalla de revisión de compras (`ReviewExpenseScreen`) sin perderse en el Dashboard.
