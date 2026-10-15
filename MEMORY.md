# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2 verificada en CI (Run 38746698996 en verde). UI-01, UI-05, UX-06, UX-07 `Completada ✅`, FIN-09 en `Pendiente de validación 🧪`.
- **Documentación Técnica:** [DOC_FASE_6_2.md](DOC_FASE_6_2.md) y [ROADMAP.md](ROADMAP.md) actualizados.

## Decisiones Técnicas y de Negocio Recientes
- **Fase 6.2 (UI/UX & Calculadora):** Iconografía canónica centralizada (`AppConstants.getCategoryIcon`), Calculadora Cambiaria en Más (`CurrencyCalculatorScreen`), agrupación `+X categorías` en dashboard y desglose interactivo en tarjetas de gasto con expansor de más de 4 ítems.
- **Optimización de Tokens de Chat:** Resumen semántico precalculado en SQLite y ventana deslizante de 5 mensajes en `ChatScreen`, reduciendo >80% de tokens de entrada.
- **Blindaje en Cloudflare Gateway:** Límite diario invisible de 50 peticiones/día por UID con mensaje amigable y bypass para API Keys propias.

## Errores y Fricciones a Evitar
- `AppConstants.categorias`: El catálogo canónico son 8 categorías fijas.
- Íconos de categorías deben consultarse exclusivamente vía `AppConstants.getCategoryIcon(cat)`.
- En `currency_calculator_screen_test.dart`: Si se usa `GastoModel`, importar explícitamente `gasto_model.dart`.
- Evitar navegación real a pantallas que requieran SQLite no mockeado (`DatabaseHelper.instance`) en tests de widgets.
- `GeminiExtractionResult` requiere obligatoriamente `impuestoIva`.

## Próximo Paso Inmediato
- Esperar validación en dispositivo de la Calculadora Cambiaria (FIN-09) por César.
