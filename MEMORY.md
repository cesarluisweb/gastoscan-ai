# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2 y Fase 5 (Closed Testing activa).
- **Tareas recientes:** `FIN-11` (Motor Multimoneda "Dos Lentes", Pulido Integral 10 Puntos y Soporte de IA) `Pendiente de validación 🧪`. `REL-01` `Pendiente de validación 🧪`. `UI-03` `Pendiente de validación 🧪`. `FIN-10` `Completada ✅`.
- **Documentación Técnica:** [ROADMAP.md](ROADMAP.md) y [DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md) actualizados.

## Decisiones Técnicas y de Negocio Recientes
- **FIN-11 (Pulido Integral Motor Multimoneda, UX y Despliegue - 9 Puntos):**
  1. Etiquetas oficiales (`En Bs. · precio a tasa BCV`, `En Bs. · precio a tasa P2P`, `En $ · efectivo o tarjeta`) y campo editable de Bolívares por redondeo comercial.
  2. Paridad total de almacenamiento: liquidación en Bs guarda `moneda: 'VES'`, `total_original` en céntimos de Bs, y escala ítems a VES.
  3. Desacoplamiento de moneda inicial del formulario vs. lente activo (siempre inicia en USD con BCV).
  4. Preservación de contexto y tasas congeladas al editar gastos indexados; edición completa de facturas en web (`panel.astro`).
  5. Alerta de discrepancia interactiva entre Monto Total y suma de ítems en móvil y web.
  6. Desambiguación robusta de IA: Bolívares explícitos obligan `moneda: 'VES'`; USD sin divisa/efectivo preselecciona `BS_BCV`.
  7. Consistencia matemática absoluta de lentes `Bs.` y `EUR`: presupuestos y categorías se proyectan determinísticamente al lente (`convertBudgetToLens`).
  8. Resiliencia local-first ante tasas ausentes o $\le 0$.
  9. Descarga de APK directa en BanaHosting con cache-buster `?b=$BUILD_NUM` embebido en HTML estático y JS sin enlazar a GitHub privado.

## Errores y Fricciones a Evitar
- **Repositorio Privado:** `cesarluisweb/gastoscan-ai` es privado; enlaces públicos a GitHub Releases devuelven HTTP 404. Usar siempre BanaHosting.
- **Regla Estricta DESIGN.md §2.2:** Prohibido texto amarillo sobre fondo blanco/claro.
- **En `CurrencyFormatter` y `BudgetBottomSheet`:** Nunca triangular USD/USDT por bolívares ni acumular deriva por redondeo.

## Próximo Paso Inmediato
- Esperar validación manual de César en dispositivo físico y panel web ([DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md)) para dar el visto bueno a `FIN-11`.
