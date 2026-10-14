---
trigger: model_decision
description: "Consultar al modificar montos, monedas (VES/USD/EUR/USDT), tasas de cambio, presupuestos mensuales, categorías o cálculos financieros en Flutter y en el panel web."
---

# Lógica Financiera, Multimoneda y Modelado de Datos

## 1. Arquitectura Multimoneda y Conversión Determinista
- **Prohibición de Tasas Cableadas:** Queda terminantemente prohibido utilizar ratios fijos cableados (ej. `usd / 1.08`) o asumir paridad 1:1 para EUR o USDT. Toda conversión DEBE realizarse mediante `CurrencyFormatter` inyectando las tasas dinámicas activas (`tasaEur`, `tasaUsdt`, `tasaCambioVesUsd`).
- **Paridad Matemática Móvil y Web:** Toda lógica de conversión agregada en la aplicación móvil DEBE replicarse de forma determinista con paridad matemática exacta al céntimo en el panel web (`landing/src/pages/panel.astro`).
- **Inmutabilidad de Gastos en Bolívares (VES):** Los gastos pagados en VES conservan su monto original inmutable (`total_original`). Los totales y distribuciones históricas en Bolívares nunca se recalculan ante fluctuaciones posteriores de la tasa oficial. Los gastos en divisas (USD, EUR, USDT) se convierten utilizando la tasa oficial vigente en la fecha exacta del registro.
- **Sincronización Histórica de Tasas en UI:** Al cambiar la fecha de un gasto (`_selectedFecha`), las tasas sugeridas en formularios deben sincronizarse asíncronamente con dicha fecha, retrocediendo automáticamente al último día hábil si corresponde a fin de semana o feriado bancario.
- **Etiquetas Neutras en Entradas de Tasa:** Los campos de formulario para tasa deben titularse de forma neutra (ej. `"Tasa de Cambio"`), delegando el detalle del par y la fecha al texto de ayuda (`helperText`).

## 2. Precisión Numérica y Centavos
- **Almacenamiento en Centavos:** En `GastoModel`, los valores monetarios se almacenan como enteros (`int`) representando centavos. El getter oficial para obtener el valor decimal (`double`) es `totalOriginalDisplay` (`totalOriginal / 100.0`). Prohibido utilizar identificadores inventados como `totalOriginalDouble`.
- **Red de Seguridad Matemática en Extracción:** La aplicación debe sumar programáticamente los montos de los ítems extraídos y contrastarlos con el total reportado en la factura, aplicando autocorrección local si la IA omitió un punto decimal.

## 3. Catálogo Canónico e Invariante de Categorías
- **Catálogo Oficial Único (8 Categorías):** Móvil y web deben utilizar estrictamente las 8 categorías canónicas de `AppConstants.categorias`:
  `'Alimentación'`, `'Salud'`, `'Higiene'`, `'Educación'`, `'Hogar'`, `'Servicios'`, `'Transporte'`, `'Otros'`.
  Prohibido inventar categorías en la web o en código móvil (como 'Ropa', 'Entretenimiento' o 'Comida').
- **Valor por Defecto Neutro:** Todo formulario de creación manual de gastos debe preseleccionar por defecto la categoría `'Otros'` si no proviene de una clasificación contextual de IA, evitando distorsionar reportes si el usuario omite el selector.
- **Normalización Defensiva en Deserialización:** Toda capa de entrada (Firestore, SQLite, `GastoModel.fromMap`, respuestas del chat o voz) DEBE invocar `AppConstants.normalizarCategoria` (y su función homóloga en JavaScript) para transformar sinónimos heredados a su categoría canónica oficial.

## 4. Presupuestos Mensuales
- **Aislamiento por Mes:** Los presupuestos se aíslan por año y mes `(anio, mes)` en SQLite. Modificar el presupuesto de un mes nunca debe alterar meses anteriores ni posteriores.
- **Copia Automática del Mes Previo:** Si un mes recién consultado no posee presupuesto registrado, el sistema debe copiar automáticamente la configuración del mes inmediatamente anterior.
- **Validación de Asignación:** La suma total de los presupuestos asignados a categorías individuales no puede superar el presupuesto general mensual. La interfaz debe validar esta restricción y bloquear el guardado si se excede.
