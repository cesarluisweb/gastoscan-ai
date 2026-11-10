# Documento Técnico: E0-03 Lectores Multimoneda, Independencia de Tasas y Pantallas

## 1. Alcance y Propósito
Este documento certifica la implementación completa del hito **E0-03** del proyecto Rinde Más, enfocado en desacoplar rigurosamente las monedas extranjeras (USD, EUR, USDT), eliminar fallbacks cruzados inventados y estandarizar las denominaciones canónicas en toda la aplicación móvil Flutter y el panel web Astro.

Cumple estrictamente con las directrices de la arquitectura:
- **D-01 / D-04 / H-1:** Independencia estricta por moneda. Ni el backend de tasas (`ExchangeRateService`), ni el proveedor de estado (`SettingsProvider`), ni la base de datos SQLite asumen que 1 USDT = 1 USD ni usan la tasa USD para calcular totales en EUR o USDT.
- **H-2:** Erradicación de equivalencias automáticas e inventadas en la presentación (`CurrencyFormatter`, `GastoModel`, `DatabaseHelper.getCategoryTotals`). Si no existe tasa o monto registrado, se muestra el indicador canónico de ausencia de dato (`—`) o 0.0 centavos sin contaminar los agregados.
- **A-16:** Integración obligatoria de `ResumenLenteMonetario` en `GastoProvider` y en `DatabaseHelper.getMonthlyTotals`, garantizando paridad matemática exacta entre base de datos, memoria y pantallas.
- **D-06:** Modelo de tres estados canónicos por moneda (`EstadoTasaMoneda`):
  1. `actualizada`: Tasa viva del día obtenida de fuentes oficiales (BCV / P2P).
  2. `referencia`: Tasa válida persistida de fecha anterior o fijada manualmente por el usuario.
  3. `sinTasa`: Tasa no disponible ($\le 1.0$), purga fallida o sin registro previo.
- **D-07:** Denominaciones visuales canónicas aprobadas en UI:
  - `✓ Actualizada hoy` (cuando la fecha de la tasa coincide con la fecha de hoy).
  - `Última tasa registrada` (cuando proviene de caché histórica válida).
  - `Tasa manual` (cuando fue fijada manualmente por el usuario).
  - `Sin tasa disponible` / `—` (cuando no existe cotización válida o es $\le 1.0$).

---

## 2. Inventario de Cambios por Subsistema

### 2.1 Dominio y Modelos
- [`lib/domain/monetary/rate_market.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/domain/monetary/rate_market.dart):
  - Incorporación del enum `EstadoTasaMoneda { actualizada, referencia, sinTasa }`.
- [`lib/data/models/gasto_model.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/models/gasto_model.dart):
  - `totalUsdtDisplay` y `tasaUsdtDisplay` convertidos a `double?` estrictamente anulables (sin invención de valor a partir de USD).

### 2.2 Servicios y Proveedores
- [`lib/services/exchange_rate_service.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/exchange_rate_service.dart):
  - Erradicación de `usdtRate = usdRate` en `getAllTodayRates`.
  - Supresión del fallback histórico a USD cuando se consulta la tasa de USDT para una fecha.
- [`lib/providers/settings_provider.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/settings_provider.dart):
  - Incorporación de estados independientes `_estadoTasaUsd`, `_estadoTasaEur`, `_estadoTasaUsdt` y método `getEstadoTasa(String moneda)`.
  - Inicialización fail-closed ante purgas fallidas: todos los estados pasan a `sinTasa`.
  - Preservación de procedencia: `setTasaCambio()` clasifica la tasa como `referencia` (procedencia manual) y activa `esTasaManualUsd`.
- [`lib/providers/gasto_provider.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/gasto_provider.dart):
  - Integración de `_resumenUsd`, `_resumenVes`, `_resumenUsdt`, `_resumenEur` vía `ResumenLenteMonetario.calcular`.
  - Exposición del getter `getResumenLente(String lente)` y unificación de advertencias de calidad monetaria (`hasPendingExpensesInCurrentLens`).

### 2.3 Base de Datos Local
- [`lib/data/datasources/local/database_helper.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/local/database_helper.dart):
  - `getMonthlyTotals` delega directamente en `ResumenLenteMonetario.calcular(gastos: getGastosByMonth)`.
  - Eliminación de sumas SQL duplicadas con fallbacks cruzados.

### 2.4 Interfaz de Usuario (Widgets Móviles)
- [`lib/ui/screens/more_screen.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/more_screen.dart):
  - Tarjeta de tasas con badge dinámico canónico (`✓ Actualizada hoy`, `Última tasa registrada`, `Sin tasa disponible`, `Tasa manual`).
  - Filas independientes para USD, EUR y USDT con fallback visual a `—` cuando la tasa es $\le 1.0$.
- [`lib/ui/screens/currency_calculator_screen.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/currency_calculator_screen.dart):
  - Supresión de `AppConstants.defaultTasaCambio` y de fallbacks cruzados entre monedas en `_obtenerTasaActiva`.
  - Cuadro comparativo simultáneo y chips de tasa con representación canónica `—` si la tasa no está disponible.
  - Indicador de brecha cambiaria protegido: muestra `Brecha USDT vs Dólar BCV: —` si falta alguna de las dos tasas.
- [`lib/ui/screens/review_expense_screen.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart):
  - `offlineSuffix` estandarizado a `· Última tasa registrada en caché` y `· Tasa manual`.
  - Eliminación de fallback de EUR a USD en `tasaAplicar`.
- Tarjetas de radiografía e historial (`expense_card.dart`, `currency_radiography_card.dart`, `daily_evolution_card.dart`, `purchase_radiography_card.dart`):
  - Consumo directo de lentes o campos anulables sin suposiciones de paridad.

### 2.5 Panel Web
- [`landing/src/pages/panel.astro`](file:///c:/Development/Control%20de%20gastos%20VE/landing/src/pages/panel.astro):
  - Saneamiento de cálculos de equivalencias: verificación estricta de tasas disponibles sin cruce USD/USDT/EUR.
  - Compilación estática verificada exitosamente (5/5 páginas generadas en Astro).

---

## 3. Guía de Pruebas Físicas en Dispositivo (*Rinde Más Dev*)

> [!IMPORTANT]
> **Artefacto Requerido:** Instalar exclusivamente el APK `rindemas-dev-apk` generado por GitHub Actions CI para el commit `dacb0f7` (o el commit final tras la subida de documentación). No tocar ni desinstalar la versión oficial de Google Play.

### Caso 1: Inspección de Tasas Independientes y Estados Canónicos en Pestaña "Más"
- **Evidencia en código:**
  - Navegación: Barra inferior $\rightarrow$ Cuarto ícono `Más` ([`lib/ui/screens/main_screen.dart:608-612`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/main_screen.dart#L608-L612)).
  - Tarjeta de Tasas: Título `Tasas de Cambio` ([`lib/ui/screens/more_screen.dart:482`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/more_screen.dart#L482)).
  - Badge de Estado: ([`lib/ui/screens/more_screen.dart:507-517`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/more_screen.dart#L507-L517)).
  - Botón de Refresco: `key: Key('refresh_rates_btn')` ([`lib/ui/screens/more_screen.dart:531`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/more_screen.dart#L531)).
  - Filas de Monedas: USD ([`L579`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/more_screen.dart#L579)), EUR ([`L611`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/more_screen.dart#L611)), USDT ([`L643`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/more_screen.dart#L643)).
- **Pasos:**
  1. Abrir *Rinde Más Dev*.
  2. Pulsar la pestaña `Más` en la barra inferior.
  3. Observar la tarjeta superior `Tasas de Cambio`.
  4. Si el teléfono tiene conexión y las tasas se sincronizaron hoy: el badge debe indicar `✓ Actualizada hoy`.
  5. Si el teléfono se coloca en modo avión y se reabre la app: el badge debe mostrar `Última tasa registrada`.
  6. Confirmar que cada fila muestra su valor independiente (`Bs. XX,XX / USD`, `Bs. XX,XX / EUR`, `Bs. XX,XX / USDT`). Ningún valor debe clonar a otro salvo coincidencia real de mercado.

### Caso 2: Calculadora Cambiaria sin Fallbacks Cruzados
- **Evidencia en código:**
  - Botón de apertura: `key: Key('more_rates_open_calculator_btn')` ([`lib/ui/screens/more_screen.dart:659`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/more_screen.dart#L659)).
  - Chips de Selección: `calc_chip_dolar_bcv` ([`L289`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/currency_calculator_screen.dart#L289)), `calc_chip_euro_bcv` ([`L297`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/currency_calculator_screen.dart#L297)), `calc_chip_usdt` ([`L305`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/currency_calculator_screen.dart#L305)), `calc_chip_custom` ([`L313`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/currency_calculator_screen.dart#L313)).
  - Campo Divisa: ([`lib/ui/screens/currency_calculator_screen.dart:650`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/currency_calculator_screen.dart#L650)).
  - Cuadro Comparativo Simultáneo: ([`lib/ui/screens/currency_calculator_screen.dart:475-494`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/currency_calculator_screen.dart#L475-L494)).
  - Brecha USDT vs BCV: ([`lib/ui/screens/currency_calculator_screen.dart:510`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/currency_calculator_screen.dart#L510)).
- **Pasos:**
  1. En la pestaña `Más`, pulsar `Abrir calculadora cambiaria`.
  2. Verificar los 3 chips superiores: cada uno debe reflejar su cotización respectiva.
  3. Ingresar `10` en el campo de monto de divisa.
  4. Revisar la sección inferior `Comparativa simultánea`:
     - Fila `Dólar BCV`: muestra `10 × tasa USD`.
     - Fila `Euro BCV`: muestra `10 × tasa EUR` (calculado con la tasa EUR real, no con la de USD).
     - Fila `USDT P2P`: muestra `10 × tasa USDT`.
  5. Verificar que la cápsula inferior de brecha calcule exactamente el diferencial porcentual entre USDT y Dólar BCV.

### Caso 3: Registro de Gasto en Divisa y Microcopy en Pantalla de Revisión
- **Evidencia en código:**
  - Botón Registrar en Calculadora: `key: Key('calc_register_expense_button')` ([`lib/ui/screens/currency_calculator_screen.dart:424`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/currency_calculator_screen.dart#L424)).
  - Origen alternativo: Menú `+` en barra principal ([`lib/ui/screens/main_screen.dart:566`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/main_screen.dart#L566)) $\rightarrow$ `Registrar gasto manual`.
  - Microcopy de fuente de tasa: ([`lib/ui/screens/review_expense_screen.dart:803-820`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L803-L820)).
- **Pasos:**
  1. En la calculadora, con chip `Dólar BCV` activo y monto `10`, pulsar `Registrar gasto`.
  2. Se abre `ReviewExpenseScreen` con el monto cargado.
  3. En la tarjeta de tasa de cambio, verificar el texto de procedencia:
     - Con conexión hoy: `Tasa oficial BCV (Hoy)`.
     - Si la tasa proviene de caché offline: `Tasa oficial BCV (Hoy) · Última tasa registrada en caché`.
  4. Cambiar la moneda a `EUR`: el campo de tasa debe actualizarse con la tasa de EUR, sin utilizar la de USD de reserva.
  5. Guardar el gasto y verificar que en el historial aparezca correctamente categorizado.
