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
  6. **Unificación del Selector de Meses (MonthSelectorBar):** Creado componente reutilizable `MonthSelectorBar` con botón píldora interactivo y diálogo de 12 meses + selector de año, reemplazando implementaciones inconsistentes y código duplicado en Inicio, Gastos, Análisis y Galería de Comprobantes.
  7. **Políticas de Google Play y Documentos Legales Desplegados:** Actualización in-app redirigida a la tienda (`market://details?id=com.cesarluis.rindemas`), eliminados permisos de alarma exacta (`USE_EXACT_ALARM`), y publicadas páginas oficiales de Privacidad (`/privacidad`) y Términos (`/terminos`) en Firebase Hosting con validación HTTP 200.

## Decisiones Técnicas y de Negocio Recientes
- **Cumplimiento Google Play:** Sin sideloading interno de APKs ni permisos de alarma exacta (`inexactAllowWhileIdle`).
- **Páginas Legales en Producción:** `rindemas.cesarluis.com/privacidad` (obligatoria para Play Console y Data Safety con método de eliminación de cuenta) y `rindemas.cesarluis.com/terminos`.
- **Package Name Oficial:** `com.cesarluis.rindemas` en Google Play Console y Android.
- **Estrategia de Lanzamiento Google Play:** Reclutamiento de 15 a 18 testers organizados por Google Groups (`rindemas-testers@googlegroups.com`), llevando registro de bugs y versiones para el formulario de producción.
- **Ruta Verificada de Pago en Venezuela:** Uso de OKX Card (Mastercard virtual) para salvar el bloqueo de tarjetas prepago directas (`OR_CCR_61`).

## Errores y Fricciones a Evitar
- Minutos de GitHub Actions en repositorio privado: Si la cuenta llega al límite, los runners no arrancan; requiere revisar Billing o pasar a público temporalmente para compilar.
- Tras finalizar compilaciones en público, retornar a 'Private' para proteger el código fuente.
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Contraste estricto en UI (`DESIGN.md`): Texto sobre amarillo SIEMPRE negro; texto sobre blanco SIEMPRE negro o gris, NUNCA amarillo.

- **Tarjeta de Donación Pago Móvil:** Actualizados campos a 'Teléfono:' (0414-8431543) y 'Cédula:' (18.903.218) en `landing/src/pages/index.astro`, desplegado a Firebase Hosting (`rindemas.cesarluis.com`) y verificado online.

## Próximo Paso Inmediato
- Esperar siguientes instrucciones de César o continuar con la preparación para el release de Google Play.
