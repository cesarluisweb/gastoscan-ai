# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2. UI-01, UI-05, UX-06, UX-07 `Completada ✅`, FIN-09 en `Pendiente de validación 🧪`, UX-11 `Implementada 🔧`.
- **Documentación Técnica:** [DOC_FASE_6_2.md](DOC_FASE_6_2.md) y [ROADMAP.md](ROADMAP.md) actualizados.

## Decisiones Técnicas y de Negocio Recientes
- **UX-11 (Feedback Vinculación/Sincronización):** Estado de carga integrado en botón de Google (*"Conectando con Google..."* + spinner negro), leyenda descriptiva, deshabilitación de botones interactivos para prevenir toques concurrentes, PopScope en hoja modal de correo y diálogo de compras con microcopy de respaldo explícito.
- **UX-07 (Refinamiento Integral):** Tira de resumen mensual fija de moneda única según `monedaPrincipal`, carrusel de chips de filtros rápidos (`[Todos]`, `[🧾 Con comprobante]`, categorías), cálculo proporcional de ítems multimoneda, desglose consistente con fila y mini-ícono incluso en compras de 1 artículo, reducción de padding derecho en 3 puntos a ~12px, y despliegue interactivo en Inicio (`onTap`) para compras con artículos.
- **FIN-09 (Refinado):** Pastilla de tasa swap interactiva (`calc_swap_button`) para invertir orden Divisa/Bolívares, botón de copia dinámico (`Copiar Bs.` / `Copiar USD/EUR/USDT`), comparativa con texto negro carbón y eliminación de dropdown innecesario.
- **Navegación Atrás (MainScreen):** PopScope inteligente: desde tabs secundarias regresa a Inicio; en Más regresa al Hub; en Inicio requiere doble toque ('Presiona de nuevo para salir') en <= 2s para invocar `SystemNavigator.pop()`.
- **Consistencia de AppBars (Opción A):** Las 4 pantallas principales (`Inicio`, `Gastos`, `Análisis`, `Más`) muestran de forma idéntica `[🔍 Buscar, ✨ Asistente IA]`. La lupa redirige directamente a Gastos activando la búsqueda con teclado desplegado. Se retiró el botón redundante de presupuestos en Análisis y al presionar atrás mientras se busca se cancela la búsqueda sin cambiar de pestaña.
- **Iconografía e IA:** `AppConstants.getCategoryIcon`, `Icons.auto_awesome` en AppBar de Inicio y agrupación `+X categorías`.

## Errores y Fricciones a Evitar
- **Regla Estricta DESIGN.md §2.2:** Prohibido texto amarillo sobre fondo blanco/claro. El amarillo (`AppColors.primaryDark` / `primary`) solo se permite en iconos, bordes activos o fondos cuyo texto sea estrictamente negro.
- `AppConstants.categorias`: El catálogo canónico son 8 categorías fijas.
- Íconos de categorías deben consultarse exclusivamente vía `AppConstants.getCategoryIcon(cat)`.
- En `currency_calculator_screen_test.dart`: Si se usa `GastoModel`, importar explícitamente `gasto_model.dart`.
- Evitar navegación real a pantallas que requieran SQLite no mockeado (`DatabaseHelper.instance`) en tests de widgets.
- `ScanQueueProvider` en tests de widgets: instanciar siempre con `autoProcess: false` y llamar `dispose()` en `tearDown` para evitar timeouts de `pumpAndSettle`.
- Para widgets que usan `RichText` en tests: especificar `find.textContaining(..., findRichText: true)`.

## Próximo Paso Inmediato
- CI en verde confirmado (`conclusion: success`, Run `38779339683`). APK publicado en BanaHosting y Landing actualizada en Firebase Hosting. Esperar validación de César en dispositivo para marcar FIN-09 `Completada ✅`.

