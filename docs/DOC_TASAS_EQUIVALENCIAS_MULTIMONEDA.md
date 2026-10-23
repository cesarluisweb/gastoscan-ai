# Documento Técnico: Equivalencias y Tasas Multimoneda Inmutables (`USD`, `VES`, `USDT`, `EUR`)

**Fecha:** 23 de octubre de 2026  
**Versión de Esquema SQLite:** `18`  
**Estado:** Pendiente de validación 🧪  
**Módulo:** Finanzas Bimonetarias / Lentes Multimoneda / Registro de Gastos  

---

## 1. Contexto y Problema Resuelto

### El Problema Detectado:
1. **Confusión en Registro en Bolívares (`VES`):** Al presionar el chip `Euro BCV`, la pantalla actualizaba la tasa a la del euro oficial, pero el campo inferior seguía diciendo erróneamente `Equiv. USD (BCV) $ 5.65`, mezclando el monto en euros con el símbolo de dólares. Además, al guardar, almacenaba ese valor en el campo `total_usd`.
2. **Ausencia de `total_eur` y `tasa_eur` en Base de Datos:** La base de datos congelaba `total_original`, `total_usd` y `total_usdt`, pero carecía de columnas para el euro. Al cambiar el lente de la app o del panel web a `EUR BCV`, los gastos históricos se recalculaban dividiendo el bolívar entre la tasa euro del día actual en lugar de la tasa vigente el día de la compra.

---

## 2. Modificaciones de Esquema (SQLite v18 y Firestore)

### Migración SQLite `v17` $\rightarrow$ `v18` (`DatabaseHelper`):
- Se agregaron las columnas:
  - `tasa_eur REAL`: Tasa oficial BCV del Euro correspondiente a la fecha de la compra.
  - `total_eur INTEGER`: Contravalor en céntimos de Euro congelado inmutablemente.
- **Backfill Inmutable Automático:**
  1. Gastos donde `moneda == 'EUR'`: `total_eur = total_original` y `tasa_eur = tasa_cambio`.
  2. Gastos en `VES` con fuente de tasa Euro: `total_eur = total_usd` y `tasa_eur = tasa_cambio`.
- Consultas `getMonthlyTotals` y `getCategoryTotals`:
  - Retornan `'EUR': sumEur` sumando los montos congelados en `total_eur`.

### Modelo de Datos (`GastoModel`):
- Agregados campos `final int? totalEur` y `final double? tasaEur`.
- Getters:
  - `double get totalEurDisplay => (totalEur ?? totalUsd) / 100.0;`
  - `double get tasaEurDisplay => (tasaEur != null && tasaEur! > 0) ? tasaEur! : tasaCambio;`
- Serialización completa en `toMap()`, `fromMap()`, `toFirestoreMap()` y `copyWith()`.

---

## 3. Comportamiento de los 4 Flujos en Pantalla de Registro (`ReviewExpenseScreen`)

### 1. Registro en Dólares (`USD`) y Euros (`EUR`)
- **En divisa directa (1.ª opción y por defecto al registrar nuevo gasto):** Formulario limpio con solo el campo `Monto Total ($/€)` y debajo un cintillo resumen con las equivalencias en las otras divisas y en Bolívares.
- **En Bs. a tasa BCV (2.ª opción):** Usuario introduce monto en etiqueta; se calcula el total en Bolívares (`monto × tasa_bcv`). Muestra equivalentes `USD BCV • EUR BCV • USDT P2P`.
- **En Bs. a tasa P2P (3.ª opción):** Usuario introduce monto en etiqueta; se calcula el total en Bolívares (`monto × tasa_usdt`). Muestra equivalentes `USDT P2P • USD BCV • EUR BCV`.

### 2. Registro en Bolívares (`VES`) - Divulgación Progresiva
- Usuario introduce el monto en Bolívares.
- **Por defecto (estado colapsado):** Muestra el campo de monto en Bolívares y debajo las **3 columnas de equivalencias simultáneas** sincronizadas con la fecha seleccionada (`Equiv. USD (BCV)`, `Equiv. EUR (BCV)` y `Equiv. USDT (P2P)`), junto con el botón sutil `Ajustar tasas ▾`.
- **Al presionar `Ajustar tasas ▾` (estado desplegado):** Revela los chips rápidos (`Dólar BCV`, `Euro BCV`, `USDT P2P`), la caja de edición manual de la tasa y el botón de restauración (`Icons.restart_alt`) para restablecer el valor oficial exacto de la fecha. Si alguna tasa fue alterada, muestra el indicador visual `Tasa personalizada activa`.
- Se guardan de forma inmutable los 4 totales y las 3 tasas correspondientes a la fecha.

### 3. Registro en USDT (`USDT`)
- El formulario permanece limpio y ágil: solo pide el `Monto Total (USDT)`.
- No satura con campos de bolívares. Muestra un cintillo informativo:
  `Se guardará en USDT (≈ $10.00 USD 1:1 • €8.92 EUR • Bs. 9,984.60)`.
- Por detrás, la app guarda silenciosamente las tasas del día para que, si el usuario activa el lente `Bs.` o `EUR` en el Inicio, el gasto tenga su contravalor exacto.

### 4. Registro en Euros (`EUR`)
- **En Bs. a tasa BCV:** Etiqueta corregida: `≈ €10.00 EUR Oficial • $11.21 USD • 9.95 USDT`.
- **En Bs. a tasa P2P:** Indexado a tasa USDT de la fecha.
- **En divisa directa:** Se guarda en `moneda: EUR` con cálculo de equivalencias en USD y USDT.

---

## 4. Paridad Matemática en Panel Web (`landing/src/pages/panel.astro`)

- `renderMetrics`, `renderCategories` y `renderBills` calculan el lente `EUR` leyendo `total_eur` y `tasa_eur`.
- Al crear o editar un gasto desde la web, se persisten `total_eur` y `tasa_eur` en Firestore con paridad matemática al céntimo con Flutter.

---

## 5. Guía de Pruebas Manuales en Dispositivo (*Rinde Más Dev*)

Para validar la tarea tras el despliegue del APK `rindemas-dev-apk`:

1. **Gasto en Bolívares (`VES`):**
   - Ir a registrar un gasto manual o por foto. Seleccionar moneda `VES`.
   - Ingresar un monto (ej. `Bs. 9.000,00`).
   - Verificar que abajo aparezcan las 3 columnas: `Equiv. USD (BCV)`, `Equiv. EUR (BCV)` y `Equiv. USDT (P2P)` con sus símbolos correctos (`$`, `€`, `USDT`).
   - Tocar el chip `Euro BCV`: confirmar que la caja de texto muestre la tasa del Euro oficial y que abajo `Equiv. USD (BCV)` no cambie ni se altere.
   - Editar manualmente la tasa: verificar que aparezca el botón circular de restaurar tasa oficial y que al presionarlo recupere el valor del BCV de la fecha del gasto.
   - Guardar y verificar en el Inicio que bajo el lente `Bs.`, `USD`, `USDT` y `EUR`, la compra se refleje con su valor respectivo.
2. **Gasto en USDT directo:**
   - Seleccionar `USDT` como moneda de pago e ingresar `10`.
   - Confirmar que el formulario no pide tasa en bolívares y que muestra el cintillo `Se guardará en USDT (≈ $10.00 USD 1:1...)`.
   - Guardar y verificar que en el lente `EUR` y `Bs.` sume con la tasa de esa fecha.
3. **Gasto en EUR:**
   - Seleccionar `EUR` con pago `En Bs. a tasa BCV`. Confirmar que la etiqueta indique `≈ €... EUR Oficial` (no dice `$`).
