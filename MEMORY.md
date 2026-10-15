# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 3 de Auditoría Integral en `Pendiente de validación 🧪` (en dispositivo por César).
- **Roadmap Actualizado:** Dividido en [ROADMAP.md](ROADMAP.md) (activo, con nueva Fase 6.2 de UI/UX y Calculadora Cambiaria) y [ROADMAP_HISTORICO.md](ROADMAP_HISTORICO.md) (memoria técnica y de marketing de hitos completados).

## Decisiones Técnicas y de Negocio Recientes
- **Roadmap Desacoplado:** `ROADMAP_HISTORICO.md` preserva todas las fases 1 a 4, 6, 7.1 y tareas completadas. `ROADMAP.md` mantiene solo tareas activas, métricas y fases futuras.
- **Fase 6.2 (UI/UX & Calculadora):** Códigos `UI-01` a `UI-05`, `UX-06` a `UX-10`, `AI-02` (Pago Móvil/Zelle transparente al flujo de escáner) y `FIN-09` (Calculadora Cambiaria exclusiva en Más; modal `+` solo para gastos).
- **Chat IA Analítico y USDT:** 5 chips analíticos diferenciados (fugas, recorte, precios, patrones y compras pendientes), saludo inicial que guía sobre capacidades (sin chips de acción directa para no ensuciar datos) e inyección de `tasa_usdt` en el contexto de Gemini.

## Errores y Fricciones a Evitar
- `AppConstants.categorias`: El catálogo canónico son 8 categorías fijas.
- Íconos de categorías deben centralizarse en un solo método (`AppConstants.getCategoryIcon`), evitando discrepancias entre pantallas.
- `SettingsProvider` expone `tasaCambioVesEur`, no `tasaCambioEurUsd`.

## Próximo Paso Inmediato
- César valida en dispositivo físico las mejoras de Fase 3 y los chips analíticos del chat.
