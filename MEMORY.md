# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **Notificaciones v1.4.0 (Broadcast FCM & Quincenal IA):** `Completada ✅`. Validado en dispositivo por César (envío masivo probado con éxito). Graduadas reglas a `privacidad-seguridad.md`, `flutter-testing.md` y `flutter-desarrollo.md`.
- **UI-08, Flujo de Compra en ReviewExpenseScreen & UX-12:** `Pendiente de validación 🧪`. CI verde (Android build 617, commit `b5e00c5`). 431 pruebas pasando. Tarjeta única «Información General» (comercio, fecha y selector de moneda con borde amarillo activo), label «Concepto» en artículos, formato formal `0,00` sin símbolos sueltos y diálogo seguro de ajuste.
- **UX-13 (Guardar Gasto como Borrador y Flujo Seguro al Editar):** `Implementada 🔧`. Diálogo al dar atrás al editar gasto existente («¿Guardar modificaciones?» con «Guardar gasto», «Descartar», «Cancelar»), título «Editar gasto» en AppBar y notificación «Gasto actualizado con éxito». 3 pruebas adicionales en `review_expense_screen_layout_test.dart` (434 pruebas pasando).
- **UI-04 (Control de Presupuestos por Categoría & Enfoque Directo):** `Pendiente de validación 🧪`. CI verde (Android build 616, commit `13b828a`). 430 pruebas unitarias y de widgets pasando. Fila superior limpia (`maxLines: 1`), botón «Editar» reubicado junto a barra, chip «Asignar presupuesto» sutil sin subrayado, scroll/enfoque automático (`initialCategory`) con cursor negro (`textSelectionTheme`), borde enfocado en input, contenedor neutral y copy conciso.
- **Artefacto para pruebas:** Descargar `rindemas-dev-apk` desde el run de CI en curso tras push.

## Decisiones Técnicas y de Negocio Recientes
- Distribución de Gastos (Dona a 130px): Diámetro de 130px (`centerSpaceRadius: 41`, `radius: 24`) con 14px de separación hacia la lista para llegar a un poco menos de la mitad de la tarjeta (lista comienza al 48.6%), manteniendo márgenes exactos y columna alineada de porcentajes (graduado a `DESIGN.md`).
- Nomenclatura canónica de 4 lentes: `USD BCV`, `VES Bolívares`, `USDT P2P` y `EUR BCV` (sin paréntesis decorativos).
- Gamificación y Retención (RET-01): Registrado en Roadmap sistema de recompensas ("Puntos Rinde"), rachas protegidas con salvavidas, botón "Día sin gastos", calibración mensual sin culpa y canje por días de prueba de Rinde Más Pro.
- Almacenamiento de Fotos: Título de tarjeta en `MoreScreen` renombrado a `Almacenamiento de fotos`. Guardado local activado por defecto (`defaultGuardarFotos = true`).

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.

## Próximo Paso Inmediato
- Probar en *Rinde Más Dev* (build 617) la pantalla unificada de revisión de gastos (tarjeta Información General, Concepto y formato 0,00), presupuestos directos (UI-04) y guardado de borradores (UX-13).
