---
trigger: model_decision
description: "Consultar al modificar montos, monedas (VES/USD/EUR/USDT), tasas de cambio, presupuestos mensuales, categorías o cálculos financieros en Flutter y en el panel web."
---

# Lógica Financiera, Multimoneda y Modelado de Datos

## 1. Arquitectura Multimoneda y Conversión Determinista
- **Paridad Directa USD/USDT:** Entre USD y USDT la conversión es determinista 1:1 a la par (1 USD = 1 USDT) en pagos directos en divisa (`DIVISA`), evitando triangular por bolívares para no introducir artificialmente la brecha cambiaria. Las tasas dinámicas de mercado (`tasaEur`, `tasaUsdt`, `tasaCambioVesUsd`) aplican cuando interviene Bolívares (VES) o para la paridad cambiaria oficial con EUR. Queda prohibido inventar ratios fijos cableados para EUR (ej. `usd / 1.08`).
- **Los 4 Lentes Financieros Canónicos:** Móvil y web operan bajo 4 lentes de visualización: `USD BCV` (tasa oficial), `USDT P2P` (tasa Binance P2P / costo de reposición), `EUR BCV` (euro oficial) y `Bs.` (bolívares). El cambio de lente altera la moneda de reporte en vivo sin distorsionar el monto original registrado.
- **Orden Canónico de Monedas:** En toda la plataforma móvil y web (selectores, menús desplegables, formularios y tablas), el catálogo de monedas se ordena estrictamente como: `USD` -> `VES` (o Bs.) -> `USDT` -> `EUR`.
- **Las 3 Opciones de Liquidación para USD/EUR:** Al registrar gastos referenciados en divisa, el usuario elige:
  1. `BS_BCV`: Liquidado en bolívares a tasa oficial BCV (comercio formal, tarjeta, punto de venta).
  2. `BS_USDT`: Liquidado en bolívares a tasa P2P / paralelo (Binance / mercado informal).
  3. `DIVISA`: Pagado directamente en dólares o divisas duras (efectivo, Zelle).
- **Redondeo Comercial en Caja (Total Bs. Editable):** En compras liquidadas en Bolívares (`BS_BCV` o `BS_USDT`), el total en Bs. es un campo editable. Si el comercio redondea el monto en el punto de venta, el usuario puede ajustar la cifra exacta pagada y ese valor se almacena como `total_original` inmutable en VES, recalculando las equivalencias.
- **Paridad Matemática Móvil y Web:** Toda lógica de conversión agregada en la aplicación móvil DEBE replicarse de forma determinista con paridad matemática exacta al céntimo en el panel web (`landing/src/pages/panel.astro`).
- **Inmutabilidad de Gastos en Bolívares (VES) y Divisas:** Los gastos pagados en VES conservan su monto original inmutable (`total_original`). Los totales y distribuciones históricas en Bolívares nunca se recalculan ante fluctuaciones posteriores de la tasa oficial. Los gastos en divisas (USD, EUR, USDT) se convierten utilizando la tasa oficial vigente en la fecha exacta del registro y sus acumulados mensuales se mantienen estables en el tiempo.
- **Sincronización Histórica de Tasas en UI:** Al cambiar la fecha de un gasto (`_selectedFecha`), las tasas sugeridas en formularios deben sincronizarse asíncronamente con dicha fecha, retrocediendo automáticamente al último día hábil si corresponde a fin de semana o feriado bancario.
- **Etiquetas Neutras en Entradas de Tasa:** Los campos de formulario para tasa deben titularse de forma neutra (ej. `"Tasa de Cambio"`), delegando el detalle del par y la fecha al texto de ayuda (`helperText`).

## 2. Precisión Numérica y Centavos
- **Almacenamiento en Centavos:** En `GastoModel`, los valores monetarios se almacenan como enteros (`int`) representando centavos. El getter oficial para obtener el valor decimal (`double`) es `totalOriginalDisplay` (`totalOriginal / 100.0`). Prohibido utilizar identificadores inventados como `totalOriginalDouble`.
- **Red de Seguridad Matemática en Extracción:** La aplicación debe sumar programáticamente los montos de los ítems extraídos y contrastarlos con el total reportado en la factura, aplicando autocorrección local si la IA omitió un punto decimal.
- **Proporcionalidad Matemática en Desglose de Compras Multimoneda:** Al desglosar artículos de una compra registrada en una divisa distinta a la moneda preferida del usuario (ej. compra en EUR o VES visualizada en USD), el monto convertido de cada ítem no debe calcularse aisladamente con redondeos independientes, sino de forma proporcional al total de la tarjeta:
  ```dart
  final double itemRatio = (itemTotalOriginal / totalOriginal);
  final double itemConverted = totalConverted * itemRatio;
  ```
  Esto garantiza que la suma de los ítems coincida exactamente al céntimo con el total mostrado en el encabezado de la tarjeta.

## 3. Catálogo Canónico e Invariante de Categorías
- **Catálogo Oficial Único (8 Categorías):** Móvil y web deben utilizar estrictamente las 8 categorías canónicas de `AppConstants.categorias`:
  `'Alimentación'`, `'Salud'`, `'Higiene'`, `'Educación'`, `'Hogar'`, `'Servicios'`, `'Transporte'`, `'Otros'`.
  Prohibido inventar categorías en la web o en código móvil (como 'Ropa', 'Entretenimiento' o 'Comida').
- **Valor por Defecto Neutro:** Todo formulario de creación manual de gastos debe preseleccionar por defecto la categoría `'Otros'` si no proviene de una clasificación contextual de IA, evitando distorsionar reportes si el usuario omite el selector.
- **Normalización Defensiva en Deserialización:** Toda capa de entrada (Firestore, SQLite, `GastoModel.fromMap`, respuestas del chat o voz) DEBE invocar `AppConstants.normalizarCategoria` (y su función homóloga en JavaScript) para transformar sinónimos heredados a su categoría canónica oficial.

## 4. Presupuestos Mensuales
- **Aislamiento por Mes:** Los presupuestos se aíslan por año y mes `(anio, mes)` en SQLite. Modificar el presupuesto de un mes nunca debe alterar meses anteriores ni posteriores.
- **Adopción Automática de Presupuesto Previo:** Si un mes recién consultado no posee presupuesto registrado, el sistema adopta automáticamente en memoria la configuración del presupuesto más reciente registrado en su historial (evitando vacíos o reinicios a cero cuando hay meses intermedios sin registros). Modificar o consolidar un mes nunca altera meses anteriores.
- **Validación de Asignación:** La suma total de los presupuestos asignados a categorías individuales no puede superar el presupuesto general mensual. La interfaz debe validar esta restricción y bloquear el guardado si se excede.
- **Escala Física de la Barra de Asignación y Meta de Ahorro:**
  - La barra de progreso de asignación escala siempre sobre el presupuesto general total (`budgetInLens`), no sobre el límite de gasto, asegurando proporcionalidad real.
  - El divisor vertical (`2dp`, sobresaliendo `3dp` arriba y abajo) se posiciona exactamente en `limite / presupuesto`, delimitando a la derecha la reserva protegida de ahorro.
  - La barra avanza físicamente cruzando el divisor hacia la derecha únicamente cuando el gasto real invade la meta de ahorro (`gasto > limite`), momento en que se tiñe de color rojo (`AppColors.error`).

## 5. Tratamiento de IVA y Precios de Anaquel
- **Precios con IVA Imputado (Anaquel):** Todo producto gravado con alícuota general `(G)` en facturas fiscales debe almacenarse y presentarse con su precio final de anaquel (IVA incluido), evitando crear un renglón independiente de 'Impuesto IVA' que distorsione los presupuestos por categoría o altere las comparaciones históricas frente a entradas por voz o manuales. Los productos exentos `(E)` no se modifican. La diferencia de redondeo ($\pm 0,01$) se compensa deterministamente en el producto gravado de mayor valor. Especificación completa en `DOC_PRECIOS_ANAQUEL_IVA.md`.
