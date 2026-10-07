# Plan de Implementación: API Key Propia de Gemini (BYOK)

**Fecha:** 7 de octubre de 2026  
**Estado:** Planificado y aprobado mediante entrevista de diseño (`/grill-me`). Pendiente de implementación tras verificación de comprobantes manuales.

---

## 1. Decisiones de Diseño Acordadas

1. **Ubicación en UI:**
   - Sección "Más", tarjeta dedicada ubicada inmediatamente debajo de **Almacenamiento y Fotos**.
   - Título: **"API Key de Gemini (Opcional)"**.
   - Descripción clara indicando que es para usuarios avanzados que deseen usar su propia cuota gratuita o de pago de Google AI Studio.
   - Enlace directo a Google AI Studio (`https://aistudio.google.com/`) para facilitar la obtención de la clave.
   - Botón **"Validar clave"** que hace un ping ligero a Gemini antes de guardarla.
   - Botón para eliminar/desactivar la clave en cualquier momento y volver al modo predeterminado de Rinde Más.

2. **Almacenamiento Seguro:**
   - Guardada en hardware Keystore mediante `flutter_secure_storage`.
   - Administrada reactivamente en `SettingsProvider` (estado `customGeminiApiKey`).

3. **Arquitectura de Red y Enrutamiento:**
   - La app envía la clave personal en la cabecera HTTP `x-custom-gemini-key` al Cloudflare Worker.
   - El Worker detecta la cabecera: si está presente y es válida, utiliza esa clave para autenticarse contra Google; si no, utiliza el secreto del sistema (`env.GEMINI_API_KEY`).
   - Esto permite conservar al 100% todos los prompts de extracción de facturas venezolanas, esquemas JSON y validaciones sin duplicar código en Flutter.

4. **Gestión de Errores y Aislamiento de Cuota:**
   - Si la clave personalizada falla (código 400 por clave inválida, 403 por cuota agotada o billing inactivo en Google), la app muestra un mensaje explícito:
     > *"Tu API Key de Gemini personalizada tiene un error o agotó su cuota. Revisa tu clave en Ajustes."*
   - No se hace fallback silencioso a la cuota comunitaria para evitar confusiones de facturación o abusos.

5. **Alcance:**
   - Aplica a todas las llamadas de IA de la aplicación:
     - Escaneo y extracción OCR de facturas (`/analyze-receipt`).
     - Consultas del analista financiero en el Chat de IA (`/chat-analyst`).

---

## 2. Tareas de Código Requeridas

1. **Cloudflare Worker (`cloudflare_worker/src/index.js`):**
   - Leer cabecera `request.headers.get("x-custom-gemini-key")`.
   - Usar `customKey || env.GEMINI_API_KEY`.
   - En respuestas de error de Google, etiquetar si el fallo provino de la clave personalizada (`isCustomKey: true`).
2. **SettingsProvider (`lib/providers/settings_provider.dart`):**
   - Métodos `getCustomGeminiKey()`, `setCustomGeminiKey(String key)` y `removeCustomGeminiKey()`.
3. **GeminiService (`lib/data/datasources/remote/gemini_service.dart`):**
   - Inyectar la cabecera `x-custom-gemini-key` en `analyzeReceiptImage`, `analyzeReceiptText` y `chatWithAnalyst` si existe en `SettingsProvider`.
4. **Pantalla Más (`lib/ui/screens/more_screen.dart`):**
   - Construir el widget de tarjeta / modal para configuración y prueba de la clave.
