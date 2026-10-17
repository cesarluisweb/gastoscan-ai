# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2 y Fase 5 (Closed Testing activa).
- **Tareas recientes:** `FIN-11` (Motor Multimoneda "Dos Lentes", Pulido Integral 10 Puntos y Soporte de IA) `Pendiente de validación 🧪`. `REL-01` `Pendiente de validación 🧪`. `UI-03` `Pendiente de validación 🧪`. `FIN-10` `Completada ✅`.
- **Documentación Técnica:** [ROADMAP.md](ROADMAP.md) y [DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md) actualizados.

## Decisiones Técnicas y de Negocio Recientes
- **FIN-11 (Pulido Integral Motor Multimoneda, UX 9 Puntos y Soporte de IA):**
  1. Etiquetas canónicas de liquidación (`En Bs. · precio a tasa BCV`, `En Bs. · precio a tasa P2P`, `En $ · efectivo o tarjeta`) con campo de Bolívares finales editable para redondeo comercial en punto de venta.
  2. Formulario de nuevo gasto desacoplado del lente activo (abre siempre en `USD` con `En Bs. · precio a tasa BCV` y sincroniza tasas en vivo desde `initState` también en `USD`).
  3. Edición completa de gastos en `panel.astro` (`✏️ Editar`) y reconstrucción de contexto indexado (`USD` + pastilla Bs. + tasas congeladas) en móvil y web.
  4. Alerta de discrepancia cuando la suma de ítems difiere del Monto Total (`> 0.05`).
  5. Conversión determinista de presupuestos y metas de ahorro al lente activo (`USD BCV`, `USDT P2P`, `EUR BCV`, `Bs.`) en `SummaryCard`, `AnalysisScreen` y `panel.astro`.
  6. Desambiguación IA: prioridad inmutable a `VES` cuando se dicta monto explícito en bolívares, y `BS_BCV` por defecto en compras en USD en Venezuela sin especificar efectivo.
  7. Descarga directa del APK en `index.astro` con cache-busting dinámico (`?b=$BUILD_NUM`).

## Errores y Fricciones a Evitar
- **Regla Estricta DESIGN.md §2.2:** Prohibido texto amarillo sobre fondo blanco/claro. El amarillo (`AppColors.primaryDark` / `primary`) solo se permite en iconos, bordes activos o fondos cuyo texto sea estrictamente negro.
- En `amount_parser.dart`: Nunca asumir que cadenas sin punto ni coma son céntimos cuando provienen de extracción IA o campos de formulario (`isPrice` debe ser `false`).
- En `CurrencyFormatter`: Nunca triangular conversiones entre USD y USDT por bolívares.
- En `BudgetBottomSheet`: Usar memoria de valor base ingresado por el usuario para evitar drift al alternar monedas.

## Próximo Paso Inmediato
- Esperar validación manual de César en dispositivo físico y panel web ([DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md)) para dar el visto bueno a `FIN-11`.
