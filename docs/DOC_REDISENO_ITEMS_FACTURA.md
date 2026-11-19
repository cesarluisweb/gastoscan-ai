# Documento Técnico: Rediseño de Ítems en Revisión de Factura (UX-20)

> **Estado:** Iteración 2 · CI en verde (build 712, commit `18ae858`, run `44435761350`). Iteración 1: build 711 (`0d52bb5`).
> **Tarea:** `UX-20` · Pendiente de validación en dispositivo físico 🧪.

## 1. Problema
En `ReviewExpenseScreen` los artículos se veían iguales y costaba recorrerlos con la vista:
1. Sección, tarjeta de ítem y campos tenían el mismo fondo blanco y el mismo borde.
2. Concepto, Cantidad, Precio y Categoría competían como cajas idénticas.
3. El espacio interno (10 dp) era casi igual al espacio entre ítems (12 dp).

## 2. Iteraciones

| Iteración | Build | Cambio | Resultado en dispositivo |
|---|---|---|---|
| 1 | 711 | Fondo gris por ítem, número `[N]`, lápiz, categoría en pastilla redondeada | Mejora parcial. El número se confunde con cantidad. Lápiz sobra. Pastilla descuadra. |
| 2 | 712 | Se quita el número y el lápiz. Vuelve la etiqueta "Concepto". Categoría en caja igual a las demás. Total más grande. | Pendiente |

## 3. Estado actual (iteración 2)
- **Fondo del ítem:** `AppColors.cardLighter` (`#F3F4F6`) sin borde. Campos en blanco con borde `#E5E7EB` y radio 10 dp.
- **Concepto:** etiqueta "Concepto", texto 15 sp `w600`. Sin número ni lápiz.
- **Categoría:** `DropdownButtonFormField` con etiqueta "Categoría", radio 10 dp, 65 % del ancho.
- **Total por ítem:** 17 sp negrita, cifras tabulares, 35 % del ancho.
- **Espaciado:** 8 dp entre filas internas y 16 dp entre ítems.
- **Deshacer al eliminar:** aviso de 5 s con "Deshacer" (`DESIGN.md` 3.2).
- **Teclado:** `TextInputAction.next` en Concepto y Cantidad.

## 4. Puntos de inspección en código
- `_removeItem` con deshacer: `lib/ui/screens/review_expense_screen.dart` (función `_removeItem`).
- Tarjeta de ítem: bloque `item_card_${item.clientKey}` en `lib/ui/screens/review_expense_screen.dart`.

## 5. Guía de pruebas en dispositivo
**Ruta:** Inicio → escanear factura, o botón `+` → pantalla "Registrar gasto" / "Editar gasto".

| Caso | Pasos | Resultado esperado |
|---|---|---|
| CP-01 | Abrir un gasto con 3 o más artículos | Cada artículo es un bloque gris separado; campos en blanco |
| CP-02 | Mirar la primera fila de cada bloque | Etiqueta "Concepto" y nombre en negrita; sin número ni lápiz |
| CP-03 | Mirar la tercera fila | "Categoría" es una caja con las mismas esquinas que Cant. y Precio |
| CP-04 | Tocar la categoría y elegir otra | El menú abre y la caja muestra la nueva categoría |
| CP-05 | Mirar el total de cada artículo | Monto más grande que en build 711 |
| CP-06 | Borrar un artículo y tocar "Deshacer" en 5 s | El artículo vuelve a su posición con sus datos |
