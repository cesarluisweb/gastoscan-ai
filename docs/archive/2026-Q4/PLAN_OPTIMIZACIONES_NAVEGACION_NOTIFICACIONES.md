# Plan de Implementación: Navegación, Transiciones, Notificaciones Globales y Registro de Gastos

## 1. Contexto y Objetivos
Este plan aborda la optimización de la experiencia de usuario (UX/UI) en Rinde Más según los requerimientos acordados:
1. Transición de desvanecimiento (*fade*) sutil e imperceptible entre las secciones principales de la app.
2. Iconos diferenciados de la pestaña Análisis en la barra inferior (modo contorno cuando está inactivo, relleno al seleccionarse).
3. Reducción de espaciado en la tarjeta de resumen (`SummaryCard`) para mayor proximidad entre el título y las cifras.
4. Ajustes textuales y estéticos en el registro de gastos:
   - Encabezado claro en el menú modal (+).
   - Título adaptativo en la barra superior ("Registrar gasto" para entrada manual vs. "Revisar factura" para comprobantes con IA).
   - Etiqueta "Fecha de gasto" en lugar de "Fecha de Emisión".
5. Selector de categorías enriquecido con iconos y distintivos de color temáticos en el formulario de gasto.
6. Unificación del selector de moneda con el componente de pastilla bimonetaria `[ USD | VES ]` usado en presupuestos.
7. Acceso directo a cámara y galería desde el menú (+) sin pantallas intermedias ni bloqueos al cancelar.
8. Barra superior flotante y discreta para el estado de escaneo en segundo plano visible desde cualquier pestaña, con acceso inmediato a revisar facturas listas mientras otras continúan procesándose.

---

## 2. Cambios por Componente

### 2.1 Navegación Principal y Transición entre Pestañas (`lib/ui/screens/main_screen.dart`)
- **Transición Fade**: Sustituir el cambio instantáneo de `IndexedStack` por una transición de desvanecimiento suave (`150 ms`, curva de aceleración sutil) que mantenga el estado de cada vista en memoria sin recargar datos ni perder posición de desplazamiento.
- **Icono de Análisis**:
  - Inactivo: `Icons.analytics_outlined` (silueta de barras).
  - Activo: `Icons.analytics` (relleno sólido).
- **Acceso Directo desde el Menú (+)**:
  - Opción "Escanear factura (IA)": Inicia directamente `ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90)`. Al tomar la foto, la inserta en la cola de `ScanQueueProvider` y emite una confirmación breve. Si el usuario cancela, permanece en su pantalla actual.
  - Opción "Subir comprobante (IA)": Inicia directamente `ImagePicker().pickMultiImage(imageQuality: 90)`. Encola las fotos seleccionadas directamente y regresa de inmediato.
  - Actualizar texto del encabezado del modal (+) a "Selecciona una opción".

### 2.2 Barra Superior Global de Escaneo en Segundo Plano (`lib/ui/screens/main_screen.dart`)
- Ubicada de forma persistente en la parte superior del cuerpo de `MainScreen` (debajo de la barra de estado).
- Cobertura total en las 4 pestañas (Inicio, Gastos, Análisis, Más).
- **Estados de la barra**:
  1. **En procesamiento**: Barra delgada y sutil con indicador de carga circular y texto:
     - *"Procesando factura en segundo plano..."* o *"Procesando N facturas en segundo plano..."*.
  2. **Factura(s) lista(s) para revisión**: Píldora de acción con fondo de acento y texto en negro (cumpliendo la regla de legibilidad):
     - Si solo hay listas: *"N factura(s) lista(s) para revisar • Toca aquí"*.
     - Si hay listas y en proceso a la vez: *"N lista(s) para revisar (M procesando...)"*.
  3. Al pulsarla, abre `ReviewExpenseScreen` de la primera factura disponible sin esperar a que el resto finalice.

### 2.3 Tarjeta de Resumen (`lib/ui/widgets/summary_card.dart`)
- Reducir el espacio vertical entre "Total gastado" y el monto principal de `SizedBox(height: 6)` a `SizedBox(height: 2)`.
- Ajustar la separación entre el monto principal y el secundario en Bolívares a `SizedBox(height: 1)`.
- Mantener los márgenes interiores compactos y proporcionales.

### 2.4 Registro y Revisión de Gastos (`lib/ui/screens/review_expense_screen.dart`)
- **Título de la AppBar**:
  - Entrada manual (sin imagen ni identificador de cola): `"Registrar gasto"`.
  - Revisión OCR con 1 elemento: `"Revisar factura"`.
  - Revisión OCR con varios elementos en cola: `"Revisar factura (N en cola)"`.
- **Etiqueta de Fecha**: Cambiar `"Fecha de Emisión"` a `"Fecha de gasto"`.
- **Selector de Moneda Bimonetario**:
  - Reemplazar `SegmentedButton` por la pastilla `[ USD | VES ]` con borde y contenedor `AppColors.cardLighter`, fondo blanco/superficie en la opción activa y tipografía en negro.
- **Desplegable de Categorías**:
  - Modificar cada `DropdownMenuItem` para incluir un distintivo circular con el color asignado a la categoría (`AppColors.categoryColors`), el icono correspondiente (`Icons.shopping_cart_outlined`, `Icons.medical_services_outlined`, etc.) y el nombre de la categoría.

---

## 3. Plan de Verificación de Calidad y Pruebas
1. **Verificación de Tests Existentes**:
   - Ejecutar revisión estática en `test/` para asegurar que ningún test busque texto obsoleto ("Revisar y Confirmar" cuando no aplique, o `Icons.bar_chart`).
   - Actualizar tests de navegación y de widgets correspondientes.
2. **Validación de Reglas del Proyecto**:
   - Sin textos en color amarillo sobre fondos claros.
   - Textos sobre fondos amarillos explícitamente en color negro.
   - Identificadores exclusivamente ASCII.
   - Consistencia de marca con "Rinde Más".
3. **Validación en GitHub Actions CI**:
   - Confirmar vía API de GitHub que el flujo de compilación (`build_apk.yml`) culmine con estado `success`.
