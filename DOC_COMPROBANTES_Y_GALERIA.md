# Gestión de Comprobantes, Galería Mensual y Álbum en Dispositivo

## Resumen de Cambios Implementados

En respuesta directa a la experiencia de usuario y requerimientos funcionales solicitados:
1. **Adjuntar y Eliminar Comprobantes Manuales:** En el formulario de registro y edición de gastos (`ReviewExpenseScreen`), ahora es posible adjuntar fotos desde la cámara o galería en transacciones manuales, así como sustituirlas o eliminarlas en cualquier momento.
2. **Visor Directo de Comprobante a Pantalla Completa (`ReceiptViewerDialog`):** Al tocar el indicador visual "Foto" en cualquier tarjeta de gasto (`ExpenseCard`), o seleccionando la opción *"Ver comprobante"* en el menú contextual de tres puntos, se abre de inmediato un visor a pantalla completa con zoom interactivo (`InteractiveViewer`), detalles del comercio/monto/fecha, opción de compartir y guardado directo en galería.
3. **Filtro Rápido de Comprobantes en Historial de Gastos (`ExpenseHistoryScreen`):** Se integró un botón de acción con icono de galería (`Icons.photo_library_outlined`) en la barra superior. Con un solo toque, el usuario puede filtrar toda la lista para ver exclusivamente los gastos que cuentan con foto de comprobante adjunta.
4. **Galería Mensual de Comprobantes (`ReceiptGalleryScreen`):** Dentro de la tarjeta existente de *"Almacenamiento y Fotos"* en la pantalla *"Más"*, se agregó la opción *"Ver comprobantes guardados"*, que muestra el conteo mensual y abre una cuadrícula organizada por mes y año con todas las fotos guardadas en el dispositivo.
5. **Cero Duplicidad y Álbum "Rinde Más" (`gal`):** Cuando la opción de guardar fotos está activa, las fotos se guardan en el álbum "Rinde Más" de la galería del teléfono sin duplicar almacenamiento ni consumir doble espacio.

---

## Archivos Modificados y Creados

- **`pubspec.yaml`**: Incorporación de dependencia `gal: ^2.3.0` para acceso nativo al MediaStore sin requerir permisos invasivos de almacenamiento global.
- **`lib/services/image_service.dart`**: Integración de guardado automático y manual en álbum "Rinde Más" con `Gal.putImage`.
- **`lib/ui/widgets/receipt_viewer_dialog.dart`** *(Nuevo)*: Visor a pantalla completa con zoom táctil, compartir (`Share.shareXFiles`) y guardado a galería.
- **`lib/ui/screens/receipt_gallery_screen.dart`** *(Nuevo)*: Cuadrícula mensual de comprobantes con navegación entre meses y acceso directo al visor.
- **`lib/ui/widgets/expense_card.dart`**: Chip "Foto" interactivo y opción en menú contextual para abrir el comprobante en un toque.
- **`lib/ui/screens/review_expense_screen.dart`**: Soporte completo para adjuntar fotos a gastos manuales, cambiar o eliminar comprobantes existentes.
- **`lib/ui/screens/more_screen.dart`**: Navegación integrada a la galería mensual dentro de la tarjeta "Almacenamiento y Fotos" con subvista segura (`PopScope`).
- **`lib/ui/screens/expense_history_screen.dart`**: Filtro rápido por comprobantes con icono `Icons.photo_library_outlined` en la barra superior.
- **`test/screens/receipt_gallery_screen_test.dart`** *(Nuevo)*: Pruebas unitarias de la pantalla de galería y navegación mensual.
- **`test/widgets/receipt_viewer_dialog_test.dart`** *(Nuevo)*: Pruebas de renderizado y estados de error del visor de comprobantes.
- **`test/screens/dashboard_search_test.dart`**: Prueba de integración del filtro de comprobantes en el historial de gastos.
- **`test/screens/more_screen_test.dart`**: Prueba de navegación interna hacia la galería de comprobantes.

---

## Guía de Pruebas Paso a Paso para Verificación Manual

### 1. Adjuntar foto a un gasto manual
1. Tocar el botón de agregar gasto manual (+).
2. Tocar el botón **"Adjuntar comprobante (Opcional)"**.
3. Tomar una foto con la cámara o seleccionar una imagen existente de la galería.
4. Confirmar que la previsualización se muestra con la opción de ampliar, cambiar o eliminar.
5. Guardar el gasto.

### 2. Visor directo desde la lista de gastos
1. En la pantalla principal o pestaña de **Gastos**, ubicar el gasto recién guardado.
2. Comprobar que aparece una etiqueta pequeña **"Foto"** al lado de la fecha.
3. Tocar directamente sobre la etiqueta **"Foto"** (o en el menú de tres puntos > **"Ver comprobante"**).
4. Verificar que se abre la pantalla completa oscura con el nombre del comercio y el monto.
5. Probar el zoom pellizcando la pantalla y los botones superiores de compartir y guardar en galería.

### 3. Filtro de comprobantes en Historial de Gastos
1. Entrar en la pestaña **Gastos**.
2. Tocar el icono de galería en la parte superior derecha (al lado del icono de búsqueda).
3. Verificar que la lista se filtra para mostrar únicamente los gastos con comprobante.
4. Tocar nuevamente el icono y verificar que reaparecen todos los gastos.

### 4. Galería mensual en Más
1. Ir a la pestaña **Más**.
2. En la tarjeta **"Almacenamiento y Fotos"**, verificar que debajo del switch aparece **"Ver comprobantes guardados"** con el conteo de fotos del mes.
3. Tocar la opción para entrar en la galería mensual.
4. Navegar entre meses con las flechas superiores (< >) para revisar los comprobantes de meses pasados o futuros.
5. Tocar cualquier comprobante de la cuadrícula para abrirlo en el visor completo.
