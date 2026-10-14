# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Adecuación integral de Política de Privacidad, aviso BYOK y Seguridad de Datos para Google Play.
- **Últimos hitos:** 
  1. **Política de Privacidad en Producción:** `landing/src/pages/privacidad.astro` actualizada con distinción explícita de IA gestionada (Tier 1 de pago sin entrenamiento) vs BYOK (términos del usuario en Google AI Studio), y tránsito efímero en Cloudflare Workers sin persistencia. Desplegada a Firebase Hosting y validada en `rindemas.cesarluis.com/privacidad`.
  2. **Aviso de Privacidad BYOK en la App:** Modal en `more_screen.dart` incluye contenedor informativo de advertencia sobre términos de Google AI Studio y cuentas gratuitas antes de ingresar la clave.
  3. **Ficha de Google Play (Seguridad de los Datos):** `FICHA_GOOGLE_PLAY.md` actualizada con desglose exacto de datos recogidos (cuenta, fotos de recibos efímeras, historial de gastos) y justificación rigurosa de "No se comparten datos con terceros" basada en proveedores de infraestructura y transferencias dirigidas por el usuario.
  4. **Compilación y Despliegue Web Verificados:** Build estático de Astro y release en Firebase Hosting finalizados con éxito (HTTP 200 verificado).
  5. **CI y Release en Verde:** Run `38498202032` completado con éxito (`conclusion: success`). Tests unitarios pasados, APK y AAB de producción generados y distribuidos.

## Decisiones Técnicas y de Negocio Recientes
- **Graduación de Reglas de Entrada Multigasto y Voz:** Incorporadas permanentemente a `AGENTS.md` (secciones 6 y 14): flujo 1 gasto directo vs 2+ encolados en `ready`, respeto estricto de moneda detectada, getter `totalOriginalDisplay`, despliegue de Cloudflare Worker y disambiguación de comercios.
- **Cumplimiento Google Play Data Safety:** Se declara recogida de fotos y texto para IA (procesamiento efímero). Se mantiene "No compartir con terceros" al estar Cloudflare y Google amparados como encargados de tratamiento (modo gestionado de pago) y excepción de transferencia dirigida por el usuario (modo BYOK informado).
- **Transparencia en BYOK:** Notificar explícitamente al usuario en la UI que al aportar su clave gratuita de Google AI Studio, Google puede usar datos para entrenamiento según sus términos de servicio.

## Errores y Fricciones a Evitar
- No asumir que BYOK no envía datos fuera del dispositivo; las solicitudes pasan por el gateway y llegan a Gemini.
- No usar `>` en PowerShell ni `&&` en PowerShell 5.1.
- Contraste estricto en UI (`DESIGN.md`): Texto sobre amarillo SIEMPRE negro; texto sobre blanco SIEMPRE negro o gris, NUNCA amarillo.

## Próximo Paso Inmediato
- Completar la sección de Seguridad de los Datos en Google Play Console con las respuestas acordadas.

