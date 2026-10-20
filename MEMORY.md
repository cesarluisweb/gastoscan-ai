# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Implementación de `REL-02` (Edge-to-Edge nativo en Android 15/16 y adaptabilidad de interfaz para pantallas grandes/tablets con ancho máximo de 600dp centrado).
- **Estado de CI:** Build 524 confirmado en verde (`conclusion: success`, commit `eba23be`).
- **Estado General:** `REL-02` en `Implementada 🔧` previo a confirmación por CI.

## Decisiones Técnicas y de Negocio Recientes
- Edge-to-Edge habilitado en capas nativa (MainActivity.kt con WindowCompat y barras transparentes en styles.xml) y Dart (SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)).
- Ancho máximo centrado (600dp) en MainScreen, ReviewExpenseScreen, CurrencyCalculatorScreen, ShoppingListScreen y ReceiptGalleryScreen para prevenir estiramiento en tablets/foldables (Android 16).
- Optimización DEX (R8) postergada para después de la prueba cerrada de 14 días (plazo Play Store feb 2027), evitando riesgos de regresión en testers.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Coordinación de Closed Testing (Fase 5) o avance en tareas planificadas de UI (`UI-02` contraste en Más, `UI-04` botón de presupuestos, `UI-06` orden canónico de monedas).
