# `RM-03-fase-0-especificacion-adjudicada-v1.2.md`

**Proyecto:** Rinde Más (`AppConstants.appName`)  
**Commit de referencia:** `38df292` (`HEAD` en `main`)  
**Estado del documento:** Especificación Técnica Adjudicada Definitiva — **Versión 1.2 (Cierre de Fase 0A y Autorización de `E0-02`)**  
**Modo de ejecución actual:** Modo Plan (Solo lectura; cero mutaciones en repositorio, esquemas, reglas o datos)

---

## 0. Resumen de Cambios (`v1.1` $\rightarrow$ `v1.2`)

Esta versión `v1.2` constituye el pliego normativo de cierre sobre `RM-03-fase-0-especificacion-adjudicada-v1.1.md`. Mantiene intactas las secciones de `v1.1` no modificadas aquí y **reemplaza normativamente** los cuatro puntos abiertos antes de iniciar `E0-02`:

| Punto | Defecto en `v1.1` | Resolución normativa en `v1.2` |
| :--- | :--- | :--- |
| **1. `EUR + BS_USDT`** | En §6.1 Caso 6 se multiplicaba `montoOriginalCentavos * rUsdt` tanto para `USD` como para `EUR`, asumiendo implícitamente paridad $1\text{ EUR} = 1\text{ USDT}$. | **Bloqueo en Fase 0A** de la combinación `monedaOriginal == 'EUR'` con `MetodoLiquidacion.bsUsdt` en [`buildNewExpenseTuple`](#13-regla-operativa-en-buildnewexpensetuple-y-ui), [`ReviewExpenseScreen`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart) y [`panel.astro`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro). Se documenta la decisión de producto faltante para `v19`. |
| **2. Validación de `RateQuoteInput`** | Validar solo `valor > 1.0 && fuente != 'USD_REFERENCIA'` permitía inyectar una tasa `USD` o P2P en el mercado equivocado bajo etiquetas genéricas como `'Gateway'` o `'DolarAPI'`. | **Validación tipada por mercado y origen (`RateMarket` + `RateSourceId`)**, invariantes estrictos de fecha (`fechaSolicitada == fechaGasto`, `fechaEfectiva <= fechaSolicitada`), exigencia de `confirmadaPorUsuario` en tasas de referencia/manuales y batería de pruebas negativas. |
| **3. Semántica de `persistidoNoVerificado`** | `puedeUsarseParaDerivar == true` en tasas `persistidoNoVerificado` permitía fabricar equivalencias faltantes y etiquetarlas como `derivable`, mezclando montos verificados y no verificados. | **Eliminación de derivación cruzada en lectura v18:** `identidadOrigen` es el único monto verificado; `persistidoNoVerificado` solo se lee en su propia columna; para `USD`/`EUR`/`USDT` con columna nula/`0` se devuelve `pendiente`; solo la lente `VES` calcula `calculadoNoVerificado` desde `total_original`. Contabilidad separada (`totalVerificadoOrigen` vs `totalNoVerificado`). |
| **4. Garantías de Sync, Tombstones y `sonContenidoNegocioIdentico`** | 1) Se trataba el CAS por `actualizado_en` como garantía absoluta. 2) Un tombstone remoto borraba físicamente filas locales con `synced = 0`. 3) `sonContenidoNegocioIdentico` usaba `.trim()`, omitía `eliminadoEn` y normalizaba categorías. | 1) Declaración explícita de límites del CAS optimista en v18. 2) Protección de `synced = 0` frente a tombstone remoto (`ConflictoTombstoneRemoto`, prohibido `eliminarGastoFisico`). 3) Comparación canónica exacta sobre todos los campos de [`GastoFirestoreMapper.toPayload`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/models/gasto_firestore_mapper.dart#L13-L48). |

---

## 1. Corrección Matemática y de Producto: `EUR + BS_USDT` (Reemplaza §6.1 Caso 6 de `v1.1`)

### 1.1 Hechos verificados en el código de `38df292`

1. **En móvil ([`lib/ui/screens/review_expense_screen.dart:1110-1142`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L1110-L1142)):**
   - Cuando el usuario elige `_selectedMoneda == 'EUR'` y `_metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsUsdt`, la línea 1131 ejecuta:
     ```dart
     totalVesCalculado = (manualBs != null && manualBs > 0)
         ? manualBs
         : (totalOrig * tasaUsdtEfectiva);
     ```
     donde `totalOrig` está expresado en **EUR** y `tasaUsdtEfectiva` está expresada en **`VES / USDT`**. Multiplicar $\text{EUR} \times (\text{VES}/\text{USDT})$ es dimensionalmente inválido y presupone que $1\text{ EUR} = 1\text{ USDT}$.
   - En la línea 1114, `tasaBcv = _effectiveBcvRate(settings)` devuelve la tasa **`VES / EUR`** ([`review_expense_screen.dart:549-560`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L549-L560)), la guarda en `tasa_cambio`, pero guarda `moneda: 'VES'` y calcula `totalUsdGuardar = totalVesCalculado / tasaUsdBcv` y `totalUsdtGuardar = totalVesCalculado / tasaUsdtEfectiva`.
   - Al reabrir ese gasto para edición ([`review_expense_screen.dart:356-360`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L356-L360)), como `isIndexedUsdt` es verdadero (`fuente_tasa_cambio == 'USDT_INDEXADO'`), toma `indexedAmount = gasto.totalUsdtDisplay` y restaura `_selectedMoneda = 'USD'`, perdiendo por completo que la referencia original era `EUR`.

2. **En el panel web ([`landing/src/pages/panel.astro:2663-2686,2716-2718`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2663-L2686)):**
   - Cuando `expMoneda === 'EUR'` y `selectedLiq === 'BS_USDT'`, la línea 2668 ejecuta `const bsFinal = bsManual > 0 ? bsManual : (monto * tasaUsdt);` ($\text{EUR} \times \text{VES}/\text{USDT}$, asumiendo nuevamente $1\text{ EUR} = 1\text{ USDT}$).
   - La línea 2685 asigna `fuenteTasa = 'Binance P2P (Pago en Bs. indexado a USDT)'`, sobrescribiendo cualquier rastro de `EUR`, y al reabrir el gasto ([`panel.astro:2499,2520-2529`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro#L2499-L2529)) lo interpreta como `USD`.

### 1.2 Análisis económico y dimensional

1. **Qué significa económicamente un precio en `EUR` cobrado en `VES` fuera de BCV:** El comercio fija un precio de referencia de $M_{\text{EUR}}$ euros, pero exige el pago en bolívares a una tasa superior a `EUR BCV`.
2. **Qué moneda representa el importe de referencia:** Euros (`EUR`), nunca `USD` ni `USDT`.
3. **Qué tasa corresponde realmente a esa referencia:** Para convertir $M_{\text{EUR}}$ directamente a bolívares sin encadenar divisas se requeriría una tasa de liquidación expresada en **`VES / EUR` de mercado libre/P2P** ($R_{\text{EUR\_P2P}}$), o bien el monto exacto en bolívares efectivamente transferido ($M_{\text{VES\_pagado}}$).
4. **Por qué no puede calcularse con las 3 tasas del sistema (`rUsd`, `rEur`, `rUsdt`):**
   - Multiplicar $M_{\text{EUR}} \times r_{\text{USDT}}$ asume $1\text{ EUR} = 1\text{ USDT}$ (**prohibido por A-03** y [`.agents/rules/dinero-datos.md:9`](file:///c:/Development/Control%20de%20gastos%20VE/.agents/rules/dinero-datos.md#L9)).
   - Derivar una tasa implícita `VES / EUR P2P` mediante $r_{\text{USDT}} \times (r_{\text{EUR}} / r_{\text{USD}})$ encadena tres mercados distintos ($\text{EUR BCV} \rightarrow \text{USD BCV} \rightarrow \text{USDT P2P}$), lo cual es un **encadenamiento prohibido por C-04 y A-03** y no está respaldado por ningún contrato de producto.

### 1.3 Regla operativa en `buildNewExpenseTuple` y UI

1. **Bloqueo normativo en Fase 0A:** La combinación `monedaOriginal == 'EUR'` + `metodo == MetodoLiquidacion.bsUsdt` queda **bloqueada** en Fase 0A:
   - En `buildNewExpenseTuple`: si `monedaOriginal == 'EUR'` y `metodo == MetodoLiquidacion.bsUsdt`, devuelve inmediatamente:
     ```dart
     TupleBuildFailure(
       code: TupleFailureCode.combinacionMonedaLiquidacionNoSoportada,
       userMessage: 'El pago en Bs. indexado a USDT solo aplica a precios en USD/USDT. '
           'Si el precio estaba en EUR y pagaste en Bs. a otra tasa, registra el monto pagado en Bs. (VES).',
     )
     ```
   - En [`ReviewExpenseScreen`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart) y en [`panel.astro`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro): cuando la moneda seleccionada es `'EUR'`, el selector de método de liquidación solo habilita:
     - `DIVISA` (*"En efectivo / Divisa directa EUR"*), y
     - `BS_BCV` (*"Pagado en Bs. a tasa EUR BCV"*).
     La opción `BS_USDT` se oculta o deshabilita cuando `moneda == 'EUR'`. Si el usuario tenía seleccionado `BS_USDT` en `'USD'` y cambia el selector de moneda a `'EUR'`, el estado de liquidación conmuta automáticamente a `BS_BCV`.
2. **Fórmula corregida de §6.1 Caso 5 y Caso 6 (`buildNewExpenseTuple`):**
   - **Caso 5 (`monedaOriginal == 'EUR'`, `metodo == MetodoLiquidacion.bsBcv`):**
     - `monedaPersistida = 'VES'`
     - $\text{total\_original} = \text{round}(M_{\text{EUR\_centavos}} \times r_{\text{EUR}})$
     - $\text{total\_eur} = M_{\text{EUR\_centavos}}$ (preservación exacta de la referencia en `EUR`)
     - $\text{total\_usd} = \text{round}(\text{total\_original} / r_{\text{USD}})$
     - $\text{total\_usdt} = \text{round}(\text{total\_original} / r_{\text{USDT}})$
     - `tasa_cambio = rUsd`, `tasa_eur = rEur`, `tasa_usdt = rUsdt`, `fuente_tasa_cambio = 'EUR_BCV_INDEXADO'`
   - **Caso 6 (`monedaOriginal == 'USD'`, `metodo == MetodoLiquidacion.bsUsdt`):** *(Exclusivo para `monedaOriginal == 'USD'`)*
     - `monedaPersistida = 'VES'`
     - $\text{total\_original} = (M_{\text{VES\_manual\_centavos}} \neq \text{null} \land M_{\text{VES\_manual\_centavos}} > 0) \text{ ? } M_{\text{VES\_manual\_centavos}} : \text{round}(M_{\text{USD\_centavos}} \times r_{\text{USDT}})$
     - $\text{total\_usdt} = M_{\text{USD\_centavos}}$ (preservación exacta del precio de referencia indexado a P2P)
     - $\text{total\_usd} = \text{round}(\text{total\_original} / r_{\text{USD}})$
     - $\text{total\_eur} = \text{round}(\text{total\_original} / r_{\text{EUR}})$
     - `tasa_cambio = rUsd`, `tasa_eur = rEur`, `tasa_usdt = rUsdt`, `fuente_tasa_cambio = 'USDT_INDEXADO'`

### 1.4 Decisión de producto faltante (diferida a `v19`)

Si en el futuro se desea soportar gastos con referencia en `EUR` pagados en `VES` a tasa no oficial, César deberá decidir para `v19` entre dos contratos posibles:
- **Opción P1 (Monto VES real + referencia EUR informativa):** El usuario ingresa obligatoriamente el monto en `EUR` y el monto real pagado en `VES` (`manualBs`), sin usar `rUsdt`, almacenando `metodo_liquidacion = 'EUR_VES_MANUAL'`.
- **Opción P2 (Tasa manual `VES/EUR` de liquidación):** El usuario ingresa el monto en `EUR` y una tasa explícita `VES/EUR` acordada con el comercio, con la cual se calcula `total_original (VES)` y luego `total_usd = total_original / rUsd` y `total_usdt = total_original / rUsdt`.

Mientras esa decisión no se tome e implemente en `v19`, `EUR + BS_USDT` permanece bloqueado.

---

## 2. Rediseño de Validación de `RateQuoteInput` (Reemplaza §5.1 de `v1.1`)

### 2.1 Por qué la validación de `v1.1` era insuficiente

En [`ExchangeRateService`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/exchange_rate_service.dart#L17-L44), las constantes actuales (`sourceGateway = 'Gateway'`, `sourceDolarApi = 'DolarAPI'`, `sourceYadio = 'Yadio'`, `sourceJsdelivr = 'jsDelivr'`, `sourceManual = 'Manual'`) identifican al **proveedor HTTP**, pero no al **mercado ni al campo extraído**. En consecuencia, evaluar `valor > 1.0 && fuente != 'USD_REFERENCIA'` no impide que por un bug de mapeo se entregue la cotización `USD BCV` dentro del slot de `cotizacionUsdt` o `cotizacionEur` con `fuente == 'Gateway'`.

### 2.2 Contrato tipado de procedencia por mercado (`RateMarket` y `RateSourceId`)

```dart
enum RateMarket {
  usdOficial, // VES / USD (BCV)
  eurOficial, // VES / EUR (BCV)
  usdtP2p,    // VES / USDT (P2P / Paralelo)
}

enum RateSourceId {
  // Mercado USD Oficial (VES/USD)
  gatewayUsdOficial,   // Cloudflare Worker: campo 'usd' / 'bcv'
  dolarApiUsdOficial,  // ve.dolarapi.com/v1/dolares/oficial -> 'promedio'
  yadioUsdOficial,     // api.yadio.io/exrates/ves -> 'VES.official'
  jsdelivrUsd,         // fawazahmed0 currency-api -> usd.json['usd']['ves']

  // Mercado EUR Oficial (VES/EUR)
  gatewayEurOficial,   // Cloudflare Worker: campo 'eur'
  dolarApiEurOficial,  // ve.dolarapi.com/v1/euros/oficial -> 'promedio'
  jsdelivrEur,         // fawazahmed0 currency-api -> eur.json['eur']['ves']
  yadioEurRatio,       // api.yadio.io: official * (VES/EUR)

  // Mercado USDT P2P (VES/USDT)
  gatewayUsdtP2p,      // Cloudflare Worker: campo 'usdt' / 'paralelo'
  yadioUsdtP2p,        // api.yadio.io/exrates/ves -> 'VES.usd'
  dolarApiParalelo,    // ve.dolarapi.com/v1/dolares/paralelo -> 'promedio'

  // Ingreso manual explícito del usuario
  manualUsuario,
}

Set<RateSourceId> allowedSourcesForMarket(RateMarket market) {
  switch (market) {
    case RateMarket.usdOficial:
      return const {
        RateSourceId.gatewayUsdOficial,
        RateSourceId.dolarApiUsdOficial,
        RateSourceId.yadioUsdOficial,
        RateSourceId.jsdelivrUsd,
        RateSourceId.manualUsuario,
      };
    case RateMarket.eurOficial:
      return const {
        RateSourceId.gatewayEurOficial,
        RateSourceId.dolarApiEurOficial,
        RateSourceId.jsdelivrEur,
        RateSourceId.yadioEurRatio,
        RateSourceId.manualUsuario,
      };
    case RateMarket.usdtP2p:
      return const {
        RateSourceId.gatewayUsdtP2p,
        RateSourceId.yadioUsdtP2p,
        RateSourceId.dolarApiParalelo,
        RateSourceId.manualUsuario,
      };
  }
}
```

### 2.3 Estructura y reglas de validación de `RateQuoteInput`

```dart
enum QuoteValidationError {
  mercadoIncorrecto,
  fuenteNoAutorizadaParaMercado,
  endpointCampoVacio,
  valorFueraDeDominio,
  fechaSolicitadaNoCoincideConGasto,
  formatoFechaInvalido,
  fechaEfectivaFutura,
  fechaEfectivaAnteriorMinima,
  inconsistenciaExactitudFecha,
  referenciaSinConfirmacionUsuario,
  manualSinConfirmacionUsuario,
}

class RateQuoteInput {
  final RateMarket mercado;
  final RateSourceId sourceId;
  final String endpointOrField;     // Ej. 'worker:/rates#eur', 'dolarapi:/v1/dolares/oficial#promedio', 'manual:input_tasa'
  final double valor;               // VES por 1 unidad de [mercado]
  final String fechaSolicitada;     // YYYY-MM-DD
  final String fechaEfectiva;       // YYYY-MM-DD
  final bool esExacta;              // true solo si es tasa oficial/P2P exacta de la fechaSolicitada
  final bool esReferencia;          // true si proviene de fallback temporal (<= 5 días) o caché no exacta
  final bool confirmadaPorUsuario;  // true si el usuario aceptó explícitamente usar referencia o ingresó tasa manual

  const RateQuoteInput({
    required this.mercado,
    required this.sourceId,
    required this.endpointOrField,
    required this.valor,
    required this.fechaSolicitada,
    required this.fechaEfectiva,
    required this.esExacta,
    required this.esReferencia,
    this.confirmadaPorUsuario = false,
  });

  static final RegExp _isoDateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static const String _minValidDate = '2023-01-03';

  QuoteValidationError? validateFor({
    required RateMarket expectedMarket,
    required String fechaGasto,
  }) {
    // 1. Mercado esperado por el slot
    if (mercado != expectedMarket) {
      return QuoteValidationError.mercadoIncorrecto;
    }

    // 2. Fuente autorizada para el mercado concreto
    if (!allowedSourcesForMarket(expectedMarket).contains(sourceId)) {
      return QuoteValidationError.fuenteNoAutorizadaParaMercado;
    }

    // 3. Trazabilidad de endpoint o campo de respuesta
    if (endpointOrField.trim().isEmpty) {
      return QuoteValidationError.endpointCampoVacio;
    }

    // 4. Dominio numérico (I1/I2/I3: > 1.0 y finito)
    if (!valor.isFinite || valor <= 1.0) {
      return QuoteValidationError.valorFueraDeDominio;
    }

    // 5. Formato de fechas e igualdad fechaSolicitada == fechaGasto
    if (!_isoDateRegex.hasMatch(fechaSolicitada) ||
        !_isoDateRegex.hasMatch(fechaEfectiva) ||
        !_isoDateRegex.hasMatch(fechaGasto)) {
      return QuoteValidationError.formatoFechaInvalido;
    }
    if (fechaSolicitada != fechaGasto) {
      return QuoteValidationError.fechaSolicitadaNoCoincideConGasto;
    }

    // 6. Fecha efectiva nunca futura respecto a la fecha solicitada
    if (fechaEfectiva.compareTo(fechaSolicitada) > 0) {
      return QuoteValidationError.fechaEfectivaFutura;
    }

    // 7. Fecha efectiva >= 2023-01-03 para fuentes automáticas
    if (sourceId != RateSourceId.manualUsuario &&
        fechaEfectiva.compareTo(_minValidDate) < 0) {
      return QuoteValidationError.fechaEfectivaAnteriorMinima;
    }

    // 8. Tratamiento seguro de tasas manuales
    if (sourceId == RateSourceId.manualUsuario) {
      if (!confirmadaPorUsuario) {
        return QuoteValidationError.manualSinConfirmacionUsuario;
      }
      if (esExacta) {
        // Una tasa manual nunca se clasifica como cotización oficial exacta de mercado
        return QuoteValidationError.inconsistenciaExactitudFecha;
      }
      return null;
    }

    // 9. Coherencia entre exactitud, fechaEfectiva y flag de referencia
    if (esExacta) {
      if (fechaEfectiva != fechaSolicitada || esReferencia) {
        return QuoteValidationError.inconsistenciaExactitudFecha;
      }
    } else {
      // Si no es exacta (o esReferencia == true o fechaEfectiva < fechaSolicitada),
      // exige confirmación explícita del usuario antes de construir el tuple.
      if (!confirmadaPorUsuario) {
        return QuoteValidationError.referenciaSinConfirmacionUsuario;
      }
    }

    return null;
  }
}
```

### 2.4 Regla en `buildNewExpenseTuple`

Antes de ejecutar cualquier cálculo en `buildNewExpenseTuple`, se invocan obligatoriamente:
1. `cotizacionUsd.validateFor(expectedMarket: RateMarket.usdOficial, fechaGasto: fechaGasto)`
2. `cotizacionEur.validateFor(expectedMarket: RateMarket.eurOficial, fechaGasto: fechaGasto)`
3. `cotizacionUsdt.validateFor(expectedMarket: RateMarket.usdtP2p, fechaGasto: fechaGasto)`

Si cualquiera de las tres devuelve un `QuoteValidationError != null`, `buildNewExpenseTuple` aborta con `TupleBuildFailure` indicando el mercado y el código de error exacto. Queda **prohibido** construir un gasto nuevo si falta o falla cualquiera de las tres validaciones (política **A-01** y **A-04**).

---

## 3. Semántica de `persistidoNoVerificado` y `calculadoNoVerificado` (Reemplaza §5.2 y §6.2 de `v1.1`)

### 3.1 El problema de `v1.1` que se corrige

En `v1.1`, `ValorTasaResuelta.puedeUsarseParaDerivar` devolvía `true` para tasas con estado `persistidoNoVerificado`. Eso provocaba dos contradicciones:
1. Permitía usar una tasa sin procedencia individual certificada en SQLite v18 para derivar una columna secundaria nula (`total_usd`, `total_eur` o `total_usdt`) y etiquetar el resultado como `derivable`, ocultando que ni la tasa ni la equivalencia derivada tenían respaldo verificable.
2. En los lectores de totales (Dashboard, Presupuestos, Estadísticas), sumaba bajo una misma bolsa montos pagados en la moneda original (`identidadOrigen`) con equivalencias secundarias no verificadas.

### 3.2 Adjudicación expresa de los 5 criterios de lectura en v18

1. **Qué importes persistidos se tratan como verificados (`identidadOrigen`):**
   - **Únicamente** `g.totalOriginal` leído en su propia moneda `g.moneda` (es decir, cuando `lente == g.moneda` y `g.totalOriginal > 0`). Representa el hecho económico primario registrado por el usuario.

2. **Qué importes persistidos se tratan como no verificados (`persistidoNoVerificado`):**
   - Todo importe positivo almacenado en una columna de equivalencia secundaria (`total_usd`, `total_eur`, `total_usdt`) cuando `lente != g.moneda`, siempre que la fila supere los invariantes de coherencia (`I5`: paridad ilegítima `EUR == USD` con tasas distintas; `I6`: colapso `total == original` en `VES`).
   - Un importe `persistidoNoVerificado` **se muestra en su propia lente** (para no destruir la visibilidad de los datos en v18), pero **jamás se utiliza como puente para calcular otra moneda**.

3. **Cuándo se puede calcular una equivalencia ausente sin marcarla como verificada (`calculadoNoVerificado`):**
   - **Para las lentes `USD`, `EUR` y `USDT`:** SQLite v18 posee columnas dedicadas (`total_usd`, `total_eur`, `total_usdt`). Si `g.moneda != lente` y la columna correspondiente es `null` o `<= 0` (con `g.totalOriginal > 0`), **NO se deriva ni fabrica en lectura** a partir de tasas `persistidoNoVerificado`; la lente devuelve `EstadoValorMonetario.pendiente`.
   - **Exclusivamente para la lente `VES` cuando `g.moneda != 'VES'`:** Dado que SQLite v18 **no posee columna `total_ves`**, la única forma de expresar un gasto en divisas (`USD`, `EUR`, `USDT`) dentro de la lente `VES` es multiplicar `g.totalOriginal` (`identidadOrigen`) por la tasa de la moneda de origen (`tasaOrigenVes`).
     - Si la tasa de la moneda de origen (`tasa_cambio` para `USD`, `tasa_eur` para `EUR`, `tasa_usdt` para `USDT`) está presente (`> 1.0`) y su estado en `resolvePersistedExpense` es `EstadoTasaPersistida.persistidoNoVerificado` (es decir, **no** es `ausente`, ni `invalidoDominio`, ni `noVerificadoAmbiguo`), el lector calcula $\text{round}(\text{total\_original} \times \text{tasaOrigenVes})$ y lo etiqueta obligatoriamente como **`EstadoValorMonetario.calculadoNoVerificado`** (nunca como verificado).
     - Si la tasa de la moneda de origen es `ausente`, `invalidoDominio` o `noVerificadoAmbiguo` (ej. gasto en `EUR` cuya `tasa_eur == tasa_cambio` sin respaldo de paridad), la lente `VES` **no calcula** el monto y devuelve `EstadoValorMonetario.pendiente`.

4. **Cómo contabiliza cada lente sin mezclar totales verificados y no verificados (`ResumenLenteMonetario`):**
   - Todo agregador de lectura (`GastoProvider`, Dashboard, Presupuestos, Estadísticas, Exportación CSV y `panel.astro`) debe producir por cada lente el siguiente desglose:
     ```dart
     class ResumenLenteMonetario {
       final String monedaLente;
       final int totalVerificadoOrigenCentavos; // Suma exclusiva de identidadOrigen
       final int totalNoVerificadoCentavos;     // Suma de persistidoNoVerificado + calculadoNoVerificado (solo VES)
       final int noVerificadosCount;            // Cantidad de gastos en persistidoNoVerificado o calculadoNoVerificado
       final int pendientesCount;               // Cantidad de gastos en EstadoValorMonetario.pendiente
       final int incoherentesCount;             // Cantidad de gastos en EstadoValorMonetario.incoherente

       int get totalMostradoCentavos =>
           totalVerificadoOrigenCentavos + totalNoVerificadoCentavos;

       bool get tieneAdvertenciaCalidad =>
           pendientesCount > 0 || incoherentesCount > 0;
     }
     ```
   - De este modo:
     - Los gastos con estado `pendiente` o `incoherente` aportan `0` a `totalMostradoCentavos` (nunca se les inventa `0.00` silencioso ni tasa `1.0`) e incrementan `pendientesCount` o `incoherentesCount`.
     - La estructura de datos mantiene estrictamente separados `totalVerificadoOrigenCentavos` y `totalNoVerificadoCentavos`. En la UI y reportes se muestra `totalMostradoCentavos`, acompañado del badge de pendientes/incoherentes si `tieneAdvertenciaCalidad == true` y del desglose informativo cuando el usuario inspecciona el detalle.

5. **Comportamiento de filas legacy de idéntica estructura a filas creadas tras Fase 0A:**
   - Dado que SQLite v18 no tiene columna `schema_version` por fila ni columnas de procedencia por cada mercado (`fuente_tasa_usd`, `fuente_tasa_eur`, `fuente_tasa_usdt`), una fila completa escrita antes de Fase 0A y una fila escrita después de Fase 0A poseen **exactamente la misma representación en disco**.
   - Por tanto, tras cerrarse la sesión de creación y leerse desde SQLite/Firestore, **ambas filas se evalúan con el mismo contrato conservador `resolvePersistedExpense`**: su `total_original` es `identidadOrigen` y sus columnas secundarias válidas son `persistidoNoVerificado`. No se promete en v18 distinción post-persistencia entre filas pre-0A y post-0A completas; esa distinción existirá únicamente a partir de `v19` con `equivalencia_estado` y procedencia por mercado.

### 3.3 Contrato corregido de `resolvePersistedExpense`

```dart
enum EstadoValorMonetario {
  identidadOrigen,       // Verificado: total_original en su propia moneda (g.moneda == lente)
  persistidoNoVerificado,// Persistido > 0 en columna secundaria coherente; no verificado en v18
  calculadoNoVerificado, // Calculado solo para lente VES desde identidadOrigen * tasaOrigen (> 1 y no ambigua)
  pendiente,             // Faltante (null o <= 0 con original > 0) o tasa origen ambigua/ausente en lente VES
  incoherente,           // Violación de invariante (ej. I5: total_eur == total_usd con tasas distintas; I6: colapso VES)
}

enum EstadoTasaPersistida {
  persistidoNoVerificado,// Tasa > 1.0 sin colisión ambigua; usable solo para calculadoNoVerificado en lente VES
  noVerificadoAmbiguo,   // Colisión sospechosa (ej. tasa_eur == tasa_cambio en gasto VES/EUR sin respaldo)
  ausente,               // null
  invalidoDominio,       // <= 1.0, NaN o infinito
}

class ValorMonetarioResuelto {
  final int? centavos;
  final EstadoValorMonetario estado;
  final String? motivoNoDisponible;

  const ValorMonetarioResuelto({
    required this.centavos,
    required this.estado,
    this.motivoNoDisponible,
  });

  bool get esVerificado => estado == EstadoValorMonetario.identidadOrigen;
  bool get esContabilizableNoVerificado =>
      estado == EstadoValorMonetario.persistidoNoVerificado ||
      estado == EstadoValorMonetario.calculadoNoVerificado;
}
```

#### Tabla de resolución por lente en `resolvePersistedExpense(GastoModel g)`

Sea $M_0 = \text{g.totalOriginalCentavos}$. Si $M_0 == 0$: todas las lentes devuelven `centavos: 0, estado: identidadOrigen`. Si $M_0 < 0$: todas las lentes devuelven `centavos: null, estado: incoherente`.

Para $M_0 > 0$:

| Lente | Si `g.moneda == Lente` | Si `g.moneda != Lente` |
| :--- | :--- | :--- |
| **`USD`** | `centavos: M_0`, `estado: identidadOrigen` | 1. Si `g.moneda == 'VES'` y `g.totalUsdCentavos == M_0`: `estado: incoherente` (`I6`).<br>2. Si `g.totalUsdCentavos != null && g.totalUsdCentavos! > 0`: `centavos: g.totalUsdCentavos`, `estado: persistidoNoVerificado`.<br>3. En cualquier otro caso (`null` o `<= 0`): `centavos: null`, `estado: pendiente` (**prohibido derivar en lectura**). |
| **`USDT`** | `centavos: M_0`, `estado: identidadOrigen` *(solo filas legacy con `moneda == 'USDT'`)* | 1. Si `g.moneda == 'VES'` y `g.totalUsdtCentavos == M_0`: `estado: incoherente` (`I6`).<br>2. Si `g.totalUsdtCentavos != null && g.totalUsdtCentavos! > 0`: `centavos: g.totalUsdtCentavos`, `estado: persistidoNoVerificado`.<br>3. En cualquier otro caso (`null` o `<= 0`): `centavos: null`, `estado: pendiente` (**prohibido aplicar paridad 1:1 con `USD` o derivar en lectura**). |
| **`EUR`** | `centavos: M_0`, `estado: identidadOrigen` | 1. Si `g.moneda == 'VES'` y `g.totalEurCentavos == M_0`: `estado: incoherente` (`I6`).<br>2. Si `g.totalEurCentavos != null && g.totalEurCentavos! > 0`:<br>   - Si `g.totalUsdCentavos != null && g.totalEurCentavos == g.totalUsdCentavos` y (`g.tasaEur == null || g.tasaCambio == null || (g.tasaEur! - g.tasaCambio!).abs() > 1e-6`): `centavos: null`, `estado: incoherente` (`I5`: copia ilegítima `EUR = USD`).<br>   - En caso contrario: `centavos: g.totalEurCentavos`, `estado: persistidoNoVerificado`.<br>3. En cualquier otro caso (`null` o `<= 0`): `centavos: null`, `estado: pendiente` (**prohibido derivar en lectura**). |
| **`VES`** | `centavos: M_0`, `estado: identidadOrigen` | Como SQLite v18 carece de columna `total_ves`:<br>1. Determinar tasa origen $R_{\text{orig}}$ y su `EstadoTasaPersistida`:<br>   - Si `g.moneda == 'USD'`: $R_{\text{orig}} = \text{g.tasaCambio}$.<br>   - Si `g.moneda == 'USDT'`: $R_{\text{orig}} = \text{g.tasaUsdt}$.<br>   - Si `g.moneda == 'EUR'`: $R_{\text{orig}} = \text{g.tasaEur}$ (es `noVerificadoAmbiguo` si `g.tasaEur == g.tasaCambio`).<br>2. Si el estado de $R_{\text{orig}}$ es `persistidoNoVerificado` ($R_{\text{orig}} > 1.0$ y no ambiguo): `centavos: (M_0 * R_orig).round()`, `estado: calculadoNoVerificado`.<br>3. En caso contrario (`ausente`, `invalidoDominio` o `noVerificadoAmbiguo`): `centavos: null`, `estado: pendiente`. |

---

## 4. Garantías de Sincronización en v18, Tombstones y `sonContenidoNegocioIdentico` (Reemplaza §2.4 y §4.6 de `v1.1`)

### 4.1 Límites reales de `remote['actualizado_en'] == baseActualizadoEn` en v18

Se adjudica expresamente qué garantiza y qué **no** garantiza el protocolo de sincronización en el esquema `v18`:

1. **Por qué `remote['actualizado_en'] == baseActualizadoEn` es una guarda optimista y no una garantía absoluta en v18:**
   - **Ausencia de `base_actualizado_en` persistido en SQLite v18:** En v18 no se añade columna nueva a `gastos`. Si el usuario edita un gasto (`actualizado_en` cambia de $T_1$ a $T_2$ en la fila local con `synced = 0`) y la app se cierra antes de sincronizar, al reabrir la app SQLite solo conserva $T_2$. Por tanto, en un push posterior al reinicio, el cliente no conoce $T_1$ y solo puede verificar en la transacción de Firestore que el documento remoto no tenga un `actualizado_en` mayor que $T_2$ o contenido divergente.
   - **Clientes legacy o relojes desfasados:** Mientras la Fase C (`firestore.rules` + versión mínima forzada) no esté activa (**A-02**, **A-11**), un cliente móvil anterior a Fase 0A o una sesión del panel web puede escribir en Firestore usando `set(..., SetOptions(merge: true))` sin respetar el CAS transaccional, o dos dispositivos con relojes desincronizados podrían generar colisiones o inversiones de orden en cadenas ISO-8601 (`actualizado_en`).
   - **Fallo entre commit remoto y ACK local:** Si la transacción de Firestore confirma en la nube pero el proceso muere antes de ejecutar `marcarGastoSincronizadoCondicional` en SQLite, la fila local permanece con `synced = 0`. En el siguiente ciclo, la guarda de idempotencia (`sonContenidoNegocioIdentico`) resuelve el estado sin duplicar el push.
2. **Garantías reales que SÍ ofrece v18 (y que deben probarse):**
   - **Atomicidad local:** Ninguna mutación local (financiera, de metadatos o de ítems) queda con `synced = 1`.
   - **No-Lost-Update local frente a ACK tardío:** `marcarGastoSincronizadoCondicional(id, expectedActualizadoEn)` garantiza mediante `WHERE id = ? AND actualizado_en = ?` que el ACK de un push en vuelo jamás marque como `synced = 1` una edición local ocurrida mientras el push viajaba por red.
   - **Protección de `synced = 0` durante el pull:** `syncFromFirestore` relee cada fila local dentro de una transacción SQLite inmediata antes de aplicar cambios remotos y **jamás sobrescribe ni elimina físicamente** una fila cuyo estado actual en SQLite sea `synced = 0`.
   - **Garantía fuerte diferida a `v19` + Fase C:** El CAS estricto con `revision` entera monótona (`base_revision` persistido en SQLite) y validación obligatoria en `firestore.rules` corresponde a `v19` + Fase C, **no a `v18`**.

### 4.2 Regla ante Tombstone Remoto (`remoto.eliminadoEn != null`) con `local.synced == 0`

En `38df292` ([`lib/services/sync_service.dart:495-499`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L495-L499)) y en el pseudocódigo de `v1.1` (§4.6), cuando llegaba un documento remoto con `eliminado_en != null`, se ejecutaba `eliminarGastoFisico(local.id!)` sin verificar si `local.synced == 0`. Eso destruía silenciosamente ediciones locales no sincronizadas si otro dispositivo borraba el gasto.

**Regla normativa adjudicada en `v1.2`:**

1. **Caso A (`remoto.eliminadoEn != null` y `local == null`):** Se ignora (no se inserta en SQLite).
2. **Caso B (`remoto.eliminadoEn != null` y `local.synced == 1`):** La fila local no tiene cambios pendientes; es seguro ejecutar `eliminarGastoFisico(local.id!)` dentro de la transacción SQLite.
3. **Caso C (`remoto.eliminadoEn != null` y `local.synced == 0` y `local.eliminadoEn != null`):** Ambos lados eliminaron el gasto. Si `sonContenidoNegocioIdentico(local, remoto)` o si el tombstone remoto ya está confirmado en la nube, se elimina físicamente la fila local (`eliminarGastoFisico(local.id!)`) tras verificar en la transacción local que sigue teniendo `eliminado_en != null`.
4. **Caso D (`remoto.eliminadoEn != null` y `local.synced == 0` y `local.eliminadoEn == null`):**
   - **PROHIBIDO ejecutar `eliminarGastoFisico(local.id!)` ni sobrescribir la fila local.**
   - La fila local permanece intacta en SQLite con `synced = 0` y con todos sus importes, metadatos e ítems locales preservados.
   - `syncFromFirestore` registra un `ConflictoTombstoneRemoto(uuid: local.uuid, localSnapshot: local, fechaEliminacionRemota: remoto.eliminadoEn!)` en la cola de conflictos de sincronización en memoria/UI (`SyncConflictNotifier`).
   - Mientras el conflicto no sea resuelto por el usuario, `syncToFirestore` **omite el push automático** de ese `uuid` para no revivir silenciosamente un gasto borrado en otro dispositivo ni borrar silenciosamente la edición local.
   - La UI presenta al usuario las dos acciones explícitas:
     - **Opción 1 — *"Confirmar eliminación"*:** ejecuta `eliminarGastoFisico(local.id!)` en SQLite y limpia el conflicto.
     - **Opción 2 — *"Conservar mi gasto editado"*:** actualiza `actualizado_en = nowIso()`, mantiene `eliminado_en = null`, `synced = 0` y autoriza a `syncToFirestore` a reescribir el documento en Firestore limpiando `eliminado_en: null`.

### 4.3 Completitud exacta de `sonContenidoNegocioIdentico`

En [`lib/data/models/gasto_firestore_mapper.dart:13-48`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/models/gasto_firestore_mapper.dart#L13-L48), `GastoFirestoreMapper.toPayload(GastoModel gasto)` serializa hacia Firestore exactamente 19 claves de primer nivel:
`uuid`, `fecha`, `comercio`, `moneda`, `total_original`, `total_usd`, `total_usdt`, `total_eur`, `tasa_cambio`, `tasa_usdt`, `tasa_eur`, `fuente_tasa_cambio`, `fecha_tasa_cambio`, `categoria`, `creado_en`, `actualizado_en`, `ocr_text`, `items`, `eliminado_en`.

En `v1.1`, `sonContenidoNegocioIdentico` aplicaba `.trim()` a strings, normalizaba `categoria`, equiparaba `null` con `''` y omitía `eliminadoEn`. Eso podía producir un **falso positivo** (marcar `synced = 1` sin hacer push cuando el usuario había cambiado espacios, limpiado un campo o marcado `eliminado_en`).

**Implementación normativa exacta en `v1.2`:**

```dart
/// Compara TODOS los campos serializados por GastoFirestoreMapper.toPayload
/// (excepto 'actualizado_en', que es el reloj de versión).
/// Prohibido usar .trim(), normalizar categorías o equiparar null con ''.
bool sonContenidoNegocioIdentico(GastoModel a, GastoModel b) {
  return a.uuid == b.uuid &&
      a.fecha == b.fecha &&
      a.comercio == b.comercio &&
      a.moneda == b.moneda &&
      a.totalOriginalCentavos == b.totalOriginalCentavos &&
      a.totalUsdCentavos == b.totalUsdCentavos &&
      a.totalUsdtCentavos == b.totalUsdtCentavos &&
      a.totalEurCentavos == b.totalEurCentavos &&
      _sameNullableDoubleExact(a.tasaCambio, b.tasaCambio) &&
      _sameNullableDoubleExact(a.tasaUsdt, b.tasaUsdt) &&
      _sameNullableDoubleExact(a.tasaEur, b.tasaEur) &&
      a.fuenteTasaCambio == b.fuenteTasaCambio &&
      a.fechaTasaCambio == b.fechaTasaCambio &&
      a.categoria == b.categoria &&
      a.creadoEn == b.creadoEn &&
      a.ocrText == b.ocrText &&
      a.eliminadoEn == b.eliminadoEn &&
      _sonItemsExactamenteIguales(a.items, b.items);
}

bool _sameNullableDoubleExact(double? x, double? y) {
  if (x == null && y == null) return true;
  if (x == null || y == null) return false;
  if (x.isNaN || y.isNaN) return false;
  return x == y;
}

/// Compara la lista de ítems tal como se serializa en GastoFirestoreMapper.toPayload:
/// descripcion, cantidad, precio_unitario (centavos), subtotal (centavos),
/// subtotal_usd (centavos), subtotal_bs (centavos), categoria.
bool _sonItemsExactamenteIguales(
  List<GastoItemModel> itemsA,
  List<GastoItemModel> itemsB,
) {
  if (itemsA.length != itemsB.length) return false;
  for (int i = 0; i < itemsA.length; i++) {
    final ia = itemsA[i];
    final ib = itemsB[i];
    if (ia.descripcion != ib.descripcion ||
        !_sameNullableDoubleExact(ia.cantidad, ib.cantidad) ||
        ia.precioUnitarioCentavos != ib.precioUnitarioCentavos ||
        ia.subtotalCentavos != ib.subtotalCentavos ||
        ia.subtotalUsdCentavos != ib.subtotalUsdCentavos ||
        ia.subtotalBsCentavos != ib.subtotalBsCentavos ||
        ia.categoria != ib.categoria) {
      return false;
    }
  }
  return true;
}
```

### 4.4 Árbol de decisión corregido de `syncFromFirestore` (Transacción SQLite por fila)

```dart
await db.transaction((txn) async {
  final localActual = await obtenerGastoPorUuidEnTxn(txn, remoto.uuid);

  // 1. Documento remoto eliminado (Tombstone)
  if (remoto.eliminadoEn != null) {
    if (localActual == null) return;
    if (localActual.synced == 1 || localActual.eliminadoEn != null) {
      await eliminarGastoFisicoEnTxn(txn, localActual.id!);
      return;
    }
    // localActual.synced == 0 && localActual.eliminadoEn == null:
    // PROHIBIDO borrar físicamente la edición local pendiente.
    registrarConflictoTombstoneRemoto(
      uuid: localActual.uuid,
      local: localActual,
      fechaEliminacionRemota: remoto.eliminadoEn!,
    );
    return;
  }

  // 2. Inserción de gasto remoto nuevo
  if (localActual == null) {
    await insertarGastoDesdeSyncEnTxn(txn, remoto.copyWith(synced: 1));
    return;
  }

  // 3. Fila local con cambios pendientes (synced == 0)
  if (localActual.synced == 0) {
    if (sonContenidoNegocioIdentico(localActual, remoto)) {
      // Idempotencia post-crash: el push anterior ya había llegado a Firestore
      // y el contenido de negocio (incluyendo eliminado_en e items) es idéntico.
      await actualizarGastoDesdeSyncEnTxn(
        txn,
        localActual.copyWith(
          actualizadoEn: remoto.actualizadoEn,
          synced: 1,
        ),
      );
    } else if (remoto.actualizadoEn.compareTo(localActual.actualizadoEn) > 0) {
      // Divergencia real: conservar fila local (synced = 0) y notificar conflicto.
      registrarConflictoEdicionConcurrente(
        uuid: localActual.uuid,
        local: localActual,
        remoto: remoto,
      );
    }
    // Nunca se sobrescribe localActual cuando synced == 0 y contenido difiere.
    return;
  }

  // 4. Fila local limpia (synced == 1): aplicar actualización remota si es más reciente
  if (remoto.actualizadoEn.compareTo(localActual.actualizadoEn) > 0) {
    await actualizarGastoDesdeSyncEnTxn(txn, remoto.copyWith(synced: 1));
  }
});
```

---

## 5. Nuevas Pruebas y Criterios de Aceptación (`v1.2`)

Estas pruebas se suman a `T-01..T-62` de `v1.1` y son **obligatorias** para cerrar `E0-02`, `E0-03` y `E0-04`:

| ID | Etapa | Caso de prueba verificable | Resultado esperado |
| :--- | :--- | :--- | :--- |
| **`T-63`** | `E0-02` | **Bloqueo de `EUR + BS_USDT`:** Invocar `buildNewExpenseTuple` con `monedaOriginal: 'EUR'`, `metodo: MetodoLiquidacion.bsUsdt` y 3 cotizaciones válidas. | Devuelve `TupleBuildFailure(code: TupleFailureCode.combinacionMonedaLiquidacionNoSoportada)`. No multiplica `EUR * rUsdt`. |
| **`T-64`** | `E0-02` | **Prueba negativa de `RateQuoteInput` — Fuente `USD` presentada como `USDT`:** Pasar en `cotizacionUsdt` un `RateQuoteInput` con `mercado: RateMarket.usdtP2p` pero `sourceId: RateSourceId.dolarApiUsdOficial` (o `mercado: RateMarket.usdOficial`). | `validateFor` rechaza con `QuoteValidationError.fuenteNoAutorizadaParaMercado` (o `mercadoIncorrecto`) y `buildNewExpenseTuple` aborta. |
| **`T-65`** | `E0-02` | **Prueba negativa de `RateQuoteInput` — Tasa P2P presentada como `USD` oficial:** Pasar en `cotizacionUsd` un `RateQuoteInput` con `sourceId: RateSourceId.yadioUsdtP2p` o `dolarApiParalelo`. | `validateFor` rechaza con `QuoteValidationError.fuenteNoAutorizadaParaMercado`. |
| **`T-66`** | `E0-02` | **Prueba negativa de `RateQuoteInput` — Fecha equivocada y referencia sin confirmación:**<br>a) `fechaSolicitada: '2026-03-10'` para `fechaGasto: '2026-03-09'`.<br>b) `fechaEfectiva: '2026-03-10'` para `fechaSolicitada: '2026-03-09'` (tasa futura).<br>c) `esExacta: false, esReferencia: true, confirmadaPorUsuario: false`.<br>d) `sourceId: RateSourceId.manualUsuario, confirmadaPorUsuario: false` o `esExacta: true`. | Rechazados respectivamente con:<br>a) `fechaSolicitadaNoCoincideConGasto`<br>b) `fechaEfectivaFutura`<br>c) `referenciaSinConfirmacionUsuario`<br>d) `manualSinConfirmacionUsuario` / `inconsistenciaExactitudFecha`. |
| **`T-67`** | `E0-02` / `E0-03` | **No derivación en lectura para `USD`/`EUR`/`USDT` y `calculadoNoVerificado` en `VES`:**<br>a) Fila persistida con `moneda: 'USD', total_original: 2000, total_eur: null, tasa_cambio: 40.0, tasa_eur: 44.0`.<br>b) Misma fila leída en lente `VES`.<br>c) Fila con `moneda: 'EUR', total_original: 2000, tasa_cambio: 40.0, tasa_eur: 40.0` (ambigua) leída en lente `VES`. | a) Lente `EUR` devuelve `EstadoValorMonetario.pendiente` (`centavos: null`); **no** deriva `2000 * 40 / 44`.<br>b) Lente `VES` devuelve `centavos: 80000, estado: calculadoNoVerificado`.<br>c) Lente `VES` devuelve `centavos: null, estado: pendiente` por ser `tasa_eur` `noVerificadoAmbiguo`. |
| **`T-68`** | `E0-03` | **Separación contable `ResumenLenteMonetario`:** Agregar en lente `USD` un gasto con `moneda: 'USD', total_original: 1000` (`identidadOrigen`), un gasto con `moneda: 'VES', total_usd: 500` (`persistidoNoVerificado`) y un gasto con `moneda: 'VES', total_usd: null` (`pendiente`). | `totalVerificadoOrigenCentavos == 1000`, `totalNoVerificadoCentavos == 500`, `totalMostradoCentavos == 1500`, `noVerificadosCount == 1`, `pendientesCount == 1`. |
| **`T-69`** | `E0-04` | **Tombstone remoto vs `synced = 0` local:** Fila local con `id: 7, uuid: 'u1', synced: 0, eliminadoEn: null, totalOriginal: 5000`. Llega en `syncFromFirestore` documento remoto `'u1'` con `eliminado_en: '2026-03-15T10:00:00Z'`. | La fila `id: 7` **no se elimina de SQLite**, conserva `totalOriginal == 5000` y `synced == 0`, y se emite `ConflictoTombstoneRemoto` para decisión del usuario. |
| **`T-70`** | `E0-04` | **Exhaustividad de `sonContenidoNegocioIdentico`:** Comparar dos `GastoModel` idénticos salvo por: (a) espacio al final en `comercio` (`'A '` vs `'A'`), (b) `fuenteTasaCambio: null` vs `''`, (c) `eliminadoEn: null` vs `'2026-03-15...'`, (d) cambio en `subtotalUsdCentavos` de un ítem. | En los 4 casos `sonContenidoNegocioIdentico` devuelve `false` (no marca `synced = 1`). |

---

## 6. Autorización Final de Ejecución e Instrucciones para Gemini Flash

### 6.1 Estado de las etapas y orden de ejecución autorizado

Queda cerrado el contrato técnico de Fase 0A en `v1.2`. Se autoriza la ejecución secuencial de las unidades de trabajo bajo las siguientes compuertas:

| Etapa | Estado | Alcance autorizado para Gemini Flash |
| :--- | :--- | :--- |
| **`E0-05a`** | **🟢 AUTORIZADA (Inmediata — Prioridad 1)** | Neutralizar la auto-ejecución de `repararGastosTasa474` y `repararGastosTasa850` en [`lib/ui/screens/main_screen.dart:132-145`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/main_screen.dart#L132-L145) y bloquear escritura automática en [`lib/services/sync_service.dart:555-767`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L555-L767) (`dryRun = true` por defecto). |
| **`E0-01`** | **🟢 AUTORIZADA (Inmediata — Prioridad 2)** | Añadir `sqflite_common_ffi` en `dev_dependencies` de [`pubspec.yaml`](file:///c:/Development/Control%20de%20gastos%20VE/pubspec.yaml) (**A-08**) y crear el arnés de pruebas sobre SQLite real en memoria. |
| **`E0-02`** | **🟢 AUTORIZADA (Tras `E0-01`)** | Implementar en `lib/domain/monetary/`:<br>1. `RateMarket`, `RateSourceId`, `RateQuoteInput` y `validateFor` (§2.2–§2.3).<br>2. `buildNewExpenseTuple` con bloqueo explícito de `EUR + BS_USDT` (§1.3) y sin cadenas `EUR → USD → USDT`.<br>3. `resolvePersistedExpense` y `ResumenLenteMonetario` con estados `identidadOrigen`, `persistidoNoVerificado`, `calculadoNoVerificado` (solo lente `VES`), `pendiente` e `incoherente` (§3.2–§3.3).<br>4. Limpieza selectiva de caché histórica en [`ExchangeRateService`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/exchange_rate_service.dart) (`tasas_historico_v1`) solo para entradas sin procedencia válida o `<= 1.0`.<br>5. Suite unitaria completa `T-01..T-70` (correspondiente a dominio). |
| **`E0-03`** | **🟡 AUTORIZADA SECUENCIALMENTE (Requiere `E0-02` en verde)** | Integrar `resolvePersistedExpense` y `ResumenLenteMonetario` en todos los lectores móviles ([`GastoModel`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/models/gasto_model.dart), [`GastoProvider`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/gasto_provider.dart), Dashboard, Presupuestos, Estadísticas, Exportación CSV) y en [`landing/src/pages/panel.astro`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro) (**A-16**). Deshabilitar la opción `BS_USDT` cuando `moneda == 'EUR'` en [`ReviewExpenseScreen`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart) y [`panel.astro`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro). |
| **`E0-04`** | **🟡 AUTORIZADA SECUENCIALMENTE (Requiere `E0-02` y `E0-03` en verde)** | En [`DatabaseHelper`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/local/database_helper.dart) y [`SyncService`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart):<br>1. `synced = 0` atómico en toda mutación de gastos e ítems.<br>2. `marcarGastoSincronizadoCondicional(id, expectedActualizadoEn)`.<br>3. `sonContenidoNegocioIdentico` exacto (§4.3).<br>4. Protección de `synced = 0` en `syncFromFirestore` incluyendo `ConflictoTombstoneRemoto` (§4.2, §4.4).<br>5. Separación de `actualizarMetadatosGasto` (allowlist) vs `reemplazarImportesGasto` con confirmación y motivo cuando el gasto ya existe (**A-09**, **A-15**). |
| **`E0-05b`** | **🟡 AUTORIZADA SECUENCIALMENTE (En paralelo o tras `E0-03`)** | Consultas de diagnóstico read-only `Q01..Q20` sin PII (**A-14**), tratando `{36.5, 40.0, 474.0, 850.0}` únicamente como indicios estadísticos (`Q20`) y nunca como prueba automática de corrupción. |
| **Fase 0B** | **🔴 BLOQUEADA (**A-12**)** | Prohibido ejecutar migración o reparación masiva de datos de usuarios hasta completar Fase 0A, diagnóstico `Q01..Q20` y aprobación expresa de César. |

### 6.2 Lo que Gemini Flash NO debe hacer ni prometer en `v18`

1. **No prometer procedencia individual post-persistencia en `v18`:** En SQLite `v18` (`_dbVersion = 18`), `fuente_tasa_cambio` y `fecha_tasa_cambio` son dos únicas columnas por fila. Una vez persistido el gasto, ninguna columna secundaria (`total_usd`, `total_eur`, `total_usdt`) ni tasa persistida tiene certificación criptográfica o de esquema por mercado individual; por eso se leen como `persistidoNoVerificado` hasta la migración a `v19`.
2. **No prometer inferencia de `DIVISA` al leer filas persistidas en `v18`:** Como `metodo_liquidacion` se incorpora en SQLite `v19` (**A-05**), `resolvePersistedExpense` jamás asume paridad 1:1 `USD == USDT` sobre gastos leídos de SQLite o Firestore.
3. **No prometer CAS absoluto inter-reinicio ni bloqueo de clientes viejos en `v18`:** La guarda `actualizado_en == baseActualizadoEn` en Firestore es optimista; la protección dura contra escrituras de clientes legacy exige `v19` + Fase C (`firestore.rules` + `min_supported_app_version`, **A-02**, **A-11**).
4. **No usar `SharedPreferences` como journal de sincronización ni modificar `_dbVersion = 18`.**
5. **No derivar columnas `USD`, `EUR` o `USDT` faltantes en lectura a partir de tasas `persistidoNoVerificado`**, ni permitir `EUR + BS_USDT` en creación/edición.

---