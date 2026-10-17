# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2 y Fase 5 (Closed Testing activa).
- **Tareas recientes:** `FIN-11` (Motor Multimoneda "Dos Lentes", Pulido Integral 10 Puntos y Soporte de IA) `Pendiente de validación 🧪`. `REL-01` `Pendiente de validación 🧪`. `UI-03` `Pendiente de validación 🧪`. `FIN-10` `Completada ✅`.
- **Documentación Técnica:** [ROADMAP.md](ROADMAP.md) y [DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md) actualizados.

## Decisiones Técnicas y de Negocio Recientes
- **FIN-11 (Pulido Integral Motor Multimoneda y Soporte de IA - 10 Puntos):**
  1. 3 opciones de liquidación USD/EUR (`Pagado en Bs. (a BCV)`, `Pagado en Bs. (a USDT P2P)`, `Pagado en $ (Divisa directa)`) en Flutter y web (`panel.astro`).
  2. Selector de 4 lentes canónicos (`USD BCV`, `USDT P2P`, `EUR BCV`, `Bs.`) en `SummaryCard`, `AnalysisScreen` y `panel.astro`.
  3. Tarjeta dedicada en `MoreScreen` para "Moneda Principal de Reportes" con nomenclatura unificada.
  4. Eliminación visual de la insignia "Brecha capturada" para mantener la UI limpia.
  5. Memoria de monto base en `BudgetBottomSheet` y `panel.astro` para eliminar deriva (drift) por redondeo y paridad 1:1 USD/USDT.
  6. Fallbacks amigables automáticos (`Compra general`, `Producto 1`, `Producto 2`) sin bloqueos.
  7. Restauración incondicional de tasas históricas al cambiar fecha (`ReviewExpenseScreen` y `panel.astro`).
  8. Calculadora cambiaria limpia: inicio vacío sin botón "X" prematuro ni 1 prepoblado, y remoción de badge duplicado.
  9. Paridad web total en `panel.astro` con consulta dinámica de tasas históricas en DolarAPI.
  10. Soporte IA: `metodo_liquidacion` (`BS_BCV`, `BS_USDT`, `DIVISA`) en Gemini y Cloudflare Workers, preselección automática en revisión y lentes preservados en contexto de chat.

## Errores y Fricciones a Evitar
- **Regla Estricta DESIGN.md §2.2:** Prohibido texto amarillo sobre fondo blanco/claro. El amarillo (`AppColors.primaryDark` / `primary`) solo se permite en iconos, bordes activos o fondos cuyo texto sea estrictamente negro.
- En `amount_parser.dart`: Nunca asumir que cadenas sin punto ni coma son céntimos cuando provienen de extracción IA o campos de formulario (`isPrice` debe ser `false`).
- En `CurrencyFormatter`: Nunca triangular conversiones entre USD y USDT por bolívares.
- En `BudgetBottomSheet`: Usar memoria de valor base ingresado por el usuario para evitar drift al alternar monedas.

## Próximo Paso Inmediato
- Esperar validación manual de César en dispositivo físico y panel web ([DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md)) para dar el visto bueno a `FIN-11`.
