# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Optimización de Tokens de Chat / Blindaje de Cuota IA (SEC-13 / AI-03) y Fase 6.2 en `Implementada 🔧`.
- **Roadmap Actualizado:** [ROADMAP.md](ROADMAP.md) refleja tareas y optimizaciones en curso.

## Decisiones Técnicas y de Negocio Recientes
- **Optimización de Tokens de Chat:** Resumen semántico precalculado en SQLite (totales por categoría, top 10 productos del mes, últimas 5 compras) y ventana deslizante de 5 mensajes en `ChatScreen`, reduciendo >80% de tokens de entrada.
- **Blindaje en Cloudflare Gateway:** Límite diario invisible de seguridad de 50 peticiones/día por UID con mensaje amigable invitando a apoyar el proyecto (`Más > Apoyar el proyecto ☕`) y bypass para API Keys propias.
- **Fase 6.2 (UI/UX & Calculadora):** Iconografía canónica centralizada (`AppConstants.getCategoryIcon`), Calculadora Cambiaria en Más y desglose directo interactivo en tarjetas de gasto.

## Errores y Fricciones a Evitar
- `AppConstants.categorias`: El catálogo canónico son 8 categorías fijas.
- Íconos de categorías deben consultarse exclusivamente vía `AppConstants.getCategoryIcon(cat)`.
- `GeminiExtractionResult` requiere obligatoriamente `impuestoIva`.
- En `GastoModel`, `uuid` es `final String uuid` no nulo (`??` posterior causa `dead_null_aware_expression`).

## Próximo Paso Inmediato
- Confirmar CI en verde tras push a `main`.
