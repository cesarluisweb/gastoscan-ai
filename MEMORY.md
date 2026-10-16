# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2 y Fase 5 (Closed Testing activa con 12 evaluadores).
- **Tareas recientes:** `REL-01` (Transición a Google Play y Silenciamiento de Actualizaciones Fantasma) `Implementada 🔧`. `FIN-10` `Implementada 🔧`. `UI-01`, `UI-05`, `UX-06`, `UX-07`, `UX-11`, `AI-02`, `AI-03`, `AI-04`, `SEC-13` `Completada ✅`. `FIN-09` `Pendiente de validación 🧪`. `UI-03` y `UX-10` `Implementada 🔧`.
- **Documentación Técnica:** [ROADMAP.md](ROADMAP.md) y [DOC_FASE_6_2.md](DOC_FASE_6_2.md) actualizados.

## Decisiones Técnicas y de Negocio Recientes
- **REL-01 (Transición a Google Play y Fin de Actualizaciones Fantasma):** Se silenciaron los popups automáticos de `checkForUpdate` en `DashboardScreen` y `MainScreen`. En `MoreScreen`, el botón "Buscar" se reemplazó por "Google Play" que abre directamente la ficha de la app en la tienda oficial. La landing mantiene el APK durante los 14 días de prueba cerrada (Fase 1) y migrará a Google Play exclusivo una vez aprobada la versión pública (Fase 2).
- **FIN-10 (Paridad Directa 1:1 USD/USDT e Inmutabilidad de Totales):** Conversión directa 1:1 entre USD y USDT en `CurrencyFormatter` y `panel.astro` sin pasar por VES a tasa BCV. Previene la distorsión artificial de la brecha cambiaria en divisas duras y fija los acumulados mensuales.
- **UI-03 (Semántica Presupuesto 85% Unificada):** `AppColors.success` (`#10B981`) centralizado vía `getBudgetProgressColor`: verde $<85\%$, ámbar $\ge 85\%$ y rojo $\ge 100\%$ o sobregiro en Inicio (`SummaryCard`), Análisis (`AnalysisScreen`) y Web (`panel.astro`).
- **UX-10 (Zona de Peligro Independiente):** "Eliminar cuenta y datos" aislado en su propia tarjeta al final de "Más". "Respaldo en la Nube" muestra botón limpio `OutlinedButton` de "Cerrar sesión".
- **Google Play (Closed Testing):** Pista cerrada activa en Play Console con 12 evaluadores requeridos.

## Errores y Fricciones a Evitar
- **Regla Estricta DESIGN.md §2.2:** Prohibido texto amarillo sobre fondo blanco/claro. El amarillo (`AppColors.primaryDark` / `primary`) solo se permite en iconos, bordes activos o fondos cuyo texto sea estrictamente negro.
- `AppConstants.categorias`: El catálogo canónico son 8 categorías fijas.
- Íconos de categorías deben consultarse exclusivamente vía `AppConstants.getCategoryIcon(cat)`.
- `ScanQueueProvider` en tests de widgets: instanciar siempre con `autoProcess: false` y llamar `dispose()` en `tearDown` para evitar timeouts de `pumpAndSettle`.
- En `amount_parser.dart`: Nunca asumir que cadenas sin punto ni coma son céntimos cuando provienen de extracción IA o campos de formulario (`isPrice` debe ser `false`).
- En `CurrencyFormatter`: Nunca triangular conversiones entre USD y USDT por bolívares.

## Próximo Paso Inmediato
- Confirmar CI en verde tras push con REL-01.
- César descarga AAB del último CI para actualizar pista cerrada en Google Play Console cuando lo requiera.


