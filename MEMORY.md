# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fases 1 y 2 de la Auditoría Integral 100% completadas y validadas por César ✅. Versión 433 (Build 430) con `targetSdk = 36` enviada a revisión en Google Play Console (Prueba Cerrada).
- **Últimos hitos:** 
  1. **Auditoría Fase 2 Validada:** Verificación exitosa en dispositivo físico de multimoneda EUR/USDT, adopción perezosa de presupuesto, reauth en borrado de cuenta, purga de SecureStorage, contraste dinámico y captura 5 anonimizada.
  2. **Play Store en Revisión:** Los 14 cambios y el paquete AAB versión 433 (`targetSdk = 36`) fueron enviados formalmente a revisión en Google Play Console.
  3. **Despliegue Web Verificado:** Landing page y panel activos en producción vía Firebase Hosting (HTTP 200).

## Decisiones Técnicas y de Negocio Recientes
- **Fotos Locales Preservadas:** No se eliminan fotos físicas del teléfono al cerrar sesión si el usuario las guardó.
- **Historial Keystore:** No se reescribe el historial Git; el repositorio pasará a Privado tras finalizar.
- **Soporte EUR Real:** `ReviewExpenseScreen` persiste la tasa oficial del euro y calcula equivalentes exactos en Bs. y USD.

## Errores y Fricciones a Evitar
- `targetSdk` debe mantenerse en 36 o superior para Google Play.
- Toda conversión de divisas debe pasar por `CurrencyFormatter` y las tasas dinámicas de `settings`.

## Próximo Paso Inmediato
- Iniciar la Fase 3 de la Auditoría Integral (mejoras de calidad y pulido):
  - UX-02: Diseño de onboarding de bienvenida (3 pantallas sencillas).
  - FIN-07: Corregir cálculo de días restantes en meses históricos en `SummaryCard`.
  - FIN-08: Validación de montos > 0 en formularios de registro.
  - UX-03: Búsqueda global cross-month en historial.
  - SEC-12: Versionado del Cloudflare Worker en el repositorio.
