# Especificación Técnica: Precios de Anaquel e Imputación de IVA en Compras (AI-06 · B-2)

> **Estado:** `Pendiente de validación 🧪` (APK build 724, run `44910561506`, SHA `9ff3d87`; Web build 33, run `44859265979`, HTTP 200 en `/panel`; Firestore build 5, run `44859266019`).
> **Tarea:** `AI-06` · Fase 6.2, Bloque C en `ROADMAP.md`.

Este documento define la regla de negocio vigente (**variante B-2**), el motor de reconciliación fiscal, el algoritmo de reparto por Mayor Resto, el comparador de precios (móvil + web) y la guía de pruebas en dispositivo para **Rinde Más**.

---

## 1. Contexto y Problema

En Venezuela conviven dos representaciones del precio:

1. **En el anaquel (hablador del comercio):**
   El precio exhibido siempre incluye IVA. Al registrar gastos manualmente o por voz, el usuario ingresa directamente el importe final desembolsado.
2. **En la máquina fiscal (ticket SENIAT):**
   Las impresoras fiscales imprimen los productos gravados a **base imponible** (sin impuesto), marcados con `(G)` (16%), `(R)` (8%) o `(E)` (exento 0%), y liquidan el IVA acumulado al pie:
   $$\text{Base} = \frac{300,00}{1,16} \approx 258,62 \qquad \text{IVA 16\%} = 41,38 \implies \text{Total} = 300,00$$

### Problemas que resuelve `AI-06` (Variante B-2)
- **Cotejo sin cálculo mental durante la revisión:** En `ReviewExpenseScreen`, los campos editables muestran los precios **sin IVA** exactamente como aparecen en el papel, mientras cada artículo gravado muestra debajo su costo final con IVA distribuido.
- **Presupuesto exacto por categoría:** Al guardar una factura reconciliada, cada artículo se persiste con su precio final con IVA dentro de su propia categoría (sin inflar *Alimentación* ni *Otros* con el IVA de *Higiene*).
- **Comparador de precios consistente:** Compras manuales, por voz y escaneadas se comparan en precio de anaquel (IVA incluido), normalizando al vuelo los registros históricos o en fallback.

---

## 2. Regla de Negocio Vigente (Opción B-2 — Papel en Revisión, Anaquel al Guardar)

1. **Fuente única persistida en SQLite (`items_gasto`) y Firestore (`items`):**
   - Cero columnas nuevas en SQLite (`v19` intacto) y cero cambios de esquema en Firestore. `ItemGastoModel.toMap()` conserva exactamente las 7 columnas originales.
   - En el camino principal (**imputado**), `precio_unitario` y `total` persistidos representan el **precio final con IVA incluido** y los nombres se guardan limpios sin `(G)`/`(E)`/`(R)`.
   - `baseImponibleOriginal`, `baseTotalOriginal`, `tasaIvaPct` y `origenAlicuota` viven únicamente en memoria (y los tres primeros en el JSON temporal de `scan_queue` `schema_v: 2`).
   - **Rol de la categoría dominante:** En modo imputado ya no existe renglón fiscal que categorizar; `ItemGastoModel.calcularCategoriaDominante` define únicamente la categoría representativa del gasto en tarjetas de Inicio/Historial y la categoría del renglón `'Impuesto IVA'` en el **fallback confirmado**.
2. **Excepciones deliberadas (para evitar sorpresas en reportes y asistente):**
   - **Fallback confirmado (`renglonSeparado`):** Si la factura tiene líneas especiales (descuento, servicio 10%/propina, IGTF) o el usuario confirma `Guardar así` ante un descuadre no resuelto, los artículos se guardan en precio base con sufijos `(G)`/`(R)`/`(E)` según la clasificación actual y se añade un renglón `'Impuesto IVA'` en la categoría dominante (calculada excluyendo renglones fiscales). Al reabrir ese gasto se verán bases + renglón fiscal; es el formato que el comparador simétrico sabe normalizar.
   - **Facturas históricas (anteriores a `build 722`):** No se recalculan retroactivamente. Al comparar presupuestos entre meses anteriores y posteriores al cambio puede observarse un pequeño corrimiento entre categorías; el asistente IA ve precios brutos en compras nuevas y continúa excluyendo el renglón fiscal en registros viejos o en fallback.
3. **Registro manual y por voz sin fricción fiscal:**
   - Nunca muestra selectores `(G)`/`(E)` ni pie fiscal en gastos manuales, dictados por voz, facturas con `impuesto_iva == 0`, `IvaModo.yaIncluido` ni al editar un gasto ya guardado.
4. **Pipeline de extracción (`GeminiExtractionResult.fromJson`) e idempotencia (`scan_queue` `schema_v: 2`):**
   - **Paso 0:** Clasificadores estrictos (`isTaxDescription`, `isIvaOnlyDescription`, `isIgtfDescription`, `isSummaryLineDescription`, `isDiscountDescription`, `isServiceOrTipDescription`), sin falsos positivos como *"Aceite de oliva"* ni *"Leche Nativa"*.
   - **Paso 1:** Reconciliación pura de decimales omitidos contra `[totalOriginal - impuestoIva, totalOriginal]`.
   - **Paso 2:** Guardia `IvaModo.yaIncluido`, imputación por **Mayor Resto (`BigInt`)** (`IvaModo.imputado`) y fallback conservador (`IvaModo.renglonSeparado`, preservando `tasaIvaPct` en memoria/cola para recuperación en pantalla).
   - **Paso 3 (`scan_queue`):** Los 6 lectores usan `GeminiExtractionResult.fromQueueJson(...)`, preservando centavos exactos, `base_imponible_original_cents`, `base_total_original_cents` y `tasa_iva_pct` sin re-ejecutar heurísticas.

---

## 3. Algoritmo de Reparto por Mayor Resto (`repartirIvaMayorResto`)

Los centavos exactos del IVA distribuido (`ivaCents`) se reparten proporcionalmente entre los totales base de las líneas gravadas mediante el método de **Mayor Resto (Hamilton)** con aritmética `BigInt` (sin riesgo de overflow en montos altos en bolívares):

1. Peso de cada línea $i$: $w_i = \text{baseTotal}_i \times \text{tasaPct}_i$ (`16` para `G`, `8` para `R`, `0` para `E`).
2. Cuota entera: $\text{share}_i = \lfloor (\text{ivaCents} \times w_i) / \sum w \rfloor$, con resto $r_i = (\text{ivaCents} \times w_i) \bmod \sum w$.
3. Los $\text{ivaCents} - \sum \text{share}_i$ centavos remanentes se asignan `+1` por orden determinista (`resto desc → peso desc → índice asc`).
4. Resultados por línea: `total_i = baseTotal_i + share_i` y `precioUnitario_i = (baseUnitario_i * (100 + tasaPct_i) + 50) ~/ 100`.

---

## 4. Experiencia de Usuario en `ReviewExpenseScreen` (Variante B-2)

1. **Tarjetas de artículos (cotejo directo contra el ticket impreso):**
   - Cada artículo gravado etiqueta sus campos como **`Precio (sin IVA)`** y **`Total sin IVA`**, mostrando exactamente los montos del papel.
   - Debajo de cada artículo gravado (`ValueKey('item_tax_gross_${item.clientKey}')`) se muestra su costo final real: `Con IVA 16%: Bs. 300` (o con detalle unitario solo cuando `cant × unitarioBruto == totalBruto`, sin símbolo `≈` y sin avisos repetidos por fila).
   - **Badges limpios para tickets largos:** Solo los artículos gravados de facturas mixtas muestran el badge tocable **`G · 16%`** / **`R · 8%`** (`ValueKey('item_tax_badge_${item.clientKey}')`). Las filas exentas nunca muestran pastilla y las facturas homogéneas (100% gravadas, p. ej. farmacia) ocultan los badges en tarjetas para evitar ruido visual.
   - Un toque sobre el badge alterna directo **`gravado → Exento`** (nunca cae accidentalmente en `8%`) y registra `OrigenAlicuota.manual`.
2. **Pie fiscal con 3 verificaciones y ancla invalidable (`Key('fiscal_summary_footer')`):**
   - Muestra `Subtotal sin IVA`, `IVA de la factura`, estado en una sola línea, `Total con IVA` y el botón **`Ajustar IVA · N gravados`** (`Key('btn_ajustar_iva_footer')`) que abre la hoja modal (`Exento` | `16%` | `8%` por artículo).
   - **3 verificaciones simultáneas:** Solo muestra **`Cuadra con la factura`** cuando (a) `|IVA calculado − IVA factura| <= fiscalRateToleranceCents(n)`, (b) `|(Subtotal + IVA factura) − Monto total| <= guardToleranceCents`, y (c) la suma bruta cuadra dentro de tolerancia.
   - **Protección de `Monto total`:** En revisión fiscal, editar cantidades, precios o alícuotas recalcula globalmente por Mayor Resto sin sobrescribir `Monto total`. Si el usuario edita `Monto total` manualmente, el ancla fiscal se invalida (`IVA de la factura` pasa a `IVA calculado` y deja de afirmar `Cuadra con la factura`).
3. **Detector de error OCR de candidato único (`Key('fiscal_suggestion_banner')`):**
   - Ante un descuadre de IVA con `Subtotal + IVA == Total`, `FiscalReconciliationHelper.sugerirCorreccionUnica` evalúa cada cambio individual usando la base total de línea y `fiscalRateToleranceCents`.
   - También recupera automáticamente facturas limpias caídas en `IvaModo.renglonSeparado` por un error puntual `(G)/(E)` del OCR.
   - Solo muestra el aviso (`¿"Detergente Líquido" lleva IVA 16% (G)?` + botón `Corregir`) si existe **exactamente un** candidato. Ante empates (dos artículos con igual base) o errores que se compensan, permanece silencioso. Nunca cambia una clasificación sin toque explícito del usuario.
4. **Guardado seguro (nunca imputa en rojo):**
   - Si el estado fiscal no cuadra al pulsar **Guardar Gasto**, aparece el diálogo `El IVA no cuadra con la factura` (`Key('dialog_fiscal_fallback_confirm')`) con **`Corregir`** y **`Guardar así`** (fallback seguro a `renglonSeparado` con sufijos `(G)`/`(R)`/`(E)` + `'Impuesto IVA'` en categoría dominante).
   - Al guardar como borrador (`_guardarComoBorrador`), se conserva `impuestoIva` y las bases para retomar la revisión B-2 intacta desde `scan_queue`.

---

## 5. Comparador de Precios Simétrico (Móvil + Panel Web)

Tanto `DatabaseHelper.findPriceHistory` como `landing/src/lib/price-comparator.js` (y `_PriceComparisonLine` / `panel.astro`) normalizan al vuelo a precio de anaquel (`× 1.16` o `× 1.08`) cualquier ítem histórico o en fallback que conserve `(G)`/`(R)` dentro de un gasto cuyo renglón `'Impuesto IVA'` cuadre con esa tasa, excluyendo muestras ambiguas y sin tocar artículos `(E)`.

---

## 6. Puntos de Inspección en Código

| Componente | Archivo y símbolos clave |
|---|---|
| Modelo y sufijos | `lib/data/models/item_gasto_model.dart` (`baseImponibleOriginal`, `baseTotalOriginal`, `tasaIvaPct`, `OrigenAlicuota`, `withFiscalSuffix`, `toMap` intacto en 7 columnas) |
| Pipeline fiscal y Mayor Resto | `lib/data/models/gemini_extraction_result.dart` (`IvaModo`, `repartirIvaMayorResto`, `fiscalRateToleranceCents`, `guardToleranceCents`, `fromJson`, `fromQueueMap`, `toMap`) |
| Motor puro B-2 y detector | `lib/domain/finance/fiscal_reconciliation_helper.dart` (`prepararSesionFiscal`, `reconciliar`, `buscarCandidatosCorreccion`, `sugerirCorreccionUnica`, `construirItemsFallback`) |
| Revisión UI B-2 | `lib/ui/screens/review_expense_screen.dart` (`_recalcularTotal`: L865, `_confirmarGuardadoFallbackFiscal`: L1125, `_buildFiscalGrossStrip`: L2109, `_buildFiscalSuggestionBanner`: L2180, `_buildFiscalSummaryFooter`: L2294, `_abrirHojaAjustarIva`: L2424) |
| Comparador SQLite y Web | `lib/data/datasources/local/database_helper.dart`, `landing/src/lib/price-comparator.js`, `landing/src/pages/panel.astro` |
| Pruebas unitarias, propiedad y widget | `test/domain/finance/fiscal_reconciliation_helper_test.dart`, `test/models/gemini_extraction_result_test.dart`, `test/screens/review_expense_screen_layout_test.dart` |
| Worker IA (alícuota `'R'`) | `workers/src/index.js` (pendiente `wrangler deploy` aparte) |

---

## 7. Guía de Pruebas en Dispositivo Físico

> **Commit / Build:** SHA `9ff3d87` · APK Build `724` (run `44910561506`) · Web Build `33` (run `44859265979`).
> **Controles reales en código:** `lib/ui/screens/review_expense_screen.dart` (`_recalcularTotal` L865, diálogo fallback L1125, franja `Con IVA` + badge `G · 16%` L2109, banner sugerencia L2180, pie fiscal L2294, hoja `Ajustar IVA` L2424).

**Ruta alcanzable:** `Inicio` → botón central `+` (`MainScreen`) → `Tomar foto de factura` / galería (`ScanScreen`) → banner `Factura lista para revisar` (`GlobalScanQueueBanner`) → `ReviewExpenseScreen`.

| Caso | Pasos | Resultado esperado |
|---|---|---|
| **CP-01** | Escanear una factura mixta de mercado (varios `(E)` + algunos `(G)` + `IVA 16%`). | En `ReviewExpenseScreen`: las filas exentas no muestran pastilla ni franja extra; las gravadas muestran `Precio (sin IVA)`, `Total sin IVA`, badge `G · 16%` y debajo `Con IVA 16%: Bs. X` (sin `≈`). El pie muestra `Subtotal sin IVA`, `IVA de la factura`, `✓ Cuadra con la factura` y `Ajustar IVA · N gravados`. |
| **CP-02** | Escanear una factura homogénea (100% gravada, ej. farmacia). | No aparecen badges `G · 16%` repetidos en las tarjetas, pero sí `Con IVA 16%` debajo de cada producto y `Ajustar IVA · N gravados` al pie. |
| **CP-03** | Tocar el badge `G · 16%` de un artículo gravado. | Pasa directo a Exento (nunca a 8%), `Monto total` no cambia, el pie marca descuadre y aparece el banner `¿"<Artículo>" lleva IVA 16% (G)?` con botón `Corregir`. Al tocar `Corregir`, vuelve a cuadrar al centavo. |
| **CP-04** | Tocar `Ajustar IVA · N gravados` al pie y alternar un artículo entre `Exento`, `16%` y `8%`. | La hoja actualiza el cálculo de IVA en vivo y al pulsar `Listo` refleja los cambios en las tarjetas y el pie. |
| **CP-05** | Editar `Monto total` a mano en una factura fiscal. | El pie cambia de `IVA de la factura` a `IVA calculado` y deja de mostrar `Cuadra con la factura`. Si hay descuadre al pulsar `Guardar Gasto`, aparece el diálogo con `Corregir` / `Guardar así`. Al elegir `Guardar así`, guarda bases con `(G)`/`(E)` + renglón `Impuesto IVA` en la categoría dominante. |
| **CP-06** | Guardar una factura cuadrada y revisar `Inicio`, `Gastos`, `Análisis` y `Editar gasto`. | Cada artículo tiene un único precio final (con IVA incluido) en su propia categoría y sin renglón `Impuesto IVA`. |
| **CP-07** | Abrir gasto manual (`+` → `Escribir gasto`) o dictado por voz. | Cero badges, cero pie fiscal y cero etiquetas `sin IVA`. |

---

## 8. Segmentación Futura (Fase 9: Rinde Más Pro)
- Selector de modo contable (*Modo Anaquel* vs *Modo Fiscal/Contable Pro*) y exportación contable con columnas separadas de Base Exenta, Base Imponible 16% y Débito Fiscal IVA.
