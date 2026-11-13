# Auditoría Integral de Producto, Arquitectura, Lógica Financiera y Seguridad — Rinde Más ("Argon")

**Fecha de Auditoría:** 22 de octubre de 2026  
**Alcance:** App móvil Flutter (`lib/`, `android/`), Panel Web y Landing (`landing/`), Gateway de IA en Cloudflare (`workers/`, `cloudflare_worker/`), Reglas de Firestore (`firestore.rules`) y Pipelines CI/CD (`.github/workflows/`).  
**Metodología:** Inspección estática exhaustiva con **cero suposiciones sin evidencia**. Cada hallazgo incluye la ruta exacta del archivo, el rango de líneas y la demostración matemática o técnica del impacto.

---

## Leyenda de Severidad
- 🔴 **Crítico:** Riesgo de seguridad exploitable, exposición de credenciales/llaves criptográficas, pérdida/corrupción de datos o error matemático en cálculos financieros.
- 🟠 **Importante:** Inconsistencia funcional entre plataformas (Móvil vs. Web), deuda técnica estructural, desviación de las reglas de negocio (`AGENTS.md` / `.agents/rules/`) o fricción de UX.
- 🟢 **Oportunidad de mejora:** Optimización de rendimiento, higiene de repositorio, pulido visual o escalabilidad.

---

# FASE 1: Auditoría de Lógica Financiera y Multimoneda Venezolana

## 1.1 Integridad Histórica de Tasas de Cambio y Lentes Financieros

### ✅ [F1-C01] [RESUELTO EN LOTE 2] Distorsión retrospectiva del lente `EUR BCV` al dividir el acumulado histórico en Bolívares entre la tasa Euro del día actual
- **Evidencia en Código:**
  - **Base de Datos Móvil:** [`lib/data/datasources/local/database_helper.dart:L556-L598`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/local/database_helper.dart#L556-L598) (`getMonthlyTotals`) y [`lib/data/datasources/local/database_helper.dart:L604-L673`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/local/database_helper.dart#L604-L673) (`getCategoryTotals`). Solo calculan y devuelven `'USD'`, `'VES'` y `'USDT'`; no existe acumulado histórico para `'EUR'`.
  - **Tarjetas y Pantallas Móvil:** [`lib/ui/widgets/summary_card.dart:L75-L84`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/summary_card.dart#L75-L84), [`lib/ui/screens/dashboard_screen.dart:L222-L245`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/dashboard_screen.dart#L222-L245), [`lib/ui/screens/analysis_screen.dart:L152-L176`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/analysis_screen.dart#L152-L176) y [`lib/ui/screens/analysis_screen.dart:L274-L285`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/analysis_screen.dart#L274-L285).
  - **Panel Web:** [`landing/src/pages/panel.astro:L1163-L1164`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1163-L1164) y [`landing/src/pages/panel.astro:L1328-L1330`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1328-L1330).
- **Análisis y Demostración Matemática:**
  - Mientras los lentes `USD BCV`, `VES` y `USDT P2P` preservan la tasa histórica de cada transacción individual, al activar el lente `EUR` tanto la app móvil como el panel web ejecutan:
    $$\text{spentInLens}_{\text{EUR}} = \frac{\sum \text{VES}_{\text{histórico}}}{\text{tasaCambioVesEur}_{\text{HOY}}}$$
  - En una economía con devaluación continua del bolívar, si un usuario gastó el equivalente a `€100,00` en enero de 2026 cuando la tasa era `400 Bs/EUR` (`totalMesVes = 40.000 Bs`) y consulta ese mes en octubre cuando la tasa del día (`liveRates.eur`) es `500 Bs/EUR`, el lente `EUR` muestra que gastó **`€80,00`** en lugar de `€100,00`, distorsionando los cierres de meses anteriores y el consumo real del presupuesto.
  - Adicionalmente, en los widgets de radiografía y evolución diaria ([`lib/ui/widgets/currency_radiography_card.dart:L53-L63`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/currency_radiography_card.dart#L53-L63), [`lib/ui/widgets/purchase_radiography_card.dart:L40-L50`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/purchase_radiography_card.dart#L40-L50) y [`lib/ui/widgets/daily_evolution_card.dart:L64-L76`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/daily_evolution_card.dart#L64-L76)), los gastos con `moneda != 'VES'` se convierten a EUR usando la relación de tasas **actuales** (`totalUsdDisplay * (usdRateHoy / eurRateHoy)`), mientras que [`SummaryCard`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/summary_card.dart#L76-L78) divide `totalMesVes` (calculado con `tasa_cambio` histórica) entre `eurRateHoy`. Esto provoca que la suma de las barras diarias de `DailyEvolutionCard` no coincida con el total de `SummaryCard` bajo el lente `EUR`.

---

### ✅ [F1-C02] [RESUELTO EN LOTE 2] Corrupción de `tasa_cambio`, `total_usd` y `total_usdt` al registrar o editar gastos históricos y en `EUR` desde el Panel Web
- **Evidencia en Código:**
  - [`landing/src/pages/panel.astro:L2335-L2336`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2335-L2336) (`formExpense.addEventListener('submit', ...)`).
  - [`landing/src/pages/panel.astro:L2371-L2376`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2371-L2376) y [`L2428-L2429`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2428-L2429).
  - Contraste con la implementación móvil en [`lib/ui/screens/review_expense_screen.dart:L824-L868`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L824-L868).
- **Análisis y Demostración Matemática:**
  1. **Pérdida de tasa histórica USDT en Web (`L2336`):**
     ```javascript
     const tasa = Number(modalExpTasa.value) || Number(liveRates.usd || 40);
     const tasaUsdt = Number(liveRates.usdt || 0) > 0 ? Number(liveRates.usdt) : tasa;
     ```
     Aunque el usuario seleccione una fecha pasada en `modalExpFecha` (lo cual actualiza `modalExpTasa.value` vía `fetchHistoricalRateForDate` en [`L2164-L2178`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2164-L2178)), `tasaUsdt` ignora la fecha histórica y toma **siempre** `liveRates.usdt` (la tasa P2P del día de hoy). Peor aún: si el usuario registra un gasto en `USDT` (`DIVISA`) o en `USD` con liquidación `BS_USDT`, el input `modalExpTasa` contiene la tasa USDT editada por el usuario, pero para `BS_USDT` en [`L2364-L2369`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2364-L2369):
     ```javascript
     const equivVes = monto * tasaUsdt;
     const refBcv = liveRates.usd > 0 ? liveRates.usd : tasa;
     totalOrigCents = Math.round(equivVes * 100);
     totalUsdCents = Math.round((equivVes / refBcv) * 100);
     ```
     Ignora el valor `tasa` escrito por el usuario en `modalExpTasa` y usa `liveRates.usdt` y `liveRates.usd` del día actual.
  2. **Inflación del equivalente en Bolívares al guardar un gasto en `EUR` (`DIVISA`) en Web (`L2371-L2376` y `L2428`):**
     En Web, cuando `expMoneda === 'EUR'` y `selectedLiq === 'DIVISA'`:
     - En [`L2373-L2375`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2373-L2375), calcula `equivVes = monto * tasa` (donde `tasa` es Bs/EUR, ej. `500 Bs/EUR`) y `totalUsdCents = Math.round((equivVes / refUsd) * 100)` (ej. para `€10` a `500 Bs/EUR` y `refUsd = 400 Bs/USD`, `totalUsdCents = 1250` centavos = `$12,50 USD`).
     - Sin embargo, en [`L2428`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2428) guarda `tasa_cambio: tasa` (`500 Bs/EUR`).
     - Cuando el panel web ([`L1154`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1154)) o SQLite en la app móvil ([`lib/data/datasources/local/database_helper.dart:L589`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/local/database_helper.dart#L589)) calculan el acumulado en Bolívares para gastos con `moneda != 'VES'`, multiplican `totalUsd * tasa_cambio` (`$12,50 * 500 = 6.250 Bs` en lugar de `5.000 Bs`), inflando artificialmente el gasto en Bolívares un **25%**. En móvil ([`lib/ui/screens/review_expense_screen.dart:L852-L855`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L852-L855)), esto se previno calculando `tasaParaGasto = (totalUsd > 0) ? (totalVes / totalUsd) : ...`, lógica que falta en `panel.astro`.

---

### ✅ [F1-C03] [RESUELTO EN LOTE 2] Multiplicación doble por `tasaCambio` en `AiInsightCard` cuando el presupuesto está en Bolívares (`VES`) e incompatibilidad con `USDT`/`EUR`
- **Evidencia en Código:**
  - [`lib/ui/screens/dashboard_screen.dart:L179-L185`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/dashboard_screen.dart#L179-L185).
  - [`lib/ui/widgets/ai_insight_card.dart:L44-L145`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/ai_insight_card.dart#L44-L145).
  - [`lib/core/utils/currency_formatter.dart:L44-L60`](file:///c:/Development/Control%20de%20gastos%20VE/lib/core/utils/currency_formatter.dart#L44-L60) (`CurrencyFormatter.formatPreferido`).
- **Análisis y Demostración Matemática:**
  1. En [`dashboard_screen.dart:L179-L185`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/dashboard_screen.dart#L179-L185), cuando `gastoProvider.monedaPresupuesto == 'VES'`, se pasan a `AiInsightCard` los valores `totalGastadoMes`, `presupuestoGeneral` y `metaAhorro` **ya expresados en Bolívares** (`totalMesVes`, `presupuestoGeneral` en Bs., `metaAhorro` en Bs.).
  2. Dentro de [`ai_insight_card.dart:L67-L92`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/ai_insight_card.dart#L67-L92), [`L100-L105`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/ai_insight_card.dart#L100-L105) y [`L126-L144`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/ai_insight_card.dart#L126-L144), el widget formatea `exceso`, `metaAhorro`, `rem`, `proy` y `ritmoDiario` invocando:
     ```dart
     CurrencyFormatter.formatPreferido(metaAhorro, null, tasaCambio, monedaPresupuesto)
     ```
  3. Sin embargo, [`CurrencyFormatter.formatPreferido`](file:///c:/Development/Control%20de%20gastos%20VE/lib/core/utils/currency_formatter.dart#L44-L55) asume que su primer argumento (`totalUsd`) está siempre en **USD** y que el segundo es `totalVes`:
     ```dart
     if (monedaPreferida == 'VES') {
       final ves = totalVes ?? (totalUsd * tasaCambio);
       return formatVes(ves);
     }
     ```
     Al recibir `totalVes == null`, multiplica `metaAhorro` (que **ya estaba en Bolívares**) nuevamente por `tasaCambio`.
  4. **Ejemplo real:** Si un usuario configura un presupuesto en Bolívares con `metaAhorro = 10.000 Bs` y la tasa BCV es `400 Bs/USD`, `AiInsightCard` muestra: *"Tu meta de ahorrar **Bs. 4.000.000,00** este mes va por buen camino"*.
  5. Adicionalmente, si `monedaPresupuesto` es `'USDT'` o `'EUR'`, [`dashboard_screen.dart:L180`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/dashboard_screen.dart#L180) pasa `gastoProvider.totalMesUsd` (en USD BCV) en lugar del gasto en USDT o EUR, mezclando divisas distintas en el cálculo de salud del ahorro.

---

### ✅ [F1-C04] [RESUELTO EN LOTE 2] Regla de `'Impuesto IVA'` con Categoría Dominante e inclusión de `'Higiene'`, `'Ropa'`, `'Entretenimiento'` y `'USDT'` en `GeminiExtractionResult.fromJson`
- **Evidencia en Código:**
  - [`lib/data/models/gemini_extraction_result.dart:L61-L117`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/models/gemini_extraction_result.dart#L61-L117).
  - Regla infringida: [`.agents/rules/dinero-datos.md:L35-L49`](file:///c:/Development/Control%20de%20gastos%20VE/.agents/rules/dinero-datos.md#L35-L49) y [`.agents/rules/ia-ocr-voz.md:L16`](file:///c:/Development/Control%20de%20gastos%20VE/.agents/rules/ia-ocr-voz.md#L16).
- **Análisis:**
  1. **Renglón artificial `'Impuesto IVA'` (`L103-L117`):** Cuando Gemini extrae una factura con `impuesto_iva > 0` cuyos ítems vienen con precios base sin IVA (`(totalOriginal - sumItems - impuestoIva).abs() <= 1.0`), `GeminiExtractionResult.fromJson` **agrega un ítem independiente llamado `'Impuesto IVA'` con categoría `'Otros'`** en lugar de imputar el IVA proporcionalmente a los ítems gravados (`alicuota_fiscal == 'G'`), como sí lo hace `ReviewExpenseScreen._ buildInitialItemsWithTaxAllocated` ([`lib/ui/screens/review_expense_screen.dart:L313-L375`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L313-L375)). Worse aún: cuando `GeminiExtractionResult.fromJson` ya inyectó el ítem `'Impuesto IVA'`, la suma de `items` pasa a igualar `totalOriginal`, por lo que al llegar a `ReviewExpenseScreen._buildInitialItemsWithTaxAllocated` ([`L329`: `final double diffConTotal = result.totalOriginal - sumItems; if (diffConTotal <= 0.05) return rawItems;`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L329-L333)), **`_buildInitialItemsWithTaxAllocated` aborta sin repartir el IVA** y deja el renglón `'Impuesto IVA'` en la lista de productos de la pantalla de revisión!
  2. **Supresión silenciosa de la categoría canónica `'Higiene'` (`L69` y `L90`):** La lista cableada `validCategorias = ['Alimentación', 'Salud', 'Educación', 'Hogar', 'Servicios', 'Transporte', 'Otros']` en [`L69`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/models/gemini_extraction_result.dart#L69) y [`L90`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/models/gemini_extraction_result.dart#L90) **omite `'Higiene'`** (incluida en `AppConstants.categorias` en [`lib/core/constants/app_constants.dart:L39-L48`](file:///c:/Development/Control%20de%20gastos%20VE/lib/core/constants/app_constants.dart#L39-L48) y enviada por el Worker en [`workers/src/index.js:L388`](file:///c:/Development/Control%20de%20gastos%20VE/workers/src/index.js#L388)). Como resultado, **el 100% de los productos clasificados como `'Higiene'` por el OCR de Gemini son sobreescritos silenciosamente a `'Otros'`**.
  3. **Supresión de `'USDT'` (`L61`):** `final moneda = ['USD', 'VES', 'EUR'].contains(monedaRaw) ? monedaRaw : 'USD';` convierte cualquier extracción `'USDT'` a `'USD'` en vez de usar `AppConstants.normalizarMoneda`.

---

## 1.2 Precisión Aritmética y Errores de Redondeo

### ✅ [F1-I01] [RESUELTO EN LOTE 2] Pérdida de decimales (`.round()`) al alternar la moneda del presupuesto entre divisas (incluso en paridad 1:1 `USD` ↔ `USDT`)
- **Evidencia en Código:**
  - **Móvil:** [`lib/ui/widgets/budget_bottom_sheet.dart:L164-L185`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/budget_bottom_sheet.dart#L164-L185).
  - **Web:** [`landing/src/pages/panel.astro:L1579-L1596`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1579-L1596) (`formatBudgetInputVal`).
- **Análisis y Demostración:**
  - En ambos clientes, la función de formateo al cambiar de pestaña de moneda aplica:
    ```dart
    String formatear(double val) {
      if (val <= 0) return '0';
      return val >= 100 ? val.round().toString() : val.toStringAsFixed(2);
    }
    ```
  - Si el presupuesto base está en `USD` con un monto de `$125.50` y el usuario toca la pestaña `USDT` (que por regla de negocio tiene paridad exacta `1:1`), `nuevaMoneda == _baseGeneralMoneda` es `false` (`'USDT' != 'USD'`), por lo que pasa por `formatear(125.50)` y **redondea el campo a `126`**, alterando el monto en paridad 1:1 si el usuario guarda o edita.

---

### ✅ [F1-I02] [RESUELTO EN LOTE 2] Deriva acumulativa de centavos en ítems al editar repetidamente un gasto indexado (`BS_BCV` / `BS_USDT`)
- **Evidencia en Código:**
  - **Móvil:** [`lib/ui/screens/review_expense_screen.dart:L262-L273`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L262-L273) (carga en edición) y [`L881-L893`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L881-L893) (guardado).
  - **Web:** [`landing/src/pages/panel.astro:L2259-L2270`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2259-L2270) (carga en edición) y [`L2403-L2413`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2403-L2413) (guardado).
- **Análisis:**
  - Cuando un gasto se registra como `USD` o `EUR` liquidado en Bolívares (`BS_BCV` o `BS_USDT`), la base de datos persiste `moneda = 'VES'` y los precios de los ítems en céntimos de Bolívar (`(bsTotal * 100).round()`).
  - Al abrir el gasto para editarlo, la UI reconstruye los precios en divisa dividiendo los céntimos de Bolívar entre `rateForItems` y redondeando a 2 decimales (`(usdUnit * 100).round()`). Al volver a guardar, multiplica ese valor redondeado nuevamente por la tasa y vuelve a redondear.Por ejemplo, un ítem de `Bs. 100,00` a tasa `36,55 Bs/USD` se convierte al abrir en `$2,74` (`100 / 36,55 = 2,7359...`), y al guardar sin tocar nada se convierte en `Bs. 100,15` (`2,74 * 36,55`), descuadrando la suma de ítems respecto a `total_original`.

---

### ✅ [F1-I03] [RESUELTO EN LOTE 2] Pérdida de la moneda `'EUR'` al abrir en modo edición un gasto indexado a Euro BCV (`BCV (Pago en Bs. indexado a EUR)`)
- **Evidencia en Código:**
  - **Móvil:** [`lib/ui/screens/review_expense_screen.dart:L231-L246`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L231-L246).
  - **Web:** [`landing/src/pages/panel.astro:L2217-L2238`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2217-L2238).
- **Análisis:**
  - Al guardar un gasto en `EUR` con método `BS_BCV`, `fuente_tasa_cambio` se guarda como `'BCV (Pago en Bs. indexado a EUR)'` ([`review_expense_screen.dart:L842`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L842)) y `moneda` pasa a `'VES'`.
  - Sin embargo, al reabrir ese gasto para editarlo:
    - En Móvil ([`L237-L241`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L237-L241)), `if (isIndexedBcv)` asigna incondicionalmente `_selectedMoneda = 'USD'`, ignorando si `fuente` contenía `'indexado a EUR'`.
    - En Web ([`L2219-L2224`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2219-L2224)), `esIndexadoBcv` solo evalúa `fuente.includes('indexado a USD') || fuente.includes('BCV (Pago en Bs.')` y fuerza `expMoneda = 'USD'`.

---

### ✅ [F1-I04] [RESUELTO EN LOTE 2] Tasa cableada `tasaFallback = 40.0` en `repararTasasHistoricasIncompletas`
- **Evidencia en Código:**
  - [`lib/data/datasources/local/database_helper.dart:L1547-L1582`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/local/database_helper.dart#L1547-L1582) y [`lib/providers/gasto_provider.dart:L174`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/gasto_provider.dart#L174).
  - Regla relacionada: `AGENTS.md:L39` (*"Nunca utilizar ratios de cambio cableados"*).
- **Análisis:**
  - Si un gasto en `USD` tiene `tasa_cambio <= 1.0` y su fecha no se encuentra en la tabla local `tasas_historicas`, el método le inyecta de forma permanente en SQLite `40.0` (`tasaFallback = 40.0`) sin consultar primero el espejo histórico por fecha ni usar la tasa vigente en `SettingsProvider`.

---

## 1.3 Paridad Móvil (`lib/`) vs. Panel Web (`landing/src/pages/panel.astro`)

### ✅ [F1-I05] [RESUELTO EN LOTE 2] `GastoProvider.savingsSnapshot` y `getSpentForCategory` en Móvil ignoran los lentes/monedas `USDT` y `EUR`
- **Evidencia en Código:**
  - [`lib/providers/gasto_provider.dart:L52-L63`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/gasto_provider.dart#L52-L63) (`savingsSnapshot`).
  - [`lib/providers/gasto_provider.dart:L442-L462`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/gasto_provider.dart#L442-L462) (`getSpentForCategory` e `isCategoryOverBudget`).
  - [`lib/ui/screens/chat_screen.dart:L330` y `L410-L413`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/chat_screen.dart#L330).
- **Análisis:**
  - En `GastoProvider.savingsSnapshot` ([`L54-L58`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/gasto_provider.dart#L54-L58)):
    ```dart
    final double gastadoEnMonedaPresupuesto = _monedaPresupuesto == 'VES'
        ? _totalMesVes
        : (_monedaPresupuesto == 'USDT' ? _totalMesUsdt : _totalMesUsd);
    ```
    Si el usuario configuró su presupuesto en `'EUR'`, compara el presupuesto en Euros contra `_totalMesUsd` (en Dólares BCV) sin convertir. Y este `savingsSnapshot` defectuoso se envía directamente al contexto del Asistente IA en [`lib/ui/screens/chat_screen.dart:L410-L412`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/chat_screen.dart#L410-L412).
  - En `getSpentForCategory` ([`L443-L444`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/gasto_provider.dart#L443-L444)), solo distingue `moneda == 'VES'` vs. `_totalesPorCategoria` (USD BCV), devolviendo montos en USD BCV cuando se consulta en `USDT` o `EUR`.

---

### ✅ [F1-I06] [RESUELTO EN LOTE 2] Discrepancias visuales y matemáticas entre Móvil y Web en Barra de Presupuesto, Desglose de Ítems y Categorías
- **Evidencia en Código:**
  1. **Escala y marcador de la Barra de Progreso del Presupuesto:**
     - **Móvil** ([`lib/ui/widgets/summary_card.dart:L384-L386`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/summary_card.dart#L384-L386), [`lib/ui/screens/analysis_screen.dart:L499-L502`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/analysis_screen.dart#L499-L502)): Cumple [`.agents/rules/dinero-datos.md:L43-L46`](file:///c:/Development/Control%20de%20gastos%20VE/.agents/rules/dinero-datos.md#L43-L46); la barra escala sobre el 100% del `presupuestoGeneral` (`effectiveSpent / budgetInLens`) y dibuja un marcador vertical en `limiteParaGastar / budgetInLens`.
     - **Web** ([`landing/src/pages/panel.astro:L1279-L1292`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1279-L1292)): Escala la barra sobre `targetBudget` (`limiteParaGastar`, es decir, `presupuesto - metaAhorro`), carece del marcador vertical de la meta de ahorro y usa colores verde/ámbar/rojo en vez de slate (`#1E293B`)/ámbar/rojo.
  2. **Moneda de los ítems al expandir una factura:**
     - **Móvil** ([`lib/ui/widgets/expense_card.dart:L317-L361`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/expense_card.dart#L317-L361)): Convierte cada ítem proporcionalmente al lente activo (`monedaPrincipal`) y limpia sufijos fiscales `(G)`/`(E)` mediante `cleanItemDescription`.
     - **Web** ([`landing/src/pages/panel.astro:L1485-L1494`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1485-L1494)): Muestra siempre el ítem en `gasto.moneda` original ignorando el lente activo (`activeLens`) y no limpia sufijos `(G)`/`(E)`.
  3. **Desglose de ítems por categoría en Móvil bajo el lente `USDT`:**
     - En [`lib/ui/widgets/category_chart.dart:L671-L690`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/category_chart.dart#L671-L690) (`_buildCategoryItems`), cuando `gasto.moneda == 'VES'` y el lente activo es `'USDT'`, llama a `CurrencyFormatter.convertFromUsd(itemUsd, 'USDT', usdRate, ...)` ([`lib/core/utils/currency_formatter.dart:L157-L162`](file:///c:/Development/Control%20de%20gastos%20VE/lib/core/utils/currency_formatter.dart#L157-L162)), el cual devuelve `amountUsd` (valor a tasa BCV) sin convertir a `USDT P2P` (`gasto.totalUsdtDisplay * ratio`). Por ende, los productos individuales dentro de una categoría en lente `USDT` muestran su precio en `USD BCV`, cuya suma no coincide con el encabezado de la categoría en `USDT`.

---

# FASE 2: Auditoría de Seguridad y Privacidad

## 2.1 Secretos, Criptografía, API Keys y Autenticación

### 🔴 [F2-C01] Keystore de Producción Android (`rindemas.jks`) y sus contraseñas en texto plano versionados en el repositorio Git Público
- **Evidencia en Código:**
  - Archivo binario versionado en Git: `android_template/rindemas.jks` (confirmado vía `git ls-files`).
  - Contraseñas en texto plano en [`android/app/build.gradle.kts:L35-L43`](file:///c:/Development/Control%20de%20gastos%20VE/android/app/build.gradle.kts#L35-L43):
    ```kotlin
    val keystoreFile = rootProject.file("../android_template/rindemas.jks")
    if (keystoreFile.exists()) {
        storeFile = keystoreFile
        storePassword = "rindemas123"
        keyAlias = "rindemas"
        keyPassword = "rindemas123"
    }
    ```
  - Contraseñas en texto plano en [`.github/workflows/build_apk.yml:L47`](file:///c:/Development/Control%20de%20gastos%20VE/.github/workflows/build_apk.yml#L47), [`L55`](file:///c:/Development/Control%20de%20gastos%20VE/.github/workflows/build_apk.yml#L55) y [`L179`](file:///c:/Development/Control%20de%20gastos%20VE/.github/workflows/build_apk.yml#L179) (`--ks-pass pass:rindemas123 --ks-key-alias rindemas --key-pass pass:rindemas123`).
  - Estado público del repositorio documentado en [`AGENTS.md:L29`](file:///c:/Development/Control%20de%20gastos%20VE/AGENTS.md#L29).
- **Impacto Crítico:**
  - Cualquier tercero puede descargar `android_template/rindemas.jks` del repositorio o de su historial de commits y firmar APKs maliciosos con la identidad criptográfica legítima de `com.cesarluis.rindemas`.
  - Dado que Firebase Auth / Google Sign-In en Android autentica la aplicación mediante el par `(package_name, SHA-1 del certificado de firma)`, un atacante con `rindemas.jks` puede compilar una app suplantadora que obtenga tokens de Google Sign-In válidos contra el proyecto Firebase `gastoscan-ai`, además de comprometer las actualizaciones directas por APK.

---

### 🔴 [F2-C02] Evasión de Rate Limiting y Consumo de Cuota de IA mediante Sesiones Anónimas Ilimitadas en el Gateway de Cloudflare
- **Evidencia en Código:**
  - [`lib/data/datasources/remote/gemini_service.dart:L390-L407`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/remote/gemini_service.dart#L390-L407) (`_ensureValidIdToken` invoca `await auth.signInAnonymously()`).
  - [`workers/src/index.js:L23-L68`](file:///c:/Development/Control%20de%20gastos%20VE/workers/src/index.js#L23-L68) (`rateLimitMap` y `dailyRateLimitMap` en memoria volátil por UID) y [`L105-L170`](file:///c:/Development/Control%20de%20gastos%20VE/workers/src/index.js#L105-L170) (`verifyFirebaseToken`).
  - Regla infringida: [`.agents/rules/privacidad-seguridad.md:L14`](file:///c:/Development/Control%20de%20gastos%20VE/.agents/rules/privacidad-seguridad.md#L14) (*"Las funciones de Inteligencia Artificial (escaneo OCR en la nube y Asistente) y la sincronización con Firestore requieren sesión autenticada con Google"*).
- **Análisis:**
  1. `verifyFirebaseToken` en [`workers/src/index.js:L105-L170`](file:///c:/Development/Control%20de%20gastos%20VE/workers/src/index.js#L105-L170) solo verifica que el JWT esté firmado por Google para el proyecto `gastoscan-ai`, pero **no verifica `payload.firebase?.sign_in_provider !== 'anonymous'`** (o que exista `payload.email`).
  2. Como Firebase Anonymous Auth está habilitado en el proyecto `gastoscan-ai`, cualquier script externo puede invocar `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=<FIREBASE_WEB_API_KEY>` para generar miles de UIDs anónimos nuevos por minuto sin coste ni interacción humana.
  3. Dado que los límites `isRateLimited(uid, 30)` y `isDailyLimitExceeded(uid, 50)` están indexados únicamente por `uid` (y además residen en un `Map` en memoria de isolate de Cloudflare que no persiste entre datacenters ni reinicios de isolate), rotar UIDs anónimos anula por completo el límite de 50 peticiones/día y permite agotar la cuota de `GEMINI_API_KEY`.

---

### ✅ [F2-C03] [RESUELTO EN LOTE 1] Exposición y Sincronización en Texto Plano de la `gemini_api_key` Personal del Usuario (BYOK) en Firestore e IndexedDB Web
- **Evidencia en Código:**
  - [`lib/services/sync_service.dart:L104-L139`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L104-L139) (`syncSettingsToCloud` / `pullSettingsFromCloud`).
  - [`landing/src/pages/panel.astro:L597`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L597) (`enableIndexedDbPersistence(db)`) y [`L985-L1035`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L985-L1035) (`getDocs(presupuestosRef)`).
- **Análisis:**
  - Aunque en el dispositivo móvil la API Key personalizada de Gemini se guarda cifrada con `FlutterSecureStorage` ([`lib/providers/settings_provider.dart:L104-L115`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/settings_provider.dart#L104-L115)), `SyncService.syncSettingsToCloud` ([`lib/services/sync_service.dart:L115-L122`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L115-L122)) la sube **en texto plano** al documento `/users/{userId}/presupuestos/user_settings` en Firestore.
  - Al estar alojada dentro de la colección `presupuestos`, cuando el usuario abre el panel web (`panel.astro`), la consulta `getDocs(collection(db, 'users', currentUser.uid, 'presupuestos'))` en [`panel.astro:L988-L989`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L988-L989) descarga automáticamente el documento `user_settings` con la `gemini_api_key` en texto plano al navegador y la persiste sin cifrar en el `IndexedDB` local del navegador (`enableIndexedDbPersistence`), donde cualquier ataque XSS (ver `[F2-C04]`) puede exfiltrarla instantáneamente.

---

### ✅ [F2-I01] [RESUELTO EN LOTE 1] Envío de `GEMINI_API_KEY` como parámetro de URL (`?key=`) en lugar de cabecera exclusiva `x-goog-api-key`
- **Evidencia en Código:**
  - [`lib/data/datasources/remote/gemini_service.dart:L28`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/remote/gemini_service.dart#L28): `Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$trimmed')` (sin cabecera `x-goog-api-key`).
  - [`workers/src/index.js:L441`](file:///c:/Development/Control%20de%20gastos%20VE/workers/src/index.js#L441): `const url = \`https://generativelanguage.googleapis.com/v1beta/models/\${currentModel}:generateContent?key=\${geminiKey}\`;`.
  - [`workers/src/index.js:L830-L839`](file:///c:/Development/Control%20de%20gastos%20VE/workers/src/index.js#L830-L839): En `handleChatAnalyst`, además de incluir `?key=${geminiKey}` en la URL, ni siquiera envía la cabecera `x-goog-api-key`.
  - [`firebase_functions/index.js:L94` y `L331`](file:///c:/Development/Control%20de%20gastos%20VE/firebase_functions/index.js#L94).
  - Regla infringida: [`.agents/rules/gateway-cloudflare.md:L16`](file:///c:/Development/Control%20de%20gastos%20VE/.agents/rules/gateway-cloudflare.md#L16) (*"Enviar la clave de API de Gemini hacia Google siempre mediante la cabecera HTTP `x-goog-api-key`, nunca como parámetro en la URL (`?key=`)"*).

---

## 2.2 Almacenamiento, Validación de Datos y Vulnerabilidades de Inyección (XSS / CSV / Firestore)

### ✅ [F2-C04] [RESUELTO EN LOTE 1] Vulnerabilidad de Cross-Site Scripting (Stored / DOM XSS) en el Panel Web (`landing/src/pages/panel.astro`)
- **Evidencia en Código:**
  1. **Inyección directa en listado de facturas (`renderBills` en [`landing/src/pages/panel.astro:L1456-L1508`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1456-L1508)):**
     ```javascript
     card.innerHTML = `
       ...
       <h4 class="font-bold text-slate-900 text-sm truncate">${gasto.comercio || 'Comercio'}</h4>
       ...
       <span>${gasto.fecha || ''}</span>
       ...
       <span>${it.cantidad || 1}x ${it.descripcion || 'Producto'}</span>
     `;
     ```
     Ni `gasto.comercio`, ni `gasto.fecha`, ni `it.descripcion` se escapan antes de interpolarse en `innerHTML`. Si un usuario escanea una factura (o recibe vía OCR/voz un texto) cuyo comercio o ítem contenga `<img src=x onerror="...">` (Prompt Injection en un ticket impreso o QR), o si se inyecta en Firestore, el JavaScript malicioso se ejecuta en el navegador del usuario con acceso total a su sesión de Firebase y a su `gemini_api_key` en IndexedDB.
  2. **Inyección de atributos y ruptura de DOM en el modal de gastos (`renderExpenseItems` en [`landing/src/pages/panel.astro:L1807-L1825`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1807-L1825)):**
     ```javascript
     <input type="text" data-idx="${idx}" data-field="descripcion" value="${item.descripcion || ''}" ... />
     ```
     Cualquier producto cuya descripción contenga comillas dobles `"` (por ejemplo, `Televisor 55"` o `Cable 1/2"`) **rompe el atributo HTML `value="..."`**, truncando el nombre del producto al editar la factura y permitiendo inyección de eventos HTML (`" onfocus="alert(1)" autofocus="`).
  3. **Inyección en nombres de categorías (`renderCategories` en [`L1373-L1395`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1373-L1395) y `openBudgetModal` en [`L1602-L1616`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1602-L1616)):**
     En [`L1358`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1358), `Object.keys(currentPresupuesto.categorias || {})` incorpora claves arbitrarias almacenadas en Firestore y las interpola sin escapar en `row.innerHTML` (`<span>${cat}</span>`, `data-cat="${cat}"`).

---

### 🔴 [F2-C05] Reglas de Seguridad de Firestore (`firestore.rules`) permisivas sin validación de esquema, tipos, tamaño ni restricción de cuentas anónimas
- **Evidencia en Código:**
  - [`firestore.rules:L1-L11`](file:///c:/Development/Control%20de%20gastos%20VE/firestore.rules#L1-L11):
    ```protobuf
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    ```
- **Análisis:**
  1. **Comodín recursivo `{document=**}` abierto:** Permite a cualquier cliente autenticado crear subcolecciones arbitrarias ilimitadas bajo `/users/{userId}/...`, no solo `gastos` y `presupuestos`.
  2. **Sin restricción de proveedor (`sign_in_provider != 'anonymous'`):** Contradice [`.agents/rules/privacidad-seguridad.md:L14`](file:///c:/Development/Control%20de%20gastos%20VE/.agents/rules/privacidad-seguridad.md#L14) al permitir que tokens anónimos escriban en Firestore.
  3. **Sin validación de tipos ni cotas de tamaño:** Un cliente manipulado puede guardar documentos de hasta 1 MB con tipos inválidos (`total_original` como `string` o `NaN`, arrays `items` gigantescos o payloads XSS en `comercio`), corrompiendo la sincronización de `SyncService` y el renderizado de `panel.astro`.

---

### ✅ [F2-I02] [RESUELTO EN LOTE 1] Riesgo de Inyección de Fórmulas en Exportación CSV (Móvil y Web)
- **Evidencia en Código:**
  - **Móvil:** [`lib/services/export_service.dart:L24-L43`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/export_service.dart#L24-L43).
  - **Web:** [`landing/src/pages/panel.astro:L1519-L1541`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L1519-L1541).
- **Análisis:**
  - Ni `ExportService.generateCsvData` ni `exportMonthCsv` en `panel.astro` sanitizan celdas cuyo contenido comience con caracteres de ejecución de fórmulas en Excel / LibreOffice Calc / Google Sheets (`=`, `+`, `-`, `@`, `\t`, `\r`). Si el nombre de un comercio o ítem extraído por OCR comienza con `-` o `=`, abrir el CSV exportado en Excel puede interpretar la celda como una fórmula ejecutable (CSV Injection) o arrojar `#NAME?`.

---

### ✅ [F2-I03] [RESUELTO EN LOTE 3] Persistencia de Fotos de Facturas y Base de Datos SQLite sin Cifrado en Reposo y Limpieza Incompleta al Cerrar Sesión
- **Evidencia en Código:**
  - [`lib/data/datasources/local/database_helper.dart:L1523-L1538`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/local/database_helper.dart#L1523-L1538) (`clearAllUserData`).
  - [`lib/services/sync_service.dart:L282-L343`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L282-L343) (`clearLocalDataOnSignOut`).
- **Análisis:**
  1. En `DatabaseHelper.clearAllUserData()` ([`L1523-L1538`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/local/database_helper.dart#L1523-L1538)), al cerrar sesión o eliminar la cuenta se borran las tablas `gastos`, `items_gasto`, `presupuestos_mensuales`, `presupuestos_categorias_mensuales`, `shopping_list` y `scan_queue`, pero **NO se eliminan del sistema de archivos local (`File(path).delete()`) las imágenes físicas de los comprobantes/facturas** referenciadas en `gastos.imagen_path` ni en `scan_queue.image_path`, dejando fotos de facturas del usuario en el almacenamiento interno del teléfono tras cerrar sesión o borrar su cuenta.
  2. Tampoco se limpia el historial en memoria de `ChatProvider` (`clearConversation()`) al ejecutar `clearLocalDataOnSignOut` en [`lib/services/sync_service.dart:L282-L343`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L282-L343), por lo que si otro usuario inicia sesión en el mismo dispositivo sin reiniciar la app, puede ver los mensajes previos del Asistente IA.

---

### 🟢 [F2-O01] Archivos Residuales, Duplicidad de Código en Gateways y Clave Local en Disco
- **Evidencia en Código:**
  - **Clave en disco local:** [`firebase_functions/.env.gastoscan-ai:L1`](file:///c:/Development/Control%20de%20gastos%20VE/firebase_functions/.env.gastoscan-ai#L1) contiene `GEMINI_API_KEY=<REDACTED_KEY>`. Aunque `.gitignore:L43` evita que suba a Git, el directorio `firebase_functions/` corresponde a una arquitectura obsoleta reemplazada por Cloudflare Workers.
  - **`node_modules` versionado en Git:** `firebase_functions/node_modules/` tiene cientos de archivos trackeados en el índice de Git (verificado con `git ls-files firebase_functions/`), inflando el tamaño del repositorio innecesariamente.
  - **Duplicación exacta del Worker:** Existen dos directorios idénticos versionados en Git: [`workers/src/index.js`](file:///c:/Development/Control%20de%20gastos%20VE/workers/src/index.js) y [`cloudflare_worker/src/index.js`](file:///c:/Development/Control%20de%20gastos%20VE/cloudflare_worker/src/index.js) (969 líneas cada uno), lo que genera riesgo de editar uno y desplegar el otro.
  - **CORS abierto (`Access-Control-Allow-Origin: *`):** En [`workers/src/index.js:L174`](file:///c:/Development/Control%20de%20gastos%20VE/workers/src/index.js#L174), el Worker permite peticiones desde cualquier origen web. Restringirlo a `https://rindemas.cesarluis.com` (y peticiones nativas sin header `Origin`) reduce la superficie de abuso desde navegadores de terceros.


---

## FASE 3: Coherencia UI/UX, Resiliencia en Bolívares y Flujo del Usuario Venezolano

### 3.1. Riesgos Exactos de `RenderFlex overflow` con Cifras Millonarias en Bolívares (`Bs. 15.850.420,00`)

En pantallas estándar de gama de entrada/media en Venezuela (`360dp` de ancho lógico, equivalente a `~312dp–320dp` de ancho útil interior tras descontar `padding: 16` o `20` en tarjetas), el formateo en Bolívares (`Bs. 15.850.420,00`, 17 caracteres) ocupa entre `135dp` y `240dp` dependiendo del `fontSize`. La inspección línea por línea de los árboles de widgets reveló **7 puntos exactos de desbordamiento horizontal (`RenderFlex overflowed`) o quiebre visual**:

#### 🔴 [F3-C01] Filas (`Row`) desprotegidas sin `Expanded` / `Flexible` / `FittedBox` al mostrar montos en `VES`
- **Severidad:** 🔴 Crítico (Rompe el renderizado en pantallas de `360dp` cuando el usuario activa el lente `Bs.` o configura su presupuesto en `VES`).
- **Evidencia exacta en código (7 ubicaciones):**
  1. **`SummaryCard` — Fila Nivel 2 (`Gastado` vs. `Límite`) (`lib/ui/widgets/summary_card.dart:L318-L379`):**
     - En `L318`, el `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [...])` contiene dos sub-filas (`Row` de `"Gastado: "` en `L320-L339` e `InkWell > Row` de `"Límite: "` en `L341-L378`).
     - Ninguno de los dos hijos del `Row` padre (`L318`) ni los `Text` de los montos (`L329-L337` y `L363-L371`, `fontSize: 13, fontWeight: FontWeight.w700`) están envueltos en `Flexible` o `Expanded`.
     - Cuando el lente activo es `VES` y tanto el gasto como el límite superan el millón de bolívares (`Gastado: Bs. 15.850.420,00` + `Límite: Bs. 20.000.000,00 ✏️`), la suma de anchos supera los `340dp` disponibles dentro de la tarjeta y dispara `RenderFlex overflowed on the right`.
  2. **`AnalysisScreen` — Fila Nivel 2 (`Gastado` vs. `Límite`) (`lib/ui/screens/analysis_screen.dart:L433-L494`):**
     - Réplica exacta de la estructura sin `Flexible` ni `Expanded` en el `Row` padre (`L433`) ni en los `Text` de montos (`L444-L452` y `L478-L486`).
  3. **`AnalysisScreen` — Fila Nivel 4 de Métricas Secundarias (`Promedio diario` | `Mayor gasto`) (`lib/ui/screens/analysis_screen.dart:L571-L629`):**
     - Cada mitad está dentro de un `Expanded` (`L573` y `L606`), dejando apenas `~138dp` de ancho útil para cada columna en un teléfono de `360dp`.
     - Dentro de la columna izquierda (`L575-L596`), el `Row` renderiza `[Icon(14), SizedBox(6), Text('Promedio diario', 12sp), SizedBox(4), Text(formattedAvgDaily, 12sp bold)]` **sin `Flexible` ni `Expanded` en ninguno de los dos `Text`** (`L582` y `L589`).
     - Tan pronto como `formattedAvgDaily` en `VES` alcanza `Bs. 15.000,00` (y con más razón `Bs. 1.500.000,00`), el texto `'Promedio diario'` (`~88dp`) + icono (`20dp`) + monto (`~95dp`) suma `>203dp` dentro de un contenedor de `138dp`, provocando desbordamiento inmediato. Lo mismo ocurre en la mitad derecha con `'Mayor gasto'` + `formattedMaxExpense` (`L608-L627`).
  4. **`SummaryCard` y `AnalysisScreen` — Monto Héroe en `32sp` sin `FittedBox` (`lib/ui/widgets/summary_card.dart:L187-L200`, `L275-L287` y `lib/ui/screens/analysis_screen.dart:L330-L343`, `L393-L405`):**
     - El `Text(CurrencyFormatter.formatAmount(disponible.abs(), activeMoneda), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800))` carece de `FittedBox(fit: BoxFit.scaleDown)` y de `maxLines: 1`. Con cifras como `Bs. 15.850.420,00` a `32sp`, el monto se parte en dos líneas a mitad de los dígitos en pantallas de `360dp`.
  5. **`ExpenseHistoryScreen._buildMonthlySummaryStrip` (`lib/ui/screens/expense_history_screen.dart:L464-L485`):**
     - En `L464`, `Row(mainAxisSize: MainAxisSize.min, children: [Icon(16), SizedBox(6), Text('Total gastado ($count compras): '), Text(primaryFormatted)])`: ninguno de los dos `Text` (`L469-L475` ni `L477-L483`) tiene `Flexible`. Cuando `primaryFormatted` es `Bs. 15.850.420,00` y `count >= 10`, la fila excede el ancho de la píldora en pantallas de `360dp`.
  6. **`PendingExpenseCard` — Fila interna de estado + fecha comprimida por el monto (`lib/ui/widgets/pending_expense_card.dart:L39-L179` y `L70-L94`):**
     - En `L39`, el `Row` principal tiene `[Icon(44dp), SizedBox(12), Expanded(Column), SizedBox(8), Column(Montos), SizedBox(4), Icon(chevron)]`.
     - La columna de montos (`L100-L175`) no tiene restricción de ancho máximo y renderiza `Bs. 15.850.420,00` a `16sp bold` (`L165-L172`). Esto comprime el `Expanded` izquierdo (`L53`) a menos de `120dp`, haciendo que su `Row` interno en `L70-L94` (`Icon(14) + Text('Pendiente de revisar') + SizedBox(8) + Text(DateFormatter.formatDate(gasto.fecha))`, donde ninguno de los dos `Text` tiene `Flexible`) desborde horizontalmente.
  7. **`MoreScreen` — Cabecera de `Tasas de Cambio` (`lib/ui/screens/more_screen.dart:L447-L515`):**
     - En `L447`, `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row('Tasas de Cambio'), Row(Container('⚠ Tasa de referencia'), IconButton)])`: ninguno de los dos `Row` hijos tiene `Flexible`. En `360dp` con escalado de fuente del sistema (`1.15x`), el badge `'⚠ Tasa de referencia'` colisiona con el título `'Tasas de Cambio'`.
- **Impacto:** Franjas amarillas y negras de error (`RenderFlex overflowed`) en producción en dispositivos Android compactos al usar el lente `Bs.` o al registrar gastos en millones de bolívares.
- **Acción recomendada:** Envolver los textos de montos en `Flexible(child: Text(..., overflow: TextOverflow.ellipsis, maxLines: 1))`, usar `FittedBox(fit: BoxFit.scaleDown)` en los montos héroe de `32sp`, y cambiar las métricas secundarias de `AnalysisScreen:L575-L627` a diseño apilado (`Column`) o con `Flexible` en el monto.

---

### 3.2. Inconsistencias Visuales y Semánticas (`DESIGN.md` vs. Implementación)

#### 🟠 [F3-I01] Uso de color Verde (`#10B981` / `bg-emerald-500`) para rellenos de barra de dinero GASTADO en `AppColors` y `panel.astro`
- **Severidad:** 🟠 Importante (Contradicción semántica directa contra `DESIGN.md:L215-L219`).
- **Evidencia en código:**
  - `DESIGN.md:L215-L219` establece taxativamente: *"El color verde (`#10B981` / `AppColors.success`) representa exclusivamente **dinero disponible (saludable)** o **ahorro positivo**. Queda prohibido usar rellenos de barra verdes para representar dinero **gastado**; el progreso de gasto normal (< 80%) debe usar **gris pizarra oscuro (`#1E293B`)** sobre riel gris claro (`#F1F5F9`)"*.
  - Mientras que `SummaryCard` (`lib/ui/widgets/summary_card.dart:L64-L66`) y `AnalysisScreen` (`lib/ui/screens/analysis_screen.dart:L97-L99`) sí aplican `const Color(0xFF1E293B)`, el método central [`AppColors.getBudgetProgressColor`](file:///c:/Development/Control%20de%20gastos%20VE/lib/core/constants/app_colors.dart#L26-L34) sigue devolviendo `AppColors.success` (`#10B981` verde) cuando `percentage < 0.85`.
  - En el panel web (`landing/src/pages/panel.astro`), la barra principal de presupuesto consumido (`#metric-progress-bar`) se inicializa en verde (`bg-emerald-500` en `L238`), se actualiza a `bg-emerald-500` cuando el gasto es `< 80%` en `L1291`, y las barras de gasto por categoría en `renderCategories()` también usan `bg-emerald-500` en `L1401`.
- **Acción recomendada:** Actualizar `AppColors.getBudgetProgressColor` para retornar `const Color(0xFF1E293B)` en el tramo `< 0.80` (y ajustar el umbral de alerta a `0.80` para coincidir con `SummaryCard`), y cambiar `bg-emerald-500` por `bg-slate-800` (`#1E293B`) en `landing/src/pages/panel.astro:L238, L1291, L1401`.

#### 🟠 [F3-I02] Violaciones de Contraste Amarillo/Gris (`DESIGN.md`) en `ScanScreen`, `MoreScreen` y `panel.astro`
- **Severidad:** 🟠 Importante (Accesibilidad visual y cumplimiento de reglas de diseño).
- **Evidencia en código:**
  1. **Icono amarillo pastel sobre fondo claro en `ScanScreen` (`lib/ui/screens/scan_screen.dart:L149-L156`):**
     - Renderiza `Icon(Icons.document_scanner_outlined, size: 64, color: AppColors.primary)` (`#FBF18F`) dentro de un círculo `AppColors.primary.withValues(alpha: 0.1)` sobre una tarjeta blanca (`AppColors.surface`). Esto viola `DESIGN.md:L42-L58` (contraste `< 1.2:1`, casi invisible); debe usar `color: AppColors.textPrimary` sobre fondo `AppColors.primary`.
  2. **Botón rojo destructivo para "Cerrar sesión" con datos respaldados en `MoreScreen` (`lib/ui/screens/more_screen.dart:L1353-L1360`):**
     - En `_confirmarCerrarSesion`, el botón de confirmar usa `ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white))`, contradiciendo `DESIGN.md:L146-L150` (que reserva el botón sólido rojo para borrado destructivo de cuenta/datos y exige `AppColors.primary` con texto negro o `TextButton` para acciones de sesión).
  3. **Abuso de `text-slate-400` en etiquetas informativas e interactivas de `panel.astro`:**
     - `DESIGN.md:L212-L213` prohíbe `text-slate-400` en elementos interactivos o informativos clave sobre fondo claro. Sin embargo, `landing/src/pages/panel.astro` lo aplica en el indicador de presupuesto `Gastado / Límite` (`L240`), subtítulos de gráficos (`L294`), botón interactivo de limpiar filtros (`L367`), contador de gastos (`L387`), cabeceras de tabla (`L391`) y pie de tabla (`L400`).

#### ✅ [F3-I03] [RESUELTO EN LOTE 2] Desincronización de Moneda en Pantalla de Inicio entre `SummaryCard` y `AiInsightCard`
- **Severidad:** 🟠 Importante (Confusión cognitiva al cambiar el lente de moneda).
- **Evidencia en código:**
  - En `lib/ui/screens/dashboard_screen.dart:L164-L185`, cuando el usuario cambia el selector de lente en `SummaryCard` (por ejemplo, de `USD BCV` a `Bs.` o `USDT P2P`), `SummaryCard` actualiza `settings.setMonedaPrincipal(val)` (`lib/ui/widgets/summary_card.dart:L447`) y muestra el disponible, gastado y límite en la moneda del lente activo.
  - Sin embargo, justo debajo (`lib/ui/screens/dashboard_screen.dart:L175-L185`), `AiInsightCard` recibe `monedaPresupuesto: gastoProvider.monedaPresupuesto` (`L183`) e ignora `settings.monedaPrincipal`. Como resultado, la tarjeta superior habla en `Bs.` (o `USDT`) mientras que la tarjeta de consejo diario inmediatamente inferior sigue hablando en la moneda base del presupuesto.

---

### 3.3. Fricción UX, Errores Silenciosos y Código Desconectado en Flujos Críticos

#### 🟠 [F3-I04] Exposición de trazas de excepción crudas (`$e` / `e.toString()`) al usuario final en `VoiceExpenseSheet` y `AuthModalSheet`
- **Severidad:** 🟠 Importante (Violación directa de `AGENTS.md:L50`: *"Nunca exponer trazas de error técnicas o `PlatformException` directamente al usuario final en la interfaz gráfica"*).
- **Evidencia en código:**
  - `lib/ui/widgets/voice_expense_sheet.dart:L111`: `_statusMessage = 'Error al iniciar micrófono: $e';` y `L209`: `_statusMessage = 'Error al procesar: $e';`.
  - `lib/ui/widgets/auth_modal_sheet.dart:L239`: `localError = e.toString();`, pintando la cadena técnica completa dentro del banner rojo de error (`L103-L119`).
- **Acción recomendada:** Mapear los errores a mensajes amigables en español venezolano y registrar el detalle técnico únicamente con `debugPrint`.

#### 🟠 [F3-I05] Pérdida silenciosa de compras múltiples dictadas en `ChatScreen` y botón de revisión anclado solo a la primera compra
- **Severidad:** 🟠 Importante (Pérdida de datos percibida por el usuario en el Asistente IA).
- **Evidencia en código:**
  - En `lib/ui/screens/chat_screen.dart:L517-L541`, cuando el usuario dicta o escribe un mensaje con varias compras (ej. *"Gasté $10 en la farmacia y $25 en el supermercado"*), el backend devuelve una lista `extractions` con `N` compras.
  - El bucle en `L520-L523` las encola en `ScanQueueProvider`, pero:
    1. El bloque `try { ... } catch (_) {}` en `L519-L525` **silencia por completo cualquier fallo de encolado** (`AGENTS.md:L47`). Si `enqueueExtractedExpense` falla, `firstQueueId` queda `null` y en `L533` solo se adjunta al mensaje `extractions.first`, perdiéndose `extractions[1..N-1]` sin ningún aviso.
    2. Incluso cuando el encolado tiene éxito para las `N` compras, la burbuja del chat (`L889-L904`) muestra un único botón `'Revisar y Guardar compra'` (en singular) que abre exclusivamente `firstQueueId` (`extractions.first`), sin indicar al usuario que las demás compras quedaron en la bandeja de pendientes ni permitir revisarlas desde el propio chat.

#### 🟠 [F3-I06] `MainScreen` omite `DocumentScannerService` (ML Kit) al escanear desde el botón `+` y deja `ScanScreen` como código muerto
- **Severidad:** 🟠 Importante (Degradación de calidad OCR y código huérfano).
- **Evidencia en código:**
  - El proyecto incluye `DocumentScannerService` (`lib/services/document_scanner_service.dart:L1-L48`, con recorte de perspectiva y mejora de contraste de ML Kit) y una pantalla dedicada `ScanScreen` (`lib/ui/screens/scan_screen.dart:L1-L265`) que sí invoca `_scannerService.scanDocument()` en `L72`.
  - Sin embargo, `ScanScreen` **no es instanciada ni navegada desde ningún archivo de `lib/`** (solo aparece en `test/widget_test.dart`).
  - Cuando el usuario toca **"Escanear factura (IA)"** en el menú principal (`lib/ui/screens/main_screen.dart:L313-L367`), `_showAddMenu` llama directamente a `ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85)` (`L323-L326`), saltándose por completo `DocumentScannerService` y el recorte inteligente de bordes de factura.
  - Adicionalmente, `ScanQueueProvider._runHybridPipeline` (`lib/providers/scan_queue_provider.dart:L396-L410`) reimplementa una heurística regex manual (`score >= 6`) en lugar de reutilizar `LocalOcrService.evaluateQuality` (`lib/services/local_ocr_service.dart:L126-L243`), ignorando las detecciones de `RIF` y palabras clave que `LocalOcrService` ya calcula.

---

## FASE 4: Arquitectura, Rendimiento, Sincronización y Modo Offline

### 4.1. Resiliencia ante Fallos de Red, Condiciones de Carrera y Sincronización (`SyncService`)

#### ✅ [F4-C01] [RESUELTO EN LOTE 3] Borrado prematuro de SQLite antes de confirmar la descarga de Firestore en `SyncService.pullGastosFromCloud(reemplazarLocales: true)`
- **Severidad:** 🔴 Crítico (Pérdida total de datos locales si la red móvil venezolana cae o da timeout durante la descarga).
- **Evidencia en código:**
  - En [`lib/services/sync_service.dart:L538-L545`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L538-L545):
    ```dart
    if (reemplazarLocales) {
      await _dbHelper.clearAllUserData();
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('gastos')
        .get();
    ```
  - Cuando el usuario inicia sesión en una cuenta existente y elige *"Usar solo los datos de la nube"* (`descartarDatosLocales: true` en `lib/providers/gasto_provider.dart:L328`), `pullGastosFromCloud` **ejecuta `await _dbHelper.clearAllUserData()` en `L539` ANTES de realizar la petición de red `.get()` a Firestore en `L541-L545`**.
  - Si la conexión falla, sufre un corte de datos móviles o lanza una excepción en `L545`, el bloque `catch (e)` en `L616` captura el error y retorna `0`, dejando al usuario con su base de datos SQLite completamente vaciada y sin los datos de la nube.
- **Acción recomendada:** Invertir el orden: descargar primero `gastos` y `presupuestos` desde Firestore en memoria, y solo cuando ambas lecturas de red hayan finalizado con éxito, ejecutar `_dbHelper.clearAllUserData()` y la inserción local dentro de una única transacción SQLite (`db.transaction(...)`).

#### ✅ [F4-C02] [RESUELTO EN LOTE 3] Sobrescritura Silenciosa de Ediciones Web y Resurrección de Gastos Borrados ("Stale Push Overwrite")
- **Severidad:** 🔴 Crítico (Corrupción de sincronización entre el Panel Web `panel.astro` y la App Móvil).
- **Evidencia en código:**
  1. **Ausencia de `updated_at` y de flag `dirty`/`is_synced` en SQLite:**
     - La tabla `gastos` (`lib/data/datasources/local/database_helper.dart:L293-L315`) y `GastoModel` (`lib/data/models/gasto_model.dart:L1-L65`) tienen `creado_en`, pero carecen de columna `actualizado_en` (`updated_at`) y de marcador de cambios pendientes (`dirty`).
  2. **Push ciego de toda la base local antes del Pull (`lib/providers/gasto_provider.dart:L326-L333`):**
     - En `sincronizarConFirestore()`, siempre que `descartarDatosLocales` es `false` (el flujo normal), la app móvil ejecuta **primero** `await _syncService.pushAllLocalDataToCloud()` (`L327`) y **después** `await _syncService.pullGastosFromCloud()` (`L332`).
     - `pushAllLocalDataToCloud()` (`lib/services/sync_service.dart:L492-L530`) lee **todos** los gastos de SQLite (`_dbHelper.getAllGastos()`) y hace `batch.set(docRef, data, SetOptions(merge: true))` en Firestore para cada uno (`L505`).
  3. **Consecuencia 1 (Pérdida de ediciones hechas en Web):** Si el usuario edita un gasto en `https://rindemas.cesarluis.com/panel` (`landing/src/pages/panel.astro:L1640-L1711`) y luego abre la app móvil (o pulsa sincronizar), `pushAllLocalDataToCloud()` sube la versión vieja almacenada en el SQLite del teléfono y **sobrescribe en Firestore la edición más reciente hecha en la web** antes de que `pullGastosFromCloud()` llegue a ejecutarse.
  4. **Consecuencia 2 (Resurrección de gastos eliminados en Web):** Si el usuario elimina un gasto desde el panel web (`panel.astro:L1614-L1638`), el documento desaparece de Firestore pero sigue existiendo en el SQLite del teléfono. Al abrir la app móvil, `pushAllLocalDataToCloud()` vuelve a subir el gasto eliminado a Firestore; y como `pullGastosFromCloud()` (`lib/services/sync_service.dart:L533-L619`) solo inserta/actualiza documentos presentes en el snapshot sin conciliar eliminaciones, los gastos borrados en la web "resucitan" permanentemente.
- **Acción recomendada:** Añadir `actualizado_en` (`ISO-8601`) y `pendiente_sync` (`0/1`) en SQLite; hacer que `pushAllLocalDataToCloud` solo envíe registros con `pendiente_sync == 1` (comparando `actualizado_en`), o ejecutar primero el `pull` comparando marcas de tiempo y propagar bajas mediante *tombstones* o conciliación de UUIDs sincronizados.

#### ✅ [F4-I01] [RESUELTO EN LOTE 3] Ruptura del límite de 500 operaciones por `WriteBatch` de Firestore en `SyncService.eliminarCuentaYDatos`
- **Severidad:** 🟠 Importante (Impide eliminar la cuenta a usuarios con historial medio/alto, incumpliendo políticas de Google Play Data Safety).
- **Evidencia en código:**
  - En [`lib/services/sync_service.dart:L361-L379`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L361-L379), `eliminarCuentaYDatos` instancia un único `final batch = _firestore.batch();` (`L361`) y vuelca en él todos los documentos de `gastos` (`L365-L367`), todos los de `presupuestos` (`L371-L373`) y el documento `users/{uid}` (`L378`), llamando a `await batch.commit()` en `L379`.
  - Cloud Firestore impone un límite estricto de **500 operaciones por `WriteBatch`**. A diferencia de `pushAllLocalDataToCloud` (que en `L498` fragmenta en lotes de `batchSize = 400`), `eliminarCuentaYDatos` no fragmenta el lote: cualquier usuario con más de ~485 gastos recibirá un `FirebaseException (INVALID_ARGUMENT: maximum 500 writes allowed per batch)` y el borrado de su cuenta fallará.

#### ✅ [F4-I02] [RESUELTO EN LOTE 3] Cascada de Timeouts en `ExchangeRateService` y condición de carrera al cambiar fechas en `ReviewExpenseScreen`
- **Severidad:** 🟠 Importante (Bloqueos de hasta 26 segundos en redes lentas y sobrescritura de tasa histórica en UI).
- **Evidencia en código:**
  - En `lib/services/exchange_rate_service.dart:L131-L263`, cuando el endpoint primario del Worker (`/tasas`, timeout `6s` en `L138`) no responde o no trae las tres tasas, `fetchVesUsdRate`, `fetchVesEurRate` y `fetchVesUsdtRate` iteran secuencialmente hasta 4 URLs de respaldo con timeouts de `6s + 6s + 6s + 8s = 26 segundos` (`L174, L197, L215, L242`).
  - En `lib/ui/screens/review_expense_screen.dart:L502-L590` (`_fetchTasaHistoricaParaFecha`), si el usuario cambia la fecha de la compra dos veces seguidas en el selector, se disparan dos peticiones asíncronas concurrentes sin un contador de generación (`requestId`); si la primera petición (más lenta) termina después de la segunda, sobrescribe `_tasaController.text` (`L557`) con la tasa de la fecha anterior.

---

### 4.2. Escalabilidad y Rendimiento (SQLite, Memoria y `build()`)

#### ✅ [F4-I03] [RESUELTO EN LOTE 3] Problema de Consultas `N+1` en SQLite (`getAllGastos`, `getGastosRecientes`, `getGastosByMonth`)
- **Severidad:** 🟠 Importante (Degradación progresiva al acumular cientos o miles de gastos).
- **Evidencia en código:**
  - En [`lib/data/datasources/local/database_helper.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/local/database_helper.dart):
    - `getAllGastos()` (`L464-L485`): ejecuta `SELECT * FROM gastos` y luego, dentro de `for (var map in maps)` (`L472`), lanza una consulta SQL individual `await db.query('items_gasto', where: 'gasto_id = ?', whereArgs: [gastoId])` (`L474-L478`) por cada gasto.
    - Exactamente el mismo patrón `N+1` se repite en `getGastosRecientes()` (`L515-L533`) y `getGastosByMonth()` (`L535-L553`).
  - Con 1.000 gastos registrados, abrir la búsqueda global en `ExpenseHistoryScreen._cargarTodosLosGastos` (`lib/ui/screens/expense_history_screen.dart:L72`) o sincronizar en `pushAllLocalDataToCloud` (`lib/services/sync_service.dart:L494`) ejecuta **1.001 consultas secuenciales a SQLite** a través del canal nativo de plataforma, cuando puede resolverse en **2 consultas** (`SELECT * FROM gastos ...` + `SELECT * FROM items_gasto WHERE gasto_id IN (...)` agrupando en un `Map<int, List<ItemGastoModel>>` en Dart).

#### 🟠 [F4-I04] Doble `jsonDecode` + Ordenamiento $O(N \log N)$ dentro de `build()` y `ListView` sin virtualización en `ExpenseHistoryScreen`
- **Severidad:** 🟠 Importante (Caída de fotogramas / *jank* al hacer scroll o escribir en el buscador de historial).
- **Evidencia en código:**
  1. **Cálculo pesado y doble parseo JSON en cada `build()` (`lib/ui/screens/expense_history_screen.dart:L144-L206` y `L326-L328`):**
     - Dentro de `build()`, en cada reconstrucción (incluyendo cada tecla pulsada en el buscador `_searchQuery`), el código itera `scanQueue.readyItems`, ejecuta `jsonDecode(item['extracted_data'])` y `GeminiExtractionResult.fromJson(data)` (`L147-L149`), filtra `baseGastos`, clona y ordena toda la lista `allGastos` (`L199`), y construye el mapa `groupedGastos` (`L201-L206`).
     - Más abajo, dentro del mismo `build()` (`L326-L328`), vuelve a ejecutar `jsonDecode(item['extracted_data'])` y `GeminiExtractionResult.fromJson(data)` **por segunda vez** para cada ítem pendiente de la cola.
  2. **`ListView(children: [...])` sin `ListView.builder` (`lib/ui/screens/expense_history_screen.dart:L298-L415`):**
     - Usa el constructor `ListView(children: [ for (final entry in groupedGastos.entries) ... ])` en lugar de `ListView.builder`. Esto fuerza a Flutter a instanciar y medir en memoria **todas las tarjetas `ExpenseCard` del mes (o de todo el historial histórico durante una búsqueda global)** de una sola vez, en lugar de reciclarlas bajo demanda conforme el usuario hace scroll.

#### ✅ [F4-O01] [RESUELTO EN LOTE 3] Índices faltantes en SQLite para `scan_queue` y `tasas_historicas`
- **Severidad:** 🟢 Oportunidad de mejora (Optimización de consultas frecuentes).
- **Evidencia en código:**
  - En `lib/data/datasources/local/database_helper.dart:L395-L398`, se crean índices para `gastos(fecha)`, `gastos(uuid)` e `items_gasto(gasto_id)`, pero faltan índices para:
    - `scan_queue(status)` y `scan_queue(image_hash)` (consultados en `getPendingScanItems`, `findDuplicateInQueue` y `findDuplicateInGastos` en `L1343-L1430`).
    - `tasas_historicas(moneda, fecha)` (consultado con `WHERE moneda = ? AND fecha <= ? ORDER BY fecha DESC LIMIT 1` en `getTasaHistorica` en `L723-L735`).

---

### 4.3. Bloques `catch (_) {}` Silenciosos y Deuda Técnica

#### ✅ [F4-I05] [RESUELTO EN LOTE 3] Más de 25 bloques `catch (_) {}` silenciosos en capas críticas de Almacenamiento Seguro, Sincronización y Cola IA
- **Severidad:** 🟠 Importante (Violación directa de `AGENTS.md:L47`: *"Nunca silenciar excepciones en bloques `catch (_) {}` sin registrar el error en capas críticas"*).
- **Evidencia exacta en código:**
  - **`SettingsProvider` (`lib/providers/settings_provider.dart`):** `L70, L97, L111, L121, L199, L234, L242, L256` — silencia fallos de lectura/escritura en `FlutterSecureStorage` y fallos de `SyncService.pushUserSettings` sin siquiera un `debugPrint`.
  - **`SyncService` (`lib/services/sync_service.dart`):** `L122, L136, L174, L294, L299, L320, L333, L375, L522, L611, L662, L736, L754, L768, L797` — silencia errores al sincronizar listas de compras, presupuestos, borrado de documentos en la nube y telemetría de errores.
  - **`ScanQueueProvider` (`lib/providers/scan_queue_provider.dart`):** `L284, L521, L562` — silencia fallos al borrar archivos temporales o actualizar estados de la cola.
  - **`ChatScreen` (`lib/ui/screens/chat_screen.dart`):** `L525` — silencia fallos al encolar gastos extraídos por el asistente.

#### 🟢 [F4-O02] Código Duplicado y Directorios Obsoletos en el Repositorio
- **Severidad:** 🟢 Oportunidad de mejora (Higiene de arquitectura y mantenimiento).
- **Evidencia en código:**
  1. **Duplicación íntegra del Cloudflare Worker:** `cloudflare_worker/src/index.js` (`969 líneas`) y `workers/src/index.js` (`969 líneas`) son copias idénticas; mantener ambos directorios genera riesgo de editar el archivo equivocado en futuros despliegues.
  2. **Directorio legacy `firebase_functions/`:** Contiene código antiguo de Cloud Functions que fue reemplazado por el Cloudflare Worker, además de mantener `firebase_functions/node_modules/` versionado en Git y el archivo local `firebase_functions/.env.gastoscan-ai`.
  3. **Ruptura parcial de la capa `GastoRepository`:** Aunque existe `lib/data/repositories/gasto_repository.dart`, clases como `ChatScreen` (`lib/ui/screens/chat_screen.dart:L313, L320`), `ShoppingListScreen` y `SyncService` invocan a `DatabaseHelper.instance` directamente.

---

## FASE 5: Plan Maestro de Corrección por Lotes (Actionable Roadmap)

Para ejecutar todas las correcciones sin romper la suite de pruebas en GitHub Actions CI y respetando el protocolo de **Tareas Críticas** (`AGENTS.md`), el trabajo se divide en **4 Lotes (Sprints Técnicos)** autocontenidos y ordenados por prioridad:

| Lote | Enfoque Principal | Hallazgos Incluidos | Nivel de Criticidad |
| :--- | :--- | :--- | :--- |
| **Lote 1** | Blindaje de Seguridad, Secretos, Reglas Firestore y XSS Web | `[F2-C01]`, `[F2-C02]`, `[F2-C03]` ✅, `[F2-C04]` ✅, `[F2-C05]` ✅ (Worker), `[F2-I01]` ✅, `[F2-I02]` ✅, `[F2-O01]` | 🔴 Crítico (Seguridad / Privacidad — En validación 🧪) |
| **Lote 2** | Exactitud Matemática Multimoneda y Paridad Móvil / Web | `[F1-C01]` ✅, `[F1-C02]` ✅, `[F1-C03]` ✅, `[F1-C04]` ✅, `[F1-I01]` ✅, `[F1-I02]` ✅, `[F1-I03]` ✅, `[F1-I04]` ✅, `[F1-I05]` ✅, `[F1-I06]` ✅, `[F3-I03]` ✅ | 🔴 Crítico (Completado en código / En validación 🧪) |
| **Lote 3** | Integridad de Sincronización Cloud/Offline, Privacidad Local y SQLite | `[F4-C01]` ✅, `[F4-C02]` ✅, `[F4-I01]` ✅, `[F4-I02]` ✅, `[F4-I03]` ✅, `[F4-I05]` ✅, `[F4-O01]` ✅, `[F2-I03]` ✅ | 🔴 Crítico (Completado en código / En validación 🧪) |
| **Lote 4** | Resiliencia UI en Bolívares (`RenderFlex`), Coherencia `DESIGN.md` y UX | `[F3-C01]` ✅, `[F3-I06]` ✅, `[F4-I04]` ✅, `[F4-O02]` ✅, `[F3-I02]` ✅ | 🟠 Importante (Completado en código / En validación 🧪) |

---

### Detalle Técnico de Ejecución por Lote

#### 🛡️ LOTE 1: Blindaje de Seguridad, Secretos, Reglas Firestore y Sanitización XSS Web
- **Objetivo:** Eliminar cualquier riesgo de ejecución de scripts (XSS) en el panel web, retirar secretos en texto plano del repositorio/Firestore y endurecer la validación en `firestore.rules` y el Cloudflare Worker.
- **Hallazgos que resuelve:** `[F2-C01]`, `[F2-C02]`, `[F2-C03]`, `[F2-C04]`, `[F2-C05]`, `[F2-I01]`, `[F2-I02]`, `[F2-O01]`.
- **Archivos exactos a modificar:**
  - `landing/src/pages/panel.astro`: Crear helper `escapeHtml(str)` y aplicarlo en `renderExpensesTable` (`L1456-L1546`), `renderCategories` (`L1400-L1432`), `openEditExpenseModal` (`L1579`) y `renderBudgetHistoryModal` (`L1838`); corregir también la condición `state.expenses.length` en `L1755` (`[F1-I06]`).
  - `lib/services/sync_service.dart` y `lib/providers/settings_provider.dart`: Eliminar la subida/descarga de `gemini_api_key` en texto plano dentro de `presupuestos/user_settings` (`[F2-C03]`), conservándola únicamente en `FlutterSecureStorage`.
  - `lib/services/gemini_service.dart`: Enviar la API Key exclusivamente por cabecera `x-goog-api-key` eliminando `?key=` de las URLs (`[F2-I01]`).
  - `lib/services/export_service.dart`: Sanitizar prefijos de fórmula (`=`, `+`, `-`, `@`) en `_escapeCsv` (`[F2-I02]`).
  - `firestore.rules`: Validar esquema y tipos en `gastos`, `presupuestos`, `listas` y `error_logs`, y restringir escritura en `rate_limits` (`[F2-C02]`). *(Requiere confirmación previa de César según Semáforo Amarillo).*
  - `workers/src/index.js`: Añadir límite de tamaño de payload (`content-length` / `body.length`) y rate-limit para `/tasas` (`[F2-C05]`).
  - `.gitignore`, `.github/workflows/build_apk.yml` y `android/app/build.gradle.kts`: Migrar `rindemas.jks` y contraseñas a GitHub Secrets y limpiar `firebase_functions/` (`[F2-C01]`, `[F2-O01]`). *(Requiere coordinación con César para configurar los Secrets en GitHub).*

#### 💱 LOTE 2: Exactitud Matemática Multimoneda y Paridad Móvil / Web
- **Objetivo:** Garantizar precisión aritmética e histórica absoluta entre `VES`, `USD BCV`, `USDT P2P` y `EUR BCV` tanto en Flutter como en el panel web, y eliminar la inflación de montos por IVA duplicado en OCR.
- **Hallazgos que resuelve:** `[F1-C01]`, `[F1-C02]`, `[F1-C03]`, `[F1-C04]`, `[F1-I01]`, `[F1-I02]`, `[F1-I03]`, `[F1-I04]`, `[F1-I05]`.
- **Archivos exactos a modificar:**
  - `lib/ui/widgets/ai_insight_card.dart`: Corregir la doble multiplicación por `tasaActual` cuando `monedaPresupuesto == 'VES'` y añadir soporte completo al lente activo (`VES`, `USD`, `USDT`, `EUR`) (`[F1-C03]`, `[F3-I03]`).
  - `lib/services/gemini_service.dart`: Eliminar la inyección del renglón artificial `'Impuesto IVA'` cuando `items.isNotEmpty`, agregar `'Higiene'` a `validCategories` y aceptar `'USDT'` en `monedaDetectada` (`[F1-C04]`).
  - `lib/providers/gasto_provider.dart`:
    - Unificar la conversión histórica del lente `EUR` usando la tasa implícita del gasto cuando `moneda == 'EUR'` (`[F1-C01]`).
    - Soportar presupuestos en `USDT` y `EUR` dentro de `savingsSnapshot` y `getSpentForCategory` (`[F1-I03]`).
    - Permitir reindexar gastos con `monedaIndexada == 'EUR'` en `actualizarGasto` (`[F1-I02]`).
  - `lib/ui/widgets/budget_bottom_sheet.dart`: Redondear a 2 decimales con `CurrencyFormatter.round2()` al convertir el presupuesto general y los sub-presupuestos por categoría antes de guardar (`[F1-I01]`).
  - `lib/ui/widgets/category_chart.dart`: Actualizar `_getItemAmountInLens` para usar `gasto.montoEnUsd` / `gasto.montoEnVes` históricos en lugar de `tasaActual` del día (`[F1-I05]`).
  - `landing/src/pages/panel.astro`:
    - En `getExpenseInLens` (`L1069-L1097`), calcular la tasa implícita histórica del gasto (`monto_ves / monto_usd`) para convertir a `USDT` cuando no exista `tasa_usdt` guardada, en lugar de usar `state.rates.usdt` de hoy (`[F1-C02]`).
    - En `saveExpenseModal` (`L1651-L1664`), guardar `tasa_cambio = rateEur` cuando `moneda === 'EUR'` (`[F1-C02]`).
    - En `updateMetrics` (`L1288-L1298`), usar el porcentaje real (`pct`) para el ancho visual y el color de alerta de la barra de progreso (`[F1-I04]`).

#### 🔄 LOTE 3: Integridad de Sincronización Cloud/Offline, Privacidad Local y Rendimiento SQLite
- **Objetivo:** Blindar `SyncService` contra cortes de internet en Venezuela, evitar que la app móvil sobrescriba ediciones hechas en el panel web, limpiar residuos al cerrar sesión y eliminar las consultas `N+1` en SQLite.
- **Hallazgos que resuelve:** `[F4-C01]`, `[F4-C02]`, `[F4-I01]`, `[F4-I02]`, `[F4-I03]`, `[F4-I05]`, `[F4-O01]`, `[F2-I03]`.
- **Archivos exactos a modificar:**
  - `lib/services/sync_service.dart` y `lib/providers/gasto_provider.dart`:
    - En `pullGastosFromCloud`, descargar los snapshots de Firestore **antes** de ejecutar `_dbHelper.clearAllUserData()` (`[F4-C01]`).
    - Corregir el orden y conciliación en `sincronizarConFirestore` para no sobrescribir ediciones más recientes hechas en `panel.astro` ni revivir gastos eliminados (`[F4-C02]`).
    - Fragmentar `eliminarCuentaYDatos` en lotes de máximo 400 operaciones por `WriteBatch` (`[F4-I01]`).
    - Registrar errores con `debugPrint` en lugar de bloques `catch (_) {}` vacíos (`[F4-I05]`).
  - `lib/data/datasources/local/database_helper.dart`:
    - Reemplazar el bucle de consultas `N+1` en `getAllGastos`, `getGastosRecientes` y `getGastosByMonth` por carga agrupada de `items_gasto` (`WHERE gasto_id IN (...)`) (`[F4-I03]`).
    - En `clearAllUserData()`, incluir el borrado de archivos físicos de imágenes (`receipts`) y de preferencias financieras locales (`[F2-I03]`).
    - Añadir índices SQLite para `scan_queue(status)`, `scan_queue(image_hash)` y `tasas_historicas(moneda, fecha)` (`[F4-O01]`).
  - `lib/ui/screens/more_screen.dart`: Limpiar `ChatProvider.limpiarHistorial()` y preferencias locales al cerrar sesión o eliminar cuenta (`[F2-I03]`).
  - `lib/ui/screens/review_expense_screen.dart`: Añadir control de carrera (token/ID de petición) en `_fetchTasaHistoricaParaFecha` (`[F4-I02]`).

#### 🎨 LOTE 4: Resiliencia UI en Bolívares (`RenderFlex`), Coherencia `DESIGN.md` y Fluidez UX
- **Objetivo:** Erradicar todos los desbordamientos horizontales con cifras millonarias en `VES` en pantallas de `360dp`, alinear los colores semánticos con `DESIGN.md`, virtualizar el historial de gastos y pulir los flujos de escaneo y voz.
- **Hallazgos que resuelve:** `[F3-C01]`, `[F3-I01]`, `[F3-I02]`, `[F3-I03]`, `[F3-I04]`, `[F3-I05]`, `[F3-I06]`, `[F4-I04]`, `[F4-O02]`.
- **Archivos exactos a modificar:**
  - `lib/ui/widgets/summary_card.dart`, `lib/ui/screens/analysis_screen.dart`, `lib/ui/screens/expense_history_screen.dart`, `lib/ui/widgets/pending_expense_card.dart` y `lib/ui/screens/more_screen.dart`:
    - Proteger todas las filas de montos con `Flexible` / `Expanded` y `FittedBox(fit: BoxFit.scaleDown)` en los montos héroe de `32sp` (`[F3-C01]`).
  - `lib/core/constants/app_colors.dart` y `landing/src/pages/panel.astro`:
    - Alinear `getBudgetProgressColor` y las barras de progreso web con `#1E293B` (`slate-800`) para gasto normal `< 80%`, reservando el verde exclusivamente para dinero disponible (`[F3-I01]`), y elevar el contraste de `text-slate-400` a `text-slate-600` (`[F3-I02]`).
  - `lib/ui/screens/dashboard_screen.dart`: Pasar `settings.monedaPrincipal` a `AiInsightCard` para que hable en el mismo lente activo que `SummaryCard` (`[F3-I03]`).
  - `lib/ui/widgets/voice_expense_sheet.dart` y `lib/ui/widgets/auth_modal_sheet.dart`: Ocultar excepciones técnicas crudas (`$e`) y mostrar mensajes amigables (`[F3-I04]`).
  - `lib/ui/screens/chat_screen.dart`: Manejar y mostrar todas las compras extraídas cuando el usuario dicta múltiples gastos en un solo mensaje (`[F3-I05]`).
  - `lib/ui/screens/main_screen.dart` y `lib/providers/scan_queue_provider.dart`: Integrar `DocumentScannerService` al escanear desde el menú `+` y unificar la evaluación de calidad OCR con `LocalOcrService.evaluateQuality` (`[F3-I06]`).
  - `lib/ui/screens/expense_history_screen.dart`: Migrar `ListView(children: ...)` a `ListView.builder` y eliminar el doble `jsonDecode` dentro de `build()` (`[F4-I04]`).
