# Especificación Técnica: Precios de Anaquel e Imputación de IVA en Compras (AI-06)

> **Estado:** Implementada 🔧 (pendiente CI verde y validación en dispositivo físico por César).
> **Tarea:** `AI-06` · Fase 6.2, Bloque C en `ROADMAP.md`.

Este documento define la regla de negocio vigente, el algoritmo determinista de reparto de IVA por Mayor Resto, el tratamiento del comparador de precios (móvil + panel web) y la guía de pruebas en dispositivo para **Rinde Más**.

---

## 1. Contexto y Problema

En Venezuela conviven dos representaciones del precio:

1. **En el anaquel (hablador del comercio):**
   El precio exhibido al consumidor siempre incluye el IVA. Si el hablador indica `Bs. 300,00`, el usuario desembolsa exactamente `Bs. 300,00`. Al registrar gastos manualmente o por voz, el usuario siempre ingresa el precio final con IVA incluido.
2. **En la máquina fiscal (ticket SENIAT):**
   Las impresoras fiscales imprimen los productos gravados a **base imponible** (sin impuesto), marcados con `(G)` (16%), `(R)` (8%) o `(E)` (exento 0%), y liquidan el IVA acumulado al pie:
   $$\text{Base} = \frac{300,00}{1,16} \approx 258,62 \qquad \text{IVA 16\%} = 41,38 \implies \text{Total} = 300,00$$

### Problemas que resuelve `AI-06`
- **Distorsión de categorías en compras mixtas:** Bajo la Opción A (renglón `'Impuesto IVA'` en la categoría dominante), el IVA de un artículo de *Higiene* dentro de una compra mayormente de *Alimentación* exenta inflaba *Alimentación*.
- **Falsas variaciones en el comparador de precios e IA:** Comparar compras manuales/voz (`Bs. 300,00`) contra facturas escaneadas a base imponible (`Bs. 258,62`) generaba falsas caídas/subidas del 14%–16%.
- **Choque cognitivo en el historial:** El usuario recuerda el precio real que pagó por cada artículo, no su base fiscal.

---

## 2. Regla de Negocio Vigente (Opción B — Precios de Anaquel con Fallback Conservador)

1. **Un solo precio persistido en SQLite (`items_gasto`) y Firestore (`items`):**
   - No se agregan columnas nuevas al esquema SQLite (`v19` intacto) ni a Firestore.
   - `precio_unitario` y `total` persistidos representan el **precio final con IVA incluido** (lo realmente pagado).
   - `baseImponibleOriginal` (en centavos) y `tasaIvaPct` (`16`, `8` o `0`) existen únicamente en memoria de `ItemGastoModel` y en el JSON temporal de `scan_queue` (`schema_v: 2`). Al guardar el gasto definitivo, esos metadatos temporales no se persisten en `items_gasto`.
   - **Compromiso consciente (v1):** En gastos nuevos con `IvaModo.imputado`, la base imponible no queda guardada en BD tras pulsar Guardar (el modo contable/fiscal queda reservado para Fase 9 — Rinde Más Pro).
2. **Registro manual y por voz sin fricción fiscal:**
   - El usuario nunca debe seleccionar `(G)` o `(E)` al registrar gastos manuales o por voz; ingresa directamente el importe final desembolsado.
3. **Pipeline determinista de extracción (`GeminiExtractionResult.fromJson`):**
   - **Paso 0 (Clasificación estricta de líneas):** Reutiliza `ItemGastoModel.isTaxDescription` / `isIvaOnlyDescription` / `isIgtfDescription` / `isSummaryLineDescription` / `isDiscountDescription` / `isServiceOrTipDescription` (cero `.contains('iva')` que rompía *"Aceite de oliva"* o *"Leche Nativa"*). Descarta subtotales/resúmenes, detecta signos negativos antes del clamp y consolida renglones explícitos de IVA con el campo `impuesto_iva` sin duplicar.
   - **Paso 1 (Reconciliación de decimales omitidos):** Evalúa la función pura `_reconcileDecimals` contra los candidatos `[totalOriginal - impuestoIva, totalOriginal]` para evitar dependencia circular entre decimales e IVA.
   - **Paso 2 (Guardia absoluta y `IvaModo`):**
     - `IvaModo.yaIncluido`: si `|sum(items) - totalOriginal| <= tol` y sumar `impuestoIva` rompe el calce, se asume que las líneas ya traen IVA incluido; limpia sufijos y no genera `baseImponibleOriginal`.
     - `IvaModo.imputado`: si `|sum(items) + impuestoIva - totalOriginal| <= tol`, no hay líneas especiales (`descuento`, `servicio`, `igtf`), y el chequeo fiscal estricto de tasa ponderada (`16%` / `8%`, probando `null` como exento vs gravado sin ambigüedad) cuadra dentro de `ceil(numGravados / 2) + 1` centavos, se imputa el IVA por **Mayor Resto**.
     - `IvaModo.renglonSeparado` (**Fallback conservador a Opción A**): si hay servicio/propina, descuentos, IGTF, alícuotas no reconciliables o ambigüedad, conserva precios base y sufijos `(G)`/`(E)` y añade un único renglón `'Impuesto IVA'` en la categoría dominante (`ItemGastoModel.calcularCategoriaDominante`).
     - `IvaModo.requiereRevision`: si el LLM devolvió múltiples líneas de IVA o un renglón de IVA cuyo monto discrepa de la cabecera `impuesto_iva`.
     - `IvaModo.sinIvaDeclarado` vs `IvaModo.noInformado`: diferencia `impuesto_iva: 0` explícito de ausencia de campo.
4. **Idempotencia de `scan_queue` (`schema_v: 2`):**
   - Los 6 lectores de `scan_queue` invocan `GeminiExtractionResult.fromQueueJson(...)` / `fromQueueMap(...)`, que restauran los centavos exactos (`precio_unitario_cents`, `total_cents`, `base_imponible_original_cents`, `tasa_iva_pct`) y `iva_modo` **sin** volver a ejecutar heurísticas ni re-imputar registros legados (`schema_v < 2`).

---

## 3. Algoritmo Determinista de Reparto por Mayor Resto (`repartirIvaMayorResto`)

En lugar de redondear `base * 1.16` ítem por ítem y empujar el residual arbitrariamente a un solo producto (lo que rompía `cantidad * precioUnitario` cuando `cantidad > 1`), los centavos exactos del `impuesto_iva` documental (`ivaCents`) se reparten proporcionalmente entre los totales base de las líneas gravadas mediante el método de **Mayor Resto (Hamilton)**:

1. Peso de cada línea $i$: $w_i = \text{baseTotal}_i \times \text{tasaPct}_i$ (donde `tasaPct` es `16` para `G`, `8` para `R`, `0` para `E`).
2. Cuota entera inicial: $\text{share}_i = \lfloor (\text{ivaCents} \times w_i) / \sum w \rfloor$, con resto $r_i = (\text{ivaCents} \times w_i) \bmod \sum w$.
3. Los $\text{ivaCents} - \sum \text{share}_i$ centavos remanentes se asignan de a `+1` a las líneas con mayor resto $r_i$ (desempate determinista por mayor peso y menor índice).
4. **Resultados por línea:**
   - `total_i = baseTotal_i + share_i` (verdad contable: $\sum \text{total}_i = \text{totalOriginal}$ exacto).
   - `precioUnitario_i = (baseUnitario_i * (100 + tasaPct_i) + 50) ~/ 100` (precio unitario de referencia, nunca alterado artificialmente con el residual).
   - Sufijos `(G)`, `(E)`, `(R)` removidos del nombre (`ItemGastoModel.stripFiscalSuffix`).

---

## 4. Experiencia de Usuario en `ReviewExpenseScreen`

- **Campo de precio:** Cuando el artículo tiene `baseImponibleOriginal != null`, la etiqueta cambia a **`Precio (con IVA)`** para evitar que el usuario sobrescriba el precio de anaquel con la base impresa del ticket.
- **Nota al pie de la tarjeta (`ValueKey('item_tax_base_${item.clientKey}')`):** Debajo de la fila Categoría/Total y encima de `_PriceComparisonLine`, muestra en `#4B5563` (`11 sp`, hasta 2 líneas):
  `Base impresa: Bs. 258.62 (+16% IVA)` (o `+8% IVA` para alícuota reducida).
- **Edición de Cantidad:** Recalcula el total desde la base imponible original (`round(cant * baseCents * (100 + tasaPct) / 100)`) y conserva visible la nota para no perder centavos por redondeo.
- **Edición manual de Precio:** Invoca `copyWith(..., clearBaseImponibleOriginal: true)` y oculta la nota de base en ese artículo. *(Nota: si el usuario elimina el ítem tras editar el precio y pulsa «Deshacer», se restaura sin base, pues ya era un precio manual).*

---

## 5. Comparador de Precios Simétrico (Móvil + Panel Web)

Para evitar falsos saltos de `+16%` o `-14%` al comparar gastos nuevos (con IVA imputado y nombres limpios) contra facturas históricas o fallbacks `renglonSeparado` (que conservan `(G)`/`(R)` y fila `'Impuesto IVA'`):

- **Móvil (`DatabaseHelper.findPriceHistory` + `shelfPriceTaxFactor` + `shelfPriceFactorForCurrentItems`)** y **Web (`landing/src/lib/price-comparator.js` + `panel.astro`):**
  1. `normalizeProductText` ya elimina `(G)`/`(E)`/`(R)` para que productos viejos y nuevos compartan `descripcion_norm`.
  2. Si un ítem (histórico o actual en revisión) conserva el sufijo `(G)` o `(R)` **y** ese mismo gasto posee un renglón de IVA cuyo total cuadra al centavo con el `16%` o el `8%` de las bases gravadas del gasto (`|taxCents - expected| <= ceil(nTaxed/2) + 1`), su precio unitario USD se normaliza al vuelo a precio de anaquel (`× 1.16` o `× 1.08`).
  3. Si el ítem es exento `(E)` o no tiene sufijo, el factor es `1.0`.
  4. Si el gasto tiene `(G)` sin renglón de IVA (p. ej. el usuario lo borró), el factor es `1.0` (no inventa 16%).
  5. Si el gasto tiene `(G)` y renglón de IVA pero la proporción es ambigua (no cuadra con 16% ni 8%), la muestra histórica se omite del comparador.

---

## 6. Puntos de Inspección en Código

| Componente | Archivo y líneas clave |
|---|---|
| Modelo y clasificadores | `lib/data/models/item_gasto_model.dart` (`baseImponibleOriginal`, `tasaIvaPct`, `clearBaseImponibleOriginal`, `isTaxDescription`, `isIvaOnlyDescription`, `stripFiscalSuffix`) |
| Pipeline fiscal y Mayor Resto | `lib/data/models/gemini_extraction_result.dart` (`IvaModo`, `repartirIvaMayorResto`, `_reconcileDecimals`, `fromJson`, `fromQueueMap`, `fromQueueJson`) |
| Validador semántico | `lib/services/semantic_validator.dart` (contabilización única según `IvaModo`) |
| Comparador SQLite | `lib/data/datasources/local/database_helper.dart` (`shelfPriceTaxFactor`, `shelfPriceFactorForCurrentItems`, subconsultas en `findPriceHistory`) |
| Revisión UI | `lib/ui/screens/review_expense_screen.dart` (`Precio (con IVA)`, `item_tax_base_${item.clientKey}`, recálculo por cantidad/precio y comparación simétrica) |
| Lectores `scan_queue` (6) | `global_scan_queue_banner.dart`, `main_screen.dart`, `dashboard_screen.dart`, `expense_history_screen.dart`, `review_expense_screen.dart` (2) |
| Panel Web (paridad) | `landing/src/lib/price-comparator.js`, `landing/src/pages/panel.astro` |
| Worker IA (alícuota `'R'`) | `workers/src/index.js` (`RECEIPT_RESPONSE_SCHEMA` y prompt; requiere `wrangler deploy` aparte) |

---

## 7. Guía de Pruebas en Dispositivo Físico

> **Commit / Build:** Actualizar tras CI en verde del commit de AI-06.

**Ruta alcanzable:** `Inicio` → botón central `+` (`MainScreen`) → `Tomar foto de factura` / galería (`ScanScreen`) → banner `Factura lista para revisar` (`GlobalScanQueueBanner`) → `ReviewExpenseScreen`.

| Caso | Pasos | Resultado esperado |
|---|---|---|
| **CP-01** | Escanear una factura fiscal venezolana mixta (ej. Harina `(E)` + Detergente `(G)` + `IVA 16%`). | En `ReviewExpenseScreen` no aparece renglón `Impuesto IVA`; los nombres no llevan `(E)`/`(G)`; Detergente muestra precio con IVA incluido, etiqueta `Precio (con IVA)` y al pie `Base impresa: Bs. X.XX (+16% IVA)`. Harina queda intacta sin nota. La suma cuadra al centavo con `Monto total`. |
| **CP-02** | En un artículo con nota `Base impresa`, cambiar `Cant.` de `1` a `3`. | El `Total` se recalcula desde la base imponible original × 1,16 y la nota `Base impresa` permanece visible. |
| **CP-03** | Editar manualmente el campo `Precio (con IVA)` de ese artículo. | La nota `Base impresa` desaparece de inmediato y la etiqueta vuelve a `Precio`. |
| **CP-04** | Guardar la compra y revisarla en `Inicio`, `Gastos`, `Análisis` y `Editar gasto`. | Cada artículo muestra un único precio final (con IVA). En compras mixtas, el IVA de *Higiene* se refleja en *Higiene* y no en *Alimentación*. |
| **CP-05** | Escanear un producto que ya tenías guardado en los últimos 60 días bajo factura vieja con `(G)` + `Impuesto IVA`. | El comparador (`_PriceComparisonLine`) compara precio con IVA vs precio con IVA equivalente, sin reportar un falso `+16%`. |
| **CP-06** | Abrir un gasto manual (`+` → `Escribir gasto`) o dictado por voz. | No aparece ningún selector `(G)/(E)` ni nota de base impresa; flujo limpio y rápido. |
| **CP-07** | Escanear una factura de restaurante con `Servicio 10%` + `IVA 16%`. | No reparte el IVA sobre el servicio; conserva fallback seguro con renglón separado `'Impuesto IVA'`. |

---

## 8. Segmentación Futura (Fase 9: Rinde Más Pro)
- Selector de modo contable (*Modo Anaquel* vs *Modo Fiscal/Contable Pro*) y exportación contable con columnas separadas de Base Exenta, Base Imponible 16% y Débito Fiscal IVA.
