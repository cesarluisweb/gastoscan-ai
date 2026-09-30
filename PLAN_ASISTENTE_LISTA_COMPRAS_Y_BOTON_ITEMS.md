# Plan de Implementación: Botón Inferior de Ítems y Gestión de Lista de Compras con Asistente IA

## 1. Contexto y Objetivos
1. **Flujo de Carga Manual de Gastos (`ReviewExpenseScreen`)**:
   - Al registrar múltiples ítems manualmente, el usuario hace scroll hacia abajo para completar cada fila.
   - Para agregar el siguiente ítem, se ve obligado a subir hasta el encabezado para pulsar el botón "+ Agregar" y luego volver a bajar.
   - Solución: Incorporar un botón secundario al final de la lista de ítems (`+ Agregar otro ítem`), manteniendo el botón superior para accesos rápidos.

2. **Gestión de Lista de Compras con el Asistente IA (`ChatScreen` y Firebase Functions)**:
   - Permitir al asistente IA interactuar con la tabla `shopping_items` de SQLite.
   - Capacidades requeridas:
     - **Agregar productos**: "Anota leche, pan y huevos en la lista de compras".
     - **Modificar productos**: "Cambia la leche por leche deslactosada".
     - **Eliminar productos**: "Quita los huevos de la lista de compras".
     - **Marcar estado**: "Marca el pan como comprado" o "desmarca el café".
     - **Consultar productos**: "Dime qué tengo en la lista de compras".

---

## 2. Cambios Propuestos por Componente

### 2.1 Botón de Agregar Ítems al Final (`lib/ui/screens/review_expense_screen.dart`)
- En el contenedor "Desglose de Ítems":
  - Conservar el botón superior `TextButton.icon(onPressed: _addItem, ...)` en la fila del encabezado.
  - Al final de la lista generada por `_items.asMap().entries.map(...)`, añadir un botón de ancho completo tipo `OutlinedButton.icon`:
    - Texto: `"Agregar otro ítem"`.
    - Icono: `Icons.add`.
    - Estilo: Borde sutil `AppColors.border`, fondo `AppColors.cardLighter` y texto oscuro `AppColors.textPrimary`.
    - Acción: Llama a `_addItem()` e inserta de inmediato un nuevo ítem bajo la vista del usuario.

### 2.2 Base de Datos Local (`lib/data/datasources/local/database_helper.dart`)
- Incorporar método de actualización de nombre en `shopping_items`:
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
- En la función `chatWithAnalyst`:
  - Declarar nuevas herramientas en `tools.functionDeclarations`:
    1. `agregar_items_lista_compras`: Parámetro `nombres` (array de strings).
    2. `modificar_item_lista_compras`: Parámetros `nombre_actual` y `nuevo_nombre` (strings).
    3. `eliminar_items_lista_compras`: Parámetro `nombres` (array de strings).
    4. `marcar_items_lista_compras`: Parámetro `nombres` (array de strings) y `comprado` (booleano).
  - Actualizar el `systemPrompt` para inyectar la lista de compras actual contenida en `contextData.lista_compras`, instruyendo al modelo a invocar estas funciones ante órdenes de gestión y responder directamente ante preguntas de consulta sobre la lista.

### 2.4 Pantalla de Chat del Asistente (`lib/ui/screens/chat_screen.dart`)
- **Paso de Contexto**: Al invocar `_geminiService.chatWithAnalyst`, consultar `DatabaseHelper.instance.getAllShoppingItems()` e inyectar `lista_compras` en `contextData`.
- **Manejo de Respuestas de Función (`functionCall`)**:
  - `agregar_items_lista_compras`: Inserta cada ítem vía `DatabaseHelper.instance.insertShoppingItem` y responde confirmando los nombres agregados.
  - `modificar_item_lista_compras`: Busca coincidencias en la lista y actualiza vía `updateShoppingItemName`.
  - `eliminar_items_lista_compras`: Busca y elimina los productos vía `deleteShoppingItem`.
  - `marcar_items_lista_compras`: Actualiza el estado (`is_purchased`) vía `updateShoppingItemStatus`.

---

## 3. Plan de Verificación

1. **Pruebas Automatizadas**:
   - Escribir prueba de widget para verificar que el botón `Agregar otro ítem` en `ReviewExpenseScreen` aparece al final y añade ítems correctamente.
   - Escribir prueba unitaria en `database_helper` para `updateShoppingItemName`.
   - Validar que no haya regresiones en los 74 tests existentes.
2. **Validación en GitHub Actions CI**:
   - Monitorear el workflow en GitHub Actions para asegurar compilación exitosa y ejecución de pruebas sin fallos.
