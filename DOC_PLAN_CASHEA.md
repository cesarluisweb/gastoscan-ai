# Especificación Técnica y Plan de Implementación: Soporte para Cashea y Compras en Cuotas (`FIN-15`)

Este documento analiza el impacto financiero y contable del modelo *Compra Ahora y Paga Después* (**Cashea** / cuotas quincenales sin interés) en la economía venezolana y define la arquitectura técnica, el modelo de datos y la experiencia de usuario para integrarlo en **Rinde Más** sin romper su filosofía *Local-First* ni introducir contabilidad bancaria compleja.

---

## 1. Análisis del Problema en el Contexto Venezolano

En Venezuela, **Cashea** se ha convertido en el método de financiamiento cotidiano principal para vestimenta, tecnología, hogar, salud e incluso supermercados y farmacias. Su mecánica presenta una particularidad financiera crítica:

1. **Fraccionamiento Temporal del Flujo de Caja:**
   - En una compra de **$100,00 USD**, el usuario paga en caja hoy únicamente la **Inicial** según su nivel (60%, 50%, 40% o 20%, ej. **$40,00 USD**).
   - El saldo restante (**$60,00 USD**) se divide en **3 cuotas iguales cada 14 días** (ej. 3 cuotas de **$20,00 USD** a los días +14, +28 y +42) o en 6, 9 y 12 cuotas en *Modo Más Cuotas*.
2. **Asimetría Cambiaria por Fecha de Pago (Anclaje en USD BCV vs Liquidación en Bs.):**
   - Aunque la factura se emite el Día 0, las cuotas quedan fijadas en **USD** y se pagan en **Bolívares a la tasa oficial BCV vigente el día en que se cancela cada cuota** (o vendiendo USDT a la tasa P2P de ese día futuro), **nunca** a la tasa del día de la compra original.

### ¿Por qué fallan los dos enfoques tradicionales puros?

| Enfoque Tradicional | ¿Qué ocurre en la práctica? | Por qué falla en Venezuela / Rinde Más |
|---|---|---|
| **Opción 1: Registrarlo todo como "Ya Pagado" el Día 0** | Se cargan los $100,00 completos al presupuesto del mes actual con la tasa BCV de hoy. | 1. **Destruye el "Disponible para gastar" del mes:** Si el usuario compra a fin de mes pagando solo $40 de inicial, la app le resta $100 hoy y le muestra sobregiro falso, cuando los otros $60 saldrán del presupuesto del mes siguiente.<br>2. **Tasa BCV/USDT irreal:** Congela las cuotas futuras a la tasa de hoy, descalzando los bolívares reales que saldrán del banco a los 14, 28 y 42 días. |
| **Opción 2: Módulo Contable de "Cuentas por Pagar / Pasivos"** | Crear un libro separado de pasivos, deudas, amortizaciones y conciliación entre cuentas. | **Viola la filosofía de Rinde Más (`AGENTS.md`):** Obliga al usuario a llevar doble contabilidad (pasivos vs gastos), genera fricción cognitiva alta y convierte la app en un sistema contable pesado. |

---

## 2. La Solución "Estilo Rinde Más": Flujo de Caja Real + Cuotas Programadas

Adoptamos un **modelo híbrido centrado en el bolsillo real del usuario (Criterio de Flujo de Caja con Compromisos Visibles)**:

1. **En el mes actual solo resta presupuesto lo efectivamente pagado:**
   - El día de la compra, el gasto que impacta el presupuesto y las gráficas del mes es **únicamente la Inicial pagada hoy** (ej. $40,00), liquidada a la tasa BCV/USDT del día de la compra.
2. **Las cuotas futuras nacen automáticamente como "Cuotas Programadas (`PENDIENTE`)":**
   - Al guardar la compra, Rinde Más genera automáticamente los registros de las 3 cuotas en sus fechas exactas (+14, +28 y +42 días) en moneda `USD` con estado `PENDIENTE`.
   - Mientras están en estado `PENDIENTE`, **no se suman al total ya gastado**, pero se muestran en un indicador preventivo de **"Próximas cuotas Cashea"** para que el usuario sepa qué parte de su presupuesto mensual ya está comprometida.
3. **Liquidación en 1 Toque el Día de Pago (Tasa BCV Fresca):**
   - Cuando llega la fecha de la cuota (o si el usuario decide **adelantarla** antes de los 14 días), toca **`[ ✓ Pagar cuota ]`**.
   - La app precarga automáticamente la **tasa BCV oficial de ese día**, permite ajustar el monto en Bolívares o adjuntar el comprobante de Pago Móvil, y pasa el registro a estado `PAGADO`, impactando el presupuesto del mes en que realmente salió el dinero.

---

## 3. Reglas de Negocio y Matemática Determinista

### 3.1. Algoritmo del Centavo Residual en Fraccionamiento de Cuotas
Cuando el saldo financiado no es exactamente divisible entre el número de cuotas (ej. compra de $100,00 con 50% de inicial $\rightarrow$ saldo de $50,00 entre 3 cuotas = $16,666...), todo el cálculo se ejecuta en **céntimos enteros (`int`)**:

$$\text{inicialCents} = \text{round}(\text{totalFacturaCents} \times \text{porcentajeInicial})$$
$$\text{saldoFinanciadoCents} = \text{totalFacturaCents} - \text{inicialCents}$$
$$\text{cuotaBaseCents} = \lfloor \text{saldoFinanciadoCents} \div N \rfloor$$
$$\text{residuoCents} = \text{saldoFinanciadoCents} - (\text{cuotaBaseCents} \times N)$$

- Las primeras $N - 1$ cuotas reciben `cuotaBaseCents` (ej. `1667` céntimos = `$16,67`).
- La última cuota absorbe deterministamente el residuo (ej. `1666` céntimos = `$16,66`).
- **Invariante estricto:** $\text{Inicial} + \sum_{i=1}^{N} \text{Cuota}_i \equiv \text{Total Factura Original}$.

### 3.2. Conservación del Desglose de Productos y Factura Original
Para no perder la riqueza de datos ("Los Datos son el Producto") ni inflar los totales por categoría:
- **Registro Padre (Inicial - Día 0):** Conserva la foto de la factura física (`ruta_foto_local`) y el listado de productos (`items`), escalando sus subtotales proporcionalmente al peso de la inicial o almacenando el precio de anaquel en la descripción para referencia histórica.
- **Registros Hijos (Cuotas 1..N):** Se vinculan mediante un identificador compartido `plan_cuotas_id` (UUID de la operación original), heredan la categoría canónica de la compra y llevan como concepto normalizado:
  - Inicial: `[Comercio] (Inicial Cashea)`
  - Cuotas: `[Comercio] (Cuota 1/3 Cashea)`, `[Comercio] (Cuota 2/3 Cashea)`, etc.

---

## 4. Diseño de Experiencia de Usuario (UX / UI)

### 4.1. Pantalla de Revisión / Nuevo Gasto (`ReviewExpenseScreen` y `panel.astro`)
Debajo del selector de método de liquidación, se incorpora un selector compacto de modalidad de pago:
- **`[ Contado ]`** (Por defecto, comportamiento actual sin cambios).
- **`[ ⚡ Cashea / Cuotas ]`**: Al activarlo, despliega una tarjeta ligera con fondo suave (`AppColors.primaryContainer` / borde de acento) que muestra:
  1. **Chips rápidos de Inicial:** `[ 60% ]` · `[ 50% ]` · `[ 40% ]` · `[ 20% ]` · `[ Monto manual ✏️ ]`.
  2. **Selector de Cuotas:** `[ 3 cuotas (c/14 días) ▾ ]` (con opciones para 6, 9 o 12 cuotas).
  3. **Vista Previa del Cronograma en Tiempo Real:**
     - **Hoy (Inicial):** `$40,00` (Pagado hoy: `Bs. X.XXX,XX` a BCV)
     - **05 Nov (Cuota 1/3):** `$20,00` *(Pendiente · se calculará a BCV del día)*
     - **19 Nov (Cuota 2/3):** `$20,00` *(Pendiente)*
     - **03 Dic (Cuota 3/3):** `$20,00` *(Pendiente)*

### 4.2. Visibilidad en Inicio (`DashboardScreen`) y Pestaña Gastos (`ExpensesScreen`)
- **En Inicio (Píldora de Compromisos del Mes):** Si existen cuotas pendientes dentro del mes consultado (o en los próximos 14 días), se muestra bajo la tarjeta de resumen o sobre los gastos recientes un banner compacto:
  > ⚡ **Cuotas por pagar este mes:** **$40,00** · Próxima: **$20,00** en 4 días (IVOO) `[Ver / Pagar]`
- **En Pestaña Gastos:**
  - Filtro rápido tipo chip: `[ ⚡ Cuotas pendientes (3) ]`.
  - Las cuotas pendientes se muestran con borde punteado e insignia ámbar `Pendiente · Vence 05 Nov` y un botón directo **`[ ✓ Pagar cuota ]`**.

### 4.3. Modal Rápido de Confirmación de Cuota (Liquidación en 1 Toque)
Al pulsar **`[ ✓ Pagar cuota ]`** sobre una cuota pendiente:
1. Establece como fecha de pago **`Hoy`** (incluso si el usuario está **adelantando** una cuota que vencía la semana siguiente).
2. Consulta automáticamente la **Tasa BCV y USDT de hoy**.
3. Permite elegir cómo se pagó la cuota (`En Bs. a tasa BCV`, `En Bs. a tasa P2P` o `En divisa directa`), editar el monto en Bolívares si hubo redondeo y, opcionalmente, adjuntar el capture del Pago Móvil.
4. Al confirmar, cambia `estado_pago` de `'PENDIENTE'` a `'PAGADO'`, recalcula e inmutabiliza `total_original`, `total_usd`, `total_usdt`, `tasa_cambio` y sincroniza con Firestore.

### 4.4. Notificaciones Locales Preventivas (`NotificationService`)
- Al programar las cuotas, la app agenda notificaciones locales offline:
  - **24 horas antes (9:00 AM):** *"⚡ Mañana vence tu cuota 1/3 de Cashea en [Comercio] por $20,00."*
  - **Día de vencimiento (9:00 AM):** *"⚡ Hoy toca pagar tu cuota 1/3 de Cashea ($20,00). Abre Rinde Más para ver el monto en Bs. a tasa BCV de hoy y marcarla como pagada."*
- Si el usuario marca la cuota como pagada por adelantado, la notificación programada se cancela automáticamente.

### 4.5. Integración con IA (Voz, OCR y Asistente Financiero)
1. **Dictado por Voz / Texto (`parseVoiceExpense`):**
   - Si el usuario dicta: *"Compré zapatos en 60 dólares con Cashea dando 40% de inicial"*, el Cloudflare Worker extrae `es_cuotas: true`, `porcentaje_inicial: 40`, `num_cuotas: 3` y abre `ReviewExpenseScreen` con el cronograma ya calculado.
2. **Escaneo OCR de Capturas de Cashea:**
   - Si el usuario sube una captura de pantalla de su plan de pagos en la app de Cashea, Gemini identifica el comercio, el monto de la inicial y las cuotas para autocompletar el formulario.
3. **Contexto Semántico en `ChatScreen`:**
   - Se inyecta en `_buildSemanticChatContext` el resumen `cuotas_pendientes_mes` y `total_deuda_cashea_usd`. Así el usuario puede preguntar: *"¿Cuánto debo de Cashea este mes?"* o *"¿Si pago mis cuotas de Cashea cuánto me queda disponible?"* y recibir una respuesta exacta al céntimo.

---

## 5. Arquitectura de Datos y Migración SQLite / Firestore

### 5.1. Nuevas Columnas en Tabla `gastos` (Migración SQLite v18)
Se agregan 4 columnas opcionales retrocompatibles (todos los gastos históricos toman `'PAGADO'` por defecto):

| Columna | Tipo SQLite | Valor por Defecto | Descripción |
|---|---|---|---|
| `estado_pago` | `TEXT NOT NULL` | `'PAGADO'` | `'PAGADO'` (impacta presupuesto y gráficas) o `'PENDIENTE'` (cuota futura programada). |
| `plan_cuotas_id` | `TEXT NULL` | `NULL` | UUID común que agrupa la Inicial y todas las cuotas de una misma compra. |
| `numero_cuota` | `INTEGER NULL` | `NULL` | `0` para la Inicial, `1..N` para cada cuota. |
| `total_cuotas` | `INTEGER NULL` | `NULL` | Cantidad total de cuotas financiadas (ej. `3`, `6`, `9`, `12`). |

### 5.2. Aislamiento en Consultas SQL y Panel Web
- Todas las consultas de gasto acumulado mensual, gráficos por categoría y cálculo de presupuesto (`DatabaseHelper`, `GastoProvider`, `BudgetProvider` y `panel.astro`) filtran por `estado_pago = 'PAGADO'` (o `estado_pago IS NULL` por retrocompatibilidad con documentos antiguos en Firestore).
- Se expone en `GastoProvider` la lista reactiva `cuotasPendientes` y el getter `totalCuotasPendientesMesUsd` para alimentar el banner preventivo y el filtro de la pestaña Gastos.

---

## 6. Fases de Ejecución Recomendadas

1. **Etapa 1 — Motor de Datos y Fraccionamiento Local (Core):**
   - Migración SQLite (`estado_pago`, `plan_cuotas_id`, `numero_cuota`, `total_cuotas`) y serialización en `GastoModel` + `SyncService` + `firestore.rules`.
   - Algoritmo determinista de generación de Inicial + $N$ cuotas con ajuste del centavo residual.
   - Filtrado de `estado_pago == 'PAGADO'` en totales mensuales y gráficas.
2. **Etapa 2 — UI de Captura y Liquidación en 1 Toque:**
   - Selector `[ Contado | ⚡ Cashea / Cuotas ]` y vista previa de cronograma en `ReviewExpenseScreen`.
   - Insignia de cuota pendiente, chip de filtro y modal de liquidación en 1 toque (con soporte de pago adelantado y tasa BCV del día) en `ExpensesScreen` y `DashboardScreen`.
   - Paridad matemática y visual en el panel web (`landing/src/pages/panel.astro`).
3. **Etapa 3 — Recordatorios Locales e Inteligencia Artificial:**
   - Programación y cancelación automática de alertas en `NotificationService`.
   - Soporte de extracción de compras en cuotas por voz/OCR en Cloudflare Worker (`workers/src/index.js`) e inyección de `cuotas_pendientes` en el contexto del Asistente IA.
