# Documento Técnico: Comparador de Precios v2 (Rinde Más)

## 1. Resumen Ejecutivo y Alcance
Este cambio optimiza la comparación de precios de artículos en el formulario de revisión y edición de gastos (`ReviewExpenseScreen`) y en el panel web (`landing/src/pages/panel.astro`).

### Problemas Resueltos:
1. **Falta de contexto temporal:** El sistema anterior omitía la fecha de la compra anterior en el texto.
2. **Selección ante compras repetidas:** Si un producto se compraba 10 veces, se comparaba a ciegas contra el último registro sin considerar el comercio ni el mejor precio.
3. **Límite rígido global (250 registros):** La consulta anterior barría los últimos 250 ítems de la base de datos completa.
4. **Desfase al eliminar ítems:** El mapa de comparaciones usaba índices enteros de lista (`int`), causando desalineación al borrar ítems intermedios.
5. **Nombres de comercios dispares:** Variaciones societarias o fiscales (`Farmatodo, C.A.`, `Farmatodo C.C.`, `RIF J-12345678`) no se agrupaban como el mismo comercio.
6. **Paridad Web:** El panel web carecía de comparador de precios en vivo en su formulario de gastos.

---

## 2. Arquitectura y Reglas del Algoritmo

### 2.1 Esquema SQLite v19
* **Columna:** `descripcion_norm TEXT DEFAULT ''` en la tabla `items_gasto`.
* **Migración:** `database_helper.dart` sube a versión 19. Si `oldVersion < 19`, ejecuta `ALTER TABLE`, lee los registros existentes, calcula `normalizeProductText` y actualiza por lotes de 500 filas en una sola transacción.
* **Índice:** `CREATE INDEX idx_items_gasto_desc_norm ON items_gasto (descripcion_norm);`.
* **Rutas de inserción:** Centralizadas en `_itemRow(ItemGastoModel item, int gastoId)`.

### 2.2 Normalización de Comercios y Productos
* `normalizeProductText`: Elimina sufijos fiscales `(E)` y `(G)`, diacríticos (`á` $\rightarrow$ `a`, `ñ` $\rightarrow$ `n`), puntuación y espacios duplicados.
* `normalizeCommerce`: Limpia RIFs (`J-12345678`), siglas de sociedades (`C.A.`, `S.A.`, `S.R.L.`), centros comerciales (`C.C.`), y singulariza prefijos comunes (`automercados` $\rightarrow$ `automercado`).
* `formatCommerceDisplay`: Formatea el nombre para lectura humana limpia en interfaz sin colas fiscales.

### 2.3 Consulta por Lote (`findPriceHistory`)
* Filtro preparado `i.descripcion_norm IN (...)`.
* Ventana máxima de 60 días calendario (`substr(g.fecha, 1, 10) >= ?`).
* Límite de seguridad: 600 registros.
* Cálculo determinista de precio unitario en USD (`_unitPriceUsd`) convirtiendo desde VES si aplica.

### 2.4 Prioridad de Mensajes en Pantalla
| Prioridad | Condición | Formato del Mensaje | Estilo Visual |
| :--- | :--- | :--- | :--- |
| **1. Mismo Comercio (0 a 30 días)** | Compra previa en el mismo local (±5% umbral). | `🔺 Está X% más caro por unidad en [Comercio] ([Fecha])`<br>`🟢 Te salió un X% más económico por unidad en [Comercio] ([Fecha])` | Rojo `AppColors.error` si subió;<br>Negro `AppColors.textPrimary` si bajó. |
| **2. Mejor Precio Mercado (0 a 30 días)** | Sin compra previa en el mismo local, pero existe mejor precio en la ventana. | `🔺 Está X% más caro por unidad que en [Comercio] ([Fecha])`<br>`🟢 Te salió un X% más económico por unidad que en [Comercio] ([Fecha])` | Rojo `AppColors.error` si subió;<br>Negro `AppColors.textPrimary` si bajó. |
| **3. Referencia Histórica (31 a 60 días)** | Cualquier compra entre 31 y 60 días atrás. | `Referencia: $X.XX/ud en [Comercio] ([Fecha])` | Gris `AppColors.textMuted` (sin porcentaje de alerta). |
| **Silencio** | Variación menor al 5%, compras > 60 días o sin historial. | No se renderiza ninguna línea. | Oculto (`SizedBox.shrink`). |

---

## 3. Evidencia Archivo:Línea de Controles Visuales

Inspección realizada en `lib/ui/screens/review_expense_screen.dart`:
- Campo Comercio: `TextFormField` con label `'¿Dónde gastaste? (opcional)'` (`line 2356`).
- Botón Agregar artículo: `OutlinedButton.icon` con `Key('review_expense_add_item_btn')` (`line 2787`).
- Campo Concepto: `TextFormField` con label `'Concepto'` (`line 2603`).
- Campo Cantidad: `TextFormField` con label `'Cant.'` (`line 2654`).
- Campo Precio: `TextFormField` con label `'Precio'` (`line 2676`).
- Línea de Comparación: `_PriceComparisonLine` con `ValueKey('price_comparison_${item.clientKey}')` (`line 3681`).
- Botón Guardar gasto: Botón inferior con texto `'Guardar Gasto'` o `'Actualizar Gasto'` (`line 3335`).

---

## 4. Guía de Pruebas en Dispositivo Físico (*Rinde Más Dev*)

* **Requisito:** Instalar el artefacto `rindemas-dev-apk` correspondiente al commit de esta entrega.

### Caso 1: Comparación en el Mismo Comercio (Subida de Precio)
1. Abrir *Rinde Más Dev*.
2. Registrar un gasto con fecha de hace 5 días:
   - Comercio: `Farmatodo, C.A.`
   - Artículo: `Café Molido 500g`, Cant: `1`, Precio: `2.00` USD.
   - Guardar el gasto.
3. Registrar un nuevo gasto con fecha de hoy:
   - Comercio: `Farmatodo C.C.`
   - Agregar artículo: `Café Molido 500g`, Cant: `1`, Precio: `2.50` USD.
4. **Verificación:** Debe aparecer inmediatamente debajo del artículo la alerta roja:  
   `🔺 Está 25% más caro por unidad en Farmatodo (hace 5 días)`.

### Caso 2: Mejor Precio en Otro Comercio
1. En el mismo gasto del Caso 1, cambiar el comercio a `Automercado Plaza`.
2. **Verificación:** El texto cambia automáticamente a:  
   `🔺 Está 25% más caro por unidad que en Farmatodo (hace 5 días)`.

### Caso 3: Referencia Antigua (31 a 60 días)
1. Registrar un gasto con fecha de hace 40 días:
   - Comercio: `Unicasa`
   - Artículo: `Aceite de Maíz 1L`, Cant: `1`, Precio: `3.00` USD.
   - Guardar el gasto.
2. Registrar un nuevo gasto hoy con `Aceite de Maíz 1L` a `4.00` USD.
3. **Verificación:** Debe mostrarse en color gris neutro:  
   `Referencia: $3.00/ud en Unicasa (hace 1 mes)` sin porcentaje de alarma.

### Caso 4: Eliminación de Ítem sin Desfase
1. En un formulario con 2 artículos que tengan avisos de comparación distintos, eliminar el primer artículo tocando la papelera.
2. **Verificación:** El segundo artículo debe conservar su aviso exacto sin desfasarse ni adoptar datos del ítem eliminado.

---

## 5. Metadatos de Validación CI
* **Build CI:** 700
* **Commit SHA:** `02233c6`
* **Workflow:** `build_apk.yml` (Compilar APK Android)
* **Estado:** `Pendiente de validación 🧪` (espera visto bueno de César en dispositivo físico).

