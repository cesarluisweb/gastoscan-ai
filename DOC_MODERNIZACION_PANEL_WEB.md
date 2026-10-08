# Modernización y Paridad del Panel Web (Rinde Más)

## 1. Contexto y Objetivos
El panel web de Rinde Más ([`landing/src/pages/panel.astro`](./landing/src/pages/panel.astro)) permite a los usuarios acceder a sus finanzas, presupuestos mensuales y desgloses de facturas desde cualquier navegador en PC, Mac o iPhone. Con las mejoras recientes en la app móvil (soporte multimoneda, presupuesto con meta de ahorro y motor determinista de proyección de gasto), el panel web requería actualización para mantener paridad estricta y evitar sobreescritura de datos en Firestore.

---

## 2. Fases Planificadas

```
Fase 1: Presupuesto y Meta de Ahorro en Modal y Firestore (Completada 🔄 En Verificación)
Fase 2: Semáforo de Salud de Ahorro y Ritmo Diario en Métricas (Completada 🔄 En Verificación)
Fase 3: Soporte Multi-Moneda (USD, VES, EUR, USDT) y Tasas en Vivo (Completada 🔄 En Verificación)
Fase 4: Autenticación con Correo y Contraseña (Pendiente)
Fase 5: Edición y Detalle Ampliado de Facturas (Pendiente)
```

---

## 3. Implementación Detallada: Fases 1 y 2

### Fase 1: Presupuesto y Meta de Ahorro en Firestore
1. **Lectura e Integración de `meta_ahorro`:**
   - La función `loadDashboardData()` ahora lee `data.meta_ahorro` del documento `/users/{uid}/presupuestos/{anio_mes}` en Firestore y lo preserva en `currentPresupuesto.meta_ahorro`.
   - Se evita la pérdida o borrado involuntario de la meta de ahorro configurada desde la aplicación móvil.
2. **Entrada y Validación en el Modal de Presupuesto:**
   - Se añadió el campo `modal-budget-savings` ("Meta de Ahorro / Inversión (Opcional)").
   - Se añadió el indicador en vivo `modal-budget-limit-indicator` que calcula y muestra en tiempo real el *Límite para gastar*: `Presupuesto General - Meta de Ahorro`.
   - Validación reactiva:
     - Si la meta de ahorro supera el presupuesto general, se muestra advertencia en rojo y se bloquea el guardado.
     - Si la suma asignada a categorías supera el límite para gastar (`general - meta_ahorro`), se alerta al usuario y se impide el guardado.
3. **Persistencia Segura en Firestore:**
   - `btnSaveBudgetModal` persiste `meta_ahorro` junto con `presupuesto_general`, `moneda`, `categorias` y `actualizado_en` usando `setDoc(..., { merge: true })`.

### Fase 2: Semáforo de Salud de Ahorro y Ritmo Diario en Métricas
1. **Motor Determinista de Salud (`calculateSavingsHealth`):**
   - Replicación matemática en JavaScript idéntica a `SavingsHealthCalculator` de Flutter:
     - `diasTranscurridos = min(diaActual, diasTotalesMes)`.
     - `gastoDiarioPromedio = gastoAcumulado / diasTranscurridos`.
     - `gastoProyectado = gastoDiarioPromedio * diasTotalesMes`.
   - Determinación del estado de la meta:
     - `protegida`: Si los días transcurridos <= 3 (período de gracia inicial) o si el gasto proyectado <= límite para gastar.
     - `enRiesgo`: Si el gasto proyectado a fin de mes supera el límite para gastar.
     - `comprometida`: Si el gasto actual acumulado ya sobrepasó el límite para gastar.
2. **Tarjetas de Métricas del Dashboard:**
   - **Tarjeta Presupuesto:** Muestra el presupuesto general y, si existe meta de ahorro, indica claramente el límite para gastar y el monto destinado a ahorro.
   - **Tarjeta Dinero Restante:** Calcula el saldo disponible respecto al límite para gastar (`limiteParaGastar - gastado`). Muestra un badge de estado del ahorro:
     - `🛡️ Protegida` (Verde esmeralda).
     - `⚠️ En riesgo` (Ámbar).
     - `🚨 Comprometida` (Rojo).
   - **Ritmo Diario Restante:**
     - Si es el mes en curso, calcula: `(Límite restante) / (Días restantes del mes)` y muestra `Faltan X días • Ritmo sugerido: $Y.YY/día`.
     - Si es un mes histórico, resume el ahorro logrado o el exceso ocurrido al cierre.
3. **Barra de Progreso:**
   - Calcula el porcentaje de consumo contra el límite para gastar cuando la meta de ahorro está activa (`meta_ahorro > 0`), alertando en rojo si supera el 100% o en ámbar si supera el 85%.
4. **Coherencia Matemática en Categorías:**
   - `renderCategories()` respeta la moneda del presupuesto (VES, USD, EUR, USDT) convirtiendo o sumando adecuadamente los gastos según la divisa del presupuesto.

### Fase 3: Multi-Moneda y Paridad Matemática Web (USD, VES, EUR, USDT)
1. **Ticker de Tasas en Vivo:**
   - Consulta concurrente al cargar el panel de USD BCV (`ve.dolarapi.com`), EUR BCV (`ve.dolarapi.com`) y USDT P2P (`api.yadio.io` con fallback a paralelo).
   - Cápsula visual compacta en la parte superior mostrando las cotizaciones del día.
2. **Paridad Matemática de Totales:**
   - Replicación idéntica de `DatabaseHelper.getMonthlyTotals`:
     - `sumUsd`: suma directa de `total_usd / 100` para todos los gastos.
     - `sumVes`: si `moneda === 'VES'`, suma `total_original / 100` (inmutabilidad del bolívar); si es divisa (USD, EUR, USDT), convierte determinísticamente `(total_usd * tasa)`.
   - Se eliminó el error donde compras en USD no sumaban al equivalente en bolívares.
3. **Métricas Adaptativas a la Moneda del Presupuesto:**
   - Tarjeta 2 (Total Gastado): Muestra el número principal en la moneda del presupuesto (`budgetCurrency`). Subtexto con el contravalor equivalente (`≈ Bs. X.XX` si el presupuesto es en divisa, o `≈ $ Y.YY` si es en bolívares).
   - Tarjetas 1, 3 y 4 formateadas en `budgetCurrency`.
4. **Modal de Gasto con 4 Monedas:**
   - Selectores rápidos `[USD $]`, `[VES Bs.]`, `[EUR €]`, `[USDT]`.
   - Campo de tasa de cambio visible y editable, prellenado con la tasa de referencia del día.
   - Previsualización en tiempo real del contravalor.
   - Guardado en Firestore preservando `tasa_cambio` real (nunca forzada a 1.0) y campos estándar de `GastoModel`.
5. **Lista de Facturas:**
   - Cada factura muestra el monto en su moneda original pagada y el subtexto con su equivalente y la tasa aplicada.

---

## 4. Guía de Pruebas Paso a Paso para Verificación Manual

### Prueba 1: Carga y Visualización de Presupuesto con Ahorro
1. Abrir el panel web en el navegador (`localhost:4321/panel` o URL desplegada).
2. Iniciar sesión con la cuenta de Google vinculada en la app móvil.
3. Seleccionar el mes actual.
4. **Resultado esperado:**
   - La Tarjeta 1 muestra el monto total presupuestado y debajo el límite para gastar y la meta de ahorro (si ya fue fijada en el móvil).
   - La Tarjeta 3 muestra el dinero disponible para gastar y el chip con el estado del ahorro (`🛡️ Protegida`, `⚠️ En riesgo` o `🚨 Comprometida`).
   - Debajo de las tarjetas, se observa el ritmo diario sugerido: `Faltan N días • Ritmo sugerido: $X.XX/día`.

### Prueba 2: Configuración de Meta de Ahorro desde el Panel Web
1. En el panel web, hacer clic en el botón **"Presupuesto"** o **"Ajustar"**.
2. Fijar un presupuesto general (ej. `$200`).
3. Ingresar una meta de ahorro (ej. `$50`).
4. **Resultado esperado:** Inmediatamente debe aparecer la etiqueta verde `Límite para gastar: $150.00`.
5. Intentar ingresar una meta de ahorro superior al general (ej. `$250`).
6. **Resultado esperado:** Debe aparecer el aviso en rojo `La meta supera el presupuesto general` y la suma de categorías alertará de la inconsistencia.
7. Ajustar la meta a `$50`, asignar categorías por un total de `$140` y presionar **Guardar**.
8. **Resultado esperado:** El modal se cierra, los datos se guardan en Firestore sin errores y el panel se actualiza mostrando `$150.00` de límite para gastar.

### Prueba 3: Validación de Exceso en Categorías
1. Abrir nuevamente el modal de presupuesto.
2. Con General `$200` y Meta `$50` (límite `$150`), colocar en las categorías sumas que den `$170`.
3. **Resultado esperado:** El indicador de suma mostrará en rojo `Suma: $170.00 (Supera el límite para gastar)`. Si se pulsa Guardar, se bloquea con alerta informativa.

### Prueba 4: Cuadre Multi-Moneda y Tasa en Vivo (Fase 3)
1. Abrir el panel web con una cuenta que posea gastos en dólares (USD) o registrar uno nuevo en USD.
2. **Resultado esperado:**
   - La barra superior muestra las tasas de referencia del día (BCV USD, BCV EUR, USDT).
   - La Tarjeta 2 muestra el total gastado en la moneda del presupuesto y en el subtexto su equivalente exacto en la otra moneda (sin mostrar "Sin compras en Bs." si hubo compras en USD).
   - En la lista de facturas, la compra en dólares muestra su monto en `$`, el equivalente en bolívares y la tasa de cambio aplicada.
3. Abrir el modal **"Registrar gasto"**, alternar entre los chips `[USD]`, `[VES]`, `[EUR]`, `[USDT]`.
4. **Resultado esperado:** La tasa se prellena automáticamente con la cotización de esa moneda y el campo muestra la previsualización en tiempo real del contravalor.
5. Guardar una compra en USD o EUR.
6. **Resultado esperado:** El gasto se almacena en Firestore con su `tasa_cambio` real (ej. 36.50) y se refleja de inmediato en los totales sin alterar los balances del teléfono.
