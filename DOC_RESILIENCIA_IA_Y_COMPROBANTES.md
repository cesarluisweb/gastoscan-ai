# Documentación Técnica: Resiliencia de IA y Comprobantes Persistentes

**Fecha:** 7 de octubre de 2026  
**Estado:** Pendiente de pruebas y visto bueno del usuario  
**Archivos modificados:**
- `lib/data/datasources/remote/gemini_service.dart`
- `lib/providers/scan_queue_provider.dart`
- `lib/ui/widgets/global_scan_queue_banner.dart`
- `lib/ui/screens/chat_screen.dart`
- `lib/ui/screens/review_expense_screen.dart`
- `MEMORY.md`

---

## 1. Resumen de Cambios Implementados

### 1.1 Resiliencia de IA y Mensajes Claros (Prioridad 1 y 3)
- **Mensajes de error orientados al usuario:** Se eliminaron los textos técnicos y prefijos como `Exception:` o jerga de servidor en `GeminiService` y `ScanQueueProvider`. Ante saturación o cuotas (HTTP 429), timeouts (HTTP 504) o indisponibilidad (HTTP 502/503), el sistema informa con calma:
  > *"El servicio de IA no está disponible en este momento. Tu comprobante está seguro y pendiente de procesamiento."*
  Y en caso de desconexión:
  > *"Sin conexión. Tu comprobante quedó guardado y se procesará automáticamente."*
- **Chat resiliente (`chat_screen.dart`):** Si el backend de IA falla o agota tiempo, el asistente responde con un mensaje limpio en el chat sin bloquear la app ni mostrar trazas de error.
- **Cola recuperable (`scan_queue_provider.dart` y `global_scan_queue_banner.dart`):**
  - Se añadió el método `retryItem(int id)` que reinicia un comprobante en estado `error` devolviéndolo a `pending` con contador de intentos en cero.
  - En la vista detallada de la cola (al tocar el banner), cada ítem en estado `error` ahora muestra un botón de **Reintentar** (icono de refrescar amarillo/acento) junto al botón de descartar.

### 1.2 Comprobantes en Gastos Manuales y Existentes (Prioridad 4, 5 y 6)
- **Persistencia 1:1:** Se reutiliza el campo `rutaFotoLocal` del modelo `GastoModel` en SQLite, asegurando total compatibilidad retroactiva sin migraciones destructivas.
- **Adjuntar comprobante opcional (`review_expense_screen.dart`):**
  - Al crear un gasto manual (sin foto previa), aparece un botón visible y opcional: **"Adjuntar comprobante (Opcional)"**.
  - Permite seleccionar entre **Cámara** o **Galería**.
  - Si un gasto ya cuenta con comprobante (escaneado o manual previo), la cabecera muestra la foto con opción de ampliarla a pantalla completa, además de dos acciones directas: **"Cambiar comprobante"** y **"Eliminar comprobante"**.
  - Al guardar, la imagen seleccionada se copia de forma permanente al almacenamiento interno de la app mediante `ImageService.saveImagePermanently` y se persiste en SQLite.

---

## 2. Guía Paso a Paso para Pruebas de Verificación

Sigue estos pasos en la aplicación para comprobar que todo funciona de acuerdo a lo esperado:

### Prueba A: Adjuntar comprobante en un gasto manual
1. Abre la aplicación y pulsa el botón **"+"** (Nuevo gasto manual).
2. Verifica que arriba de los campos aparece el botón **"Adjuntar comprobante (Opcional)"**.
3. Pulsa el botón y selecciona **"Tomar foto con la cámara"** o **"Elegir de la galería"**.
4. Selecciona cualquier foto de prueba.
5. Comprueba que la imagen se muestra en la cabecera con el botón de "Tocar para ampliar", "Cambiar comprobante" y "Eliminar comprobante".
6. Completa un comercio (ej. "Prueba Foto"), monto y pulsa **Guardar Gasto**.
7. Ve a la pantalla de Historial, busca el gasto guardado y ábrelo. Verifica que la foto sigue allí asociada.

### Prueba B: Cambiar o eliminar un comprobante existente
1. Abre el gasto que acabas de guardar en la Prueba A.
2. Pulsa en **"Cambiar comprobante"**, elige otra imagen y verifica que la miniatura se actualice.
3. Pulsa en **"Eliminar comprobante"** y verifica que la foto desaparezca y vuelva a aparecer el botón "Adjuntar comprobante (Opcional)".
4. Pulsa Guardar y verifica que el gasto se guarde sin errores.

### Prueba C: Recuperación y reintento en cola de escaneo
1. Abre la cola de escaneo si tienes comprobantes pendientes o con error.
2. Si un comprobante falló por red o cuota y quedó en estado `Error de procesamiento`, abre el modal de la cola tocando el banner superior.
3. Verifica que el ítem con error muestra el botón de refrescar (flecha circular).
4. Pulsa el botón de reintentar y comprueba que su estado cambia a `En cola de espera` para reintentar el procesamiento.

### Prueba D: Mensajes en el Chat de IA
1. Entra al Asistente IA (Chat).
2. Envía una consulta. Si el servicio responde, verifica que la respuesta sea natural.
3. Si en algún momento no hay internet o el servicio estuviera temporalmente caído, verifica que el chat no muestre `Exception: ...` sino un mensaje legible y amigable.

---

## 3. Próximo Paso
Una vez realizadas estas pruebas y recibido tu visto bueno:
1. Se registrará el hito como completado en `ROADMAP.md`.
2. Se procederá con la siguiente tarea planificada (Planificación de API Key propia opcional para Gemini en sección Más).
