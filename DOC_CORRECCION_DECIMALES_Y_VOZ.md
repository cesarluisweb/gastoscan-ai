# Documentación Técnica: Consenso de Decimales en OCR y Blindajes de Dictado por Voz

**Fecha:** 23 de octubre de 2026  
**Estado:** Implementada 🔧 (Pendiente de validación 🧪 en CI/CD y dispositivo físico por César)  
**ID de Tarea:** `AI-08` / `FIN-16`  
**Archivos modificados:**
- `lib/data/models/gemini_extraction_result.dart`
- `lib/services/semantic_validator.dart`
- `lib/services/local_ocr_service.dart`
- `lib/data/datasources/remote/gemini_service.dart`
- `cloudflare_worker/src/index.js`
- `workers/src/index.js`
- `.agents/rules/ia-ocr-voz.md`
- `test/models/gemini_extraction_result_test.dart`
- `test/services/semantic_validator_test.dart`
- `test/services/local_ocr_service_test.dart`
- `test/widgets/voice_expense_sheet_test.dart`

---

## 1. Causa Raíz del Problema

El usuario reportó que, al escanear una factura física, la mayoría de los productos se leyeron correctamente con decimales, pero un ítem perdió su separador decimal (se extrajo como `1156` en vez de `11,56`), inflando drásticamente el monto.

La investigación técnica identificó 3 factores concurrentes:

1. **Límite de la regla individual previa:** En `GeminiExtractionResult.fromJson`, la condición previa (`it.totalDisplay > totalOriginal * 1.05`) solo corregía un producto si su valor superaba el total general de toda la factura. Si la factura sumaba por ejemplo `1.800,00 Bs`, el ítem de `1156` no la superaba y quedaba sin corregir.
2. **Sobre-escritura del Total por la IA en el Worker:** En `cloudflare_worker/src/index.js`, el prompt instruía *"La suma de los precios de los items debe coincidir con total_original"*. Ante un ítem leído como `1156`, la IA sumaba `1156` al `total_original`, inflando ambos valores e impidiendo detectar la diferencia.
3. **Comas partidas en OCR térmico y expresiones coloquiales en voz:** Impresoras térmicas con cabezales desgastados generan espacios antes o después de la coma (`11 . 56`, `11 , 56`), y en dictado por voz los usuarios suelen decir *"11 con 56"* o *"3 harinas en 4 dólares"*, lo que requería pre-procesamiento defensivo.

---

## 2. Solución Implementada

### 2.1 Doble Escudo en `GeminiExtractionResult.fromJson`
1. **Calce por Residuo (Residual Match):** Si la suma de los ítems supera al `total_original` impreso, se comprueba si al dividir un ítem de $\ge 3$ cifras entre 100 la suma cuadraría con el total impreso. Al coincidir matemáticamente, se divide automáticamente entre 100.
2. **Consenso de Decimales y Detección de Outliers de Escala (Propuesta de César blindada):** Si la mayoría de los ítems en una factura poseen decimales explícitos (ej. `.25`, `.50`) y un ítem aparece sin decimales (entero) con una magnitud desproporcionada ($\ge 10\times$ la mediana de los ítems con decimales, no terminando en `00` o con ratio $> 20\times$), se normaliza a `11.56`. Si el `total_original` había sido inflado por la IA con esa misma suma errónea, se reajusta también el `total_original`.
3. **Preservación de Precios Enteros Legítimos:** Se probó que precios enteros reales (ej. un ítem de `$10.00` en USD o `1.200.00 Bs` en Venezuela) no se alteran al estar dentro del rango normal de compra.

### 2.2 Blindaje en `SemanticValidator` (Eliminación de Doble Suma de IVA)
Se corrigió la validación semántica para no sumar `factura.impuestoIva` cuando la lista `items` ya contiene el renglón `'Impuesto IVA'`, evitando que facturas fiscales válidas con 16% de IVA fueran catalogadas falsamente como descuadradas.

### 2.3 Sanitización en `LocalOcrService`
Se añadió `LocalOcrService.sanitizeOcrLine` para unir automáticamente comas y puntos partidos por cabezales térmicos (`11 . 56` o `11 , 56` $\to$ `11.56`).

### 2.4 Blindaje de Dictado por Voz en `GeminiService`
1. **Normalización Coloquial Venezolana:** `GeminiService.normalizeVoiceText` transforma expresiones orales:
   - `"11 con 56"` $\to$ `"11.56"`
   - `"12 y medio"` $\to$ `"12.50"`
   - `"3 coma 20"` $\to$ `"3.20"`
2. **Subtotal vs. Precio Unitario:** En frases como *"3 harinas en 4 dólares"*, si el producto de `cantidad * precio_unitario` supera el total dictado pero el precio unitario coincide con el total, se recalcula `precio_unitario = total / cantidad` (`1.33` c/u) para no triplicar el gasto.
3. **Suma Automática sin Total Explícito:** Si se dictan múltiples productos y no se menciona el total final, se calcula como la suma exacta en centavos de los productos dictados.

### 2.5 Refuerzo de Prompts en Cloudflare Worker
Se actualizaron `cloudflare_worker/src/index.js` y `workers/src/index.js`:
- El `total_original` debe leerse con fidelidad del TOTAL impreso al pie del papel, no inventarse sumando ítems a ciegas.
- Si un ítem omitió la coma elevando la suma sobre el total impreso, la IA debe reubicar el punto decimal (`11.56`).

---

## 3. Cobertura de Pruebas Unitarias

Se agregaron pruebas exhaustivas que validan la solución:
- `test/models/gemini_extraction_result_test.dart`:
  - `Caso H (Residual Match)`: Ítem `1156` con total impreso `36.56`.
  - `Caso I (Consenso de Decimales y Outlier)`: Ítem `1156` con `total_original` inflado a `1181.00`.
  - `Caso J (Preservar precio entero legítimo)`: Ítem de `$10.00` no se modifica.
  - `Caso K (Bolívares)`: Ítem de `1.200.00 Bs` no se modifica.
- `test/services/semantic_validator_test.dart`:
  - Validación de no duplicidad de IVA cuando `items` ya tiene el renglón fiscal.
- `test/services/local_ocr_service_test.dart`:
  - Sanitización de `11 . 56` $\to$ `11.56`.
- `test/widgets/voice_expense_sheet_test.dart`:
  - Normalización de `"11 con 56"`, `"12 y medio"` y `"2 coma 25"`.

---

## 4. Guía de Pruebas en Dispositivo Físico (Paso a Paso)

Una vez compilado el APK tras CI en verde:

### Prueba 1: Escaneo de Factura con Producto Desfasado
1. Abre la app $\to$ **"+"** $\to$ **Escanear factura**.
2. Toma foto a un ticket o factura de supermercado/farmacia.
3. Al abrir la pantalla de revisión, comprueba que:
   - Ningún producto muestre un monto de 4 cifras enteras (tipo `1156`) si en el papel costaba `11,56`.
   - El total general de la factura coincida con el total impreso en el papel.

### Prueba 2: Dictado por Voz con Expresiones Coloquiales
1. Abre la app $\to$ **"+"** $\to$ **Dictar gasto**.
2. Di claramente: *"Compré jamón por 5 con 50 y queso por 6 y medio en el automercado"*.
3. Presiona **Procesar Gasto**.
4. **Verificación:** Los productos deben cargarse como `$ 5,50` y `$ 6,50`, con un total de `$ 12,00`.

### Prueba 3: Dictado por Voz con Cantidades Múltiples
1. Abre el micrófono y di: *"Compré 3 harinas en 4 dólares"*.
2. Presiona **Procesar Gasto**.
3. **Verificación:** Debe registrar 3 harinas a `$ 1,33` c/u con un total de `$ 4,00` (y no `$ 12,00`).
