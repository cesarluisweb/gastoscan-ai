# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Correcciones críticas de Auditoría Integral (Fases 1 y 2 de Google Play).
- **Últimos hitos:** 
  1. **Auditoría Integral Guardada:** Diagnóstico exhaustivo consolidado en `DOC_AUDITORIA_INTEGRAL.md`.
  2. **Chat IA con Revisión Obligatoria:** `chat_screen.dart` ya no muta SQLite/Firestore a espaldas del usuario; redirige a `ReviewExpenseScreen` y añade botón de reporte de IA.
  3. **Seguridad en Vinculación:** `sync_service.dart` valida primero la autenticación antes de borrar la base de datos local SQLite.
  4. **Multimoneda Dinámica en Galería:** `receipt_gallery_screen.dart` usa `CurrencyFormatter.formatPreferido` eliminando ratio fijo `usd / 1.08`.
  5. **Cumplimiento Google Play:** Eliminados `READ_MEDIA_IMAGES` de `AndroidManifest.xml` y fallback de descarga de APK externo en `update_service.dart`. `exactAllowWhileIdle` cambiado a `inexactAllowWhileIdle`.
  6. **Fuga de Memoria Corregida:** Controladores en `auth_modal_sheet.dart` liberados mediante `whenComplete`.

## Decisiones Técnicas y de Negocio Recientes
- **Cero Mutación Silenciosa de IA:** Todo gasto detectado en el chat exige confirmación humana en `ReviewExpenseScreen`.
- **Actualizaciones Solo por Play Store:** La app no descarga ni distribuye APKs directamente.
- **Protección de Datos Locales:** En flujos de vinculación (`descartarDatosLocales`), el borrado local solo ocurre tras `linkWithCredential` o `signInWithCredential` exitoso.

## Errores y Fricciones a Evitar
- Prohibido reintroducir URLs de descarga de `.apk` o permisos `READ_MEDIA_IMAGES` en Android 13+.
- Toda conversión de divisas debe pasar por `CurrencyFormatter` y las tasas dinámicas de `settings`.

## Próximo Paso Inmediato
- Verificar SHA-1 de Play App Signing en Firebase Console (`DOC_CONFIGURACION_GOOGLE_SIGNIN.md`) y sustituir gráfico de funciones sin botón CTA.
