# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 2 de Auditoría Integral implementada (multimoneda EUR/USDT, adopción perezosa de presupuesto, reauth en eliminación de cuenta, compile/targetSdk=35, anonimización captura 5, limpieza de credenciales en logout, rendimiento y contraste).
- **Últimos hitos:** 
  1. **Multimoneda e Integridad (FIN-04, FIN-05, FIN-06, TEC-06):** Conversión dinámica EUR/USDT en colas de escaneo e historial; soporte completo de tasa EUR en `ReviewExpenseScreen`; adopción perezosa de presupuesto consolidada en BD local; UUIDs con `Random.secure()`.
  2. **Seguridad y Sesión (SEC-03, SEC-04, SEC-06):** Reautenticación por contraseña en borrado de cuenta (`requires-recent-login`); purga de API key de SecureStorage en logout; eliminación de `--dart-define=GEMINI_API_KEY` en CI.
  3. **Calidad Visual y Rendimiento (UX-01, UX-04, TEC-03, TEC-04):** Contraste dinámico blanco/negro en dona por luminancia; borde de foco en `primaryDark`; verificación asíncrona de archivos en galería; guardas `mounted` tras awaits.
  4. **Activos Google Play y SDK (GP-07, GP-08):** Correo real anonimizado en captura 5 (`usuario@ejemplo.com`); `compileSdk = 35` y `targetSdk = 35` inyectados en build de CI.

## Decisiones Técnicas y de Negocio Recientes
- **Fotos Locales Preservadas:** No se eliminan fotos físicas del teléfono al cerrar sesión si el usuario las guardó.
- **Historial Keystore:** No se reescribe el historial Git; el repositorio pasará a Privado tras finalizar.
- **Soporte EUR Real:** `ReviewExpenseScreen` persiste la tasa oficial del euro y calcula equivalentes exactos en Bs. y USD.

## Errores y Fricciones a Evitar
- Prohibido reintroducir URLs de descarga de `.apk` o permisos `READ_MEDIA_IMAGES` en Android 13+.
- Toda conversión de divisas debe pasar por `CurrencyFormatter` y las tasas dinámicas de `settings`.

## Próximo Paso Inmediato
- Monitorear GitHub Actions CI tras el push hasta confirmar build exitoso y pruebas unitarias en verde.
- Descargar nuevo AAB firmado y subir a la pista cerrada de Google Play.
