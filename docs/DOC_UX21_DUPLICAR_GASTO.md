# DOC UX-21: Duplicar Gasto (Móvil + Panel Web) y REL-04 / REL-03

> **Estado:** `Implementada 🔧` (pendiente de CI en verde y validación en dispositivo por César).
> **Versión:** `v1.6.0` (`pubspec.yaml:4`).

## 1. Resumen Técnico

- **Duplicar gasto en app móvil (`UX-21`):**
  - [expense_card.dart](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/expense_card.dart#L390-L435): Añade opción `Duplicar` (`expense_card_menu_duplicate`) en el menú `⋮`.
  - [dashboard_screen.dart](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/dashboard_screen.dart#L576-L585) y [expense_history_screen.dart](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/expense_history_screen.dart#L410-L423): Conectan `onDuplicate` abriendo `ReviewExpenseScreen(templateGasto: gasto)`.
  - [review_expense_screen.dart](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L36-L52): Precarga comercio, categoría, moneda, método de liquidación e ítems limpios (`id: null`, `gastoId: null`) con fecha de **hoy**, tasas vigentes (`_actualizarTasaPorFecha`), `_bolivaresAjustadosManualmente = false`, `rutaFotoLocal = null`, título `'Duplicar gasto'`, nuevo `UuidGenerator.generate()` y `SnackBar` fijo con **Deshacer** (`snackbar_undo_duplicate`).
- **Paridad en Panel Web (`UX-21`):**
  - [expense-money.js](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/lib/expense-money.js#L316-L407): Función pura `buildDuplicateExpensePrefill` con paridad matemática y bloqueo `EUR + BS_USDT`.
  - [panel.astro](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2076-L2107): Botón `.btn-duplicate-expense` en tarjetas que abre `#modal-expense` con título `"Duplicar gasto"`, fecha VET de hoy y tasas vivas.
- **Aviso de actualización (`REL-04`) y `portrait` en CI (`REL-03`):**
  - [update_service.dart](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/update_service.dart#L71-L152): Caché persistente (`getCachedUpdateInfo`) y control de descarte único por versión (`dismissBanner`), preservando el *throttle* de 4 h.
  - [main_screen.dart](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/main_screen.dart#L186-L237) y [more_screen.dart](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/more_screen.dart#L201-L245): Chequeo no bloqueante al arranque, píldora discreta `Nueva vX.Y.Z` y botón `Comprobar actualizaciones` en `Más → Sobre Rinde Más`. `landing/public/version.json` permanece en `1.0.0 / 1` durante Prueba Cerrada (`ci-distribucion.md:30`).
  - [firebase.json](file:///c:/Development/Control%20de%20gastos%20VE/firebase.json#L16-L24): `Cache-Control: no-cache` para `/version.json`.
  - [build_apk.yml](file:///c:/Development/Control%20de%20gastos%20VE/.github/workflows/build_apk.yml#L185-L199): Inyección idempotente de `<uses-feature android:name="android.hardware.screen.portrait" android:required="false"/>`.

## 2. Guía de Pruebas en Dispositivo y Web

> **SHA / Build CI:** *(Completar al finalizar CI en verde)*

1. **Duplicar gasto indexado (`USD BS_BCV` / `BS_USDT`):**
   - Ruta: `Inicio` o `Gastos` → menú `⋮` de un gasto de días anteriores → **Duplicar**.
   - Verificar: abre `ReviewExpenseScreen` titulado **Duplicar gasto**, fecha de **hoy**, sin foto adjunta, monto en USD intacto y bolívares recalculados a la tasa de hoy.
   - Guardar y confirmar que el gasto original sigue intacto, aparece la copia y el `SnackBar` muestra **Deshacer**. Probar **Deshacer** para confirmar borrado limpio.
2. **Duplicar gasto `VES` puro:**
   - Repetir sobre un gasto en bolívares sin indexación y verificar que conserva el monto en Bs. y actualiza su equivalente en USD a la tasa de hoy.
3. **Salir sin editar:**
   - Abrir **Duplicar** y presionar atrás de inmediato: debe cerrar sin diálogo de confirmación.
4. **Comprobar actualizaciones (`REL-04`):**
   - Ruta: `Más → Sobre Rinde Más → Comprobar actualizaciones`. Confirmar respuesta limpia sin errores ni bloqueos offline.
5. **Panel Web (`https://rindemas.cesarluis.com/panel`):**
   - Pulsar **⧉ Duplicar** en una factura de días anteriores; verificar título **Duplicar gasto**, fecha VET de hoy y creación de copia independiente al guardar.
