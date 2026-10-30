# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **Notificaciones v1.4.0 (Broadcast FCM & Quincenal IA):** `Completada ✅`. Validado en dispositivo por César (envío masivo probado con éxito). Graduadas reglas a `privacidad-seguridad.md`, `flutter-testing.md` y `flutter-desarrollo.md`.
- **UI-08, Flujo de Compra en ReviewExpenseScreen & UX-12:** `Pendiente de validación 🧪`. CI verde (Android build 622, commit `cab03e0`). 435 pruebas pasando. Tarjeta única «Información General», label «Concepto», capitalización automática (palabras en comercio, frases en concepto), formato formal `0,00` y diálogo seguro de ajuste.
- **UX-13 (Guardar Gasto como Borrador y Flujo Seguro al Editar):** `Pendiente de validación 🧪`. CI verde (Android build 620, commit `9d946da`). 434 pruebas pasando. Título dinámico «Editar gasto» en AppBar, diálogo al retroceder «¿Guardar modificaciones?» con «Guardar gasto», «Descartar» y «Cancelar», y aviso «Gasto actualizado con éxito».
- **UI-04 (Control de Presupuestos por Categoría & Scroll Automático Completo):** `Pendiente de validación 🧪`. CI verde (Android build 622, commit `cab03e0`). 435 pruebas pasando. Migrado a `SingleChildScrollView` (resuelve omisión de layout en categorías inferiores como Entretenimiento y Otros), listener post-frame al desplegarse el teclado (`bottomInset > 0`) y alineación vertical limpia.
- **UI-14 (Autocategorización Semántica Local de Conceptos):** `Implementada 🔧`. Clasificador determinista y offline (`CategoryClassifierService`), máquina de estados `OrigenCategoria` de 4 estados, unificación con fallback de voz en `gemini_service.dart`, sincronización de impuestos e identidad estable `clientKey`.
- **Artefacto para pruebas:** Descargar `rindemas-dev-apk` desde el run de CI 41092016500.

## Decisiones Técnicas y de Negocio Recientes
- Distribución de Gastos (Dona a 130px): Diámetro de 130px (`centerSpaceRadius: 41`, `radius: 24`) con 14px de separación hacia la lista para llegar a un poco menos de la mitad de la tarjeta (lista comienza al 48.6%), manteniendo márgenes exactos y columna alineada de porcentajes (graduado a `DESIGN.md`).
- Nomenclatura canónica de 4 lentes: `USD BCV`, `VES Bolívares`, `USDT P2P` y `EUR BCV` (sin paréntesis decorativos).
- Gamificación y Retención (RET-01): Registrado en Roadmap sistema de recompensas ("Puntos Rinde"), rachas protegidas con salvavidas, botón "Día sin gastos", calibración mensual sin culpa y canje por días de prueba de Rinde Más Pro.
- Almacenamiento de Fotos: Título de tarjeta en `MoreScreen` renombrado a `Almacenamiento de fotos`. Guardado local activado por defecto (`defaultGuardarFotos = true`).

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.

## Próximo Paso Inmediato
- Validar en CI la autocategorización semántica local de conceptos (UI-14) y monitorear la suite de pruebas.
