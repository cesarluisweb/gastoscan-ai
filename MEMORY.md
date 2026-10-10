# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Finalizadas Fases 1 a 6 (Estabilidad IA, Comprobantes persistentes, Reportes Privacidad, Mejoras UI Tasas).
- **Últimos hitos:** 
  1. **Cuenta de Desarrollador Google Play Console Creada y Pagada ($25 USD):** Pago exitoso procesado mediante la ruta `Zinli` → `OKX P2P` → `OKX Pay` → `OKX Card` → `Google Payments`. Cuenta "Rinde Más" lista para configuración.
  2. **Actualización de Playbook y Aprendizaje (/learn):** Documentación técnica y skill `growth-first-100-users` actualizados con la ruta de pago (evitando error `OR_CCR_61`), el requisito de 12+ testers por 14 días y la bitácora obligatoria para la solicitud de producción.
  3. **Modernización y Paridad del Panel Web:** Integración de `meta_ahorro`, salud financiera, 4 divisas (USD, VES, EUR, USDT) y despliegue validado en Firebase Hosting (`rindemas.cesarluis.com`).
  4. **Preparación de Google Play:** Paquete configurado a `com.cesarluis.rindemas` (Gradle, Kotlin, Firebase), ícono 512x512 PNG generado y pipeline CI actualizado para compilar y firmar `.aab` de producción.
  5. **Auditoría y Robustecimiento de Seguridad (20/20):** Implementadas Security Headers en Firebase Hosting (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `X-XSS-Protection`, `Strict-Transport-Security`, `Permissions-Policy`, `Referrer-Policy`) desplegado y verificado en producción vía HTTP. Sanitizado endpoint de diagnóstico `/health` en Cloudflare Worker para eliminar exposición de fragmentos de API key y llamadas a Gemini no autenticadas. Activado `paths-ignore` en workflow de CI para no consumir minutos en documentación ni `.md`.
  6. **Unificación del Selector de Meses (MonthSelectorBar):** Creado componente reutilizable `MonthSelectorBar` con botón píldora interactivo y diálogo de 12 meses + selector de año en Inicio, Gastos, Análisis y Galería de Comprobantes. Homologado diseño en Gastos eliminando contenedor blanco para paridad visual exacta.
  7. **Políticas de Google Play y Documentos Legales Desplegados:** Actualización in-app redirigida a la tienda (`market://details?id=com.cesarluis.rindemas`), eliminados permisos de alarma exacta (`USE_EXACT_ALARM`), y publicadas páginas oficiales de Privacidad (`/privacidad`) y Términos (`/terminos`) en Firebase Hosting con validación HTTP 200.
  8. **Unificación Terminológica de Cola y Facturas:** Fase de escaneo/análisis habla de 'fotos'; fase de resultados y notificaciones habla de 'facturas'. Corregida concordancia singular/plural.
  9. **Aislamiento Total de Cuentas y Limpieza Local al Cerrar Sesión:** Creado método `limpiarBaseDatosLocal()` en SQLite/repositorio. Flujo de `cerrarSesion()` vacía el dispositivo para inicio en cero. Diálogo de decisión ("Conservar y sumar" vs "Reemplazar") al vincular o iniciar sesión si hay gastos locales huérfanos, erradicando contaminación de datos entre cuentas.
  10. **Firma Oficial Única en AAB (Google Play):** Resuelto error de doble cadena de certificados. Firma nativa en Gradle (`signingConfigs.release`) con `rindemas.jks` y eliminación de re-firma manual con `jarsigner` en CI.
  11. **Rediseño de Diálogo 'Compra Registrada' y Unificación de Vinculación:** Popup en modo anónimo adaptado a recomendación (ícono de check verde, texto amigable, botones de Google y 'Vincular con correo'). Unificado el modal de correo (`auth_modal_sheet.dart`) y diálogo de decisión ('Conservar y sumar' vs 'Reemplazar') tanto en Revisión de Gasto como en la pantalla Más cumpliendo DRY.

## Decisiones Técnicas y de Negocio Recientes
- **Firma Nativa de Producción:** Gradle firma directamente el `.aab` con `rindemas.jks` una sola vez. `jarsigner` solo verifica integridad.
- **Cumplimiento Google Play:** Sin sideloading interno de APKs ni permisos de alarma exacta (`inexactAllowWhileIdle`).
- **Aislamiento de Cuentas:** Al cerrar sesión, el teléfono se pone a cero en SQLite. Los datos remotos quedan intactos en Firestore. Al entrar con otra cuenta, solo se descargan los datos correspondientes.
- **Flujo de Vinculación Unificado:** Diálogo de decisión ("Conservar y sumar" vs "Reemplazar") centralizado en `auth_modal_sheet.dart` accesible desde Más y desde el modal de compra guardada.
- **Páginas Legales en Producción:** `rindemas.cesarluis.com/privacidad` y `rindemas.cesarluis.com/terminos`.
- **Package Name Oficial:** `com.cesarluis.rindemas` en Google Play Console y Android.

## Errores y Fricciones a Evitar
- NUNCA usar `jarsigner` para re-firmar un AAB en CI (produce doble cadena de certificados y rechazo en Play Console); la firma debe ser nativa en Gradle.
- Minutos de GitHub Actions en repositorio privado: Si la cuenta llega al límite, los runners no arrancan; requiere revisar Billing o pasar a público temporalmente para compilar.
- Tras finalizar compilaciones en público, retornar a 'Private' para proteger el código fuente.
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Contraste estricto en UI (`DESIGN.md`): Texto sobre amarillo SIEMPRE negro; texto sobre blanco SIEMPRE negro o gris, NUNCA amarillo.

## Próximo Paso Inmediato
- Monitorear CI hasta confirmación en verde y proceder con la verificación de los flujos de vinculación.
