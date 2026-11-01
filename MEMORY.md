# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase A (Cierre Controlado APK Directo):** Implementada e integrada en `main` (redirects en `firebase.json` hacia landing, `version.json` de transición 1.0.0/build 1 para neutralizar G1–G4, paso de preservación eliminado en `deploy_web.yml`, eliminación de QRs legados y actualización de reglas).
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **Notificaciones v1.4.0 (Broadcast FCM & Quincenal IA):** `Completada ✅`. Validado en dispositivo por César (envío masivo probado con éxito). Graduadas reglas a `privacidad-seguridad.md`, `flutter-testing.md` y `flutter-desarrollo.md`.
- **UI-08, Flujo de Compra en ReviewExpenseScreen & UX-12:** `Pendiente de validación 🧪`. CI verde (Android build 622, commit `cab03e0`). 435 pruebas pasando. Tarjeta única «Información General», label «Concepto», capitalización automática (palabras en comercio, frases en concepto), formato formal `0,00` y diálogo seguro de ajuste.
- **UX-13 (Guardar Gasto como Borrador y Flujo Seguro al Editar):** `Pendiente de validación 🧪`. CI verde (Android build 620, commit `9d946da`). 434 pruebas pasando. Título dinámico «Editar gasto» en AppBar, diálogo al retroceder «¿Guardar modificaciones?» con «Guardar gasto», «Descartar» y «Cancelar», y aviso «Gasto actualizado con éxito».
- **UI-04 (Control de Presupuestos por Categoría & Scroll Automático Completo):** `Completada ✅`. Validado en dispositivo por César (scroll automático en todas las categorías, cursor negro, borde enfocado en input y contenedor neutral). Graduadas reglas a `DESIGN.md`, `flutter-desarrollo.md` y `flutter-testing.md`.
- **UI-14 (Autocategorización Semántica Local de Conceptos):** `Completada ✅`. Validado en dispositivo por César (autocategorización inmediata, cambio dinámico entre categorías, respeto de selección manual y protección de IA). Graduadas reglas a `flutter-desarrollo.md`.
- **Artefacto para pruebas:** Descargar `rindemas-dev-apk` desde el run de CI 41116447019.

## Decisiones Técnicas y de Negocio Recientes
- Distribución de Gastos (Dona a 130px): Diámetro de 130px (`centerSpaceRadius: 41`, `radius: 24`) con 14px de separación hacia la lista para llegar a un poco menos de la mitad de la tarjeta (lista comienza al 48.6%), manteniendo márgenes exactos y columna alineada de porcentajes (graduado a `DESIGN.md`).
- Nomenclatura canónica de 4 lentes: `USD BCV`, `VES Bolívares`, `USDT P2P` y `EUR BCV` (sin paréntesis decorativos).
- Gamificación y Retención (RET-01): Registrado en Roadmap sistema de recompensas ("Puntos Rinde"), rachas protegidas con salvavidas, botón "Día sin gastos", calibración mensual sin culpa y canje por días de prueba de Rinde Más Pro.
- Almacenamiento de Fotos: Título de tarjeta en `MoreScreen` renombrado a `Almacenamiento de fotos`. Guardado local activado por defecto (`defaultGuardarFotos = true`).
- Autocategorización Semántica Local (UI-14): Máquina de estados de 4 orígenes (`OrigenCategoria`), `clientKey` secuencial estable, normalización diacrítica previa y protección estricta de elecciones manuales y de IA (graduado a `flutter-desarrollo.md`).

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.
- Comandos Git de mutación (`.git/index.lock`) o red requieren `BypassSandbox: true` en Windows.

## Próximo Paso Inmediato
- Unidades E0-05a y E0-01 de RM-03 Fase 0A implementadas en local (neutralización de auto-reparaciones 474/850 con dryRun = true por defecto, arnés SQLite real en memoria con sqflite_common_ffi y pruebas de infraestructura listas). Pendiente validación de César para autorizar E0-02.
