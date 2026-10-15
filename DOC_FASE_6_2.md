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
   - Las tarjetas de gasto en `ExpenseHistoryScreen` muestran directamente los productos (`showDirectItemBreakdown: true`) en una superficie blanca continua integrada en la misma tarjeta, delimitada por un divisor sutil `Divider(height: 1, color: AppColors.border)`.
   - Se eliminó el contenedor gris inferior y la etiqueta redundante "Desglose de Ítems:".
   - Cada producto cuenta con mini-ícono temático de su categoría y subtotal formateado.
   - Si una compra contiene más de 4 ítems, muestra un botón interactivo tipo cápsula/pill con fondo tenue y texto en negro carbón `AppColors.textPrimary` (`Ver X artículos más ▾` / `Ver menos ▴`), erradicando cualquier texto amarillo sobre fondo claro.
   - En el Dashboard (`Inicio`), las tarjetas permanecen compactas con conteo resumido (`14 Oct • 4 artículos`).

5. **FIN-09 (Calculadora Cambiaria Rápida en Pestaña "Más"):**
   - Creada `CurrencyCalculatorScreen` con subvista en `MoreScreen` (`MoreSubView.calculator`) y acceso directo desde la tarjeta de tasas.
   - Conversión bidireccional inmediata en tiempo real (tipear en Divisa actualiza Bolívares y viceversa).
   - Chips de tasa en un toque: `Dólar BCV`, `Euro BCV`, `USDT Binance` y `Personalizada ✏️`. Los chips comandan directamente la divisa activa sin selectores desplegables redundantes.
   - Pastilla central interactiva (`Key('calc_swap_button')`): pulsar `1 USD = Bs. X` conmuta el orden de los campos:
     - Divisa arriba / Bolívares abajo $\rightarrow$ Botón `Copiar Bs.`.
     - Bolívares arriba / Divisa abajo $\rightarrow$ Botón `Copiar USD` (o EUR/USDT).
     - Al alternar de moneda con Bolívares arriba, preserva la cantidad de bolívares y recalcula la divisa correspondiente en tiempo real.
   - Comparativa simultánea de montos y cálculo de brecha cambiaria en vivo, utilizando texto negro carbón `AppColors.textPrimary` (cumplimiento estricto de `DESIGN.md`).
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
2. Observar una compra con múltiples ítems: los productos aparecen integrados sobre el fondo blanco de la tarjeta, separados del encabezado por una línea sutil, sin recuadro gris ni títulos redundantes.
3. En una factura con más de 4 ítems, verificar que el botón cápsula `Ver X artículos más ▾` tenga texto negro carbón (cero amarillo). Pulsar para desplegar y verificar que alterne a `Ver menos ▴`.

### Prueba 5: Calculadora Cambiaria y Botón Interactivo de Tasa (FIN-09)
1. Ir a la pestaña **Más** y pulsar sobre la tarjeta de Tasas o la opción **Calculadora Cambiaria**.
2. Escribir un monto en el campo de divisa (ej. `10`): confirmar que el campo en Bolívares calcule al instante según la tasa BCV activa.
3. Pulsar la pastilla central `1 USD = Bs. X`:
   - El campo de Bolívares debe pasar arriba y el de USD abajo.
   - El botón inferior debe cambiar dinámicamente a `Copiar USD`.
4. Escribir un monto en Bolívares: verificar que se calcule cuántos dólares representa.
5. Seleccionar el chip `Euro BCV`: verificar que el monto en euros se actualice a partir de los bolívares y el botón cambie a `Copiar EUR`.
6. En el cuadro inferior de comparativa simultánea, comprobar que los montos se lean en texto negro nítido.
7. Pulsar `Copiar`: verificar el copiado al portapapeles.
8. Pulsar `Registrar gasto`: confirmar que abra la pantalla de revisión con el monto y la tasa cargados.
