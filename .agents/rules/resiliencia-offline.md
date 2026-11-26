---
trigger: model_decision
description: "Consultar al trabajar con conectividad offline/online, caché local de avatares o imágenes remotas, fail-fast de red, clientes HTTP o auto-recuperación al reconectar."
---

# Resiliencia Offline, Caché de Red y Ciclo de Vida HTTP

## 1. Avatares e Imágenes Remotas de Cuenta
- **Prohibido `NetworkImage` directo en pestañas persistentes (`IndexedStack`):** `NetworkImage` solo cachea en RAM (`ImageCache`), falla en silencio offline (dejando círculos vacíos si falta `onBackgroundImageError`) y no reintenta al reconectar.
- **Caché local por `uid` + hash de URL:** Persistir en `<ApplicationSupportDirectory>/avatars/avatar_<safeUid>_<urlHash>.img` (escritura atómica `.tmp` → `rename`). Cambiar el hash al cambiar `photoUrl` evita colisiones de `FileImage` en `ImageCache`.
- **Defensa contra portales cautivos:** Validar siempre URL `https://`, timeout acotado (<= 6 s), `statusCode == 200`, `content-type: image/*`, límite de peso (<= 2 MB) y firma de *magic bytes* (JPEG, PNG, WebP, GIF) antes de guardar en disco.
- **Respaldo visual y cuentas sin foto:** Mostrar siempre la inicial del usuario como fallback (`onBackgroundImageError`). Si el usuario autenticado no tiene `photoURL`, mostrar la inicial en 0 ms sin agendar reintentos de red.
- **Purga obligatoria por privacidad:** Eliminar archivos de avatar y sus metadatos en `cerrarSesion()`, `eliminarCuentaYDatos()` (siempre, independiente del flag de recibos) y `limpiarArchivosApp()`.

## 2. Fail-Fast Offline y Ciclo de Vida de `http.Client`
- **Comprobar conectividad antes de abrir sockets:** Consultar `ConnectivityService.instance.isConnected()` **antes** de instanciar `http.Client()` o ejecutar cascadas de red. Si devuelve `false`, retornar en 0 ms con el estado/caché local.
- **Cierre obligatorio de clientes propios:** Todo servicio que cree su propio `http.Client()` (cuando no se inyecta uno de prueba) DEBE cerrarlo en `finally` o exponer `close()` e invocarlo en `dispose()` del widget/proveedor propietario.
- **Caché Persistente ante *Throttle* de Red:** Cuando un servicio aplique *throttle* devolviendo `null` sin consultar red (ej. `UpdateService.checkForUpdate(force: false)`), las pantallas consumidoras nunca deben interpretar `null` como "al día". Persistir el último payload válido y exponer una lectura cacheada (`getCachedUpdateInfo()`) que reevalúe el estado contra los datos actuales del dispositivo.

## 3. Auto-Recuperación al Reconectar
- **Debounce y cooldown:** Al escuchar `ConnectivityService.onConnectivityChanged`, aplicar debounce de ~2 s tras emitir `true` (negociación DHCP/DNS en Android) y cancelar el timer al emitir `false` o al ejecutar `dispose()`.
- **Disparo condicional y cerrojo:** Proteger rutinas de red con cerrojo de concurrencia (compartir `Future` en vuelo) y disparar auto-refrescos solo cuando falte frescura real, evitando tormentas de peticiones al cambiar de pestaña o alternar Wi-Fi ↔ datos.

## 4. Arranque Offline de Notificaciones FCM y Bandeja de Intenciones
- **Listeners y `getInitialMessage()` antes de red:** En `initializeFirebaseMessaging()`, registrar `onMessage` / `onMessageOpenedApp` (protegidos con bandera idempotente `_fcmListenersAttached`) y resolver `getInitialMessage()` antes de `requestPermission()` o llamadas `subscribeToTopic` / `unsubscribeFromTopic`. Aislar cada operación de red en su propio `try/catch` para que un arranque sin conexión nunca aborte el deep-link.
- **Sin doble emisión en `enqueueAction`:** Asignar `_pendingAction` e `_initialPayload` antes de notificar `pendingActionNotifier` y actualizar `selectedPayloadNotifier` solo si `!action.isHandled`.
- **Guarda contra doble toque en toggles remotos:** En switches de preferencias que sincronicen topics FCM tras un `await`, verificar `if (_campo != value) return;` antes de invocar suscripción/desuscripción.
