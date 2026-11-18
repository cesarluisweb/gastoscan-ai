# Documento Técnico: Rediseño de Ítems en Revisión de Factura (Variante 1-B)

> **Estado:** Implementada en `main` · CI en verde (build 711, commit `0d52bb5`, run `44330777911`).
> **Tarea:** `UX-20` · Pendiente de validación en dispositivo físico 🧪.

## 1. Contexto y Problema
En `ReviewExpenseScreen`, la lista de artículos extraídos o ingresados presentaba problemas de fatiga visual y falta de diferenciación:
1. **Tres planos blancos idénticos:** El contenedor de sección (`AppColors.card` `#FFFFFF`), la tarjeta de cada ítem (`AppColors.surface` `#FFFFFF`) y los campos de texto (`AppColors.surface` `#FFFFFF`) compartían el mismo fondo y borde `#E5E7EB`, anulando el contraste figura-fondo.
2. **Jerarquía plana:** `Concepto`, `Cant.`, `Precio` y `Categoría` competían como 4 cajas idénticas sin ancla visual.
3. **Falta de proximidad:** El espaciado interno (10 dp) y externo (12 dp) impedía discernir dónde terminaba un artículo y dónde empezaba el siguiente.

## 2. Solución Implementada (Variante 1-B)
Se implementaron los cambios visuales y funcionales en `lib/ui/screens/review_expense_screen.dart`:
- **Contraste de superficie:** Tarjetas de ítem con fondo `AppColors.cardLighter` (`#F3F4F6`) y `side: BorderSide.none`. Los campos de entrada conservan fondo blanco `#FFFFFF` con borde sutil.
- **Insignia numérica `[N]`:** Badge de 24×24 dp (`#E5E7EB`, radio 6 dp) con número en 11sp `FontWeight.w700` (`#4B5563`) antes del nombre.
- **Concepto jerarquizado:** `TextFormField` en 15sp `FontWeight.w600` (`AppColors.textPrimary`), `hintText: 'Nombre del artículo'` y sufijo de edición `Icons.edit_outlined` en 16 dp (`AppColors.textMuted`).
- **Pastilla de categoría:** Sustitución de `DropdownButtonFormField` gigante por pastilla compacta de 34 dp con fondo blanco, borde `#E5E7EB`, radio de 17 dp y menú desplegable `DropdownButton<String>`.
- **Cifras tabulares en total:** Total por ítem alineado a la derecha con `FontFeature.tabularFigures()`.
- **Relación de proximidad 1:2:** 8 dp entre filas internas y 16 dp entre artículos (`margin: EdgeInsets.symmetric(vertical: 8)`).
- **Deshacer al eliminar:** SnackBar de 5 s con fondo `AppColors.primaryDark` e `InkWell` ("Deshacer") conforme a `DESIGN.md` 3.2, restaurando el ítem y su historial de precios.
- **Flujo de teclado:** `TextInputAction.next` en Concepto y Cantidad; `done`/`next` en Precio.
- **Eliminación de microcopy superfluo:** Se retiró el subtítulo redundante "Detalle del gasto para clasificarlo y comparar precios.", ahorrando 24 dp verticales.

## 3. Puntos de Inspección en Código
- **Cabecera de ítems y eliminación de subtítulo:** [`lib/ui/screens/review_expense_screen.dart:2566-2580`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L2566-L2580).
- **Tarjeta de ítem, badge `[N]` y concepto en w600:** [`lib/ui/screens/review_expense_screen.dart:2610-2715`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L2610-L2715).
- **Campos Cantidad y Precio unitario:** [`lib/ui/screens/review_expense_screen.dart:2716-2795`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L2716-L2795).
- **Pastilla de Categoría y Total tabular:** [`lib/ui/screens/review_expense_screen.dart:2796-2885`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L2796-L2885).
- **Función `_removeItem` con SnackBar de deshacer:** [`lib/ui/screens/review_expense_screen.dart:978-1040`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L978-L1040).

## 4. Guía de Pruebas en Dispositivo Físico
**Ruta alcanzable:**
1. Abrir la app Rinde Más.
2. Desde la pestaña **Inicio** o **Gastos**, presionar el botón de escaneo de factura o el botón flotante `+` para registrar gasto manual.
3. Al ingresar a la pantalla `ReviewExpenseScreen` ("Registrar gasto" o "Revisar Factura"):

**Casos de prueba:**
- **CP-01 (Contraste y Recorrido Visual):**
  - Con 2 o más artículos, verificar que cada bloque de artículo resalta en fondo gris claro (`#F3F4F6`), mientras los campos de texto (`Nombre del artículo`, `Cant.`, `Precio unit.`) y la pastilla de categoría se mantienen en blanco puro.
  - Verificar que la separación entre un bloque y otro (16 dp) es claramente mayor que el espacio entre los campos internos (8 dp).
- **CP-02 (Numeración y Tipografía del Concepto):**
  - Comprobar que aparece la insignia `[1]`, `[2]`, etc. a la izquierda de cada producto.
  - Verificar que el nombre del producto se muestra en negrita seminegrita (`w600`) y con el icono de lápiz sutil a la derecha.
- **CP-03 (Selector de Categoría en Pastilla):**
  - Tocar la pastilla de categoría `[ (icono) Categoría ▾ ]`.
  - Verificar que se despliega el menú con las 10 categorías y que al seleccionar una (ej. *Hogar* o *Salud*), la pastilla se actualiza correctamente.
- **CP-04 (Eliminación y Deshacer):**
  - Con al menos 2 artículos, presionar el icono de papelera de uno de ellos.
  - Verificar que el artículo desaparece y en la parte inferior emerge un SnackBar amarillo con el texto *"Artículo eliminado"* y un botón *"Deshacer"*.
  - Tocar *"Deshacer"* antes de 5 segundos.
  - Verificar que el artículo vuelve a su posición original con todos sus datos y montos intactos.
- **CP-05 (Navegación con Teclado Soft):**
  - Enfocar el campo del nombre del artículo y presionar la tecla "Siguiente" del teclado virtual.
  - Verificar que el foco salta directamente al campo `Cant.`, y al pulsar "Siguiente" salta a `Precio unit.`.
