# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Declaración de Seguridad de los Datos (Data Safety) para Google Play Console formalizada.
- **Últimos hitos:** 
  1. **Política de Privacidad en Producción:** `landing/src/pages/privacidad.astro` describe con exactitud la distinción entre almacenamiento local en SQLite, respaldo en Firestore y envío a Gemini (modo gestionado de pago sin entrenamiento vs BYOK gratuito). Validada en `rindemas.cesarluis.com/privacidad`.
  2. **Aviso de Privacidad BYOK en la App:** Modal en `more_screen.dart` advierte de forma visible sobre las condiciones de Google AI Studio y el nivel gratuito antes de registrar la clave.
  3. **Data Safety Formalizado:** `DOC_DECLARACION_SEGURIDAD_DATOS_PLAY.md` cerrado con la decisión estratégica de declarar "Compartido: Sí" para las 3 categorías enviadas a Google para IA (Fotos, Mensajes, Compras en OCR/chat), "Efímero: No" por retención de logs en Google Cloud / AI Studio, e Identificadores de usuario obligatorios por `signInAnonymously()`.
  4. **Compilación y CI en Verde:** Run `38498202032` completado exitosamente con tests aprobados y AAB/APK generados.

## Decisiones Técnicas y de Negocio Recientes
- **Estrategia Data Safety (Google Play):** Máxima transparencia. Se declara que se comparten datos con Google exclusivamente para las funciones de IA (evitando disputas sobre la excepción de transferencia iniciada por el usuario en BYOK). Para Firestore y Auth se mantiene "Compartido: No" (proveedor de servicios).
- **Procesamiento Efímero:** Declarado "NO" para la IA por retención de logs en la infraestructura de Google y el régimen de retención de AI Studio Free Tier.
- **Aislamiento Local:** Todo dato que permanece exclusivamente en SQLite local no constituye recogida ni compartición.

## Errores y Fricciones a Evitar
- No marcar efímero si el proveedor escribe en disco o conserva logs de servidor.
- No asumir que el usuario introduciendo su clave convalida automáticamente una excepción sin divulgación destacada y consentimiento previo.
- Contraste estricto en UI (`DESIGN.md`): Texto sobre amarillo SIEMPRE negro; texto sobre blanco SIEMPRE negro o gris, NUNCA amarillo.

## Próximo Paso Inmediato
- Completar el formulario de Seguridad de los Datos en Google Play Console utilizando `DOC_DECLARACION_SEGURIDAD_DATOS_PLAY.md` como guía definitiva.
