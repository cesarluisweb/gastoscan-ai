# Plan Técnico y de Diseño UI/UX: Ajustes Fase 2 y Presupuestos Multi-Moneda

## 1. Ajustes Visuales de UI (Pulitura de Componentes)

### 1.1 AppBar y Navegación
- **Icono de Ayuda/IA:** Crear un icono compuesto (Stack) que muestre una burbuja de chat nativa con un signo de interrogación en su interior. Esto comunica claramente que es un asistente de chat de ayuda.
- **Selector de Mes (`DashboardScreen`):**
  - Convertir el área de texto central (Mes, Año e icono `arrow_drop_down`) en un botón sólido tipo píldora de color gris claro.
  - Eliminar el contenedor blanco y el borde gris que encierra actualmente todo el selector.
  - **Ubicación de flechas:** Mantener las flechas laterales (`<` y `>`) separadas a los extremos de la pantalla, sin que queden pegadas al nuevo botón píldora central.

### 1.2 Unificación de Botones
- **Floating Action Button (+):** Asegurar que use el color amarillo primario correcto (`#FBF18F` / `AppColors.primary`).
- **Botón "Consultar" (Asistente IA):** Mantener el estilo actual (amarillo sólido con flecha).
- **Enlaces de Texto ("Ver detalle" y "Ver todos"):** Transformarlos a botones sólidos tipo píldora de color gris claro, **incluyendo un icono de flecha hacia la derecha** (igual al estilo del botón de Consultar, pero en gris).

### 1.3 Tarjetas Principales (`SummaryCard` y `AiInsightCard`)
- **SummaryCard (Presupuesto):**
  - Reducir el espaciado vertical entre los elementos (Total gastado, Monto, Barra de progreso y métricas inferiores).
  - Cambiar el icono del botón de editar presupuesto a contorno (`Icons.edit_outlined`).
- **AiInsightCard (Asistente IA):**
  - Cambiar el color del icono de destellos (chispa) a amarillo primario.
  - Cambiar el color del icono del robot a negro.

### 1.4 Lógica de Agrupación ("Otros") en `CategoryChart`
- Si la categoría "Otros" ya existe en los datos originales, sumar su monto al bucket agrupado de "Otros" que consolida las categorías fuera del Top 4, evitando nombres duplicados en la leyenda.

---

## 2. Iconos de Categorías (Consistencia)
- **AnalysisScreen:** Integrar los iconos temáticos (colores y formas) en la lista de "Control de presupuestos por categoría".
- **BudgetBottomSheet:** Mostrar el icono de la categoría al lado de su nombre en el editor.

---

## 3. Presupuestos Nativos Multi-Moneda (VES / USD)

### 3.1 Arquitectura de Base de Datos (Migración v11)
- Actualizar `database_helper.dart` (v11) para añadir la columna `moneda TEXT DEFAULT 'USD'` a las tablas `presupuestos_mensuales` y `presupuestos_categorias_mensuales`.
- Actualizar `GastoProvider` y el modelo/repositorio para leer y guardar la moneda.

### 3.2 Lógica del Editor (`BudgetBottomSheet`)
- **Selector de Moneda:** Añadir un toggle para que el usuario elija guardar en USD o VES.
- **Conversión en vivo (Opción A):** Si el usuario cambia el selector de moneda, el monto en pantalla se convertirá automáticamente utilizando la tasa de cambio actual. Al guardar, el presupuesto se fijará permanentemente en la moneda seleccionada.

### 3.3 Dashboard (`SummaryCard`)
- Si el presupuesto está en **VES**: La etiqueta superior mostrará `Presupuesto: Bs. X`. La barra de progreso y el ritmo diario se calcularán evaluando el monto gastado convertido a bolívares al día de hoy.
- Si está en **USD**: Se mostrará en USD y los cálculos se harán sobre la base en dólares, blindando el presupuesto contra la fluctuación diaria.

---

## 4. Corrección de Tests en CI
- **Archivo:** `test/screens/dashboard_category_budget_test.dart` (línea 364).
- **Acción:** Cambiar `expect(find.byIcon(Icons.edit), findsOneWidget);` por `expect(find.byIcon(Icons.edit_outlined), findsOneWidget);`.
