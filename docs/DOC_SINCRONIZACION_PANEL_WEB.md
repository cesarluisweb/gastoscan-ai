# Documentación Técnica: Sincronización del Registro y Edición de Gastos en Panel Web

> **Estado:** Implementada 🔧 (Pendiente de validación 🧪 tras CI y despliegue a producción).  
> **Referencia:** Fase 5 de [`DOC_MODERNIZACION_PANEL_WEB.md`](../DOC_MODERNIZACION_PANEL_WEB.md).  
> **Archivos clave:**  
> - [`landing/src/pages/panel.astro`](../landing/src/pages/panel.astro)  
> - [`landing/src/lib/expense-money.js`](../landing/src/lib/expense-money.js)  
> - [`landing/src/lib/category-classifier.js`](../landing/src/lib/category-classifier.js)  
> - [`landing/test/expense-money.test.js`](../landing/test/expense-money.test.js)  
> - [`landing/test/category-classifier.test.js`](../landing/test/category-classifier.test.js)  

---

## 1. Contexto y Objetivos

El registro y edición de facturas en el panel web de Rinde Más presentaba divergencias visuales y matemáticas respecto a la aplicación móvil (`lib/ui/screens/review_expense_screen.dart`):
1. **Divergencia en flujo y orden:** La selección de moneda estaba ubicada al final dentro de "Monto total", en lugar de figurar en la tarjeta inicial de "Información General".
2. **Métodos de pago en divisas:** El panel permitía liquidar euros a tasa P2P, lo cual es inexistente y ajeno a la economía venezolana.
3. **Cálculo bidireccional:** Ajustar los bolívares en el punto de venta solo modificaba una etiqueta de texto pero no recalculaba la tasa efectiva ni la guardaba en el documento de Firestore.
4. **Protección de total dictado:** La interfaz web sobreescribía automáticamente el total general en cada pulsación de tecla (`recalculateGrandTotal`), violando la regla de `dinero-datos.md` §2.
5. **Autoclasificación inteligente:** La web carecía del motor determinista de categorización en vivo según la descripción del producto (`CategoryClassifierService`).
6. **Tasas históricas:** Fechas pasadas podían adoptar la tasa del día actual por fallos de fallback o desbordamientos en la fecha (ej. 31 de febrero).

---

## 2. Arquitectura de Módulos Puros (Node.js)

Para blindar la paridad matemática y evitar que el panel web y la app móvil vuelvan a divergir, se desacopló la lógica de cálculo y clasificación en dos librerías puras en `landing/src/lib/`:

### A. `landing/src/lib/expense-money.js`
- **`computeExpenseTotals({ moneda, monto, metodoLiquidacion, tasaUsd, tasaEur, tasaUsdt, tasaCobrada, bolivaresManuales })`:**
  - Aplica las reglas canónicas de conversión y cálculo de totales en centavos para Firestore (`total_original`, `total_usd`, `total_eur`, `total_usdt`).
  - Sincroniza la tasa efectiva cobrada en caja (`tasa_cambio`) en pagos indexados.
  - Guarda de forma consistente `fuente_tasa_cambio` respetando los contratos de lectura de la app móvil.
- **`computeItemCents(item, ratioConversion)`:**
  - Preserva centavos enteros originales (`origBsTotal`, `origBsPrecio`) cuando un ítem no ha sufrido modificaciones de cantidad ni precio al editar un gasto.
  - Recalcula exactamente con `Math.round(cant * precio * ratio * 100)` cuando el usuario edita valores.

### B. `landing/src/lib/category-classifier.js`
- Port 100% fiel de `CategoryClassifierService` en Dart.
- Normalización estricta de diacríticos y caracteres especiales.
- Evaluación prioritaria de frases compuestas con límites de palabra (`\b`).
- Desambiguación de términos ambiguos aislados (`aceite`, `gas`, `bateria`, `agua`).
- Catálogo oficial de las 10 categorías canónicas.
- Sincronización automática de renglones de `Impuesto IVA` con la categoría predominante del gasto (`sincronizarCategoriaImpuestos`).

---

## 3. Matriz de Casos Dorados de Paridad al Céntimo

Tasas de referencia fijas en la suite de pruebas: **USD BCV: 36,50 | EUR BCV: 39,80 | USDT P2P: 42,10**.

| Caso | Entrada Nominal | Tasa USD BCV Ref. | total_original | total_usd | total_eur | total_usdt | tasa_cambio | tasa_eur | fuente_tasa_cambio |
|---|---|---|---|---|---|---|---|---|---|
| **C1** | VES Bs. 1.234,56 @ 36,50 | 36,50 | 123.456 | 3.382 ($33,82) | 3.102 (€31,02) | 2.932 (29,32 USDT) | 36,50 | 39,80 | `BCV` |
| **C2** | USD $20, Bs. 740 @ efectiva 37,00 | 36,50 | 74.000 | 2.000 ($20,00) | 1.859 (€18,59) | 1.758 (17,58 USDT) | **37,00** | 39,80 | `BCV (Pago en Bs. indexado a USD)` |
| **C3** | USD $15, Bs. 631,50 @ P2P 42,10 | 36,50 | 63.150 | **1.730 ($17,30)** | 1.587 (€15,87) | 1.500 (15,00 USDT) | 36,50 | 39,80 | `Binance P2P (Pago en Bs. indexado a USDT)` |
| **C4** | EUR €10, Bs. 398 @ EUR 39,80 | 36,50 | 39.800 | 1.090 ($10,90) | 1.000 (€10,00) | 945 (9,45 USDT) | **39,80** | 39,80 | `BCV (Pago en Bs. indexado a EUR)` |
| **C5** | EUR €25 divisa directa | 36,50 | 2.500 | 2.726 ($27,26) | 2.500 (€25,00) | 2.726 (27,26 USDT) | 36,50 | **39,80** | `Euro BCV (Bs. 39.80)` |
| **C6** | USD / EUR / VES Reapertura sin cambios | N/A | Sin desvío | Sin desvío | Sin desvío | Sin desvío | Intacta | Intacta | Centavos de ítems preservados bit a bit |

> **Nota sobre C3:** `total_usd` es $17,30 (1.730 céntimos) porque tanto la app móvil como el web dividen los Bolívares pagados (Bs. 631,50) entre la tasa oficial USD BCV (36,50) para reportes financieros agregados. `total_usdt` refleja fielmente los 1.500 céntimos ($15,00 USDT).

---

## 4. Estructura y Comportamiento de las 4 Tarjetas en UI

1. **Tarjeta 1: Información General:**
   - `¿Dónde gastaste? (opcional)`: Campo de texto para el comercio o lugar (`placeholder="Ej. Farmatodo, Panadería..."`, helper text para compras informales).
   - `¿Cuándo gastaste?`: Input con límites `min="2023-01-03"` y `max="hoy"`, prevención de fechas inválidas de fin de mes, y badge reactivo con la fecha de la tasa oficial histórica consultada.
   - `¿En qué moneda están los precios?`: Selector de 4 cápsulas en **orden canónico estricto (`USD → VES → USDT → EUR`)**.
2. **Tarjeta 2: ¿En qué gastaste? (Desglose de Ítems):**
   - Título dinámico: `¿En qué gastaste?` ($\le 1$ ítem) o `¿En qué gastaste? (X artículos)` ($> 1$ ítem).
   - Filas de productos con proporciones 35% (`Cant.`) y 65% (`Precio` con prefijo de moneda).
   - Autoclasificación en tiempo real mientras el usuario escribe en `Concepto`.
   - Total calculado de solo lectura por fila.
3. **Tarjeta 3: Monto total:**
   - Input principal con prefijo de moneda e `inputmode="decimal"`.
   - **Banner de discrepancia en vivo:** Advertencia ámbar no bloqueante dentro del formulario si `|suma_artículos - total_general| > 0.05`.
   - **VES:** 3 cápsulas simultáneas (`USD BCV`, `EUR BCV`, `USDT P2P`), chip de estado (`Tasas del DD/MM/AAAA` o `Tasa personalizada activa`) y toggle de ajuste progresivo de tasas con botón de restaurar a oficial.
   - **USDT:** Cintillo verde confirmatorio de paridad 1:1.
4. **Tarjeta 4: ¿Cómo pagaste? (Solo para USD y EUR):**
   - Opciones según divisa: para USD (`En divisa`, `En Bs. a tasa BCV`, `En Bs. a tasa P2P`); para EUR (`En divisa`, `En Bs. a tasa BCV`). Opción P2P totalmente excluida para EUR.
   - En pagos en Bs.: cálculo bidireccional entre la tasa cobrada y los Bolívares finales de tarjeta/punto de venta.
5. **Diálogo de Decisión al Guardar (Accesible, role="dialog"):**
   - Reemplaza de forma definitiva las ventanas `confirm()` nativas del navegador.
   - Opciones: *Ajustar total a la suma de artículos* (resetea ajustes de Bs y recalcula antes de guardar), *Guardar manteniendo el total* (conserva el valor del usuario) o *Seguir editando*.

---

## 5. Verificación y Pruebas Automatizadas

Se ejecutan localmente con Node.js nativo (sin dependencias adicionales):
```bash
node --test landing/test/category-classifier.test.js landing/test/expense-money.test.js
```
Resultado: **11/11 pruebas en verde (0 fallos)**.

Compilación de frontend en Astro:
```bash
npm --prefix landing run build
```
Resultado: **5 páginas estáticas generadas sin errores**.

---

## 7. Corrección de Apilamiento (Z-Index)

En pruebas de interfaz, el diálogo de decisión por discrepancia (`#modal-discrepancy-decision`) aparecía por debajo del modal principal `#modal-expense` (`z-50`) debido a que Tailwind no define la clase `z-60` por defecto sin configuración previa.

- Se actualizó a clase arbitraria `z-[100]` y se añadió el atributo en línea `style="z-index: 100;"` como salvaguarda en [panel.astro](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro).
- Con esto, el diálogo y su fondo oscuro (`bg-slate-900/60 backdrop-blur-sm`) se superponen inequívocamente al modal de registro de gasto.
