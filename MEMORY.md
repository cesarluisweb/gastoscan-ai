# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2. Refinamiento tras feedback de César en UX-07 y FIN-09. UI-01, UI-05, UX-06, UX-07 `Completada ✅`, FIN-09 en `Pendiente de validación 🧪`.
- **Documentación Técnica:** [DOC_FASE_6_2.md](DOC_FASE_6_2.md) y [ROADMAP.md](ROADMAP.md) actualizados.

## Decisiones Técnicas y de Negocio Recientes
- **UX-07 (Refinado):** Superficie blanca continua sin recuadro gris ni label 'Desglose de Ítems:', delimitada por `Divider` sutil. Expansor en pastilla sutil con texto negro carbón `AppColors.textPrimary`.
- **FIN-09 (Refinado):** Pastilla de tasa swap interactiva (`calc_swap_button`) para invertir orden Divisa/Bolívares, botón de copia dinámico (`Copiar Bs.` / `Copiar USD/EUR/USDT`), comparativa con texto negro carbón y eliminación de dropdown innecesario.
- **Iconografía e IA:** `AppConstants.getCategoryIcon`, `Icons.auto_awesome` en AppBar de Inicio y agrupación `+X categorías`.

## Errores y Fricciones a Evitar
- **Regla Estricta DESIGN.md §2.2:** Prohibido texto amarillo sobre fondo blanco/claro. El amarillo (`AppColors.primaryDark` / `primary`) solo se permite en iconos, bordes activos o fondos cuyo texto sea estrictamente negro.
- `AppConstants.categorias`: El catálogo canónico son 8 categorías fijas.
- Íconos de categorías deben consultarse exclusivamente vía `AppConstants.getCategoryIcon(cat)`.
- En `currency_calculator_screen_test.dart`: Si se usa `GastoModel`, importar explícitamente `gasto_model.dart`.
- Evitar navegación real a pantallas que requieran SQLite no mockeado (`DatabaseHelper.instance`) en tests de widgets.

## Próximo Paso Inmediato
- Validar CI en verde tras push de refinamientos de Fase 6.2 y esperar validación de César en dispositivo.

