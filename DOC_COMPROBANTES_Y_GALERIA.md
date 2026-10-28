# Gestión de Comprobantes, Galería Mensual y Álbum en Dispositivo

## Resumen de Cambios Implementados

En respuesta directa a la experiencia de usuario y requerimientos funcionales solicitados:
1. **Adjuntar y Eliminar Comprobantes Manuales:** En el formulario de registro y edición de gastos (`ReviewExpenseScreen`), ahora es posible adjuntar fotos desde la cámara o galería en transacciones manuales, así como sustituirlas o eliminarlas en cualquier momento.
2. **Visor de Comprobante a Pantalla Completa (`ReceiptViewerDialog`):** Los gastos con comprobante muestran un icono discreto de foto junto a la fecha (no cliqueable). Al pulsar el menú contextual de opciones (tres puntos), el orden es: *Editar*, *Ver comprobante* y *Eliminar*. Al seleccionar *Ver comprobante*, se abre de inmediato el visor a pantalla completa con zoom interactivo (`InteractiveViewer`), detalles del comercio/monto/fecha, opción de compartir, guardado directo en galería, botón para **«Ver o editar gasto»** y botón de papelera para **eliminar la foto del dispositivo** preservando el registro contable.
3. **Filtro Rápido de Comprobantes en Historial de Gastos (`ExpenseHistoryScreen`):** Se integró un botón de acción con icono de galería (`Icons.photo_library_outlined`) en la barra superior. Con un solo toque, el usuario puede filtrar toda la lista para ver exclusivamente los gastos que cuentan con foto de comprobante adjunta.
4. **Galería Mensual de Comprobantes (`ReceiptGalleryScreen`):** Dentro de la tarjeta *"Almacenamiento de fotos"* en la pantalla *"Más"*, se agregó la opción *"Ver comprobantes guardados"*, que muestra el conteo mensual y abre una cuadrícula organizada por mes y año con todas las fotos guardadas en el dispositivo.
5. **Selección Múltiple y Eliminación en Lote:** Dentro de la galería mensual, el usuario puede activar el modo de selección (tocando «Seleccionar» o manteniendo presionado cualquier comprobante) para marcar varias fotos y eliminarlas del teléfono de un solo toque para liberar almacenamiento. El diálogo de confirmación aclara expresamente que las compras, montos y categorías se conservan intactos en la base de datos.
6. **Enlace Directo para Ver o Editar el Gasto:** Tanto en la barra superior como en la barra inferior del visor de pantalla completa, un botón destacado abre directamente la pantalla de edición del gasto (`ReviewExpenseScreen`), evitando tener que salir a buscar la compra al Historial.
7. **Cero Duplicidad y Álbum "Rinde Más" (`gal`):** Cuando la opción de guardar fotos está activa, las fotos se guardan en el álbum "Rinde Más" de la galería del teléfono sin duplicar almacenamiento ni consumir doble espacio.

---

## Archivos Modificados y Creados

- **`pubspec.yaml`**: Incorporación de dependencia `gal: ^2.3.0` para acceso nativo al MediaStore sin requerir permisos invasivos de almacenamiento global.
- **`lib/services/image_service.dart`**: Integración de guardado automático y manual en álbum "Rinde Más" con `Gal.putImage`.
- **`lib/ui/widgets/receipt_viewer_dialog.dart`**: Visor a pantalla completa con zoom táctil, compartir (`Share.shareXFiles`), guardado a galería, acceso a edición de gasto y eliminación individual de foto con confirmación.
- **`lib/ui/screens/receipt_gallery_screen.dart`**: Cuadrícula mensual de comprobantes con selección individual, modo de selección múltiple, eliminación masiva con salvaguarda del gasto y acceso directo al visor.
- **`lib/data/datasources/local/database_helper.dart`**: Métodos `clearRutaFotoLocal` y `clearRutasFotosLocales` para desvincular rutas en SQLite preservando los registros contables.
- **`lib/data/repositories/gasto_repository.dart`**: Métodos de repositorio para desvincular rutas locales de fotos.
- **`lib/providers/gasto_provider.dart`**: Métodos `eliminarFotoComprobante` y `eliminarFotosComprobantes` para borrar archivos del disco y desvincularlos en base de datos.
- **`lib/data/models/gasto_model.dart`**: Método `sinFoto()` para generar copias desvinculadas.
- **`lib/ui/widgets/expense_card.dart`**: Chip "Foto" interactivo y opción en menú contextual para abrir el comprobante en un toque.
- **`lib/ui/screens/review_expense_screen.dart`**: Soporte completo para adjuntar fotos a gastos manuales, cambiar o eliminar comprobantes existentes.
- **`lib/ui/screens/more_screen.dart`**: Navegación integrada a la galería mensual dentro de la tarjeta "Almacenamiento de fotos" con subvista segura (`PopScope`).
- **`lib/ui/screens/expense_history_screen.dart`**: Filtro rápido por comprobantes con icono `Icons.photo_library_outlined` en la barra superior.
- **`test/screens/receipt_gallery_screen_test.dart`**: Pruebas de galería, navegación mensual, selección múltiple y eliminación en lote.
- **`test/widgets/receipt_viewer_dialog_test.dart`**: Pruebas de renderizado, apertura de edición y eliminación individual.

---

## Guía de Pruebas Paso a Paso para Verificación Manual

### 1. Eliminar foto individual desde el visor
1. Abrir la pestaña **Más** y entrar en **Almacenamiento de fotos** > **Ver comprobantes guardados**.
2. Tocar cualquier comprobante de la cuadrícula para abrirlo en grande.
3. Tocar el icono de papelera (en la barra superior o en la barra inferior).
4. Comprobar que el diálogo explica claramente: *"La foto se borrará del teléfono para liberar espacio. El registro del gasto, sus montos y detalles se conservarán intactos en tu historial."*
5. Confirmar la eliminación.
6. Verificar que la pantalla se cierra, la foto ya no aparece en la galería, y al ir a la pestaña **Gastos**, el registro de compra sigue existiendo con sus montos intactos (solo sin la foto).

### 2. Ver o editar el gasto desde el visor de foto
1. Abrir un comprobante en pantalla completa.
2. Tocar el botón inferior **«Ver o editar gasto»** (o el icono de lápiz superior).
3. Verificar que se abre inmediatamente el formulario de edición de ese gasto (`ReviewExpenseScreen`).
4. Al regresar, comprobar que la vista vuelve a la galería de comprobantes con los cambios reflejados.

### 3. Selección múltiple y eliminación masiva en la galería
1. En la pantalla **Comprobantes Guardados**, tocar el botón **«Seleccionar»** en la esquina superior derecha (o mantener presionado cualquier comprobante).
2. Comprobar que la barra superior cambia a modo selección con el contador de seleccionados.
3. Tocar varios comprobantes para seleccionarlos/deseleccionarlos (o usar el botón «Seleccionar todos»).
4. Tocar el botón inferior rojo **«Eliminar X fotos»** o el icono de papelera superior.
5. Confirmar en el diálogo de advertencia.
6. Verificar que las fotos se borran del almacenamiento y se muestra un mensaje informativo, mientras todos los registros de gastos se conservan en la aplicación.
