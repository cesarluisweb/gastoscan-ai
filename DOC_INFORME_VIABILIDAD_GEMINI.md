# Informe de Viabilidad: Capacidad Individual de Gemini API

## Análisis de la sugerencia del usuario
La idea propuesta por el usuario es utilizar la "disponibilidad individual" de su cuenta personal de Google para consumir la API de Gemini, en lugar de depender de los límites de cuota de la cuenta de desarrollador de Rinde Más.

A continuación, el análisis técnico detallado:

### 1. ¿Cómo se asocia la cuota de Gemini API?
Actualmente, las llamadas a la API de Gemini (a través de Google AI Studio o Vertex AI) están asociadas estrictamente a un **Proyecto de Google Cloud** y a una **API Key** o credenciales IAM generadas por el desarrollador. No existe el concepto de "trae tu propia cuota personal gratuita" simplemente vinculando una cuenta de Gmail estándar de consumidor.

### 2. ¿Existe un mecanismo oficial para usar la cuota de cada usuario?
No existe un mecanismo oficial "transparente" para delegar el consumo a la cuenta del usuario final (OAuth 2.0 no permite delegar cuotas de servicios B2B). La única forma de que un usuario pague o use su propia cuota sería que el usuario genere su propia API Key en Google AI Studio y la pegue dentro de los ajustes de Rinde Más (Bring Your Own Key - BYOK).

### 3. Requisitos de implementación (Si se usara BYOK)
Para que el usuario use su propia cuota, la aplicación tendría que obligarlo a:
1. Acceder a Google AI Studio desde un navegador.
2. Crear un proyecto y aceptar términos y condiciones técnicos.
3. Generar una clave alfanumérica (API Key).
4. Copiar y pegar esa clave dentro de Rinde Más.
5. Si excede los límites gratuitos, tendría que añadir una tarjeta de crédito en su propio Google Cloud Billing.

### 4. Impacto en la Experiencia de Usuario (UX)
Esta opción destruye la propuesta de valor principal: *"instalar, abrir y usar con cero fricción"*. 
Solicitarle a un usuario común que entienda qué es una API Key, cómo generarla y cómo pegarla en la aplicación introduce una barrera técnica inmensa.

### 5. Riesgos de Seguridad y Soporte
- **Seguridad:** Manejar API Keys introducidas por usuarios implica guardarlas localmente de forma segura. Si un usuario revoca su clave sin darse cuenta, la aplicación se romperá mágicamente.
- **Soporte Técnico:** Rinde Más recibiría quejas y malas calificaciones en Google Play por errores como "Facturación no habilitada" o "Clave inválida", los cuales están 100% fuera de nuestro control porque pertenecen al proyecto personal del usuario.

## Conclusión y Recomendación

**¿Es viable técnicamente?** Solo mediante el modelo de "Trae tu propia API Key" (BYOK).
**¿Mejora la privacidad?** No necesariamente, ya que sus datos de comprobantes seguirían enviándose a los mismos servidores de Gemini (solo que bajo su propio proyecto).
**¿Vale la pena para Rinde Más?** **No.** 

### Decisión
**Se recomienda descartar esta opción.** Introduciría una complejidad técnica enorme para el usuario promedio y violaría el principio rector de "cero fricción". La solución correcta para mitigar límites de cuota es optimizar los reintentos locales y, en el futuro, depender del modelo de negocio planificado (cuota gratuita inicial y plan Pro asequible para los usuarios más intensivos), manteniendo toda la complejidad de APIs transparente y gestionada por el backend de la app.
