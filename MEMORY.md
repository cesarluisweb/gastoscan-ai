# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (Working tree con correcciones de E0-02 + Sprint Teléfono ReviewExpenseScreen; sin commit/push).
- **Fase A & Fase 5:** Integradas en `main`; Closed Testing activo en Google Play.
- **Sprint Teléfono (ReviewExpenseScreen):**
  - Implementada inicialización de moneda desde `settings.monedaPrincipal` con soporte asíncrono vía `didChangeDependencies`.
  - Re-selección de moneda activa y métodos de liquidación convertidos en no-op estricto (no borra tasas ni bolívares manuales).
  - Cambio de moneda sin conversión de importe escrito ni de artículos.
  - Gastos indexados: preservación de bolívares efectivamente pagados ante cambio de fecha; bloqueo normativo de `EUR + BS_USDT`.
  - Nomenclatura normalizada a `VES Bs.` en selectores y descripciones breves en Más (`Dólar oficial`, `Bolívares`, `Dólar digital`, `Euro oficial`).
  - Eliminados fallbacks a 850.0 y umbral 50.0 en ReviewExpenseScreen.
  - 8 pruebas de widget obligatorias añadidas en `test/screens/review_expense_screen_layout_test.dart`.
  - Entorno local sin Flutter/Java/Android SDK: APK de revisión requiere compilación vía GitHub Actions (`rindemas-dev-apk`).
- **RM-03 E0-02:** Estado previo conservado en working tree. Cero commits/push.

## Decisiones Técnicas y de Negocio Recientes
- ReviewExpenseScreen: `_userTouchedCurrency` evita sobrescribir preferencia cuando el usuario interactúa manualmente.
- `_buildLiquidacionPill` y selector de divisas no mutan estado si la opción pulsada ya está activa.
- Coexistencia de revisión en teléfono: `com.cesarluis.rindemas.dev` (*Rinde Más Dev*), preservando app oficial.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido hacer commit o push sin autorización expresa de César.
