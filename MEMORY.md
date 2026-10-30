# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **Notificaciones v1.4.0 (Broadcast FCM & Quincenal IA):** `Completada ✅`. Validado en dispositivo por César (envío masivo probado con éxito). Graduadas reglas a `privacidad-seguridad.md`, `flutter-testing.md` y `flutter-desarrollo.md`.
- **UI-08, Flujo de Compra en ReviewExpenseScreen & UX-12:** `Pendiente de validación 🧪`. CI verde (Android build 611, commit `68c670c`). 421 pruebas pasando. Formulario de compra reordenado, eliminado recuadro gris anidado en el total, advertencia en vivo de discrepancia y diálogo seguro con «Revisar artículos».
- **UX-13 (Guardar Gasto como Borrador / Por revisar):** `Pendiente de validación 🧪`. CI verde (Android build 613, commit `0e7df32`). 428 pruebas pasando. Diálogo con 3 opciones al dar atrás con datos (`Guardar borrador`, `Descartar`, `Seguir editando`), botón sutil en AppBar (`Icons.bookmark_border_rounded`), persistencia en `scan_queue` SQLite (`ready`), y «Comercio no especificado» si comercio está vacío.
- **UI-04 (Control de Presupuestos por Categoría & Enfoque Directo):** `Implementada 🔧`. Fila superior limpia (`maxLines: 1`), botón «Editar» reubicado junto a barra, chip «Asignar presupuesto» sutil sin subrayado, scroll/enfoque automático (`initialCategory`) con cursor negro (`textSelectionTheme`), borde enfocado en input, contenedor neutral y copy conciso.
- **Artefacto para pruebas:** Descargar `rindemas-dev-apk` desde el run de CI 40877979791.

## Decisiones Técnicas y de Negocio Recientes
- Distribución de Gastos (Dona a 130px): Diámetro de 130px (`centerSpaceRadius: 41`, `radius: 24`) con 14px de separación hacia la lista para llegar a un poco menos de la mitad de la tarjeta (lista comienza al 48.6%), manteniendo márgenes exactos y columna alineada de porcentajes (graduado a `DESIGN.md`).
- Nomenclatura canónica de 4 lentes: `USD BCV`, `VES Bolívares`, `USDT P2P` y `EUR BCV` (sin paréntesis decorativos).
- Gamificación y Retención (RET-01): Registrado en Roadmap sistema de recompensas ("Puntos Rinde"), rachas protegidas con salvavidas, botón "Día sin gastos", calibración mensual sin culpa y canje por días de prueba de Rinde Más Pro.
- Almacenamiento de Fotos: Título de tarjeta en `MoreScreen` renombrado a `Almacenamiento de fotos`. Guardado local activado por defecto (`defaultGuardarFotos = true`).

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.

## Próximo Paso Inmediato
- Probar en *Rinde Más Dev* (build 615) el flujo de edición directa de presupuestos por categoría (`UI-04`) y el guardado de borradores (`UX-13`).
