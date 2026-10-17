# Documentación Técnica: Motor Multimoneda "Dos Lentes" (USD BCV vs. USDT P2P)

## 1. Contexto y Problema Resuelto
En la economía venezolana conviven dos realidades cambiarias con paridades asimétricas:
1. **Lente Comercial / Oficial (USD BCV):** Los comercios fijan precios de lista en dólares pero facturan en bolívares a la tasa oficial del Banco Central de Venezuela (`total_ves / tasa_bcv`).
2. **Lente de Reposición / Mercado Libre (USDT P2P):** Los usuarios que generan o mantienen sus fondos en criptoactivos (Binance P2P) venden sus USDT a tasa paralela/P2P para obtener bolívares (`total_ves / tasa_usdt`). Al ser la tasa USDT generalmente mayor a la oficial, pagar en bolívares a tasa oficial consume **menos USDT** de su patrimonio que los dólares nominales de la etiqueta.
3. **Paridad Directa 1:1 en Pagos en Divisa:** Si el gasto se paga directamente en moneda dura (efectivo USD, suscripciones digitales como Spotify o transferencias USDT), la relación es estrictamente 1:1 (`$7.99 USD = 7.99 USDT`).

Anteriormente (`FIN-10`), forzar paridad 1:1 global solucionó las suscripciones en divisas pero eliminó la distinción entre bolívares y divisas, impidiendo ver el ahorro y la brecha cambiaria capturada en compras locales.

El nuevo **Motor Multimoneda Dos Lentes** separa la moneda de origen físico del gasto y persiste ambos lentes de valoración en SQLite y Firestore de forma inmutable y determinística.

---

## 2. Cambios en la Base de Datos (Migración SQLite v17)
Se incrementó la versión de base de datos a `17` en `DatabaseHelper`.

### Columnas Nuevas en la Tabla `gastos`:
- `tasa_usdt REAL`: Tasa P2P de referencia al momento de registrar el gasto.
- `total_usdt INTEGER`: Equivalente del gasto bajo el lente USDT P2P, almacenado en céntimos enteros (al igual que `total_original` y `total_usd`).

### Determinismo y Backfill Histórico:
- Para gastos donde `moneda != 'VES'`: `total_usdt = total_usd` (paridad 1:1 directa para USD, USDT y equivalentes en divisa).
- Para gastos históricos en bolívares (`moneda == 'VES'`):
  - Si `fuente_tasa_cambio` contiene `'USDT'`: `tasa_usdt = tasa_cambio` y `total_usdt = total_usd`.
  - Si `tasa_usdt > 0`: `total_usdt = round(total_original / tasa_usdt)`.
  - Fallback seguro para registros antiguos sin tasa USDT histórica: `total_usdt = total_usd` para evitar divisiones por cero o recálculos retroactivos volátiles.

---

## 3. Experiencia de Captura y Verdad Física (`ReviewExpenseScreen`)

### Caso A: Gasto Pagado en Bolívares (`moneda == 'VES'`)
- Se muestran dos campos de tasa: **Tasa BCV (USD)** y **Tasa USDT (P2P Binance)**.
- Vista previa dual en tiempo real: `= $X,XX BCV • Y,YY USDT`.
- El usuario puede editar la tasa USDT si vendió a un precio específico en P2P.

### Caso B: Gasto con Precio de Etiqueta en Divisa pero Pagado en Bolívares
- Para usuarios que piensan en dólares (ej. "$20 de gasolina") pero cancelan con tarjeta de débito en bolívares a tasa oficial:
- Se incorporó el selector de método de liquidación: **`[ Pagado en Bs. a tasa BCV ]`** vs **`[ Pagado en Divisa ]`**.
- Al activar *"Pagado en Bs. a tasa BCV"*, la aplicación calcula automáticamente los bolívares (`$20 * 40 = Bs. 800`), los persiste con su verdad física (`moneda = 'VES'`), sella `total_usd = 2000` y calcula `total_usdt = 1600` (a tasa P2P 50).

---

## 4. Agregaciones, Métricas y Brecha Capturada

### Switch Rápido de Lente en Dashboard y Análisis:
- En `SummaryCard` y `AnalysisScreen` se añadió un selector rápido con 3 modos:
  - **`USD BCV`**: Visión de precios de lista comerciales y presupuesto estándar.
  - **`USDT P2P`**: Visión de costo real de reposición patrimonial.
  - **`Bs.`**: Total físico en bolívares.
- Cuando el lente activo es `USDT` y el usuario tiene compras en bolívares, se despliega la insignia destacada:
  **`Brecha capturada: +$X,XX vs BCV`** (`sumUsd - sumUsdt`).

### Presupuestos (`BudgetBottomSheet`):
- Corregido el bug de triangulación: cambiar la moneda del presupuesto entre `USD` y `USDT` utiliza conversión directa 1:1 sin pasar por la tasa del bolívar.

### Asistente Inteligente (`ChatScreen`):
- El contexto semántico (`_buildSemanticChatContext`) ahora suministra:
  - `total_usd_bcv`: Total mensual bajo lente oficial BCV.
  - `total_usdt_p2p`: Total mensual bajo costo de reposición P2P.
  - `total_ves`: Total gastado en bolívares nominales.
  - `brecha_capturada`: Ahorro neto obtenido por arbitraje de tasas.

---

## 5. Paridad Web (`panel.astro`)
- Se eliminó el multiplicador estático prohibido `liveRates.usd * 1.08`.
- Se implementó la acumulación `sumUsdt` y la insignia de brecha capturada.
- El registro manual de facturas en la web persiste `total_usdt` y `tasa_usdt` en Firestore.

---

## 6. Guía de Pruebas de Validación para César

1. **Prueba de Gasolina (USD pensado, pagado en Bs):**
   - Abrir "Registrar Gasto" y seleccionar moneda `USD`.
   - Ingresar monto `20.00`.
   - Activar el botón `[ Pagado en Bs. a tasa BCV ]`.
   - Verificar que muestre el cálculo en Bolívares y el equivalente en USDT (menor a $20).
   - Guardar y revisar la tarjeta del gasto: debe guardarse como gasto en `Bs.` indicando equivalentes en `$ BCV` y `USDT`.

2. **Prueba de Suscripción Digital (USD pagado en Divisa):**
   - Registrar gasto de `7.99 USD` con la opción `[ Pagado en Divisa ]`.
   - Verificar que en el lente `USDT` el monto sea exactamente `7.99 USDT` (paridad 1:1).

3. **Prueba del Switch de Lentes en Dashboard:**
   - En la tarjeta principal de Inicio, alternar entre `USD BCV`, `USDT P2P` y `Bs.`.
   - En `USDT P2P`, verificar que el total gastado refleje el costo P2P y aparezca la insignia verde de `Brecha capturada: +$X.XX vs BCV`.

4. **Prueba de Presupuestos:**
   - Abrir el editor de presupuestos y cambiar la moneda de `USD` a `USDT`.
   - Comprobar que un presupuesto de `$200` se convierta en `200 USDT` sin alteración.
