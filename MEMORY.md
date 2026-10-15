# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2. UI-01, UI-05, UX-06, UX-07 `Completada ✅`, FIN-09 y UX-11 en `Pendiente de validación 🧪`.
- **Documentación Técnica:** [DOC_FASE_6_2.md](DOC_FASE_6_2.md) y [ROADMAP.md](ROADMAP.md) actualizados.

## Decisiones Técnicas y de Negocio Recientes
- **IA-05 (Persistencia de Chat y Regla Fiscal IVA):** `ChatProvider` en memoria (`MultiProvider`) mantiene la conversación activa al salir o navegar en la app. Botón de reinicio en AppBar (`Icons.restart_alt`) con modal de confirmación antes de borrar. Se excluye el renglón impositivo (`DatabaseHelper.isTaxItem`) de `_buildSemanticChatContext` y se instruye al modelo en Cloudflare Worker que el IVA en Venezuela es costo obligatorio legal no modificable, prohibiendo clasificarlo como producto o gasto hormiga.
- **UX-11 (Feedback Vinculación/Sincronización):** Estado de carga integrado en botón de Google (*"Conectando con Google..."* + spinner negro), leyenda descriptiva, deshabilitación de botones interactivos para prevenir toques concurrentes, PopScope en hoja modal de correo y diálogo de compras con microcopy de respaldo explícito.
- **UX-07 (Refinamiento Integral):** Tira de resumen mensual fija de moneda única según `monedaPrincipal`, carrusel de chips de filtros rápidos (`[Todos]`, `[🧾 Con comprobante]`, categorías), cálculo proporcional de ítems multimoneda, desglose consistente con fila y mini-ícono incluso en compras de 1 artículo, reducción de padding derecho en 3 puntos a ~12px, y despliegue interactivo en Inicio (`onTap`) para compras con artículos.
- **FIN-09 (Refinado):** Pastilla de tasa swap interactiva (`calc_swap_button`) para invertir orden Divisa/Bolívares, botón de copia dinámico (`Copiar Bs.` / `Copiar USD/EUR/USDT`), comparativa con texto negro carbón y eliminación de dropdown innecesario.
- **Navegación Atrás (MainScreen):** PopScope inteligente: desde tabs secundarias regresa a Inicio; en Más regresa al Hub; en Inicio requiere doble toque ('Presiona de nuevo para salir') en <= 2s para invocar `SystemNavigator.pop()`.
- **Consistencia de AppBars (Opción A):** Las 4 pantallas principales (`Inicio`, `Gastos`, `Análisis`, `Más`) muestran de forma idéntica `[🔍 Buscar, ✨ Asistente IA]`. La lupa redirige directamente a Gastos activando la búsqueda con teclado desplegado. Se retiró el botón redundante de presupuestos en Análisis y al presionar atrás mientras se busca se cancela la búsqueda sin cambiar de pestaña.
- **Iconografía e IA:** `AppConstants.getCategoryIcon`, `Icons.auto_awesome` en AppBar de Inicio y agrupación `+X categorías`.

- **POL-01 (Blindaje Política Gubernamental Google Play):** Para subsanar el rechazo por "Información gubernamental / Afirmaciones engañosas", se agregó descargo explícito de no representación y enlace funcional a `https://www.bcv.org.ve/` tanto en la Ficha de Play Store (`DOC_FICHA_PLAY_STORE.md` / `FICHA_GOOGLE_PLAY.md`) como en la app (`currency_calculator_screen.dart` y `more_screen.dart`), con tests automatizados. Versión incrementada a `1.0.4+4`.

## Errores y Fricciones a Evitar
- **Regla Estricta DESIGN.md §2.2:** Prohibido texto amarillo sobre fondo blanco/claro. El amarillo (`AppColors.primaryDark` / `primary`) solo se permite en iconos, bordes activos o fondos cuyo texto sea estrictamente negro.
- `AppConstants.categorias`: El catálogo canónico son 8 categorías fijas.
- Íconos de categorías deben consultarse exclusivamente vía `AppConstants.getCategoryIcon(cat)`.
- En `currency_calculator_screen_test.dart`: Si se usa `GastoModel`, importar explícitamente `gasto_model.dart`.
- Evitar navegación real a pantallas que requieran SQLite no mockeado (`DatabaseHelper.instance`) en tests de widgets.
- `ScanQueueProvider` en tests de widgets: instanciar siempre con `autoProcess: false` y llamar `dispose()` en `tearDown` para evitar timeouts de `pumpAndSettle`.
- Para widgets que usan `RichText` en tests: especificar `find.textContaining(..., findRichText: true)`.

## Próximo Paso Inmediato
- CI en verde confirmado (`conclusion: success`, Run `38800883233`). AAB v1.0.4 y APK generados y desplegados. César debe: 1) Descargar `app-release.aab` desde GitHub Releases/Actions y subirlo a Pruebas Cerradas en Play Console, 2) Pegar la descripción completa con el descargo y enlace oficial, 3) Confirmar el cuestionario de app no gubernamental y 4) Enviar a revisión.


