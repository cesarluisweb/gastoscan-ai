# Herramientas del Panel Web: Calculadora Cambiaria y Asistente IA (Bloque 1)

> **Estado:** `Pendiente de validación 🧪` (CI en verde: run `44784979988`, build `32`, SHA `3df3104`; verificado HTTP 200 en `https://rindemas.cesarluis.com/panel`).
> **Alcance:** Panel Web Astro (`landing/`). Cero cambios en Flutter, SQLite o `firestore.rules`.

---

## 1. Arquitectura Modular

| Capa | Archivo | Responsabilidad |
|---|---|---|
| Totales mensuales y ahorro | `landing/src/lib/expense-money.js` | `computeMonthTotals` y `calculateSavingsHealth` compartidos entre `renderMetrics` y el Asistente IA. *(Nota: `renderCategories` conserva su desglose interno por ítems).* |
| Predicado fiscal único | `landing/src/lib/category-classifier.js` + `price-comparator.js` | `isTaxDescription` delega en `isTaxItem` (`iva`, `iva 16`, `iva 8`, `iva g`, `iva r`, `impuesto`, `tax`). |
| Calculadora pura | `landing/src/lib/currency-calculator.js` | `parseAmount`, conversión bidireccional, comparativa simultánea + brecha y `buildCalculatorExpensePrefill`. |
| Asistente IA puro | `landing/src/lib/ai-assistant.js` | Calendario VET (`America/Caracas`), `resolveSpokenExpenseDate`, `buildSemanticChatContext`, `prepareChatExtractions`, máquina de estados `extractionQueue`, `sliceRecentChatMessages` (`{ role, text }`), sanitización XSS y mapeo HTTP. |
| Componentes UI (sin `<script>`) | `landing/src/components/CalculatorModal.astro`, `landing/src/components/AiChatDrawer.astro` | Marcado HTML accesible (`role="dialog"`, `aria-modal="true"`, `aria-live="polite"`) con jerarquía `z-index`: Drawer `z-[85]` < Calculadora `z-[90]` < `#modal-expense` `z-[95]` < Confirmaciones `z-[100]` < `#panel-toast` `z-[110]`. |
| Coordinador Web | `landing/src/pages/panel.astro` | Estado de sesión, listeners, prefill seguro en `openExpenseModal` y llamadas a `POST /chat-analyst`. |
| CI Web | `.github/workflows/deploy_web.yml`, `landing/package.json` | Ejecuta `npm test` (29 pruebas en 5 archivos) y `npm run build` en `push` y `pull_request` (despliegue solo fuera de `pull_request`). |

---

## 2. Decisiones de Paridad y Divergencias Intencionales

1. **Paridad 1:1 en liquidación de la Calculadora (incluyendo `Personalizada ✏️`):**
   - `Dólar BCV` / `Euro BCV` abren `#modal-expense` en `DIVISA`, `USDT P2P` en moneda `USDT` nativa, y Bolívares arriba en `VES`.
   - `Personalizada ✏️` conserva `DIVISA` y la moneda seleccionada, aplicando `rateOverride` sobre `activeRates` (`tasaModificadaManualmente = true`) sin sobrescribir `officialRates` (paridad con `review_expense_screen.dart:1358-1368`).
2. **Coma decimal vs punto decimal:**
   - La Calculadora (`CalculatorModal.astro`) usa `type="text" inputmode="decimal"` con `parseAmount`, aceptando formato venezolano (`1.234,56`) e internacional (`1,234.56`).
   - `#modal-expense` conserva sus 5 inputs `type="number"` existentes (esperan punto decimal manual); todos los prefills inyectan strings con punto (`.toFixed(2)`).
3. **Divergencias intencionales respecto al móvil (Bloque 1):**
   - `buildSemanticChatContext` incluye `moneda_principal` (leído por `workers/src/index.js:872` como `defaultMoneda`) y `lista_compras: null`, `lista_compras_disponible: false` (para evitar que el LLM afirme que la lista está vacía mientras la sincronización de lista de compras espera el Bloque 2).
   - El 5.º chip de sugerencias en web consulta *"¿Cuáles son los productos en los que más se me ha ido el presupuesto este mes?"* en lugar del chip de lista de compras.
   - Sin micrófono web (`firebase.json` bloquea `microphone=()`).
4. **Cuota diaria compartida:**
   - El límite de seguridad de **50 consultas/día por cuenta (UID)** en Cloudflare D1 es compartido entre la app móvil y el panel web.
5. **Privacidad:**
   - El drawer muestra aviso permanente sobre el tránsito vía Cloudflare Workers y Google Gemini (retención hasta 55 días) con enlace directo a `/privacidad`.

---

## 3. Checklist de Aceptación (18/18)

| # | Criterio | Estado |
|---|---|---|
| 1 | Opción B: `type="number"` intacto en `#modal-expense` + `parseAmount` en Calculadora | ✅ |
| 2 | Cola distingue `save` de `close_without_save` con doble guarda y test | ✅ |
| 3 | Contrato Worker `messages: [{ role, text }]` testeado | ✅ |
| 4 | Tasa `EUR` en chat usa `liveRates.eur` y fuerza `BS_BCV` si llega `BS_USDT` | ✅ |
| 5 | `#panel-toast` y `showPanelToast` en `z-[110]` (amarillo + texto negro) | ✅ |
| 6 | `loadHistoricalRatesForExpenseDate` conserva UI, race guard y `resetManualOverrides` | ✅ |
| 7 | `computeMonthTotals` con test de paridad sobre 10 gastos sintéticos mixtos | ✅ |
| 8 | Predicado fiscal único (`isTaxDescription` -> `isTaxItem`) | ✅ |
| 9 | Paridad de liquidación en Calculadora (`DIVISA`/`USDT`/`VES`) | ✅ |
| 10 | 5.º chip compatible con web + `lista_compras: null` | ✅ |
| 11 | `modalExpFecha.max` en VET (`America/Caracas`) en los 3 puntos | ✅ |
| 12 | CI `deploy_web.yml` con `npm test` y `pull_request` sin desplegar | ✅ |
| 13 | Documento técnico `DOC_HERRAMIENTAS_PANEL_WEB.md` + `ROADMAP.md` | ✅ |
| 14 | `Personalizada ✏️` con `DIVISA` + `rateOverride` sin cambiar moneda | ✅ |
| 15 | `totalEditadoManualmente = true` en prefill e ítems con `precio = total/cantidad` | ✅ |
| 16 | `prepareChatExtractions`: repregunta de precio, inferencia de método, clasificación y `args.gastos` | ✅ |
| 17 | `finalizeExpenseSaveAndClose` en ambas salidas de `executeSaveExpense` y reset de `activeQueueItemId` | ✅ |
| 18 | Fecha por defecto en `openExpenseModal` y día actual en `renderMetrics` en VET | ✅ |

---

## 4. Guía de Pruebas Manuales (Navegador)

- **URL:** `https://rindemas.cesarluis.com/panel`
- **Pruebas automatizadas:** `cd landing && npm test` (29/29 en verde) y `npm run build` (5 páginas).

| Caso | Ruta / Control Real | Resultado Esperado |
|---|---|---|
| **P1. Abrir Calculadora desde tasas** | `landing/src/pages/panel.astro:201-212` (`.rate-pill-trigger`) y `:174` (`#btn-open-calculator`) | Abre `#modal-calculator` (`z-[90]`) con el chip de tasa tocado preseleccionado y foco en el campo superior. |
| **P2. Coma venezolana, swap y copiar** | `landing/src/components/CalculatorModal.astro` (`#calc-divisa-input`, `#btn-calc-swap`, `#btn-calc-copy`) | Escribir `12,50` calcula Bs. y actualiza las 3 filas + brecha `%`. `⇅` invierte orden. `Copiar` muestra `#panel-toast` amarillo con texto negro (`panel.astro:802`). |
| **P3. Personalizada + Registrar gasto** | `CalculatorModal.astro` (chip `Personalizada ✏️`, `#btn-calc-register-expense`) → `panel.astro:3070` (`openExpenseModal`) | Abre `#modal-expense` (`z-[95]`) en `USD` + `DIVISA` con la tasa manual aplicada en `activeRates` y el ítem `Gasto calculado`. |
| **P4. Asistente IA y sugerencias** | `panel.astro:178` (`#btn-open-chat`) → `AiChatDrawer.astro` (`#chat-suggestions-bar`) | Abre drawer derecho (`z-[85]`), muestra aviso de privacidad con enlace `/privacidad` y responde consultas con datos reales del mes visible. |
| **P5. Múltiples comercios y cola** | Escribir: *"Ayer compré medicina en Farmatodo por 10 dólares por pago móvil y pan en Panadería por 250 bolívares"* | Muestra 2 tarjetas (`Pendiente`). Pulsar `Revisar compra 1 de 2` abre `#modal-expense` **encima** del drawer (`z-[95] > z-[85]`). Guardar marca la tarjeta 1 como `Guardada ✓` y deja la 2 `Pendiente`. Cerrar el modal sin guardar en la 2 la devuelve a `Pendiente`. |
| **P6. Cambio automático de mes** | Navegar a un mes pasado, registrar un gasto con fecha de hoy (`panel.astro:3349` `finalizeExpenseSaveAndClose`) | Al guardar, el panel navega automáticamente al mes del gasto y muestra el toast `"Gasto guardado en [Mes Año]"`. |
| **P7. Reinicio y reporte local** | `AiChatDrawer.astro` (`#btn-chat-reset`, botón `🏳️ Reportar respuesta`) | Abren diálogos en `z-[100]` sin usar `window.confirm`. Cerrar y reabrir el drawer conserva el historial de la sesión. |
