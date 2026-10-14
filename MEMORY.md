# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 2 de Auditoría Integral completada en CI (Build 429 exitoso en verde, 223 pruebas unitarias aprobadas). En espera de validación de César en dispositivo físico (`Pendiente de validación 🧪`).
- **Últimos hitos:** 
  1. **CI en Verde (Build 429):** Compilación exitosa de APK y AAB de producción firmado, 223 unit tests pasados, despliegue web verificado (HTTP 200).
  2. **Multimoneda e Integridad (FIN-04, FIN-05, FIN-06, TEC-06):** Conversión dinámica EUR/USDT en colas de escaneo e historial; soporte completo EUR en `ReviewExpenseScreen`; adopción perezosa de presupuesto consolidada en BD; UUIDs con `Random.secure()`.
  3. **Seguridad y Sesión (SEC-03, SEC-04, SEC-06):** Reautenticación por contraseña en borrado de cuenta; purga de API key de SecureStorage en logout; eliminación de `--dart-define=GEMINI_API_KEY` en CI.
  4. **Calidad Visual y Rendimiento (UX-01, UX-04, TEC-03, TEC-04):** Contraste dinámico blanco/negro en dona por luminancia; borde de foco en `primaryDark`; verificación asíncrona de archivos en galería; guardas `mounted` tras awaits.
  5. **Activos Google Play y SDK (GP-07, GP-08):** Captura 5 anonimizada (`usuario@ejemplo.com`); `targetSdk = 36` fijado en build de producción para Play Store.

## Decisiones Técnicas y de Negocio Recientes
- **Fotos Locales Preservadas:** No se eliminan fotos físicas del teléfono al cerrar sesión si el usuario las guardó.
- **Historial Keystore:** No se reescribe el historial Git; el repositorio pasará a Privado tras finalizar.
- **Soporte EUR Real:** `ReviewExpenseScreen` persiste la tasa oficial del euro y calcula equivalentes exactos en Bs. y USD.

## Errores y Fricciones a Evitar
- `targetSdk` debe ser al menos 36 según el requisito vigente de Google Play Console.
- Toda conversión de divisas debe pasar por `CurrencyFormatter` y las tasas dinámicas de `settings`.

## Próximo Paso Inmediato
- Monitorear build 430 en GitHub Actions hasta confirmar éxito y subir AAB a Play Store.
