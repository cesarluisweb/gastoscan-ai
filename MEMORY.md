# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Finalizadas Fases 1 a 6 (Estabilidad IA, Comprobantes persistentes, Reportes Privacidad, Mejoras UI Tasas).
- **Últimos hitos:** 
  1. **Autenticación Agnóstica de Correo y Alias (Addy.io / Dominios Propios):** Soporte en `SyncService` y `GastoProvider` para registrar o iniciar sesión con cualquier correo/contraseña sin forzar la cuenta de Google de Android. Modal ergonómico en `MoreScreen` (`btn_vincular_email`), vinculación limpia de cuentas anónimas sin pérdida de datos locales y tests unitarios/widgets dedicados (`test/services/sync_service_auth_test.dart`).
  2. **Frases Predeterminadas en Asistente IA (`ChatScreen`):** Barra horizontal de 5 chips de sugerencia rápida con envío directo, auto-scroll, bloqueo de concurrencia y enriquecimiento de contexto con presupuestos (`test/screens/chat_screen_test.dart`).
  3. **Gestión de Comprobantes, Visor Directo y Galería Mensual (`DOC_COMPROBANTES_Y_GALERIA.md`):** Adjuntar/eliminar comprobantes en gastos manuales, visor interactivo con zoom y compartir (`ReceiptViewerDialog`), filtro por foto en historial y galería mensual (`ReceiptGalleryScreen`).
  4. **API Key Propia (BYOK Gemini) con Sincronización en Nube:** Soporte en Cloudflare Worker con cabecera `x-custom-gemini-key`, rate limit ampliado (60 rpm). En Flutter, persistencia segura en Firestore (`user_settings`).
  5. **Gate Estricto de CI:** Pruebas unitarias/widgets al 100% en verde y compilación automatizada de APK release.

## Decisiones Técnicas y de Negocio Recientes
- **Cero Duplicidad en Comprobantes:** Si el usuario elige guardar fotos, se registran en el álbum "Rinde Más" mediante `gal` (MediaStore) sin clonar archivos ni inflar el almacenamiento.
- **Acceso Directo a Comprobantes:** Chip táctil "Foto" en `ExpenseCard` abre el visor completo en 1 toque sin obligar a entrar en la pantalla de edición.
- **Mocks con `noSuchMethod` para Plugins:** En tests, clases de dependencias externas se simulan extendiendo `Fake` y delegando en `noSuchMethod`.
- **Transparencia en Errores de Gemini:** El gateway reporta causa real sin enmascarar modelos muertos como límites de cuota.
- **Observabilidad Declarativa:** Logs y telemetría de Cloudflare Workers fijados con `[observability] enabled = true` en `wrangler.toml`, reportando en vivo modo (`TEXTO_OCR` vs `VISION_MULTIMODAL`), peso en KB y tokens.
- **Cache-Buster en APKs OTA:** URLs de descarga y verificación de APK llevan `?b=$BUILD_NUM` para evitar descargas cacheadas por Cloudflare.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Prohibido textos amarillos en la UI; amarillo reservado estrictamente para iconos y acentos gráficos.

## Próximo Paso Inmediato
- Monitorear ejecución del pipeline en GitHub Actions hasta confirmar `success` y entregar guía de pruebas a César.
