# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **Notificaciones v1.4.0 (Broadcast FCM & Quincenal IA):** `Pendiente de validación 🧪`. CI verde (Android build 609, commit `6c83b5c`). 420 pruebas unitarias y de widgets pasando. Integrado `firebase_messaging: ^15.1.3`, topic `anuncios_generales`, recordatorio quincenal de compras (sábados 18:30) con 4 mensajes rotativos del Asistente IA sincronizables online desde Firestore (`/config/recordatorios`), inactividad a 30 días, modal limpio en pantalla *Más* y guía en `docs/GUIA_BROADCAST_FIREBASE.md`.
- **UI-06, Desglose Bimonetario & ReviewExpenseScreen:** `Pendiente de validación 🧪`. CI verde (Android build 604, commit `2f14526`). 410 pruebas unitarias y de widgets pasando. Tarjetas independientes para Moneda, Monto Total y Forma de pago (USD/EUR). Selector fijo de 3 tasas en VES (`Dólar BCV`, `Euro BCV`, `USDT P2P`) y ajuste bidireccional de tasa al liquidar en bolívares.
- **Artefacto para pruebas:** Descargar `rindemas-dev-apk` desde el run de CI 40775534107.

## Decisiones Técnicas y de Negocio Recientes
- Notificaciones Masivas (Broadcast): Implementado con Firebase Cloud Messaging suscrito anónimamente a `anuncios_generales`. César puede emitir mensajes desde la consola web de Firebase sin servidor ni costos.
- Recordatorios Quincenales Dinámicos: Sábados 18:30 con banco de 4 mensajes del Asistente IA. Sincroniza desde Firestore (`config/recordatorios`) con fallback offline local.
- Inactividad a 30 días: Rediseñado el recordatorio de inactividad de 7 a 30 días para evitar fatiga de alertas; toque único sin reprogramación en bucle si el usuario no entra.
- UI Despejada en Más: Una sola fila `Notificaciones` con icono y flecha que abre una hoja modal inferior con los 3 interruptores independientes.
- Nomenclatura canónica de 4 lentes: `USD BCV`, `VES Bolívares`, `USDT P2P` y `EUR BCV` (sin paréntesis decorativos).
- Almacenamiento de Fotos: Título de tarjeta en `MoreScreen` renombrado a `Almacenamiento de fotos`. Guardado local activado por defecto (`defaultGuardarFotos = true`).

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.

## Próximo Paso Inmediato
- Probar en *Rinde Más Dev* (build 609) la fila de Notificaciones en Más, el modal inferior y realizar un envío de prueba desde Firebase Console al tema `anuncios_generales`.
