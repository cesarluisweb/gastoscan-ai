# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2 y Fase 5 (Closed Testing activa).
- **Tareas recientes:** `FIN-11` (Motor Multimoneda "Dos Lentes", Pulido Integral 10 Puntos y Soporte de IA) `Pendiente de validación 🧪`. `REL-01` `Pendiente de validación 🧪`. `UI-03` `Pendiente de validación 🧪`. `FIN-10` `Completada ✅`.
- **Documentación Técnica:** [ROADMAP.md](ROADMAP.md) y [DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md) actualizados.
- **Herramientas de Mantenimiento:** `scripts/wait_ci.ps1` monitorea GitHub Actions como proceso dormido único (regla permanente en `AGENTS.md` §2). El repositorio está **Público** durante el desarrollo; vuelve a Privado al terminar.

## Decisiones Técnicas y de Negocio Recientes
- **FIN-11 (Motor Multimoneda "Dos Lentes", Pulido Integral y Soporte de IA):**
  1. Tres opciones canónicas de liquidación con campo de Bolívares finales editable para redondeo comercial en caja.
  2. Desacoplamiento del formulario de nuevo gasto (abre en USD con `En Bs. · precio a tasa BCV`).
  3. Switch de 4 lentes táctil en `SummaryCard`: envuelto en `Material`, `Expanded`, `HitTestBehavior.opaque` y callback `onMonedaChanged` directo desde `DashboardScreen`.
  4. Carga inmediata de tasas en `SettingsProvider` (descartando semillas `<= 50.0`) y respaldo en cascada (`DolarAPI` -> `Yadio Oficial` -> `jsDelivr`).
  5. `_cargarTasasChips`: consulta unificada de tasas en `ReviewExpenseScreen` (evita 9 peticiones en serie) y conversión unificada de categorías por lente en `DashboardScreen`.
  6. Edición en `panel.astro` con reconstrucción de contexto y paridad multimoneda.

## Errores y Fricciones a Evitar
- **Regla Estricta DESIGN.md §2.2:** Prohibido texto amarillo sobre fondo blanco/claro.
- En `SettingsProvider`: Nunca demorar la carga de SharedPreferences esperando a Firestore en red.
- En `ExchangeRateService`: Descartar siempre tasas `<= 50.0` para prevenir residuos de caché obsoleta.
- En `SummaryCard`: Envolver los switches táctiles en `Material` con área accesible para no perder toques en listas Android.

## Próximo Paso Inmediato
- Instalar el **build 494** (Run 490) en dispositivo y validar: (1) que las tasas carguen en vivo (~880 Bs BCV) en MoreScreen, ReviewExpenseScreen y CurrencyCalculatorScreen y no en 40, (2) selector táctil de 4 lentes en Inicio, (3) lentes y edición de gastos en el panel web. Cierra `FIN-11` ([DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md)).
