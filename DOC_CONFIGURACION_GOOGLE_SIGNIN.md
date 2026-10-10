# Configuración de Google Sign-In y Resolución de Error 10 (DEVELOPER_ERROR)

Este documento detalla la configuración requerida para la autenticación con Google en **Rinde Más**, explicando la causa raíz del `Error 10` y los pasos exactos para resolverlo entre **Google Play Console** y **Firebase Console**.

---

## 1. Causa Raíz del Error 10 (`DEVELOPER_ERROR: 10`)

En Android y Google Play Services, el error 10 ocurre cuando la aplicación instalada en el dispositivo móvil intenta autenticarse mediante Google Sign-In, pero los servidores de Google rechazan la solicitud.

Esto sucede por la arquitectura de firma de **Google Play App Signing**:
1. El código fuente compila un `.aab` firmado con la clave de subida local (`android_template/rindemas.jks`).
2. Al subir el `.aab` a Google Play Console (prueba interna o producción), **Google Play re-firma la aplicación con su propia clave privada** (*Clave de firma de aplicaciones de Google Play*).
3. Cuando instalas la app desde Google Play en tu teléfono, el APK en el dispositivo tiene la huella digital **SHA-1 de Google Play**, **NO** la de `rindemas.jks`.
4. Si la huella SHA-1 de Google Play no está registrada en **Firebase Console** bajo el paquete `com.cesarluis.rindemas`, Google Play Services bloquea la autenticación con `ApiException: 10`.

---

## 2. Huellas Digitales del Proyecto

### A. Clave de Subida Local (`rindemas.jks`)
*Usada para firmar el AAB en GitHub Actions y para compilaciones directas de APK.*
* **Alias:** `rindemas`
* **SHA-1:** `D3:85:0D:17:34:0B:EE:8D:E4:16:1D:B8:FA:DD:D5:12:1F:02:0D:10`
* **SHA-256:** `B2:06:E4:7B:53:63:04:9F:0E:D9:D1:E1:84:22:9D:B8:99:4D:4A:EB:88:95:12:E5:11:96:C8:EE:28:69:14:5D`

### B. Clave de Firma de Google Play (Play App Signing)
*Generada por Google Play Console para las descargas de la tienda y pruebas internas.*
* **Ubicación:** Google Play Console > Rinde Más > Configuración > Integridad de la app > Firma de apps > *Certificado de la clave de firma de la app*.

### C. Web Client ID (OAuth 2.0)
*Configurado en `AppConstants.googleWebClientId`:*
* `758679432067-p4lll1b5vfia32fndd68gjif6bmfmvel.apps.googleusercontent.com`

---

## 3. Pasos para Solucionar el Error 10

### Paso 1: Obtener la Huella SHA-1 de Google Play Console
1. Entra a [Google Play Console](https://play.google.com/console).
2. Selecciona la app **Rinde Más**.
3. En el menú lateral izquierdo, baja a **Configuración** > **Integridad de la app** (o *Firma de apps de Play*).
4. En la pestaña **Firma de apps**, ubica el primer bloque: **Certificado de la clave de firma de la app**.
5. Copia la **Huella digital del certificado SHA-1**.

### Paso 2: Registrar la App y las Huellas en Firebase Console
1. Entra a [Firebase Console](https://console.firebase.google.com/).
2. Abre el proyecto **gastoscan-ai**.
3. Haz clic en el ícono de engranaje ⚙️ junto a *Descripción general* y entra a **Configuración del proyecto**.
4. En la pestaña **General**, baja a la sección **Tus apps**:
   - Si no existe una app de Android con paquete `com.cesarluis.rindemas`:
     - Haz clic en **Agregar aplicación** (ícono de Android).
     - Nombre de paquete: `com.cesarluis.rindemas`.
     - Apodo: `Rinde Más`.
     - Haz clic en **Registrar aplicación**.
   - En la app Android `com.cesarluis.rindemas`:
     - Haz clic en **Agregar huella digital**.
     - Pega la huella **SHA-1 de Google Play Console** (obtenida en el Paso 1).
     - Haz clic de nuevo en **Agregar huella digital**.
     - Pega la huella **SHA-1 de la clave de subida**: `D3:85:0D:17:34:0B:EE:8D:E4:16:1D:B8:FA:DD:D5:12:1F:02:0D:10`.
5. Descarga el archivo **`google-services.json`** actualizado y colócalo en `android/app/google-services.json`.

### Paso 3: Verificar Correo de Asistencia
1. En **Firebase Console** > **Configuración del proyecto** > pestaña **General**.
2. Verifica que el campo **Correo electrónico de asistencia del proyecto** tenga un correo asignado (ej. tu correo de Google).
3. En **Autenticación** (Authentication) > pestaña **Sign-in method**:
   - Asegúrate de que el proveedor **Google** esté habilitado con el correo de asistencia configurado.

---

## 4. Validación Inmediata en el Teléfono
Una vez agregadas las huellas SHA-1 en Firebase Console:
- Google Play Services en los servidores de Google propaga las nuevas huellas en aproximadamente 5 a 15 minutos.
- Abre la app instalada en tu teléfono y vuelve a pulsar **Vincular con Google**.
- Al seleccionar tu cuenta, Google validará la huella y completará la vinculación sin mostrar el Error 10.
