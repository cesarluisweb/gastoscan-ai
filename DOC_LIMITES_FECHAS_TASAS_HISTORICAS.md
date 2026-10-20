# DOC: Límites de Fechas y Blindaje de Tasas Históricas (FIN-13)

## 1. Problema Identificado
Al registrar o editar un gasto con fechas pasadas remotas (ejemplo: `29/06/2021`), el sistema colocaba la tasa de cambio del día de hoy (`Bs. 881.88`) en lugar de la tasa real de esa fecha o de alertar la ausencia de datos.

### Causas Raíz:
1. **Inicio de registros oficiales:** La API oficial de tasas venezolanas (`DolarAPI`) tiene histórico continuo a partir del **3 de enero de 2023** (`2023-01-03`). No existen registros diarios oficiales continuos previos en dicha API.
2. **Reconversión Monetaria:** El 1 de octubre de 2021 entró en vigencia el Bolívar Digital (eliminando 6 ceros a los Bolívares Soberanos). Fechas previas a esa reconversión operaban en una escala monetaria incompatible.
3. **Fallback ciego a tasa de hoy:** En `ExchangeRateService.getRateForDate`, si no se encontraba tasa histórica para una fecha pasada, el paso 4 ejecutaba `getAllTodayRates()`, retornando la tasa de hoy (881.88).
4. **Selector sin límites realistas:** El `showDatePicker` en `ReviewExpenseScreen` permitía seleccionar desde el año 2020 hasta 2030.
5. **Solapamiento en gráfico (Captura 1):** En meses de 31 días (como Octubre), el eje X mostraba `d30` (múltiplo de 5) y `d31` (fin de mes) solapándose visualmente como `d30d31`.
6. **Margen de proyección (Captura 1):** La fila de proyección a fin de mes carecía de flexibilidad de ancho (`Expanded`), presionando el valor contra el margen derecho en pantallas compactas.

---

## 2. Solución Implementada

### A. Constante de Límite Histórico (`AppConstants`)
- Se definió `AppConstants.fechaMinimaHistoricoTasas = DateTime(2023, 1, 3)` y `fechaMinimaHistoricoTasasIso = '2023-01-03'`, coincidiendo con el registro más antiguo disponible en las plataformas de tasas oficiales.

### B. Blindaje en `ExchangeRateService`
- Para fechas anteriores a `2023-01-03`, `getRateForDate` retorna inmediatamente `0.0`.
- Para `USDT`, si la fecha histórica no tiene registro paralelo en DolarAPI (anteriores a febrero de 2026), realiza fallback a la tasa USD oficial de esa misma fecha histórica.
- Para cualquier fecha histórica sin datos o sin red, se eliminó el fallback a la tasa de hoy (`getAllTodayRates()`); ahora retorna `0.0`, impidiendo falsificar tasas pasadas.

### C. Selector de Fechas y UI en `ReviewExpenseScreen`
- El `showDatePicker` limita estrictamente:
  - `firstDate`: `AppConstants.fechaMinimaHistoricoTasas` (`2023-01-03`).
  - `lastDate`: Fecha de hoy (`DateTime.now()`).
  - `initialDate`: Clampeado de forma defensiva entre `firstDate` y `lastDate`.
- En `_cargarTasasChips` y `_actualizarTasaPorFecha`: Si una fecha histórica no tiene tasa (`0.0`), no se sustituye con la tasa de hoy de `SettingsProvider`. La interfaz muestra:
  `Sin histórico oficial (fecha) · Ingresa tasa manual`
- Los `ActionChip` de tasas muestran `'Dólar BCV: No disponible'` si la fecha pasada no posee registro, evitando sobreescribir con valores de hoy.

### D. Selector de Meses (`MonthSelectorBar`)
- Se bloqueó la navegación hacia años anteriores a 2023 en el chevron izquierdo y en el modal selector de mes.

### E. Corrección de `d30d31` (`DailyEvolutionCard`)
- En meses de 31 días, se omite el `d30` (`totalDiasMes - valInt > 1`), mostrando limpiamente: `d1, d5, d10, d15, d20, d25, d31` sin colisión de texto.

### F. Ajuste de Proyección en Análisis (`AnalysisScreen`)
- Se envolvió el texto de la proyección en `Expanded` con espaciado horizontal de 8dp, garantizando alineación consistente con las filas de Presupuesto y Promedio diario.

---

## 3. Guía de Pruebas Paso a Paso (Para César)

1. **Selector de Fechas al registrar gasto:**
   - Entrar a la pantalla de registrar gasto.
   - Tocar el campo de fecha.
   - Intentar navegar a años anteriores a 2023: el calendario debe bloquear y no permitir seleccionar fechas antes del 3 de enero de 2023 ni fechas futuras posteriores a hoy.
2. **Cálculo de tasa histórica válida:**
   - Seleccionar una fecha entre 2023 y 2025 (ejemplo: `15/05/2024`).
   - El sistema debe consultar la tasa histórica oficial BCV de ese día y colocarla en el campo (ej. ~36.5 Bs/$ en mayo de 2024), **nunca** 881.88.
3. **Gráfico Evolución Diaria (Octubre):**
   - Abrir la pestaña de Análisis en el mes actual (Octubre).
   - Observar el eje X del gráfico: la etiqueta final debe ser `d31` precedida por `d25`, sin el solapamiento `d30d31`.
4. **Fila de Proyección en Análisis:**
   - En la tarjeta superior de Análisis, verificar que la fila *"Si sigues a este ritmo gastarás en el mes"* y su monto proyectado mantengan márgenes simétricos y limpios con respecto al resto de filas.
