# Documentación Técnica: API Key Propia de Gemini (BYOK)

**Fecha:** 7 de octubre de 2026  
**Estado:** Implementado — Pendiente de pruebas y visto bueno del usuario  
**Archivos modificados:**
- `cloudflare_worker/src/index.js` (desplegado a producción)
- `lib/data/datasources/remote/gemini_service.dart`
- `lib/providers/settings_provider.dart`
- `lib/ui/screens/more_screen.dart`
- `MEMORY.md`

---

## 1. Resumen de Implementación

### 1.1 Gateway Serverless (`cloudflare_worker/src/index.js`)
- **Detección de clave personalizada:** El worker extrae la cabecera `x-custom-gemini-key`. Si está presente y supera 10 caracteres, la utiliza para autenticar las peticiones de Google Gemini en `/analyze-receipt` y `/chat-analyst`. Si no, recurre a la clave del sistema (`env.GEMINI_API_KEY`).
- **Aislamiento de cuota y rate limit:** Las peticiones con clave propia tienen su límite ampliado a 60 req/min (para prevención DoS del worker) sin consumir la cuota central de la app.
- **Detección y respuesta de errores propios:** Ante errores 400 (clave inválida), 403 (permisos/cuota) o 429 de Google cuando se usa clave propia, el worker responde con `{ isCustomKey: true, error: "Tu API Key de Gemini personalizada tiene un error o agotó su cuota..." }`, impidiendo que la app confunda errores de la clave del usuario con caídas del servicio de Rinde Más.
- **Despliegue verificado:** Desplegado exitosamente a `rindemas-gateway.cesarluispuntocom.workers.dev`.

### 1.2 Cliente Flutter (`GeminiService` y `SettingsProvider`)
- **Validación en vivo previa:** Método estático `GeminiService.validateGeminiApiKey(key)` que consulta directamente `https://generativelanguage.googleapis.com/v1beta/models?key=...` antes de guardar, comprobando al instante si la clave es auténtica y tiene acceso activo.
- **Inyección transparente:** `GeminiService._buildHeaders()` consulta `FlutterSecureStorage` de forma asíncrona e inyecta la cabecera `x-custom-gemini-key` sin necesidad de alterar las firmas de métodos existentes ni romper tests o componentes llamadores.
- **Eliminación y retorno:** `SettingsProvider.removeApiKey()` borra la clave del Keystore seguro y notifica a los listeners, revirtiendo la app inmediatamente al servicio estándar.

### 1.3 Interfaz de Usuario (`more_screen.dart`)
- **Ubicación:** Tarjeta dedicada situada inmediatamente debajo de la sección **Almacenamiento y Fotos**.
- **Estado dinámico:**
  - Si no hay clave: muestra descripción explicativa y chevron para configurar.
  - Si hay clave activa: muestra badge verde **"Activa"**, miniatura enmascarada (`AIzaSy...****`) y botón "Gestionar".
- **Modal de gestión:**
  - Explicación clara del funcionamiento.
  - Enlace directo a Google AI Studio (`https://aistudio.google.com/app/apikey`) para obtener la clave con un toque.
  - Campo de texto con alternancia de visibilidad (ocultar/mostrar caracteres) y botón para limpiar.
  - Botón **"Validar y guardar clave"** con indicador de carga durante la comprobación.
  - Botón **"Eliminar clave personalizada"** (cuando ya existe una configurada).
  - Feedback visual con SnackBars legibles según las reglas de estilo de Rinde Más.

---

## 2. Guía Paso a Paso para Pruebas de Verificación

Sigue estos pasos en la aplicación para verificar el funcionamiento de la nueva funcionalidad:

### Prueba A: Visualización y apertura del modal
1. Abre la app y navega a la pestaña **Más** (última pestaña de la barra inferior).
2. Haz scroll hasta pasar la tarjeta de **Almacenamiento y Fotos**.
3. Verifica que inmediatamente debajo aparece la nueva tarjeta: **"API Key de Gemini (Opcional)"**.
4. Pulsa sobre la tarjeta y comprueba que se despliega la hoja modal con el título, la explicación y el enlace a Google AI Studio.

### Prueba B: Validación de clave inválida
1. En el campo de texto, escribe cualquier texto falso (ej. `clave_falsa_12345`).
2. Pulsa el botón **"Validar y guardar clave"**.
3. Verifica que muestra el indicador de carga y luego muestra el mensaje de error: *"Clave inválida o sin acceso a Gemini. Verifica tu clave."* sin guardarla.

### Prueba C: Validación y guardado de clave real
1. Si tienes una clave de Gemini (Google AI Studio), pégala en el campo.
2. Pulsa **"Validar y guardar clave"**.
3. Verifica que valida exitosamente contra Google, se cierra el modal y aparece el SnackBar de confirmación.
4. En la tarjeta de la pantalla Más, verifica que ahora dice **"Activa"** con la clave enmascarada (`AIzaSy...****`).

### Prueba D: Escaneo o Chat con la clave propia
1. Ve al Chat IA o escanea una factura.
2. Comprueba que el procesamiento o consulta responde normalmente (utilizando tu cuota personal a través del Worker).

### Prueba E: Eliminación de la clave
1. Vuelve a la pantalla Más y pulsa en la tarjeta de API Key (o en "Gestionar").
2. Pulsa el botón rojo **"Eliminar clave personalizada"**.
3. Comprueba que la clave se borra, la tarjeta vuelve a su estado inicial y la app sigue funcionando con el servicio estándar de Rinde Más.
