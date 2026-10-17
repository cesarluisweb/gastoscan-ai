# Documentación Técnica: Motor Multimoneda y Soporte de IA

## 1. Contexto y Arquitectura Multimoneda
En la economía venezolana conviven realidades cambiarias y formas de liquidación asimétricas:
1. **Lente Comercial / Oficial (USD BCV):** Los comercios fijan precios de referencia en dólares pero cobran en bolívares a tasa oficial del Banco Central de Venezuela.
2. **Lente de Reposición / Cripto (USDT P2P):** Los usuarios que mantienen fondos en criptoactivos (Binance) venden USDT en el mercado P2P para cubrir consumos locales. Al ser la tasa USDT superior a la oficial, pagar en bolívares a tasa BCV consume **menos USDT** de su patrimonio que el monto nominal en dólares.
3. **Lente Euro Oficial (EUR BCV):** Facturas o servicios tasados en euros oficiales del BCV.
4. **Lente Físico en Bolívares (VES):** El valor real liquidado en la moneda nacional.
5. **Pagos Directos en Divisas:** Efectivo USD, Zelle o compras digitales donde la relación USD/USDT es estrictamente 1:1.

---

## 2. Los 10 Puntos de Pulido Implementados

### 1. Tres Opciones de Liquidación y Redondeo Comercial en Bs. (`ReviewExpenseScreen` y `panel.astro`)
- Al registrar o revisar un gasto en `USD` o `EUR`, se presentan 3 pastillas de selección clara:
  - **`En Bs. · precio a tasa BCV`** (`BS_BCV`): Compra comercial cuyo precio está referenciado en USD pero se liquida en bolívares a tasa oficial BCV.
  - **`En Bs. · precio a tasa P2P`** (`BS_USDT`): Cobro en bolívares calculado sobre tasa USDT P2P / paralelo.
  - **`En $ · efectivo o tarjeta`** (`DIVISA`): Pago directo en divisas sin conversión a bolívares.
- **Campo de Bolívares Editable (Redondeo Comercial):** En las opciones liquidadas en Bs., el total a pagar en Bolívares es un campo editable (`input_total_bs_manual` / `modal-exp-bs-final`). Si el comercio redondea el monto en el punto de venta (ej. de 5.012,40 Bs a 5.000,00 Bs), el usuario puede ajustarlo directamente y ese monto exacto se guarda como `total_original` inmutable en `VES`, recalculando las equivalencias en USD y USDT.
- **Desacoplamiento del Lente Activo:** El formulario de nuevo gasto abre siempre en `USD` con `En Bs. · precio a tasa BCV` preseleccionado, independientemente del lente activo de reportes.
- **Reconstrucción de Contexto al Editar y Edición en Web:** Tanto en móvil como en `panel.astro` (botón `✏️ Editar`), abrir un gasto guardado en `VES` pero originado como indexado a USD/USDT reconstruye el formulario en `USD` con la pastilla de liquidación activa, los ítems convertidos visualmente a USD, la tasa histórica congelada y los bolívares pagados en la caja de liquidación.
- **Alerta de Discrepancia entre Total e Ítems:** Si la suma de los productos detallados difiere del Monto Total por más de `0.05`, se muestra un diálogo que permite ajustar el total a la suma de productos o conservar el monto ingresado.

### 2. Selector de 4 Lentes en Dashboard, Análisis y Panel Web
- Expandido a 4 lentes canónicos sincronizados:
  - `USD BCV` (Dólar oficial)
  - `USDT P2P` (Binance / Cripto)
  - `EUR BCV` (Euro oficial)
  - `Bs.` (Bolívares)
- Disponible en `SummaryCard`, `AnalysisScreen` y en la cabecera métrica de `panel.astro`.

### 3. Tarjeta Dedicada para "Moneda Principal de Reportes" (`MoreScreen`)
- Separada de la tarjeta de tasas de cambio a su propia tarjeta independiente.
- Nomenclatura unificada en el menú desplegable:
  - `USD`: `USD BCV (Dólar oficial)`
  - `USDT`: `USDT P2P (Binance / Cripto)`
  - `EUR`: `EUR BCV (Euro oficial)`
  - `VES`: `Bs. (Bolívares)`

### 4. Eliminación Visual de "Brecha Capturada"
- Retirada la insignia visual de "Brecha capturada" en las tarjetas de resumen (`SummaryCard` y `panel.astro`) para mantener una interfaz limpia y libre de sobrecarga cognitiva.

### 5. Corrección de Deriva (Drift) en Presupuestos (`BudgetBottomSheet` y `panel.astro`)
- Almacenamiento en memoria del valor base original ingresado por el usuario (`_baseGeneralAmount`, `_baseSavingsAmount`, `_baseCategoryAmounts`, `_baseMoneda`).
- Paridad 1:1 directa entre USD y USDT (`effFrom = (from == 'USDT') ? 'USD' : from`).
- Conversión determinista que previene la degradación progresiva por redondeo al alternar monedas. Si el usuario vuelve a la moneda base original, se restaura el número exacto.

### 6. Fallbacks Amigables en Captura
- Si el comercio se deja en blanco al guardar, el sistema asigna automáticamente `'Compra general'` sin bloquear al usuario con validaciones innecesarias.
- Si los ítems desglosados no tienen descripción, se nombran automáticamente `'Producto 1'`, `'Producto 2'`, etc.

### 7. Restauración de Tasa Histórica por Fecha
- Al cambiar la fecha del gasto en `ReviewExpenseScreen` o en `panel.astro`, se consultan las tasas oficiales y de mercado para ese día y se actualizan incondicionalmente tanto la tasa oficial (`tasaCambioCtrl`) como la tasa USDT (`tasaUsdtCtrl`).

### 8. Pulido Visual de la Calculadora Cambiaria
- Apertura en estado limpio y vacío sin botón "X" de borrado prematuro ni `1` precargado que confunda al usuario.
- Eliminación del badge duplicado de divisa en la cabecera del campo.

### 9. Paridad Total en Panel Web (`panel.astro`)
- Barra de selección de 4 lentes (`USD BCV`, `USDT P2P`, `EUR BCV`, `Bs.`).
- Formulario de gasto con las 3 opciones de liquidación y vista previa dinámica.
- Consulta de tasas históricas vía DolarAPI al modificar la fecha.
- Memoria de monto base en el modal de presupuestos.

### 10. Soporte Integral de IA (Voz, OCR y Chat)
- **Extracción de Gastos por Voz / Texto (`GeminiService` y Workers Cloudflare):**
  - Esquema JSON y prompt actualizados para detectar `metodo_liquidacion`:
    - `"BS_BCV"`: Pago en bolívares a tasa oficial, tarjeta, punto de venta o pago móvil.
    - `"BS_USDT"`: Cobro en bolívares a tasa paralelo, USDT, Binance o P2P.
    - `"DIVISA"`: Pago directo en divisas o efectivo.
- **Preselección Automática en `ReviewExpenseScreen`:** Mapea el campo de IA directamente al enum `MetodoLiquidacionUsd`.
- **Contexto Semántico del Chat (`ChatScreen`):** Mantiene los 4 lentes (`total_usd_bcv`, `total_usdt_p2p`, `total_eur_bcv`, `total_ves`) con instrucciones claras para responder preguntas sobre rendimiento o ahorro cambiario cuando el usuario lo consulte explícitamente.

---

## 3. Guía de Pruebas Paso a Paso para César

1. **Prueba de Voz / IA con Liquidación:**
   - Dictar por voz: *"Gasté 20 dólares de gasolina por pago móvil"* o *"15 dólares en farmacia en bolívares a BCV"*.
   - Verificar que en `ReviewExpenseScreen` la pastilla **`Pagado en Bs. (a BCV)`** ya aparezca seleccionada con los bolívares calculados.
   - Dictar: *"Pagué 10 dólares en efectivo"*. Verificar que preseleccione **`Pagado en $`**.

2. **Prueba de los 3 Métodos de Liquidación en Revisión:**
   - Seleccionar moneda USD con monto 20.00:
     - En **`Pagado en Bs. (a BCV)`**: bolívares calculados a tasa oficial y equivalente USDT menor a 20.
     - En **`Pagado en Bs. (a USDT P2P)`**: bolívares calculados a tasa USDT P2P y equivalente en lente BCV revaluado.
     - En **`Pagado en $`**: monto en dólares exacto (20 USD = 20 USDT).

3. **Prueba del Selector de 4 Lentes:**
   - En la pantalla principal, alternar entre `USD BCV`, `USDT P2P`, `EUR BCV` y `Bs.`.
   - Confirmar que el total gastado cambia al lente seleccionado y que la insignia visual de "Brecha capturada" ya no aparece.

4. **Prueba de Presupuestos sin Drift:**
   - Abrir el configurador de presupuestos, ingresar 100 USD.
   - Cambiar a VES, luego a EUR, luego a USDT y volver a USD.
   - Confirmar que regresa exactamente a `100` sin pérdida de decimales.

5. **Prueba de Paridad en Panel Web:**
   - Ingresar a `https://rindemas.cesarluis.com/panel` tras el despliegue.
   - Verificar la barra de 4 lentes métricos y el modal de registro con las 3 opciones de pago.
