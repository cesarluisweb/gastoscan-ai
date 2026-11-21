# Reporte de Respuestas de IA (AI-10)

> Cumple la política de Google Play **"Contenido generado por IA"**: el usuario reporta una respuesta desde la app y el desarrollador recibe el reporte.

## 1. Qué cambió

| Archivo | Cambio |
|---|---|
| `firestore.rules:142` | Nueva colección `ai_reports`. Crear solo el propio reporte; leer y borrar solo los propios; `update` prohibido. |
| `lib/services/ai_report_service.dart` | Servicio de envío. Valida conexión, resuelve el usuario, recorta textos y traduce errores a mensajes amigables. |
| `lib/ui/screens/chat_screen.dart:1006` | Diálogo nuevo: motivo (4 opciones), comentario opcional, estado de carga y error inline. |
| `lib/ui/screens/chat_screen.dart:1393` | Botón "Reportar respuesta". Se oculta en el saludo inicial. |
| `lib/services/sync_service.dart:575` | El borrado de cuenta elimina los reportes del usuario. |
| `landing/src/pages/privacidad.astro` | Sección 2.D: reportes almacenados en Firestore. |
| `landing/src/pages/eliminar-cuenta.astro` | Fila nueva en la tabla de datos eliminados. |

## 2. Documento en Firestore

`ai_reports/{autoId}`

| Campo | Tipo | Regla |
|---|---|---|
| `uid` | string | Igual a `request.auth.uid`. |
| `texto_respuesta` | string | 1 a 4000 caracteres. |
| `motivo` | string | `Inexacta`, `Inapropiada`, `Ofensiva` u `Otro`. |
| `comentario` | string | Hasta 500 caracteres. Puede ir vacío. |
| `origen` | string | `app` o `web`. |
| `creado_en` | timestamp | Debe ser `request.time`. |

## 3. Cómo revisar los reportes

1. Abrir [Firebase Console](https://console.firebase.google.com/) → proyecto `gastoscan-ai`.
2. Ir a **Firestore Database** → colección `ai_reports`.
3. Ordenar por `creado_en` descendente.
4. Cada documento muestra el texto reportado, el motivo y el comentario.

Los reportes se leen con acceso de administrador. Las reglas bloquean la lectura ajena desde la app.

## 4. Despliegue de reglas (manual)

`deploy_rules.yml` no corre con cada `push`. Después de que `test_rules.yml` esté en verde:

1. GitHub → Actions → **Desplegar Reglas de Firestore (manual)** → *Run workflow*.
2. Escribir `DEPLOY` en el campo de confirmación.
3. Verificar que el job termine en verde.

Sin este paso, los reportes fallan con `PERMISSION_DENIED`.

## 5. Guía de pruebas en dispositivo

- **SHA:** `467a45e`
- **APK build:** `730` (run `44925424000`)
- **Reglas Firestore:** emulador en verde (build `6`, run `44925423926`) — **requiere `deploy_rules.yml` manual con `DEPLOY` antes de probar**
- **Web:** build `34` (run `44925423898`, `/privacidad` y `/eliminar-cuenta` HTTP 200)

1. Abrir la app → pestaña **Más** → **Asistente IA**.
2. Enviar un mensaje, por ejemplo: *"¿En qué gasté más este mes?"*.
3. En la burbuja de respuesta, pulsar **Reportar respuesta** (`chat_screen.dart:1393`).
4. Elegir un motivo, por ejemplo **Inexacta**.
5. Escribir un comentario opcional.
6. Pulsar **Enviar reporte** (`chat_screen.dart:1086`).
7. Confirmar el mensaje "Gracias por tu reporte. Lo revisaremos para mejorar el asistente.".
8. En Firebase Console, confirmar el documento nuevo en `ai_reports`.

Casos adicionales:

- **Sin conexión:** activar modo avión y enviar. Debe aparecer "Necesitas conexión a internet para enviar el reporte.".
- **Saludo inicial:** el botón no aparece en el primer mensaje del asistente.
- **Borrado de cuenta:** eliminar la cuenta y confirmar que sus reportes desaparecen de `ai_reports`.

## 6. Pruebas automáticas

| Archivo | Cobertura |
|---|---|
| `test/services/ai_report_service_test.dart` | Construcción del documento, recorte y validación. |
| `test/screens/chat_screen_test.dart` | Diálogo, envío, error y botón oculto en el saludo. |
| `test/firestore_rules/rules.test.js` | RT-25 a RT-29: creación, uid ajeno, update, tamaño y lectura. |

## 7. Data Safety

No requiere cambios. La declaración ya incluye **"Otros mensajes en la app (Chat con IA)"** como dato recogido (`docs/DOC_DECLARACION_SEGURIDAD_DATOS_PLAY.md:69`).

## 8. Limitación conocida

El botón **Reportar respuesta** del panel web (`landing/src/pages/panel.astro:4146`) sigue siendo local. Igualarlo requiere aprobación explícita por la regla de sincronización web.
