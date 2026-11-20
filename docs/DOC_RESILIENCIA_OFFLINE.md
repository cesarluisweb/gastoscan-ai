# Resiliencia Offline y Recuperación Automática

> **Estado:** `Implementada 🔧` (pendiente de CI en verde y validación en dispositivo físico).
> **Commit / Build:** *(se completa tras CI en verde).*

## 1. Resumen de cambios

### A. Caché local de avatar de perfil y recuperación automática
- **`lib/services/profile_avatar_service.dart`:** guarda el avatar en `<ApplicationSupportDirectory>/avatars/avatar_<safeUid>_<urlHash>.img` con escritura atómica (`rename`), validación de URL `https://`, timeout de 6 s, `content-type: image/*`, límite 2 MB y verificación de *magic bytes* (JPEG, PNG, WebP, GIF) para bloquear portales cautivos.
- **`lib/ui/screens/more_screen.dart`:** reemplaza `NetworkImage` por `FileImage` con `onBackgroundImageError` y respaldo inmediato a la inicial del usuario (nunca círculo vacío). Se suscribe a `ConnectivityService.onConnectivityChanged` (debounce 2 s) y expone `onTabVisible()` para reintentar automáticamente al recuperar red o volver a "Más". Cuentas sin `photoURL` muestran la inicial en 0 ms sin disparar red.
- **`lib/services/sync_service.dart` e `lib/services/image_service.dart`:** purgan la caché de avatares en `cerrarSesion()`, `eliminarCuentaYDatos()` (siempre, independiente del flag de recibos) y `limpiarArchivosApp()`.

### B. Tasas de cambio: fail-fast offline y auto-recuperación inteligente
- **`lib/services/exchange_rate_service.dart`:** verifica `ConnectivityService.isConnected()` antes de instanciar `http.Client()` (fail-fast en 0 ms offline) y cierra el cliente propio en `finally`. `ExchangeRatesData` informa `usdEnVivo`, `eurEnVivo`, `usdtEnVivo` para distinguir tasas vivas de semillas previas.
- **`lib/providers/settings_provider.dart`:**
  - Cerrojo de concurrencia (`_inFlightRateSync`) en `actualizarTasaAutomatica()`.
  - Fix de estado por moneda: una tasa de semilla previa queda en `EstadoTasaMoneda.referencia` y una tasa en `0.0` queda en `EstadoTasaMoneda.sinTasa`.
  - Comparación de día en hora local (`_esMismoDiaLocal` con `_now()`), evitando desfases nocturnos UTC vs VET (UTC-4).
  - Nuevo predicado `necesitaActualizarTasas` y método `refrescarTasasSiDesactualizadas()` con cooldown anti-flapping (3 min) y escucha reactiva en `ConnectivityService.onConnectivityChanged` (debounce 2 s).
- **`lib/ui/screens/main_screen.dart`:** invoca `refrescarTasasSiDesactualizadas()` en `AppLifecycleState.resumed` y al entrar a la pestaña "Más" (`_onTabTapped(3)`), además de `onTabVisible()` en `MoreScreen`.

### C. Dictar Gasto sin conexión (Opción 1)
- **`lib/data/datasources/remote/gemini_service.dart`:** distingue `VoiceOfflineException` (corte de red, `SocketException`, `TimeoutException`, `http.ClientException`, HTTP `504`) de `VoiceServiceException` (`401`, `429` cuota, API Key personalizada, `502`/`503`). Conserva `_parseVoiceExpenseLocalFallback` en HTTP `200` sin `functionCall` (tolerancia a compras dictadas sin precio). Expone `close()` cuando posee su propio `http.Client`.
- **`lib/ui/widgets/voice_expense_sheet.dart`:** ante falta de conectividad (al abrir, por stream, `error_network` o `VoiceOfflineException`), muestra la vista "Dictar gasto necesita internet" sin activar micrófono ni caja de texto libre, con botón primario amarillo **Escribir gasto** y secundario **Cerrar**. Ante `VoiceServiceException` (ej. 429), muestra un banner informativo con el motivo real y botones **Escribir gasto** / **Reintentar** sin fingir falta de internet.
- **`lib/ui/screens/main_screen.dart`:** helper `_abrirFormularioManual(BuildContext rootContext)` con guarda `rootContext.mounted` y `hasPendingReplaceBlock`.

## 2. Guía de Pruebas Manuales en Dispositivo Físico

*(Controles verificados en `lib/ui/`)*

| # | Escenario | Ruta y control verificado en `lib/ui/` | Resultado esperado |
|---|---|---|---|
| 1 | **Avatar offline (con caché previa)** | Abrir app con internet → pestaña **Más** (`more_screen.dart:606`, `Key('more_account_avatar')`) → cerrar app → activar Modo Avión → reabrir y entrar a **Más**. | La foto de perfil se muestra al instante sin conexión. |
| 2 | **Avatar sin caché → reconexión** | Limpiar datos/caché o iniciar en Modo Avión → pestaña **Más** (`more_screen.dart:606`) → quitar Modo Avión y esperar ~2–3 s (o volver a entrar a **Más**). | Offline muestra la inicial del usuario (nunca círculo vacío). Al volver la red, la foto aparece sola sin tocar nada. |
| 3 | **Tasas fail-fast offline → reconexión** | Con tasas de otro día o recién instalada, activar Modo Avión → pestaña **Más** → tocar botón recargar (`more_rates_card.dart:120`, `Key('refresh_rates_btn')`). Luego quitar Modo Avión y volver a **Más**. | Offline responde al instante sin quedarse girando (muestra "Última registrada"). Al volver internet, actualiza automáticamente a "Actualizada hoy". |
| 4 | **Dictar gasto sin conexión** | En Modo Avión, pulsar `+` → **Dictar gasto** (`main_screen.dart:519`, `Key('add_menu_option_voice')`). Observar `voice_expense_sheet.dart:566` (`Key('voice_offline_title')`) y pulsar **Escribir gasto** (`voice_expense_sheet.dart:614`, `Key('voice_offline_manual_button')`). | No enciende el micrófono ni muestra caja de texto libre; muestra *"Dictar gasto necesita internet"*. Pulsar **Escribir gasto** abre el formulario manual en 1 toque. |
| 5 | **Privacidad al cerrar sesión** | Pestaña **Más** → engranaje de cuenta (`more_screen.dart:680`, `Key('btn_ajustes_cuenta')`) → cerrar sesión y vincular otra cuenta. | Nunca aparece la foto cacheada de la cuenta anterior. |
