# Guía Operativa: Envíos Masivos (Broadcast) y Control de Textos Online

Esta guía describe el procedimiento para que César pueda:
1. Enviar una notificación masiva push a todos los usuarios de **Rinde Más** cuando lo desee.
2. Editar los textos del Asistente IA y recordatorios de compras online sin publicar nuevas versiones en Google Play.

---

## 1. Cómo enviar una Notificación Masiva (Broadcast)

Las notificaciones masivas se envían directamente desde la consola oficial de Google Firebase, sin costo y sin necesidad de escribir código.

### Paso a paso:

1. **Acceder a la Consola de Firebase:**
   * Entra en tu navegador a: [https://console.firebase.google.com/](https://console.firebase.google.com/)
   * Inicia sesión con la cuenta de Google del proyecto y selecciona el proyecto **Rinde Más** (`gastoscan-ai` / `com.cesarluis.rindemas`).

2. **Ir a la sección de Mensajería:**
   * En el menú lateral izquierdo, despliega la sección **Participación (Engagement)** o **Compilar (Build)** y haz clic en **Cloud Messaging** (o **Mensajería**).

3. **Crear una Nueva Campaña:**
   * Haz clic en el botón azul **Nueva campaña** (o *Crear tu primera campaña*).
   * Elige la opción **Notificaciones de Firebase**.

4. **Paso 1: Redactar la Notificación:**
   * **Título de la notificación:** El encabezado llamativo (ej. `¡Nueva versión disponible!` o `Aviso de Rinde Más`).
   * **Texto de la notificación:** El cuerpo del mensaje (ej. `Ya puedes dictar tus compras con la voz y escanear tickets más rápido. Actualiza tu app.`).
   * *(Opcional)* Nombre de la notificación: Identificador interno para tus estadísticas en Firebase (ej. `lanzamiento_v1_4`).

5. **Paso 2: Segmentación (Destinatarios):**
   * En lugar de seleccionar la app directamente, elige la opción **Tema (Topic)**.
   * En el campo de búsqueda escribe o selecciona:
     ```text
     anuncios_generales
     ```
   * *Nota:* Todos los usuarios que tienen la app instalada quedan automáticamente suscritos de forma anónima a este tema.

6. **Paso 3: Programación:**
   * Selecciona **Ahora** para enviar de inmediato, o define una fecha y hora futura si deseas programarla.

7. **Paso 4: Revisar y Publicar:**
   * Haz clic en **Siguiente** hasta llegar a **Revisar**.
   * Verifica el título, el mensaje y el tema (`anuncios_generales`).
   * Haz clic en **Publicar**.

En cuestión de pocos segundos, la notificación llegará a todos los teléfonos con la app instalada y conexión a internet.

---

## 2. Cómo editar los Textos de los Recordatorios Online (Sin actualizar la App)

Los recordatorios quincenales de fin de semana y de inactividad se alimentan de Cloud Firestore. Si deseas cambiar una frase, mejorar el tono del Asistente IA o lanzar un mensaje alusivo a una fecha especial:

1. En la consola de Firebase, ve a **Firestore Database**.
2. En la lista de colecciones, selecciona la colección `config` (o créala si es la primera vez).
3. Añade o abre el documento con ID: `recordatorios`.
4. Puedes definir los siguientes campos:

### Campos admitidos en `/config/recordatorios`:

* **`mensajes_quincenales`** *(Tipo: array)*:
  Lista de objetos (mapas) con los mensajes rotativos para los sábados. Cada elemento contiene:
  * `titulo` *(string)*: Encabezado del recordatorio.
  * `cuerpo` *(string)*: Mensaje del Asistente IA.

  *Ejemplo en Firestore:*
  ```json
  [
    {
      "titulo": "Mantén tu presupuesto al día",
      "cuerpo": "Aquí estoy para ayudarte: si hiciste compras hoy, tómale foto a los comprobantes y yo me encargo de ordenar los números."
    },
    {
      "titulo": "¿Compras de fin de semana?",
      "cuerpo": "Pásame una foto de tus facturas de hoy antes de que se borre el papel térmico y extraigo los precios en segundos."
    },
    {
      "titulo": "Tus cuentas claras",
      "cuerpo": "Sube tus tickets del mercado o díctame tus gastos de hoy para cuadrar la quincena sin estrés."
    },
    {
      "titulo": "Que no se te acumulen los tickets",
      "cuerpo": "Una foto rápida a tus comprobantes de hoy y dejo tus gastos organizados por categoría de una vez."
    }
  ]
  ```

* **`inactividad_titulo`** *(Tipo: string)*:
  Título del recordatorio tras 30 días sin registros (ej. `Tus cuentas al día`).

* **`inactividad_cuerpo`** *(Tipo: string)*:
  Texto del recordatorio de inactividad (ej. `Ha pasado un mes desde tu último registro. Si tienes comprobantes acumulados, aquí estoy para ayudarte a ordenar tus números cuando quieras.`).

5. Haz clic en **Guardar**.
6. **Efecto inmediato:** La próxima vez que cualquier usuario abra la app con internet, los nuevos textos se descargarán y guardarán en la memoria de su teléfono de forma automática. Si no hay conexión o no has creado el documento en Firestore, la app utiliza su banco base preinstalado de forma transparente.
