# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Finalizadas Fases 1 a 6 (Estabilidad IA, Comprobantes persistentes, Reportes Privacidad, Mejoras UI Tasas).
- **Últimos hitos:** 
  1. **Gestión de Comprobantes, Visor Directo y Galería Mensual (`DOC_COMPROBANTES_Y_GALERIA.md`):** Adjuntar/eliminar comprobantes en gastos manuales, visor interactivo a pantalla completa con zoom y compartir (`ReceiptViewerDialog`), filtro rápido por foto en historial de gastos (`Icons.photo_library_outlined`), acceso a galería mensual desde la tarjeta "Almacenamiento y Fotos" en Más (`ReceiptGalleryScreen`), y guardado directo en álbum "Rinde Más" del teléfono sin duplicidad de almacenamiento (`gal: ^2.3.0`).
  2. **API Key Propia (BYOK Gemini) con Sincronización en Nube:** Soporte en Cloudflare Worker con cabecera `x-custom-gemini-key`, rate limit ampliado (60 rpm). En Flutter, almacenamiento seguro y sincronización bidireccional en Firestore (`users/{uid}/presupuestos/user_settings`).
  3. **Cadena Gemini Optimizada a Flash-Lite y Headers x-goog-api-key:** Reducción estricta a `gemini-3.1-flash-lite` y `gemini-3.5-flash-lite`. Soporte para nuevas keys `AQ.` vía `x-goog-api-key` y métricas expuestas (`x-gemini-model`, `x-gemini-tokens`).
  4. **Chips Dinámicos por Fecha:** Tasas históricas de la fecha del gasto en `ReviewExpenseScreen`.
  5. **Gate Estricto de CI:** `flutter analyze --fatal-warnings` y suite completa de pruebas unitarias/widgets activas en verde.

## Decisiones Técnicas y de Negocio Recientes
- **Cero Duplicidad en Comprobantes:** Si el usuario elige guardar fotos, se registran en el álbum "Rinde Más" mediante `gal` (MediaStore) sin clonar archivos ni inflar el almacenamiento.
- **Acceso Directo a Comprobantes:** Chip táctil "Foto" en `ExpenseCard` abre el visor completo en 1 toque sin obligar a entrar en la pantalla de edición.
- **Mocks con `noSuchMethod` para Plugins:** En tests, clases de dependencias externas se simulan extendiendo `Fake` y delegando en `noSuchMethod`.
- **Transparencia en Errores de Gemini:** El gateway reporta causa real sin enmascarar modelos muertos como límites de cuota.
- **Observabilidad Declarativa:** Logs y telemetría de Cloudflare Workers fijados con `[observability] enabled = true` en `wrangler.toml`.
- **Cache-Buster en APKs OTA:** URLs de descarga y verificación de APK llevan `?b=$BUILD_NUM` para evitar descargas cacheadas por Cloudflare.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Prohibido textos amarillos en la UI; amarillo reservado estrictamente para iconos y acentos gráficos.

## Próximo Paso Inmediato
- Monitorear ejecución del pipeline en GitHub Actions hasta confirmar `success` y entregar guía de pruebas a César.
