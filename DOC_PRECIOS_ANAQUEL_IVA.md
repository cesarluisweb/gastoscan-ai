# Especificación Técnica: Precios de Anaquel e Imputación de IVA en Compras

Este documento define la regla de negocio, el modelo matemático y la experiencia de usuario para reflejar los precios de anaquel (con IVA incluido) en la extracción de facturas y el desglose de compras de **Rinde Más**.

---

## 1. Contexto y Problema

En Venezuela conviven dos realidades de precios:

1. **En el anaquel (hablador del comercio):**
   Por ley y práctica comercial, el precio exhibido al consumidor **siempre incluye el IVA**. Si el hablador indica **$3,00**, el usuario paga exactamente $3,00 (en divisas o bolívares a tasa oficial).
2. **En la máquina fiscal (ticket SENIAT):**
   Las impresoras fiscales imprimen los productos gravados a **base imponible** (sin impuesto), agregando el IVA 16% al final en el subtotal liquidado:
   $$\text{Base} = \frac{3,00}{1,16} \approx 2,59$$
   $$\text{IVA 16\%} \approx 0,41 \implies \text{Total} = 3,00$$
3. **Productos exentos `(E)`:**
   Alimentos básicos (harina de maíz, arroz, huevos, leche, carnes) no pagan IVA; en ellos la base y el precio final coinciden.

### Problemas que resuelve esta especificación
- **Distorsión de categorías y presupuestos:** Si el IVA de $0,41 se guarda como un renglón independiente ("Impuesto IVA" en categoría 'Otros'), el 16% de las compras de Higiene u Hogar infla la categoría 'Otros', desvirtuando el gasto real y falseando los presupuestos mensuales.
- **Falsas variaciones en comparador de precios e IA:** Al registrar gastos por voz o de forma manual, el usuario siempre introduce el precio de anaquel ($3,00). Si la cámara extrae $2,59, el comparador histórico (`findPreviousPrice`) y el Asistente IA interpretan erróneamente que el producto bajó de precio un 14%.
- **Choque cognitivo:** El usuario recuerda lo que pagó por el producto en el anaquel ($3,00), no la base imponible ($2,59).

---

## 2. Regla de Negocio

1. **Precios de Anaquel por Defecto:**
   Todo producto gravado con alícuota general `(G)` debe almacenarse y presentarse en la aplicación con su precio final con IVA incluido.
2. **Productos Exentos Intactos:**
   Los productos exentos marcados con `(E)` mantienen su precio original sin modificaciones.
3. **Eliminación del Renglón Huérfano de IVA:**
   No se creará una línea independiente de gasto denominada *"Impuesto IVA"* en la base de datos ni en los desgloses; el impuesto queda imputado en los productos que lo causaron.
4. **Cotejo en Pantalla de Revisión (`ReviewExpenseScreen`):**
   Para no generar dudas cuando el usuario coteje la app contra el papel físico de la factura:
   - El campo principal editable muestra el **precio final con IVA** (ej. `$3,00`).
   - Debajo del campo, en texto secundario gris sutil, se muestra la base leída en el papel: `IVA 16% incl. (Base en factura: $2,59)`.

---

## 3. Algoritmo Determinista del Centavo Residual ($\pm 0,01$)

Las máquinas fiscales del SENIAT no aplican el 16% producto por producto; suman todas las bases imponibles y aplican el 16% sobre el subtotal acumulado. 

Al calcular el IVA por ítem y redondear a 2 decimales, la suma de los ítems puede presentar una discrepancia de $\pm 0,01$ respecto al total general de la factura (`total_original`).

### Algoritmo de Imputación:
1. Para cada producto con `alicuota_fiscal == 'G'`:
   $$\text{precioConIva}_i = \text{round}(\text{base}_i \times 1,16 \times 100) / 100$$
   $$\text{totalItem}_i = \text{cantidad}_i \times \text{precioConIva}_i$$
2. Calcular la suma de todos los ítems (exentos + gravados con IVA):
   $$\text{sumaCalculada} = \sum \text{totalItem}$$
3. Calcular la diferencia con el total real de la factura:
   $$\text{delta} = \text{round}((\text{totalOriginal} - \text{sumaCalculada}) \times 100) / 100$$
4. Si $|\text{delta}| == 0,01$:
   - Identificar el ítem gravado `(G)` con mayor monto total.
   - Ajustar su monto sumando o restando el centavo residual (`delta`).
   - Recalcular su `precio_unitario` dividiendo entre su cantidad.
5. De esta forma, la suma de los renglones cuadra con exactitud matemática con el monto pagado en caja.

---

## 4. Arquitectura y Puntos de Implementación

1. **Backend / Gateway (`workers/src/index.js`):**
   - El prompt mantiene la extracción de `alicuota_fiscal` (`E` o `G`), `precio_unitario` (base fiscal de la factura) y el total general de la factura `total_original`.
2. **Modelo Cliente (`GeminiExtractionResult.fromJson`):**
   - Aplica el algoritmo del centavo residual sobre la lista de ítems.
   - Preserva la base original en un atributo `baseImponibleOriginal` de cada ítem para alimentar el subtítulo informativo.
   - Omite la inyección del ítem artificial `Impuesto IVA`.
3. **Pantalla de Revisión (`ReviewExpenseScreen`):**
   - Renderiza el precio con IVA en el campo numérico.
   - Muestra el texto informativo `Base factura: $X,XX` cuando el ítem provenga de `(G)`.
4. **Historial de Gastos y Gráficos:**
   - Consume directamente los ítems con su precio de anaquel, garantizando que Higiene, Hogar o Alimentación sumen el 100% de su valor real pagado.

---

## 5. Segmentación Futura (Fase 9: Rinde Más Pro)

Para usuarios comerciales, contadores o personas que requieran declaraciones ante el SENIAT:
- Incorporar en la pestaña **Más** un selector de modo contable:
  - *Modo Anaquel (Predeterminado):* Precios finales con IVA integrado.
  - *Modo Fiscal / Contable (Pro):* Precios desglosados a base imponible con resumen tributario explícito.
- Exportación contable en Excel y PDF con columnas separadas para Base Exenta, Base Imponible 16% y Débito Fiscal IVA.
