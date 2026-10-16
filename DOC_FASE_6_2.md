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

4. **UX-07 (Desglose Directo y Refinamiento Integral en "Gastos"):**
   - **Corrección Proporcional Multimoneda:** Los ítems calculan su monto proporcional respecto a `totalOriginalDisplay` y `totalUsdDisplay`. Si una compra fue registrada en EUR, sus ítems se convierten proporcionalmente a USD (o a la `monedaPrincipal` elegida), eliminando discrepancias matemáticas entre la suma de productos y el total de la tarjeta.
   - **Tira de Resumen Mensual Fija:** Barra compacta bajo el selector de mes con el total gastado (`$ 46,62 • Bs. 40.838,04 (X compras)`), formateada según la moneda preferida del usuario en **Más**.
   - **Carrusel de Chips de Filtro Rápido:** Reemplazó el ícono ambiguo de galería del AppBar por chips horizontales interactivos (`[Todos]`, `[🧾 Con comprobante]`, y las 8 categorías canónicas con sus mini-íconos).
   - **Jerarquía y Precio Unitario vs. Total:** Los ítems muestran a la derecha el total de la fila. Si la cantidad es mayor a 1, un subtítulo detalla `${cantidad}x a ${unitario} c/u`.
   - **Compras de 1 Ítem Optimizadas:** Se integran directamente en el subtítulo de la tarjeta (`${descripción} • Tasa ${tasa}`), omitiendo el divisor inferior y la fila repetida, ahorrando ~40% de espacio vertical.
   - **Eliminación del Ícono Grande:** En el historial de gastos se suprime el contenedor de 44x44 px para dar amplitud al nombre del comercio.
   - **Normalización a Title Case y 2 Líneas:** Nombres de comercios en mayúsculas de impresoras fiscales se formatean a Title Case (`Importadora Hong Kong C.A.`) con hasta 2 líneas sin truncados prematuros.
   - **Limpieza de Sufijos Fiscales de OCR:** Filtrado automático de marcas fiscales como `(G)`, `(E)`, `(R)` en las descripciones de los artículos.
   - **Contraste WCAG AA y Tasa Visible:** El monto en bolívares se presenta en texto oscuro nítido (`AppColors.textPrimary`, 13 px, semibold) y la tasa de cambio de la transacción es visible en la cabecera.

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

6. **UI-03 (Semántica de Color Unificada en Progreso de Presupuesto):**
   - Se definió el token `AppColors.success = Color(0xFF10B981)` (Verde esmeralda).
   - Se centralizó la lógica semafórica en `AppColors.getBudgetProgressColor(double percent, {bool isExceeded = false})`:
     - Verde (`success`): Consumo saludable $< 85\%$.
     - Ámbar (`warning`): Advertencia $\ge 85\%$ y $< 100\%$.
     - Rojo (`error`): Límite superado ($\ge 100\%$ o `isExceeded: true`).
   - Se unificó su aplicación en la barra de progreso de `SummaryCard` (Inicio), `AnalysisScreen` (Análisis) y la versión web en `panel.astro`.

7. **UX-10 (Zona de Peligro Independiente para "Eliminar Cuenta"):**
   - Se desacopló la acción destructiva de la tarjeta "Respaldo en la Nube", evitando confusión entre sincronización y eliminación definitiva.
   - En "Respaldo en la Nube" se sustituyó la fila de botones por un `OutlinedButton` de ancho completo para "Cerrar sesión" (`Key('btn_cerrar_sesion')`) con borde sutil y estilo secundario neutro, sin divisor colgante.
   - Se creó una sección y tarjeta dedicada al final de la pantalla llamada "Zona de Peligro" (`_buildDangerZoneSection`), visible únicamente cuando el usuario posee una cuenta vinculada en la nube (`!isAnon`), con advertencia de irreversibilidad y botón `OutlinedButton` rojo (`Key('btn_eliminar_cuenta')`), preservando intacto el flujo de diálogo de confirmación y reautenticación por contraseña.

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

### Prueba 6: Semántica de Color Unificada en Presupuesto (UI-03)
1. Con un presupuesto configurado (ej. $100):
   - Con un gasto de $30 (30%): verificar que tanto en **Inicio** como en **Análisis** la barra de progreso sea verde (`AppColors.success`).
   - Con un gasto de $88 (88%): verificar que ambas barras pasen a amarillo/ámbar (`AppColors.warning`).
   - Con un gasto de $105 (105%): verificar que ambas barras se muestren en rojo (`AppColors.error`).
2. Abrir el panel web (`panel.astro`) y verificar idéntico comportamiento semafórico (verde $<85\%$, ámbar $\ge 85\%$, rojo $>100\%$).

### Prueba 7: Zona de Peligro y Cerrar Sesión (UX-10)
1. En la pestaña **Más** con una cuenta vinculada:
   - Observar la tarjeta superior de "Respaldo en la Nube": muestra datos del usuario y un botón ordenado de "Cerrar sesión" a lo ancho, sin divisores ni botón destructivo.
   - Desplazar al final de la pantalla (debajo de Versión de la App): observar la tarjeta "Zona de Peligro" con borde sutil rojo e ícono de advertencia.
   - Pulsar "Eliminar cuenta y datos": confirmar que se abre el diálogo de confirmación irreversible con las protecciones de reautenticación correspondientes.
2. Iniciar sesión anónima o cerrar sesión: verificar que la tarjeta "Zona de Peligro" no se renderiza.
