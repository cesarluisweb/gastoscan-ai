# Documentación Técnica: Asistente IA para Lista de Compras y UX en Carga Manual

## 1. Contexto y Objetivos
Durante las iteraciones de la aplicación se resolvieron dos fricciones de usabilidad y comportamiento:
1. **Ergonomía en formularios de carga manual de gastos:** Al desglosar múltiples ítems de una factura en `ReviewExpenseScreen`, el botón para añadir productos estaba duplicado en la cabecera superior y al pie, obligando a desplazarse hacia arriba y hacia abajo repetidamente.
2. **Capacidad de gestión de la lista de compras vía chat:** El asistente virtual debía ser capaz de añadir, modificar, eliminar y tachar productos de la lista de compras (`shopping_items`), manteniendo una regla estricta de desambiguación para evitar confusiones con el registro de gastos.

---

## 2. Decisiones de Arquitectura y Diseño

### 2.1. Patrón UX en Formularios con Listas Dinámicas
- **Regla:** En listas desplazables donde se añaden elementos progresivamente, se elimina el botón de adición en la cabecera superior.
- **Implementación:** Se utiliza un único botón al pie de la lista de ítems (`ReviewExpenseScreen`):
  - Etiqueta contextual: "Agregar ítem" (si está vacía) o "Agregar otro ítem".
  - Ancho completo (`double.infinity`) con borde suave (`AppColors.cardBorder`).
  - Icono de adición con el color de acento reservado para elementos gráficos: `AppColors.primaryDark`.

### 2.2. Gestión de Lista de Compras por el Asistente IA
- **Backend (`firebase_functions/index.js`):**
  - Se definieron 4 declaraciones de herramientas (`FunctionDeclaration`):
    - `agregar_items_lista_compras`: Recibe arreglo de nombres de ítems a agregar.
    - `modificar_item_lista_compras`: Recibe identificador del ítem (`id`) y nuevo texto (`nuevo_nombre`).
    - `eliminar_items_lista_compras`: Recibe identificadores (`ids`) o nombres a borrar.
    - `marcar_items_lista_compras`: Recibe `ids` y estado booleano (`comprado`).
  - **Contexto dinámico:** La Cloud Function recibe la lista actual de compras en `contextData.lista_compras`.
  - **Prompt del sistema:** Se instruye al modelo a responder de manera directa y concisa en español tras ejecutar cualquiera de estas herramientas.

### 2.3. Desambiguación Obligatoria (Gasto vs. Lista de Compras)
- **Problema:** Frases como *"anota harina pan"* o *"recuérdame comprar café"* carecen de monto y contexto contable inmediato.
- **Comportamiento requerido:**
  - El asistente nunca debe asumir por su cuenta si se trata de un gasto efectuado o de un ítem para la lista de compras.
  - Debe solicitar aclaración usando exactamente la fórmula:
    > *"¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?"*
  - Si el usuario indica un gasto explícito con monto (ej. *"gasté 5$ en café"*), se deriva a registro de gasto.
  - Si el usuario dice *"anótalo en la lista"* o usa comandos directos hacia la lista, se ejecuta la herramienta correspondiente.

### 2.4. Capa de Datos Local (`DatabaseHelper.dart`)
- Se implementó el método `updateShoppingItemName(int id, String newName)` para permitir la edición del texto de un ítem existente en SQLite.

---

## 3. Verificación y Pruebas
- Pruebas unitarias añadidas en `test/models/shopping_item_model_test.dart`.
- Verificación en integración continua (GitHub Actions): Suite de 75 tests ejecutada exitosamente sin regresiones.
