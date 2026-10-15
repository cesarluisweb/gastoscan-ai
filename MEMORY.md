# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2 (UI-01, UI-05, UX-06, UX-07, FIN-09) `Implementada 🔧`. Fase 3 de Auditoría Integral `Completada ✅`.

## Decisiones Técnicas y de Negocio Recientes
- **UI-01 Iconografía Canónica:** Centralizada en `AppConstants.getCategoryIcon(cat)` para Inicio, Gastos, Análisis y Revisión.
- **UI-05 & UX-06 AppBar y Gráfico Inicio:** Destellos `Icons.auto_awesome` en AppBar y etiqueta `+X categorías` en consolidación de categorías secundarias.
- **UX-07 Desglose Gastos:** Mini-íconos por ítem y expansor interactivo `Ver X artículos más` para compras de más de 4 productos.
- **FIN-09 Calculadora Cambiaria:** Conversor bidireccional en tiempo real, chips directos de tasa (Dólar BCV, Euro BCV, USDT, Personalizada), tabla comparativa de brecha, copiado rápido a portapapeles y pre-llenado de gasto.

## Errores y Fricciones a Evitar
- `AppConstants.categorias`: El catálogo canónico son 8 categorías fijas.
- Íconos de categorías deben consultarse exclusivamente vía `AppConstants.getCategoryIcon(cat)`.
- `SettingsProvider` expone `tasaCambioVesEur`, no `tasaCambioEurUsd`.

## Próximo Paso Inmediato
- Monitorear CI en verde y proceder con validación de Fase 6.2 en dispositivo físico.
