# Plan de Implementación: Botón Inferior de Ítems y Gestión de Lista de Compras con Asistente IA

## 1. Contexto y Objetivos

1. **Flujo de Carga Manual de Gastos (`ReviewExpenseScreen`)**:
   - Simplificar la interfaz dejando un **único botón al final** de la lista de ítems (`+ Agregar ítem`).
   - Se elimina el botón superior del encabezado para evitar duplicidad. Al estar siempre al final, el usuario puede continuar agregando productos sucesivamente conforme desciende en la pantalla.

2. **Gestión de Lista de Compras y Desambiguación en el Asistente IA (`ChatScreen` y Firebase Functions)**:
   - Permitir al asistente IA gestionar la tabla `shopping_items` (agregar, modificar, eliminar, marcar estado y consultar).
   - **Regla de Desambiguación de Intención**:
     - Si el usuario especifica explícitamente "en la lista de compras", "tengo que comprar", "para comprar" -> Ejecuta la acción en la lista de compras.
     - Si el usuario especifica "gasté", "compré", "pagué" o incluye montos/precios -> Ejecuta el registro de gasto.
     - **Si la orden es ambigua** (ej. "anota una harina pan", "agrega café"): La IA **no asume**, sino que pregunta directamente:
       > *"¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?"*
     - En el siguiente mensaje, ejecuta la acción según la respuesta del usuario.

---

## 2. Cambios Propuestos por Componente

### 2.1 Botón de Agregar Ítem al Final (`lib/ui/screens/review_expense_screen.dart`)
- En el contenedor "Desglose de Ítems":
  - **Encabezado**: Dejar solo el título `"Desglose de Ítems"` (sin botón superior).
  - **Al final del listado**: Colocar un único botón estilizado de ancho completo (`OutlinedButton.icon`):
    - Texto: `"Agregar ítem"` (o `"Agregar otro ítem"` si ya hay ítems).
    - Icono: `Icons.add`.
    - Estilo: Borde sutil `AppColors.border`, fondo `AppColors.cardLighter` y texto oscuro `AppColors.textPrimary`.
    - Acción: Llama a `_addItem()`.

### 2.2 Base de Datos Local (`lib/data/datasources/local/database_helper.dart`)
- Añadir soporte para renombrar productos en `shopping_items`:
  ```dart
  Future<void> updateShoppingItemName(int id, String newName) async {
    final db = await instance.database;
    await db.update(
      'shopping_items',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  ```

### 2.3 Cloud Function del Asistente (`firebase_functions/index.js`)
- En `chatWithAnalyst`:
  - Declarar las 4 herramientas de lista de compras en `tools`:
    1. `agregar_items_lista_compras(nombres: string[])`
    2. `modificar_item_lista_compras(nombre_actual: string, nuevo_nombre: string)`
    3. `eliminar_items_lista_compras(nombres: string[])`
    4. `marcar_items_lista_compras(nombres: string[], comprado: boolean)`
  - Instruir en `systemPrompt`:
    - Pasar la lista actual de compras en `contextData.lista_compras`.
    - **Regla estricta de desambiguación**: Si la petición es ambigua (ej. "anota X" sin indicar si es compra futura o gasto ya hecho con precio), NO invocar herramientas; preguntar primero al usuario: *"¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?"*.

### 2.4 Pantalla de Chat del Asistente (`lib/ui/screens/chat_screen.dart`)
- Pasar la lista de compras actual en `contextData` al consultar `chatWithAnalyst`.
- Manejar las llamadas de función:
  - `agregar_items_lista_compras`: Inserta los elementos en SQLite con `DatabaseHelper.instance.insertShoppingItem` y confirma en español directo.
  - `modificar_item_lista_compras`: Localiza el ítem por nombre y actualiza con `updateShoppingItemName`.
  - `eliminar_items_lista_compras`: Elimina el ítem con `deleteShoppingItem`.
  - `marcar_items_lista_compras`: Actualiza estado con `updateShoppingItemStatus`.

---

## 3. Plan de Verificación

1. **Pruebas Automatizadas**:
   - Verificar con tests de widgets que `ReviewExpenseScreen` tiene un único botón de agregar al final de la lista de ítems.
   - Probar operaciones CRUD de lista de compras en `database_helper_test.dart`.
   - Ejecutar la suite completa de tests (`flutter test`).
2. **Validación en GitHub Actions CI**:
   - Confirmar estado de compilación y pruebas en verde vía API de GitHub.
