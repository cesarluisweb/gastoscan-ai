---
name: sincronizar-panel-web
description: Procedimiento para portar y sincronizar flujos, formularios y cálculos financieros desde la app móvil Flutter hacia el panel web Astro.
---

# Procedimiento de Sincronización Móvil -> Panel Web

Esta habilidad se activa cuando una tarea requiera alinear o sincronizar pantallas, formularios o lógica de negocio de la app Flutter (`ReviewExpenseScreen`, etc.) con el panel web (`landing/src/pages/panel.astro`).

## 1. Mapeo Inicial contra la Pantalla Móvil
1. Identificar la pantalla Flutter de referencia (ej. `lib/ui/screens/review_expense_screen.dart`).
2. Mapear la jerarquía exacta de tarjetas, etiquetas, proporciones de columnas (ej. 35/65 descripción/categoría) y flujos de divulgación progresiva.
3. Contrastar con `.agents/rules/dinero-datos.md`:
   - Orden canónico de monedas: `USD -> VES -> USDT -> EUR`.
   - Exclusiones de divisas (ej. no existe liquidación en Bs. P2P para EUR).
   - Inmutabilidad y preservación de centavos originales al reabrir en edición.

## 2. Extracción de Módulos Puros y Entrega 0 (Sin Acoplamiento al DOM)
Para evitar scripts monolíticos inmanejables y regresiones silenciosas en `panel.astro`:
- **Entrega 0 para lógica inline existente:** Si una nueva herramienta reutiliza cálculos que viven inline en `panel.astro` (ej. totales mensuales en `renderMetrics`), extraerlos primero a `landing/src/lib/` en un paso aislado con un test de paridad contra la implementación inline original sobre gastos sintéticos mixtos.
- Aislar toda lógica matemática, de fechas VET, de contexto IA y de colas en librerías puras en `landing/src/lib/` (`expense-money.js`, `category-classifier.js`, `price-comparator.js`, `currency-calculator.js`, `ai-assistant.js`).
- Comprobar siempre la **moneda de las métricas** del móvil: `savingsSnapshot` en el contexto del Asistente IA se calcula en `moneda_presupuesto`, nunca en la moneda del lente visual (`displayCurrency`).
- Prohibido acoplar la matemática financiera al DOM de Astro.

## 3. Pruebas Automatizadas con Node Nativo (Compatible con Node 20 CI)
Antes de tocar el DOM o Astro:
1. Crear o actualizar pruebas en `landing/test/*.test.js` usando el test runner nativo de Node (`node:test`).
2. Registrar explícitamente cada archivo nuevo en el script `"test"` de `landing/package.json` (evitar globs como `landing/test/*.test.js` en CI de Node 20).
3. Verificar la tabla de casos dorados de dinero (C1 a C6), paridad de liquidación (`DIVISA`, `BS_BCV`, `BS_USDT`, bloqueo de `BS_USDT` en `EUR`, `rateOverride` en tasa personalizada) y estados de colas (`save` inmutable frente a `close_without_save`).

## 4. Adaptación en Astro, Prefills y Accesibilidad
1. Extraer marcado de nuevos modales/drawers a `landing/src/components/*.astro` (sin `<script>` propio) e importarlos en `landing/src/pages/panel.astro`.
2. Respetar la jerarquía `z-index` de `.agents/rules/web.md` §5 (`z-[85]` / `z-[90]` / `z-[95]` / `z-[100]` / `z-[110]`) con `style="z-index: N;"`.
3. En prefills hacia `#modal-expense`:
   - Fijar `totalEditadoManualmente = true` y proveer `precio = (total / cantidad).toFixed(2)` con punto decimal por ítem.
   - Para fechas pasadas sin tasa manual bloqueada, invocar `loadHistoricalRatesForExpenseDate(fecha, { resetManualOverrides: false })` en lugar de disparar `change` (para no borrar tasas personalizadas).
   - Al guardar, actualizar `selectedYear`/`selectedMonth` **antes** de `await loadDashboardData()` si cambió el mes, y emitir `'save'` en todas las salidas de `executeSaveExpense` (metadatos y guardado completo) **antes** de `closeExpenseModal({ reason: 'saved' })`.
   - Limpiar `activeQueueItemId = null` en `openEditExpenseModal`.
4. Proveer diálogos accesibles (`role="dialog"`, `aria-modal="true"`) en lugar de `window.confirm()`.

## 5. Verificación y Despliegue
1. Ejecutar las pruebas unitarias: `Set-Location landing; npm test; Set-Location ..` (mismo script que ejecuta `.github/workflows/deploy_web.yml` en `push` y `pull_request`).
2. Compilar Astro localmente para validar que no haya errores de bundling ni variables duplicadas: `Set-Location landing; $env:ASTRO_TELEMETRY_DISABLED="1"; npm run build; Set-Location ..`.
3. Commitear y pushear a `main`.
4. Monitorear el CI con `powershell -ExecutionPolicy Bypass -File scripts/wait_ci.ps1`.
5. Validar HTTP 200 en `https://rindemas.cesarluis.com/panel`.
