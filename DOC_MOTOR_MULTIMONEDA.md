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

### 1. Tres Opciones de Liquidación en USD/EUR (`ReviewExpenseScreen` y `panel.astro`)
- Al registrar o revisar un gasto en `USD` o `EUR`, se presentan 3 pastillas de selección clara con sus etiquetas oficiales definitivas:
  - **`En Bs. · precio a tasa BCV`** (`BS_BCV`): Compra comercial con precio fijado en dólares pero cobrada en bolívares a tasa oficial BCV. Se guardan los bolívares exactos y se calcula su costo equivalente en USDT.
  - **`En Bs. · precio a tasa P2P`** (`BS_USDT`): Cobro en bolívares calculado sobre tasa USDT P2P / Binance.
  - **`En $ · efectivo o tarjeta`** (`DIVISA`): Pago directo en divisas en efectivo, Zelle, tarjeta internacional o cripto. Paridad 1:1 estricta con USDT.
- **Ajuste de Bolívares por Redondeo Comercial:**
  - La caja de liquidación tanto en móvil como en web incluye un campo editable de **Total a pagar en Bolívares (VES)**.
  - Si el punto de venta o comercio aplicó un redondeo (ej. de 5.000 Bs a 4.950 Bs o 5.100 Bs), el usuario puede ajustar los bolívares finales directamente. Ese importe exacto se convierte en el `total_original` inmutable en `VES`, recalculando las equivalencias.

### 2. Selector de 4 Lentes en Dashboard, Análisis y Panel Web
- Expandido a 4 lentes canónicos sincronizados: `USD BCV`, `USDT P2P`, `EUR BCV` y `Bs. (VES)`.
- **Consistencia Matemática Absoluta:**
  - El presupuesto general, meta de ahorro y límites por categoría se proyectan determinísticamente al lente activo (`convertBudgetToLens` / `convertToLens`).
  - Esto elimina de raíz discrepancias visuales donde un presupuesto fijado en USD se comparaba contra gastos acumulados en bolívares, evitando montos restantes negativos erróneos y consumos irreales (ej. 45499%).

### 3. Desacoplamiento de Moneda Inicial del Formulario vs. Lente Activo
- El formulario de registro en móvil y panel web inicializa siempre en `USD` con la opción `En Bs. · precio a tasa BCV` preseleccionada, independientemente de que el usuario tenga activo el lente `USDT P2P` o `Bs.`.
- Los bolívares ingresados directamente al seleccionar `VES` son 100% inmutables y nunca se reconstruyen desde un aproximado.

### 4. Preservación del Contexto al Editar y Edición en Web
- **En Web (`panel.astro`):** Funcionalidad completa para editar facturas existentes, con actualización en Firestore y recálculo en vivo.
- **Reconstrucción de Gastos Indexados:** Si un gasto fue originado como indexado a USD y liquidado en Bs., al abrirlo para editar se reconstruye en modo `USD` con su pastilla de liquidación correspondiente activa, su tasa congelada intacta y los ítems convertidos visualmente a USD.

### 5. Alerta de Discrepancia entre Monto Total y Suma de Ítems
- Si el usuario desglosó ítems cuya suma difiere del campo `Monto Total`, el sistema muestra un diálogo de confirmación que permite:
  1. Ajustar el total al valor de los productos.
  2. Mantener el monto total actual (respetando propinas, redondeos o impuestos no detallados en los ítems).

### 6. Desambiguación Robusta en IA (Voz, OCR y Chat)
- Si el usuario menciona un monto explícito en Bolívares (*"Gasté 4.000 Bs en gasolina, eran unos 20 dólares"*), el dato original obligatorio e inmutable es `4.000 VES` (`moneda: "VES"`); el monto en dólares es meramente referencial y nunca sobreescribe los bolívares.
- Si menciona USD sin especificar divisa ni efectivo (*"20 dólares en gasolina por punto de venta"*), el sistema asigna por defecto `metodo_liquidacion: "BS_BCV"` preseleccionando la opción en bolívares a tasa oficial.

### 7. Resiliencia Local-First ante Tasas Ausentes
- Protección estricta contra tasas $\le 0$ o divisiones por cero en `ExchangeRateService` y `panel.astro`. En ausencia de conexión, se recurre a la última tasa válida en caché.

### 8. Descarga Directa del APK sin Dependencia de GitHub Releases
- Al ser el repositorio privado en GitHub, el botón de descarga en la landing page (`index.astro`) enlaza directamente a BanaHosting con cache-buster `?b=$BUILD_NUM` inyectado tanto en el HTML estático en tiempo de compilación de CI como dinámicamente vía `/version.json`.

---

## 3. Guía de Pruebas Paso a Paso para César

1. **Prueba de Lentes en Panel Web (`panel.astro`):**
   - Acceder a `https://rindemas.cesarluis.com/panel`.
   - Seleccionar el lente `Bs. (VES)` y verificar que el presupuesto, dinero restante y categorías se muestren en Bolívares con porcentajes normales y coherentes (~69% o ~51%), sin desbordes negativos ni porcentajes astronómicos.
   - Probar el lente `EUR BCV` y confirmar coherencia en euros.

2. **Prueba de Registro con Ajuste de Bolívares en Web y Móvil:**
   - Abrir "Registrar gasto" teniendo el lente en `USDT P2P`. Confirmar que el formulario abra en `USD` con la opción `En Bs. · precio a tasa BCV`.
   - Escribir `20` USD. Observar cómo se calculan los bolívares en la caja inferior.
   - Modificar manualmente los bolívares a `4950.00`. Guardar y verificar que la factura registre exactamente `4.950,00 Bs.`.

3. **Prueba de Edición de Factura en Web:**
   - En la lista mensual de facturas en el panel web, hacer clic en `✏️ Editar` sobre una factura existente.
   - Modificar un ítem o el monto, guardar y verificar que se actualice inmediatamente en Firestore y en pantalla.

4. **Prueba de Alerta de Discrepancia:**
   - Registrar un gasto con total `10.00` y agregar un ítem con precio `8.00`.
   - Al pulsar Guardar, verificar que aparezca la confirmación para ajustar el total o mantenerlo.

5. **Prueba de Descarga del APK en Landing:**
   - En `https://rindemas.cesarluis.com`, hacer clic en "Descargar APK Directo" y verificar que descargue la versión más reciente del build.
