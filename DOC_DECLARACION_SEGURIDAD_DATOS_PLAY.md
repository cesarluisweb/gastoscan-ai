# Documento de Trabajo Técnico: Análisis de Seguridad de los Datos (Data Safety) para Google Play Console

**Aplicación:** Rinde Más: Control de Gastos  
**Package Name:** `com.cesarluis.rindemas`  
**Estado:** Documento de trabajo técnico en evaluación (No definitivo)  
**Fecha de revisión:** 14 de octubre de 2026  

---

## 1. Fuentes Oficiales de Referencia

Este análisis se fundamenta exclusivamente en la documentación oficial vigente de Google y en los términos contractuales de las API utilizadas:

1. **Google Play Console - Proporcionar información sobre las prácticas de privacidad y seguridad de una aplicación:**  
   [https://support.google.com/googleplay/android-developer/answer/10787469?hl=es](https://support.google.com/googleplay/android-developer/answer/10787469?hl=es)  
   - Secciones de referencia:
     - *«Qué deben declarar los desarrolladores: Recogida de datos»*
     - *«Qué deben declarar los desarrolladores: Uso compartido de datos»*
     - *«Excepciones a la recogida y el uso compartido de datos»* (Proveedores de servicios, Transferencias iniciadas por el usuario, Procesamiento efímero)
     - *«Tipos de datos y finalidades»*
2. **Google Play Console - Política de Datos de Usuario (Divulgación Destacada y Consentimiento):**  
   [https://support.google.com/googleplay/android-developer/answer/10144306?hl=es](https://support.google.com/googleplay/android-developer/answer/10144306?hl=es)  
   - Sección de referencia: *«Requisitos de divulgación destacada y consentimiento»*
3. **Términos de Servicio Adicionales de Google Gemini API y Google AI Studio:**  
   [https://ai.google.dev/gemini-api/terms](https://ai.google.dev/gemini-api/terms)  
   - Secciones de referencia:
     - *Section 2: «Use of Customer Data»*
     - *Section 2.1: «Paid Services»* (Garantía de no entrenamiento)
     - *Section 2.2: «Free Services»* (Uso para entrenamiento de modelos y evaluación humana)
4. **Google Cloud Data Processing Addendum (DPA):**  
   [https://cloud.google.com/terms/data-processing-addendum](https://cloud.google.com/terms/data-processing-addendum)  
   - Secciones de referencia: *Section 5.2 («Data Processor Obligations»)* y *Section 6 («Security and Logging»)*

---

## 2. Análisis Crítico de Conceptos Regulatorios

### 2.1 Procesamiento Efímero: Definición Estricta vs. Realidad de los Servidores

#### Criterio Oficial de Google Play (Sección «Procesamiento efímero»):
> *"Los datos se procesan de forma efímera si se transmiten fuera del dispositivo, se procesan únicamente en memoria, no se retienen más allá del tiempo necesario para responder a la solicitud concreta en tiempo real y no se utilizan para ningún otro fin."*  
> *"Si los datos se escriben en el disco o en almacenamiento persistente, incluso de forma temporal, o se conservan en registros del servidor más allá de lo necesario para atender la solicitud en tiempo real, NO se consideran procesados de forma efímera."*

#### Comportamiento Técnico por Servidor y Proveedor:
1. **Cloudflare Workers (Gateway de Rinde Más):**
   - El código (`cloudflare_worker/src/index.js`) opera en isolates de memoria V8. Valida el token JWT de Firebase y reenvía la petición. No escribe en almacenamiento persistente (KV, D1 o R2).
   - *Conclusión:* A nivel del Worker propio no hay persistencia.
2. **Google Gemini API - Modo Gestionado (Comercial de Pago / Pay-as-you-go):**
   - Aunque la *Section 2.1 («Paid Services»)* de los términos de Gemini prohíbe el uso de datos para entrenar modelos, la infraestructura de Google Cloud conserva registros de sistema, telemetría de red, prevención de abusos y auditoría de facturación durante un período de retención determinado (según las políticas de logging de Google Cloud).
   - **Corrección obligatoria:** No se debe confundir la ausencia de almacenamiento en bases de datos propias de la app con la ausencia de retención por parte del proveedor. Al existir registros del servidor del proveedor en disco, la transmisión **no cumple la definición estricta de procesamiento efímero de Google Play**.
3. **Google Gemini API - Modo BYOK Gratuito (Google AI Studio Free Tier):**
   - La *Section 2.2 («Free Services»)* de los términos de Gemini autoriza expresamente a Google a almacenar, procesar y retener entradas (prompts, imágenes) y respuestas por períodos prolongados, utilizarlas para entrenar modelos de IA y someterlas a revisión por evaluadores humanos.
   - **Conclusión:** Incompatible al 100% con la definición de efímero.

**Veredicto Unificado para Play Console:**  
Para cualquier dato que viaje a la API de Gemini (Fotos de facturas, Mensajes de chat, Compras analizadas en OCR), la respuesta obligatoria en el formulario de Play Console es:  
**«¿Se procesan estos datos de forma efímera? → NO»**.

---

### 2.2 BYOK y Datos Compartidos: Requisitos de la Excepción de Transferencia Iniciada por el Usuario

#### Criterio Oficial de Google Play (Sección «Excepciones al uso compartido de datos»):
> *"Una transferencia a un tercero no se considera uso compartido si el usuario inicia específicamente la transferencia (por ejemplo, si decide compartir un archivo o conectar su cuenta a un servicio de terceros), siempre que el usuario haya iniciado la acción explícitamente y se le haya informado adecuadamente mediante una divulgación destacada y consentimiento previo."*

#### Requisitos Regulatorios Expresos (Sección «Requisitos de divulgación destacada y consentimiento»):
Para que una transferencia iniciada por el usuario sea válida ante una auditoría de Google Play, la aplicación debe cumplir concurrentemente:
1. **Divulgación destacada en la app:** Debe mostrarse en el flujo normal de la interfaz (no oculta en la política de privacidad ni en un menú secundario), especificando con claridad qué datos se transmitirán y a qué tercero concreto.
2. **Explicación del uso del tercero:** Debe advertir expresamente qué hará el tercero con los datos (en este caso, que Google puede usar las solicitudes para entrenamiento en su nivel gratuito).
3. **Acción afirmativa y consentimiento explícito:** El usuario debe realizar una acción inequívoca que manifieste su consentimiento (por ejemplo, marcar una casilla de aceptación o pulsar un botón con redacción de consentimiento explícito).

#### Comprobación de la Implementación Real en Rinde Más:
Al inspeccionar `lib/ui/screens/more_screen.dart` (líneas 1314–1370):
- **Lo que sí está implementado:** Existe un contenedor informativo azul en el modal que advierte:  
  *«Aviso de privacidad: Al usar tu clave personal, tus consultas y comprobantes se procesan bajo las condiciones de tu propia cuenta de Google AI Studio. En el nivel gratuito de Google, las solicitudes pueden estar sujetas a revisión humana o entrenamiento según las políticas de Google.»*
- **Lo que falta para cumplir el estándar estricto de consentimiento:**
  - El usuario solo ingresa la clave en un campo de texto y presiona el botón: *«Validar y guardar clave»*.
  - No existe una casilla de consentimiento afirmativo (*«Acepto que mis consultas e imágenes se transmitan a Google bajo los términos de Google AI Studio»*) ni un diálogo previo de confirmación explícita.
- **Conclusión de cumplimiento:**  
  No se puede dar por válida la excepción de transferencia iniciada por el usuario únicamente porque este ingrese la clave. Si un revisor de Google Play considera que la advertencia no incluye consentimiento afirmativo previo, o si determina que la recepción de datos por Google para entrenamiento constituye cesión a terceros facilitada por la app, clasificarlo como «No se comparten datos» conllevará observaciones o rechazo.

---

### 2.3 Datos Recogidos: Diferenciación Local vs. Remota y Respuestas Únicas

Google Play establece que **«Recogida»** implica exclusivamente la transmisión de datos fuera del dispositivo. Los datos almacenados y procesados localmente en SQLite mediante `sqflite` no constituyen recogida.

Dado que Play Console exige **una única respuesta por tipo de dato para toda la aplicación**, se debe evaluar la regla de máxima cobertura de Google Play:
- Si un tipo de dato se transmite fuera del dispositivo en *cualquiera* de los flujos de la aplicación (incluso si es solo para usuarios con cuenta o solo al usar una función opcional), debe marcarse **«Recogido: Sí»**.
- Si un usuario no puede evitar la transmisión de ese dato al utilizar la aplicación, se marca **«Obligatorio»**. Si el dato solo se transmite si el usuario decide activar una función (ej. respaldo o IA), se marca **«Opcional»**.

---

## 3. Matriz por Categoría: Decisiones Verificadas y Pendientes

### 1. Información personal → Identificadores de usuario (User ID)
- **Comprobación en código:** En `lib/main.dart` (línea 32), la app invoca `FirebaseAuth.instance.signInAnonymously()` en el arranque. Todo usuario conectado genera un UID único asignado por Firebase Auth.
- **¿Sale del dispositivo?:** Sí (se transmite a los servidores de Firebase Auth).
- **¿Se comparte?:** No (Firebase opera bajo Google Cloud DPA como proveedor de servicios).
- **¿Es efímero?:** No (el UID persiste en Firebase Auth para mantener la sesión).
- **¿Obligatorio u Opcional?:** **Obligatorio** (ningún usuario con conexión puede evitar la generación del UID al abrir la app).
- **Finalidad en Play Console:** *Funcionalidad de la aplicación*, *Gestión de la cuenta*.
- **Estado:** **Verificado en el código fuente.**

---

### 2. Información personal → Dirección de correo electrónico
- **Comprobación en código:** En `lib/services/sync_service.dart`, el correo solo se transmite a Firebase Auth si el usuario vincula su cuenta de Google (`vincularCuentaGoogle`) o se registra/inicia sesión con email (`vincularConEmail` / `iniciarSesionConEmail`).
- **¿Sale del dispositivo?:** Sí (cuando el usuario vincula o inicia sesión). En modo anónimo nunca se recopila.
- **¿Se comparte?:** No (Firebase opera como proveedor de servicios).
- **¿Es efímero?:** No (se almacena en el registro de la cuenta en Firebase Auth).
- **¿Obligatorio u Opcional?:** **Opcional** (el usuario puede usar la app en modo anónimo sin proporcionar correo).
- **Finalidad en Play Console:** *Gestión de la cuenta*, *Funcionalidad de la aplicación*.
- **Estado:** **Verificado en el código fuente.**

---

### 3. Información personal → Nombre
- **Comprobación en código:** En `lib/services/sync_service.dart`, el nombre solo se recibe desde `GoogleSignIn` (`user.displayName`) y se asocia al perfil en Firebase Auth. En registro por correo o modo anónimo no se solicita ni envía nombre.
- **¿Sale del dispositivo?:** Sí (al vincular con Google).
- **¿Se comparte?:** No (proveedor de servicios).
- **¿Es efímero?:** No (persiste en Firebase Auth).
- **¿Obligatorio u Opcional?:** **Opcional** (el inicio de sesión con Google es voluntario).
- **Finalidad en Play Console:** *Gestión de la cuenta*.
- **Estado:** **Verificado en el código fuente.**

---

### 4. Información financiera → Historial de compras (Compras / Gastos)
- **Comprobación en código:**
  - *En el dispositivo:* Se almacena en la tabla SQLite `gastos`.
  - *Fuera del dispositivo:*
    1. Si `user.isAnonymous == true`, `SyncService.syncBidirectional()` (línea 58) **retorna inmediatamente** sin enviar datos a Firestore.
    2. Si `!user.isAnonymous`, se sincronizan a Cloud Firestore todos los gastos (montos, comercios, fechas, categorías).
    3. Si el usuario (anónimo o vinculado) escanea una factura con IA (`GeminiService`), los datos extraídos viajan por red hacia Cloudflare y Gemini.
- **¿Sale del dispositivo?:** Sí (al sincronizar en la nube o al escanear con IA).
- **¿Es efímero?:** **No** (se almacena en Firestore; Gemini conserva registros de servidor).
- **¿Obligatorio u Opcional?:** **Opcional** (un usuario anónimo que registra gastos manualmente no transmite ningún dato financiero fuera del teléfono).
- **Finalidad en Play Console:** *Funcionalidad de la aplicación*.
- **Decisión sobre Datos Compartidos:** **Pendiente.**
  - *Si se asume la excepción de transferencia iniciada para BYOK:* Se declara **Compartido: No**.
  - *Si se opta por máxima transparencia preventiva:* Se declara **Compartido: Sí (con Google)** debido a que el modo BYOK gratuito autoriza a Google a utilizar los datos para sus propios fines.

---

### 5. Información financiera → Otra información financiera (Presupuestos y Metas)
- **Comprobación en código:** En `DatabaseHelper`, se almacenan en SQLite local. Si el usuario vincula su cuenta (`!user.isAnonymous`), se respaldan en Firestore (`/users/{uid}/presupuestos/user_settings`). No se transmiten a Gemini salvo que el usuario pregunte en el chat por su presupuesto.
- **¿Sale del dispositivo?:** Sí (al respaldar en la nube con cuenta vinculada).
- **¿Se comparte?:** No (Firestore es proveedor de servicios puro).
- **¿Es efímero?:** No (persiste en Firestore).
- **¿Obligatorio u Opcional?:** **Opcional** (no se transmite en modo anónimo).
- **Finalidad en Play Console:** *Funcionalidad de la aplicación*.
- **Estado:** **Verificado en el código fuente.**

---

### 6. Mensajes → Otros mensajes en la aplicación (Consultas al Asistente IA)
- **Comprobación en código:** En `lib/data/datasources/remote/gemini_service.dart` (`chatAnalyst`), las preguntas y el historial de conversación se transmiten mediante POST a Cloudflare y se reenvían a Gemini API.
- **¿Sale del dispositivo?:** Sí.
- **¿Es efímero?:** **No** (Google Cloud conserva logs de servidor en el modo comercial; en BYOK gratuito se retiene para entrenamiento).
- **¿Obligatorio u Opcional?:** **Opcional** (el uso del chat es voluntario).
- **Finalidad en Play Console:** *Funcionalidad de la aplicación*.
- **Decisión sobre Datos Compartidos:** **Pendiente.** Sujeta a la decisión de política sobre el flujo BYOK.

---

### 7. Fotos y vídeos → Fotos (Imágenes de facturas enviadas a IA)
- **Comprobación en código:** En `GeminiService.analyzeReceiptImage`, cuando la imagen se analiza con visión multimodal de Gemini, se envía codificada en Base64 a Cloudflare y luego a Gemini API. Si el OCR local de ML Kit tiene suficiente confianza, solo viaja el texto extraído (`analyzeReceiptText`).
- **¿Sale del dispositivo?:** Sí (cuando se requiere interpretación visual con IA).
- **¿Es efímero?:** **No** (por la retención de registros en Google Cloud y la retención prolongada en AI Studio Free Tier).
- **¿Obligatorio u Opcional?:** **Opcional** (el escaneo visual con IA es voluntario; el registro manual no transmite fotos).
- **Finalidad en Play Console:** *Funcionalidad de la aplicación*.
- **Decisión sobre Datos Compartidos:** **Pendiente.** Sujeta a la decisión de política sobre el flujo BYOK.

---

### 8. Dispositivo u otros identificadores
- **Comprobación en código:** Se revisaron las dependencias en `pubspec.yaml` y el código fuente.
  - No se utiliza `firebase_analytics`, `firebase_crashlytics` ni `firebase_messaging`.
  - No se integran SDKs de publicidad ni mediación (AdMob, Meta, etc.).
  - No se consultan identificadores de hardware (IMEI, dirección MAC, Android ID, Advertising ID).
  - El UID de Firebase Auth es un identificador de usuario, no de dispositivo.
- **¿Sale del dispositivo?:** No.
- **¿Recogido?:** **No**.
- **¿Compartido?:** **No**.
- **Estado:** **Verificado en el código fuente.**

---

## 4. Respuestas Recomendadas para Google Play Console

Para completar el formulario con una postura consistente que represente todos los flujos reales de la aplicación:

| Tipo de Dato en Play Console | ¿Recogido? | ¿Compartido? | ¿Efímero? | ¿Obligatorio u Opcional? | Finalidad Declarada |
|---|---|---|---|---|---|
| **Identificadores de usuario (UID)** | **Sí** | **No** | **No** | **Obligatorio** | Funcionalidad, Gestión de cuenta |
| **Correo electrónico** | **Sí** | **No** | **No** | **Opcional** | Gestión de cuenta |
| **Nombre** | **Sí** | **No** | **No** | **Opcional** | Gestión de cuenta |
| **Historial de compras (Gastos)** | **Sí** | *Pendiente (No / Sí con Google)* | **No** | **Opcional** | Funcionalidad de la aplicación |
| **Otra info financiera (Presupuestos)** | **Sí** | **No** | **No** | **Opcional** | Funcionalidad de la aplicación |
| **Otros mensajes en la app (Chat IA)** | **Sí** | *Pendiente (No / Sí con Google)* | **No** | **Opcional** | Funcionalidad de la aplicación |
| **Fotos (Facturas enviadas a IA)** | **Sí** | *Pendiente (No / Sí con Google)* | **No** | **Opcional** | Funcionalidad de la aplicación |
| **Identificadores de dispositivo** | **No** | **No** | N/A | N/A | No se recogen |

---

## 5. Prácticas Generales de Seguridad Declarables

1. **¿Se cifran todos los datos en tránsito?:** **Sí** (todas las conexiones hacia Firebase, Cloudflare y Gemini utilizan HTTPS / TLS con cifrado estándar).
2. **¿Mecanismo para solicitar la eliminación de datos?:** **Sí**.
   - Enlace directo in-app: *Más > Respaldo en la nube > Eliminar cuenta y datos*.
   - Enlace web oficial: `https://rindemas.cesarluis.com/eliminar-cuenta`.
3. **URL de eliminación de datos:** `https://rindemas.cesarluis.com/eliminar-cuenta`.
4. **URL de la política de privacidad:** `https://rindemas.cesarluis.com/privacidad`.

---

## 6. Lista Final de Decisiones: Verificadas vs. Pendientes

### A. Decisiones Verificadas (Comprobables en código y términos oficiales):
1. **Identificadores de usuario es Obligatorio:** En `lib/main.dart`, `signInAnonymously()` se ejecuta al iniciar la app. Todo usuario conectado transmite su UID anónimo a Firebase Auth.
2. **Historial de compras es Opcional:** En `lib/services/sync_service.dart`, los usuarios anónimos nunca sincronizan sus gastos con Firestore; la recogida fuera del dispositivo solo ocurre si el usuario activa el respaldo o usa la IA.
3. **Procesamiento efímero es NO para toda la IA:** Por los requisitos expresos de Google Play sobre registros del servidor y los términos de retención de Google Cloud / AI Studio, no se puede declarar procesamiento efímero en Gemini.
4. **Identificadores de dispositivo es NO:** La app no contiene SDKs de analítica, publicidad ni hardware tracking.
5. **Cifrado en tránsito y mecanismo de eliminación:** Ambos verificados en código y en producción web.

### B. Decisiones Pendientes (Exigen resolución estratégica antes de guardar el formulario):
1. **Tratamiento de BYOK frente a «Datos compartidos»:**
   - *Ruta 1 (Declarar «No se comparten datos»):* Sostener que BYOK es una transferencia iniciada por el usuario. *Pendiente:* Requiere evaluar si la advertencia informativa actual en `more_screen.dart` es suficiente o si Play Console exige un mecanismo formal de consentimiento explícito (checkbox/diálogo de confirmación) para respaldar la excepción.
   - *Ruta 2 (Declarar «Sí se comparten datos con Google»):* Declarar cesión a Google para fotos, mensajes y compras analizadas. *Pendiente:* Evaluar si es preferible la máxima transparencia en la ficha pública para eliminar cualquier riesgo de rechazo por parte de los revisores.
