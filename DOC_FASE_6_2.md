# Documento Técnico: Fase 6.2 — Consistencia Visual, Refinamiento UX y Calculadora Cambiaria

## 1. Resumen de Implementación
En esta fase se abordaron 5 tareas clave de consistencia visual, experiencia de usuario y utilidades financieras rápidas:

1. **UI-01 (Unificación Canónica de Íconos de Categorías):**
   - Se centralizó la lógica en `AppConstants.getCategoryIcon(String? cat)` soportando las 8 categorías canónicas del proyecto y sus sinónimos comunes:
     - Alimentación: `Icons.restaurant`
     - Educación: `Icons.school_outlined`
     - Salud: `Icons.favorite_border`
     - Hogar: `Icons.home_outlined`
     - Higiene: `Icons.clean_hands_outlined`
     - Servicios: `Icons.bolt`
     - Transporte: `Icons.directions_car_outlined`
     - Otros: `Icons.more_horiz`
   - Se unificó su consumo en `CategoryChart`, `ExpenseCard`, `ReviewExpenseScreen` y demás componentes.

2. **UI-05 (Ícono de Asistente IA en AppBar de Inicio):**
   - Se reemplazó el ícono ambiguo de interrogación por `Icons.auto_awesome` (Key: `dashboard_ai_chat_button`), consistente con la identidad de IA en el resto de la app.

3. **UX-06 (Etiqueta de Agrupación en Gráfico de Inicio):**
   - En la vista compacta del Dashboard (`showBudgetBars: false`), las categorías fuera del Top 4 se consolidan bajo la etiqueta `+X categorías` (ej. `+2 categorías`), evitando colisiones con la categoría real *Otros*.

4. **UX-07 (Desglose Directo de Productos en Pestaña "Gastos"):**
   - Las tarjetas de gasto en `ExpenseHistoryScreen` ahora muestran directamente los productos (`showDirectItemBreakdown: true`) con mini-ícono de categoría y subtotal.
   - Si una compra contiene más de 4 ítems, muestra un botón interactivo `Ver X artículos más ▾` / `Ver menos ▴`.
   - En el Dashboard (`Inicio`), las tarjetas permanecen compactas con conteo resumido (`14 Oct • 4 artículos`).

5. **FIN-09 (Calculadora Cambiaria Rápida en Pestaña "Más"):**
   - Creada `CurrencyCalculatorScreen` con subvista en `MoreScreen` (`MoreSubView.calculator`) y acceso directo desde la tarjeta de tasas.
   - Conversión bidireccional inmediata en tiempo real (tipear en Divisa actualiza Bolívares y viceversa).
   - Chips de tasa en un toque: `Dólar BCV`, `Euro BCV`, `USDT Binance` y `Personalizada ✏️`.
   - Comparativa simultánea de montos y cálculo de brecha cambiaria en vivo.
   - Acción rápida `Copiar Bs.` para transferir al portapapeles el monto formateado listo para la app bancaria.
   - Acción rápida `Registrar gasto` que navega a `ReviewExpenseScreen` pre-llenando monto, moneda y tasa activa.

---

## 2. Guía de Pruebas Paso a Paso para Validación

### Prueba 1: Iconografía Canónica (UI-01)
1. Abrir la app y revisar la pestaña **Inicio** (gráfico de categorías y compras recientes).
2. Ir a la pestaña **Gastos** y luego a **Análisis**.
3. Verificar que las 8 categorías utilicen exactamente los mismos íconos en todas las pantallas (ej. Higiene muestra manos con jabón, Alimentación cubiertos, Servicios rayo).

### Prueba 2: Acceso a Chat IA desde Inicio (UI-05)
1. En la pestaña **Inicio**, observar la esquina superior derecha del AppBar.
2. Confirmar que el botón muestre el ícono de destellos (`Icons.auto_awesome`).
3. Pulsar el botón: debe abrir el Asistente IA conservando la barra inferior de navegación. Pulsar retroceso para volver a Inicio.

### Prueba 3: Agrupación en Gráfico de Inicio (UX-06)
1. Contar con gastos registrados en 5 o más categorías distintas en el mes actual.
2. En la tarjeta de distribución de Inicio, verificar que se muestren las 4 principales y la quinta fila indique `+X categorías` (no "Otros").

### Prueba 4: Desglose Directo y Expansor en Gastos (UX-07)
1. Ir a la pestaña **Gastos**.
2. Observar una compra con múltiples ítems: los primeros productos deben aparecer visibles directamente con su mini-ícono y monto.
3. En una factura con más de 4 ítems, pulsar `Ver X artículos más ▾`: debe desplegar el resto y cambiar a `Ver menos ▴`.

### Prueba 5: Calculadora Cambiaria (FIN-09)
1. Ir a la pestaña **Más** y pulsar sobre la tarjeta de Tasas o la opción **Calculadora Cambiaria**.
2. Escribir un monto en el campo de divisa (ej. `10`): confirmar que el campo en Bolívares calcule al instante según la tasa BCV activa.
3. Modificar el campo en Bolívares: confirmar que el campo en divisa se actualice en tiempo real.
4. Alternar entre chips: `Euro BCV`, `USDT` y `Personalizada`. Probar ingresar una tasa manual.
5. Pulsar `Copiar Bs.`: verificar el mensaje de confirmación y pegar en otra app para verificar el número.
6. Pulsar `Registrar gasto`: confirmar que abra la pantalla de revisión con el monto y la tasa cargados.
