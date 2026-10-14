# Guía y Declaración Oficial: Seguridad de los Datos (Data Safety) para Google Play Console

**Aplicación:** Rinde Más: Control de Gastos  
**Package Name:** `com.cesarluis.rindemas`  
**Estado:** Documento de Referencia Cerrado para Google Play Console  
**Fecha de formalización:** 14 de octubre de 2026  

---

## 1. Fuentes Oficiales de Referencia

Este documento y sus respuestas se fundamentan exclusivamente en las políticas y términos oficiales vigentes:

1. **Google Play Console - Proporcionar información sobre las prácticas de privacidad y seguridad de una aplicación:**  
   [https://support.google.com/googleplay/android-developer/answer/10787469?hl=es](https://support.google.com/googleplay/android-developer/answer/10787469?hl=es)  
   - Secciones aplicadas:
     - *«Qué deben declarar los desarrolladores: Recogida de datos»*
     - *«Qué deben declarar los desarrolladores: Uso compartido de datos»*
     - *«Excepciones a la recogida y el uso compartido de datos»* (Proveedores de servicios, Transferencias iniciadas por el usuario, Procesamiento efímero)
     - *«Tipos de datos y finalidades»*
2. **Google Play Console - Política de Datos de Usuario (Divulgación Destacada y Consentimiento):**  
   [https://support.google.com/googleplay/android-developer/answer/10144306?hl=es](https://support.google.com/googleplay/android-developer/answer/10144306?hl=es)  
3. **Términos de Servicio Adicionales de Google Gemini API y Google AI Studio:**  
   [https://ai.google.dev/gemini-api/terms](https://ai.google.dev/gemini-api/terms)  
   - *Section 2: «Use of Customer Data»* (Diferenciación entre Paid Services y Free Services)
4. **Google Cloud Data Processing Addendum (DPA):**  
   [https://cloud.google.com/terms/data-processing-addendum](https://cloud.google.com/terms/data-processing-addendum)  

---

## 2. Decisión Estratégica Adoptada: Datos Compartidos

Se ha adoptado la decisión estratégica más transparente y segura para la ficha de Google Play:

- **Para las funciones de Inteligencia Artificial (Google Gemini API):**  
  Se declara **«Compartido: Sí»** exclusivamente para las tres categorías de datos que se transmiten a Google a través del Gateway (`Fotos`, `Otros mensajes en la aplicación` e `Historial de compras` procesado en OCR/chat).  
  *Justificación:* Dado que Rinde Más admite la modalidad BYOK (donde un usuario puede vincular una clave gratuita de Google AI Studio sujeta a los términos de Google de retención y entrenamiento), declarar la compartición con Google neutraliza cualquier interpretación adversa o rechazo por parte de los revisores sobre la excepción de transferencia iniciada por el usuario.
- **Para los datos de respaldo en la nube (Firebase Auth y Cloud Firestore):**  
  Se mantiene **«Compartido: No»**. Google Cloud opera bajo el *Data Processing Addendum* (DPA) como **proveedor de servicios** puro, procesando la información exclusivamente en nombre de la aplicación para la autenticación y el respaldo privado, sin fines propios.
- **Para los datos almacenados exclusivamente en el dispositivo (SQLite):**  
  Por definición de Google Play, los registros locales que no se transmiten fuera del dispositivo **no constituyen recogida ni compartición** y no se computan en el formulario.

---

## 3. Justificación Técnica de Parámetros Clave

1. **Procesamiento efímero (Declarado «NO» para servicios de IA):**  
   Google Play establece que si los datos se conservan en registros del servidor del proveedor más allá de la atención en tiempo real en memoria, no califican como efímeros. Dado que la infraestructura de Google Cloud conserva logs de auditoría/seguridad y Google AI Studio Free Tier retiene datos para entrenamiento, la única respuesta rigurosa en el formulario es **«¿Se procesan estos datos de forma efímera? → NO»**.
2. **Identificadores de usuario (Declarado «Obligatorio: SÍ»):**  
   En `lib/main.dart` (línea 32), la app ejecuta `FirebaseAuth.instance.signInAnonymously()` en el arranque. Todo usuario conectado genera un UID anónimo transmitido a Firebase Auth, haciendo que esta recogida sea técnicamente obligatoria para el funcionamiento de la app conectada.
3. **Historial de compras y Presupuestos (Declarado «Opcional: SÍ»):**  
   En `lib/services/sync_service.dart` (línea 58), la sincronización con Firestore solo ocurre para usuarios con cuenta vinculada (`!user.isAnonymous`). Un usuario anónimo puede gestionar sus gastos de forma 100% local en SQLite sin que salgan del teléfono. Por ende, la recogida externa es opcional a nivel global.
4. **Identificadores de dispositivo (Declarado «NO se recogen»):**  
   Rinde Más no utiliza SDKs de publicidad (AdMob), atribución ni analítica externa (`firebase_analytics`, `crashlytics`). No se consulta IMEI, MAC, Android ID ni Advertising ID.

---

## 4. Matriz de Respuestas para Google Play Console

Esta tabla contiene las respuestas definitivas para completar la sección **Seguridad de los datos** (Data Safety) en Google Play Console:

| Categoría de Google Play | Tipo de Dato Declarado | ¿Recogido? | ¿Compartido? | ¿Efímero? | ¿Obligatorio u Opcional? | Finalidad Declarada en Play Console |
|---|---|---|---|---|---|---|
| **Información personal** | **Identificadores de usuario (User ID)** | **Sí** | **No** (proveedor de servicio) | **No** | **Obligatorio** (generado al iniciar la app) | *Funcionalidad de la aplicación*, *Gestión de la cuenta* |
| **Información personal** | **Dirección de correo electrónico** | **Sí** | **No** (proveedor de servicio) | **No** | **Opcional** (solo si vincula cuenta) | *Gestión de la cuenta* |
| **Información personal** | **Nombre** | **Sí** | **No** (proveedor de servicio) | **No** | **Opcional** (solo si vincula con Google) | *Gestión de la cuenta* |
| **Información financiera** | **Historial de compras (Compras / Gastos)** | **Sí** | **Sí** (transmitido a Google para OCR/IA) | **No** | **Opcional** (anónimo opera local en SQLite) | *Funcionalidad de la aplicación* |
| **Información financiera** | **Otra información financiera (Presupuestos)** | **Sí** | **No** (solo Firestore, proveedor) | **No** | **Opcional** (no se envía en modo anónimo) | *Funcionalidad de la aplicación* |
| **Mensajes** | **Otros mensajes en la app (Chat con IA)** | **Sí** | **Sí** (transmitido a Google para el asistente) | **No** | **Opcional** (uso del chat es voluntario) | *Funcionalidad de la aplicación* |
| **Fotos y vídeos** | **Fotos (Facturas analizadas por IA)** | **Sí** | **Sí** (transmitido a Google para escáner) | **No** | **Opcional** (se puede registrar gasto manual) | *Funcionalidad de la aplicación* |
| **Identificadores** | **Dispositivo u otros identificadores** | **No** | **No** | N/A | N/A | No se recogen |

---

## 5. Prácticas Generales de Seguridad y Enlaces Comprobables

- **¿Se cifran todos los datos de usuario en tránsito?:** **Sí** (todas las conexiones hacia Firebase, Cloudflare Workers y Google Gemini API utilizan protocolos HTTPS / TLS 1.2+ con cifrado estándar).
- **¿Proporcionas a los usuarios un mecanismo para solicitar la eliminación de sus datos?:** **Sí**.
  - Canal in-app: Pestaña *Más > Respaldo en la nube > Eliminar cuenta y datos*.
  - Canal web oficial: `https://rindemas.cesarluis.com/eliminar-cuenta`.
- **URL de eliminación de datos:** `https://rindemas.cesarluis.com/eliminar-cuenta`
- **URL de la política de privacidad:** `https://rindemas.cesarluis.com/privacidad`

---

## 6. Coherencia con la Política Pública y el Aviso en la App

1. **Política de Privacidad Pública (`landing/src/pages/privacidad.astro`):**  
   - Describe con exactitud en la Sección 2 la distinción entre almacenamiento local en SQLite y sincronización opcional en Google Cloud Firestore.
   - Detalla en la Sección 2.C y Sección 4 la transmisión a Google Gemini API para el escaneo y el chat, diferenciando la modalidad gestionada de la modalidad con clave propia (BYOK) en el nivel gratuito.
   - Refleja fielmente las opciones de eliminación in-app y web.
2. **Aviso en la Interfaz de la App (`lib/ui/screens/more_screen.dart`):**  
   - El modal de configuración de la API Key incluye el aviso visible de privacidad advirtiendo que las solicitudes se procesan bajo las condiciones de Google AI Studio y pueden estar sujetas a revisión o entrenamiento en el nivel gratuito.

---

## 7. Instrucciones para Completar el Formulario en Play Console

1. Iniciar sesión en [Google Play Console](https://play.google.com/console).
2. Seleccionar la aplicación **Rinde Más: Control de Gastos** (`com.cesarluis.rindemas`).
3. En el menú lateral izquierdo, ir a **Contenido de la aplicación** > **Seguridad de los datos** (Data Safety).
4. **Preguntas iniciales:**
   - ¿Tu aplicación recoge o comparte datos obligatorios? → **Sí**.
   - ¿Se cifran todos los datos en tránsito? → **Sí**.
   - ¿Permites solicitar la eliminación de datos? → **Sí**.
   - Pegar la URL: `https://rindemas.cesarluis.com/eliminar-cuenta`.
5. **Selección de tipos de datos:** Marcar las casillas correspondientes a:
   - *Información personal:* Nombre, Dirección de correo electrónico, Identificadores de usuario.
   - *Información financiera:* Historial de compras, Otra información financiera.
   - *Mensajes:* Otros mensajes en la aplicación.
   - *Fotos y vídeos:* Fotos.
   - *(Desmarcar Ubicación, Audio, Contactos, Dispositivo u otros IDs).*
6. **Configuración de cada tipo de dato:** Completar los detalles siguiendo estrictamente la tabla de la Sección 4.
7. Guardar el borrador y proceder con el envío de la declaración.
