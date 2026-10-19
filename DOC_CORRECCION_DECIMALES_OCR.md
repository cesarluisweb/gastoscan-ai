# Documentación Técnica: Corrección de Escala de Decimales en OCR y Registro de Gastos

**Fecha:** 19 de octubre de 2026  
**Estado:** Pendiente de validación 🧪 (Build 521 aprobado en CI/CD con 316 tests en verde)  
**ID de Tarea:** `AI-07` / `FIN-13`  
**Archivos modificados:**
- `lib/data/models/gemini_extraction_result.dart`
- `lib/core/utils/amount_parser.dart`
- `lib/ui/screens/review_expense_screen.dart`
- `cloudflare_worker/src/index.js`
- `workers/src/index.js`
- `test/models/gemini_extraction_result_test.dart`
- `test/core/utils/amount_parser_test.dart`

---

## 1. Causa Raíz del Problema

El usuario reportó la reaparición del fallo donde los decimales no se colocaban correctamente al registrar o escanear un gasto (por ejemplo, \$56,12 se inflaba a \$5.612,00 o montos con separadores de miles se truncaban).

Tras la inspección del pipeline de extracción y parseo, se identificaron 4 causas raíz concurrentes:

### 1.1 Inversión de Ramas de Validación Cruzada en `GeminiExtractionResult.fromJson`
En la lógica introducida para reconciliar tickets donde el OCR omite el punto decimal:
- `ratioSumToTotal = sumItems / totalOriginal;`
- `ratioTotalToSum = totalOriginal / sumItems;`

**El error:**
1. Si los productos sumaban `56.12` y el total extraído venía como `5612` (sin punto decimal), `ratioTotalToSum` era `100.0`. El código entraba erróneamente en:
   ```dart
   else if (ratioTotalToSum >= 90.0 && ratioTotalToSum <= 110.0) {
     // Multiplicaba CADA ítem por 100 en lugar de dividir el total entre 100!
     correctedItems.add(old.copyWith(precioUnitario: old.precioUnitario * 100.0));
   }
   ```
   Esto provocaba que una compra de \$56,12 pasara a inflar los productos a \$5.612,00 y mantuviera el total en \$5.612,00.
2. A la inversa: si los ítems sumaban `5612` (sin punto) y el total era `56.12` con punto, `ratioSumToTotal` era `100.0`. El código dividía el total entre 100 (`0.5612`) y dejaba los ítems en `5612.00`.

### 1.2 Falta de Detección en Ítems Individuales sin Decimal
Si en una factura de 5 ítems solo uno perdía el punto decimal (ej. un producto de \$12,00 extraído como \$1200), la suma global no se desviaba exactamente por un factor de 100 $\times$, por lo que la validación general de ratios no se activaba y el ítem quedaba con \$1.200,00 desvirtuando el cálculo.

### 1.3 Parser Numérico Vulnerable a Múltiples Puntos de Miles (`amount_parser.dart`)
En tickets de alto valor en bolívares (ej. `1.250.000,00` o `1.250.000`), el parser esperaba como máximo un separador de miles. La presencia de múltiples puntos o comas consecutivas podía provocar que el parseo fallara o devolviera un valor nulo/truncado.

### 1.4 Residuos de Coma Flotante IEEE 754 en `_recalcularTotal` (`review_expense_screen.dart`)
Al sumar productos directamente con `double` (`total += it.precioUnitario * it.cantidad`), acumulaciones como `19.99 + 0.01` generaban residuos binarios (`19.999999999999996`) que al formatearse o convertirse producían discrepancias visuales de centavos.

---

## 2. Solución Implementada

### 2.1 Reconciliación Matemática Estricta (`GeminiExtractionResult.fromJson`)
1. **Inversión Corregida:**
   - Si `ratioTotalToSum ~= 100` (el total es 100 veces la suma de los ítems): se divide `totalOriginal` entre 100.0 (`totalOriginal = totalOriginal / 100.0`).
   - Si `ratioSumToTotal ~= 100` (la suma de los ítems es 100 veces el total): se divide el precio unitario de cada ítem entre 100.0 (`old.precioUnitario / 100.0`).
2. **Defensa para Ítems Individuales Descalzados:**
   - Para cada producto, si `it.totalDisplay > totalOriginal * 1.05` pero `(it.totalDisplay / 100.0) <= totalOriginal * 1.05`, se normaliza dividiendo su precio unitario entre 100.0.

### 2.2 Soporte de Miles Repetidos en `tryParseAmount`
Se actualizó la expresión regular y la lógica de normalización para admitir múltiples puntos o comas de miles sin alterar el separador decimal final (`1.250.000` $\to$ `1250000.0`).

### 2.3 Suma Exacta en Centavos Enteros (`review_expense_screen.dart`)
`_recalcularTotal` ahora acumula centavos en enteros `int`:
```dart
final precioCents = (it.precioUnitario * 100).round();
totalCents += (precioCents * it.cantidad).round();
// Al finalizar:
nuevoTotal = totalCents / 100.0;
```
Esto erradica al 100% las anomalías por coma flotante IEEE 754.

### 2.4 Refuerzo de Prompts en Cloudflare Worker (`cloudflare_worker/src/index.js` y `workers/src/index.js`)
Se reforzó la Regla 2 del sistema en el Worker para instruir explícitamente a Gemini que todo monto debe expresarse siempre con punto decimal y 2 decimales (`12.50` y nunca `1250`).

### 2.5 Cobertura de Pruebas Unitarias
- `test/models/gemini_extraction_result_test.dart`: 6 pruebas que validan tickets normales, tickets con total $\times 100$, ítems $\times 100$, descalces individuales, y tickets legítimos grandes.
- `test/core/utils/amount_parser_test.dart`: Pruebas de números con miles repetidos, decimales mixtos y entradas parciales.
- **Resultado en CI/CD:** Build 521 aprobado en verde con 316 tests aprobados.

---

## 3. Guía de Pruebas en Dispositivo Físico (Paso a Paso)

Sigue estos pasos en tu teléfono para validar la corrección en condiciones reales:

### Caso 1: Escaneo de Comprobante / Factura Comercial
1. Abre la app y presiona el botón central **"+"** $\to$ **Escanear factura**.
2. Toma una foto a un ticket o factura de compra cotidiana (ej. supermercado o farmacia con varios productos y decimales tipo \$5,12, \$18,40).
3. Espera el procesamiento en segundo plano y toca el comprobante listo en la barra superior.
4. **Verificación:**
   - Comprueba que el total en la cabecera coincide exactamente con la factura y no está inflado 100 veces (ej. \$24,50 en vez de \$2.450,00).
   - Comprueba que los precios unitarios de la lista de productos tienen sus decimales correctos.
   - Modifica la cantidad de algún producto y confirma que el subtotal y el total se recalculan con precisión de centavos sin números raros tipo `.9999`.

### Caso 2: Registro Manual con Decimales
1. Presiona el botón central **"+"** $\to$ **Gasto manual**.
2. Escribe en el campo Monto: `12,50` o `12.50`.
3. Agrega dos productos manualmente: uno de `5,25` y otro de `7,25`.
4. **Verificación:**
   - El total recalculado debe reflejar exactamente `12,50`.
   - Guarda el gasto y confirma que en la lista de Gastos y en la tarjeta de Inicio se muestra `$ 12,50`.

### Caso 3: Registro de Montos en Bolívares con Miles
1. Presiona el botón central **"+"** $\to$ **Gasto manual**.
2. Cambia la moneda a `Bs.` e ingresa un monto con separador de miles: `1.500,00` o `2500.50`.
3. Guarda el gasto.
4. **Verificación:**
   - Confirma que el gasto se registra como `Bs. 1.500,00` y no como `Bs. 1,50`.
