# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2 y Fase 5 (Closed Testing activa con 12 evaluadores).
- **Tareas recientes:** `FIN-11` (Motor Multimoneda "Dos Lentes" y SQLite v17) `Implementada 🔧`. `REL-01` `Implementada 🔧`. `FIN-10` `Completada ✅`. `UI-01`, `UI-05`, `UX-06`, `UX-07`, `UX-11`, `AI-02`, `AI-03`, `AI-04`, `SEC-13` `Completada ✅`. `FIN-09` `Pendiente de validación 🧪`. `UI-03` y `UX-10` `Implementada 🔧`.
- **Documentación Técnica:** [ROADMAP.md](ROADMAP.md) y [DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md) actualizados.

## Decisiones Técnicas y de Negocio Recientes
- **FIN-11 (Motor Multimoneda "Dos Lentes" USD BCV vs USDT P2P):** SQLite v17 con columnas `total_usdt INTEGER` (en céntimos inmutables) y `tasa_usdt REAL`. Distingue gastos en bolívares (convertidos a USD BCV y USDT P2P para capturar la brecha de arbitraje) de gastos en divisas (paridad 1:1 directa). Selector de método de liquidación `[ Pagado en Bs. a tasa BCV ]` vs `[ Pagado en Divisa ]` en ReviewExpenseScreen. Switch de lente rápido en SummaryCard y AnalysisScreen con insignia de "Brecha capturada". Paridad total en panel.astro eliminando multiplicador prohibido `* 1.08`.
- **REL-01 (Transición a Google Play y Fin de Actualizaciones Fantasma):** Se silenciaron los popups automáticos de `checkForUpdate` en `DashboardScreen` y `MainScreen`. En `MoreScreen`, el botón "Buscar" se reemplazó por "Google Play" que abre directamente la ficha de la app en la tienda oficial.
- **UI-03 (Semántica Presupuesto 85% Unificada):** `AppColors.success` (`#10B981`) centralizado vía `getBudgetProgressColor`: verde $<85\%$, ámbar $\ge 85\%$ y rojo $\ge 100\%$ o sobregiro en Inicio (`SummaryCard`), Análisis (`AnalysisScreen`) y Web (`panel.astro`).
- **Google Play (Closed Testing):** Pista cerrada activa en Play Console con 12 evaluadores requeridos.

## Errores y Fricciones a Evitar
- **Regla Estricta DESIGN.md §2.2:** Prohibido texto amarillo sobre fondo blanco/claro. El amarillo (`AppColors.primaryDark` / `primary`) solo se permite en iconos, bordes activos o fondos cuyo texto sea estrictamente negro.
- `AppConstants.categorias`: El catálogo canónico son 8 categorías fijas.
- Íconos de categorías deben consultarse exclusivamente vía `AppConstants.getCategoryIcon(cat)`.
- `ScanQueueProvider` en tests de widgets: instanciar siempre con `autoProcess: false` y llamar `dispose()` en `tearDown` para evitar timeouts de `pumpAndSettle`.
- En `amount_parser.dart`: Nunca asumir que cadenas sin punto ni coma son céntimos cuando provienen de extracción IA o campos de formulario (`isPrice` debe ser `false`).
- En `CurrencyFormatter`: Nunca triangular conversiones entre USD y USDT por bolívares.

## Próximo Paso Inmediato
- Monitorear GitHub Actions CI tras el push y confirmar `conclusion: success`.
- Entregar a César guía de pruebas de FIN-11 para validación en dispositivo.


