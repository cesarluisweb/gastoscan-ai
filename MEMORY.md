# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **Notificaciones v1.4.0 (Broadcast FCM & Quincenal IA):** `Pendiente de validación 🧪`. CI verde (Android build 609, commit `6c83b5c`). 420 pruebas unitarias y de widgets pasando. Integrado `firebase_messaging: ^15.1.3`, topic `anuncios_generales`, recordatorio quincenal de compras (sábados 18:30) con 4 mensajes rotativos del Asistente IA sincronizables online desde Firestore (`/config/recordatorios`), inactividad a 30 días, modal limpio en pantalla *Más* y guía en `docs/GUIA_BROADCAST_FIREBASE.md`.
- **UI-08, Flujo de Compra en ReviewExpenseScreen & UX-12:** `Pendiente de validación 🧪`. CI verde (Android build 611, commit `68c670c`). 421 pruebas pasando. Reordenado el formulario de compra: ¿Dónde compraste? $\rightarrow$ ¿Cuándo compraste? $\rightarrow$ ¿En qué moneda están los precios? $\rightarrow$ ¿Qué compraste? $\rightarrow$ Monto total $\rightarrow$ ¿Cómo pagaste? (solo en USD/EUR). Eliminado el recuadro gris anidado en el total, advertencia en vivo de discrepancia, autoasignación al guardar para gastos de un solo artículo y diálogo seguro con «Revisar artículos» como acción primaria. Registrado `UX-12` en `ROADMAP.md`.
- **Artefacto para pruebas:** Descargar `rindemas-dev-apk` desde el run de CI 40812119999.

## Decisiones Técnicas y de Negocio Recientes
- Notificaciones Masivas (Broadcast): Implementado con Firebase Cloud Messaging suscrito anónimamente a `anuncios_generales`. César puede emitir mensajes desde la consola web de Firebase sin servidor ni costos.
- Recordatorios Quincenales Dinámicos: Sábados 18:30 con banco de 4 mensajes del Asistente IA. Sincroniza desde Firestore (`config/recordatorios`) con fallback offline local.
- Inactividad a 30 días: Rediseñado el recordatorio de inactividad de 7 a 30 días para evitar fatiga de alertas; toque único sin reprogramación en bucle si el usuario no entra.
- UI Despejada en Más: Una sola fila `Notificaciones` con icono y flecha que abre una hoja modal inferior con los 3 interruptores independientes.
- Distribución de Gastos (Dona a 130px): Diámetro de 130px (`centerSpaceRadius: 41`, `radius: 24`) con 14px de separación hacia la lista para llegar a un poco menos de la mitad de la tarjeta (lista comienza al 48.6%), manteniendo márgenes exactos y columna alineada de porcentajes.
- Nomenclatura canónica de 4 lentes: `USD BCV`, `VES Bolívares`, `USDT P2P` y `EUR BCV` (sin paréntesis decorativos).
- Gamificación y Retención (RET-01): Registrado en Roadmap sistema de recompensas ("Puntos Rinde"), rachas protegidas con salvavidas, botón "Día sin gastos", calibración mensual sin culpa y canje por días de prueba de Rinde Más Pro.
- Almacenamiento de Fotos: Título de tarjeta en `MoreScreen` renombrado a `Almacenamiento de fotos`. Guardado local activado por defecto (`defaultGuardarFotos = true`).

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.

## Próximo Paso Inmediato
- Probar en *Rinde Más Dev* (build 611) el nuevo flujo de registro y revisión de compras, la ausencia del recuadro anidado en el total, la advertencia en vivo de discrepancia y el guardado con un solo artículo.
