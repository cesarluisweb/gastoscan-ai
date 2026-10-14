# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Validación manual de Fase 7.1 (Auditoría Integral y Blindaje para Google Play) y preparación de Fase 2 pendiente.
- **Últimos hitos:** 
  1. **CI en Verde (Build 428):** GitHub Actions completó compilación de APK, AAB oficial firmado, pruebas unitarias y despliegue web.
  2. **Blindaje de Permisos AAB Verificado:** Confirmada la ausencia total de `READ_MEDIA_IMAGES` y `READ_MEDIA_VIDEO` en el manifiesto binario fusionado del `.aab`.
  3. **Chat IA Seguro:** Eliminada mutación silenciosa; los gastos en conversación muestran botón interactivo que abre `ReviewExpenseScreen`.
  4. **Seguridad en Vinculación:** `sync_service.dart` valida primero la autenticación antes de borrar la base de datos local SQLite.
  5. **Multimoneda Dinámica en Galería:** `receipt_gallery_screen.dart` usa `CurrencyFormatter.formatPreferido`.
  6. **Cumplimiento Google Play:** Eliminados `READ_MEDIA_IMAGES` con `tools:node="remove"` y fallback de descarga de APK en `update_service.dart`. `exactAllowWhileIdle` cambiado a `inexactAllowWhileIdle`.
  7. **Gráfico de Funciones Cumple Políticas:** Eliminado botón «Descargar gratis» y reemplazado por chips de valor.

## Decisiones Técnicas y de Negocio Recientes
- **Cero Mutación Silenciosa de IA:** Todo gasto en chat exige confirmación humana en `ReviewExpenseScreen`.
- **Actualizaciones Solo por Play Store:** La app enruta exclusivamente a `market://` y web de Google Play.
- **Protección de Datos Locales:** En vinculación, el borrado local solo ocurre tras autenticación exitosa.

## Errores y Fricciones a Evitar
- Prohibido reintroducir URLs de descarga de `.apk` o permisos `READ_MEDIA_IMAGES` en Android 13+.
- Toda conversión de divisas debe pasar por `CurrencyFormatter` y las tasas dinámicas de `settings`.

## Próximo Paso Inmediato
- Probar en dispositivo físico los 5 recorridos críticos de la compilación 427.
- Continuar con las tareas pendientes de Fase 2 (anonimizar captura 5, fijar compileSdk=35, soporte EUR/USDT en cola de escaneo).
