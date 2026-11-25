# Documento Técnico: Consejos Dinámicos en Inicio (`AI-08`)

## 1. Resumen Ejecutivo y Alcance
La tarea **`AI-08`** reemplaza los mensajes estáticos de la tarjeta **Asistente IA** en **Inicio** (`DashboardScreen`) por un motor de consejos financieros útiles (2 a 4 líneas) basados en **señales ocultas reales** de SQLite, con generación periódica en segundo plano en Gemini y profundización en vivo en el Chat al pulsar **`Consultar ->`**.

### Problemas Resueltos
1. **Ceguera de banner y repetición de `SummaryCard`:** La tarjeta anterior repetía siempre el ritmo diario o los mismos totales visibles en la tarjeta superior.
2. **Ahorro de cuota D1 y tokens:** Se añadió `modo: "insight_inicio"` en el Cloudflare Worker sin `tools` (~900 tokens menos por llamada) y con caché estricta de 24 horas en `SharedPreferences`.
3. **Negritas literales y ruido visual:** Se eliminó el avatar de robot para usar todo el ancho útil de la tarjeta y se implementó renderizado real de negritas (`Text.rich`) reservado a montos, porcentajes, cantidades, productos y comercios clave.
4. **Copiado al portapapeles e idempotencia:** Se habilitó copiar consejos en Inicio y respuestas en el Chat, y se evitó duplicar mensajes/peticiones si el usuario vuelve a Inicio sin chatear y toca `Consultar ->` nuevamente.
5. **Eliminación de falsos ahorros cambiarios:** Se retiró el cálculo `brecha_capturada` / `rendimiento_cambiario` que inducía a Gemini a afirmar que pagar en Bs. a tasa BCV en lugar de USDT era un "ahorro".

---

## 2. Arquitectura Técnica

### 2.1 Señales Ocultas Precalculadas (`lib/services/ai_insight_service.dart`)
`AiInsightService.computeHiddenSignals` calcula 3 señales de compra reales que no se ven a simple vista en Inicio:
1. **Diferencias y subidas de precios (SQLite 60 días):** Reutiliza `DatabaseHelper.findPriceHistory` para detectar productos comprados al menos 10% más caros en un comercio que en otro (o subidas $\ge 12\%$ en el mismo local), excluyendo IVA (`DatabaseHelper.isTaxItem`).
2. **Gastos hormiga (`< $ 10,00` USD):** Acumula compras pequeñas discrecionales del mes ($\ge 4$ compras y $\ge 12\%$ del gasto mensual o $\ge \$ 20,00$) y detecta el comercio más repetido.
3. **Comparativa vs. mes pasado a la misma fecha (días `1..hoy`):** Consulta `DatabaseHelper.getGastosByMonth(prevYear, prevMonth)` filtrando hasta `now.day` para identificar categorías en alza ($\ge 20\%$) o con ahorro real ($\ge 15\%$, única base para felicitaciones ganadas).

### 2.2 Generación en Segundo Plano, Invalidación por Firma y Cuota Independiente `v3`
- **Endpoint:** `POST /chat-analyst` con `modo: "insight_inicio"` en [`workers/src/index.js`](../workers/src/index.js).
- **Esquema JSON estricto:** `responseMimeType: "application/json"`, `responseSchema: { consejo: string }`, sin bloque `tools` y `maxOutputTokens: 260`.
- **Separación entre validez de caché y cuota diaria:**
  - **Validez estricta (`getCachedGeminiInsight`):** un consejo cacheado en `SharedPreferences` (`v3`) solo se devuelve si coincide con el mes (`prefYearMonthKey`), la fecha local del día (`prefCachedDateKey == todayIso`, garantizando frescura diaria automática aunque no hayan cambiado los gastos) y la firma canónica determinista de los gastos (`buildExpenseSignature`, FNV-1a de 32 bits sobre `jsonEncode` ordenado por `uuid` e ítems, excluyendo metadatos volátiles de sync y evitando colisiones por delimitadores).
  - **Purga inmediata preservando cuota:** ante cualquier cambio en los gastos (alta, edición o borrado) o al bajar de 3 gastos (`< minExpensesForBackgroundGemini`), se eliminan `prefTextKey`, `prefSignatureKey`, `prefYearMonthKey` y `prefCachedDateKey`, conservando intactos `prefLastFetchDateKey` y `prefFetchCountKey`.
  - **Tope diario independiente (`3/día`):** `prefFetchCountKey` (con migración segura `?? 1` si ya existía `prefLastFetchDateKey == todayIso`) se protege con reserva síncrona en memoria (`_completedTodayCount + _inFlightReservations`) para impedir que ráfagas concurrentes superen el tope, contando todo intento completado en el servidor (incluidas respuestas no-JSON).
  - **Concurrencia y sin parpadeo en `DashboardScreen`:** `_inFlightTokens` (por firma e identidad de token) + `_latestFetchEpoch` evitan atascos y escrituras obsoletas. En [`lib/ui/screens/dashboard_screen.dart`](../lib/ui/screens/dashboard_screen.dart), `build` filtra `cachedGeminiText` y `hiddenSignals` por clave `todayIso + firma` sin `setState` en `build`, descarta respuestas lentas por `requestId` y aplica un *debounce* de 3 s en cambios posteriores al arranque en frío (cancelado en `dispose`).
  - **Purga de claves heredadas:** `_purgeLegacyCache` limpia claves `_v1` y `_v2` al migrar a `_v3`.
- **Respaldo local inteligente:** si no hay conexión, se alcanzó el tope de 3/día, quedan `< 3` gastos o aún corre el *debounce* de 3 s, `_buildLocalSmartInsight` redacta al instante el hallazgo de mayor impacto desde las señales de SQLite (o el consejo curado/ritmo diario si aún no hay historial).
- **Nota futura (`AI-11`):** rotación opcional por franjas horarias (mañana/tarde/noche) enviando `ultimo_consejo` al Worker para garantizar variedad genuina sin parafrasear el mismo hallazgo.

### 2.3 Profundización en Vivo al Pulsar `Consultar ->`
- **`ChatProvider.startInsightDeepDive`** ([`lib/providers/chat_provider.dart`](../lib/providers/chat_provider.dart)):
  - Inserta `'Sobre el análisis de hoy:\n\n<consejo>'` como burbuja del Asistente (sin burbuja artificial del usuario) y fija `_pendingInsightDeepDive`.
  - Es **idempotente** mediante `_lastDeepDivedInsight`: si el usuario regresa a Inicio sin interactuar y vuelve a tocar `Consultar ->` sobre el mismo consejo, abre el chat existente sin duplicar burbujas ni llamar otra vez a Gemini.
- **`ChatScreen._runInsightDeepDive`** ([`lib/ui/screens/chat_screen.dart`](../lib/ui/screens/chat_screen.dart)):
  - Al abrir el chat con un consejo pendiente, muestra el indicador de carga y consulta `/chat-analyst` en vivo con el contexto semántico + señales ocultas de SQLite para entregar el desglose detallado y continuar la conversación.

---

## 3. Evidencia `archivo:línea` de Controles Visuales

- **Tarjeta Asistente IA (Inicio)** — [`lib/ui/widgets/ai_insight_card.dart`](../lib/ui/widgets/ai_insight_card.dart):
  - Contenedor principal: `Key('ai_insight_card')` (`línea 164`).
  - Botón Copiar consejo: `InkWell` con `Key('ai_insight_card_copy_btn')` e icono `Icons.copy_outlined` (`línea 202`).
  - Botón Consultar: `InkWell` con `Key('ai_insight_card_consultar_btn')` (`línea 215`).
  - Texto enriquecido a ancho completo con `onLongPress` para copiar: `GestureDetector` + `buildFormattedText` (`líneas 245-252`).
- **Chat con Asistente IA** — [`lib/ui/screens/chat_screen.dart`](../lib/ui/screens/chat_screen.dart):
  - Copia por pulsación larga en burbujas: `GestureDetector(onLongPress: ...)` (`línea 1182`).
  - Botón Copiar al pie de respuestas del asistente: `InkWell` con `Key('chat_copy_message_btn_$index')` junto a `Reportar respuesta` (`línea 1266`).

---

## 4. Guía de Pruebas en Dispositivo Físico (*Rinde Más Dev*)

1. **Consejo útil sin repetición de `SummaryCard`:**
   - Abre la pestaña **Inicio** con al menos 3 gastos registrados en el mes actual.
   - Verifica que la tarjeta **Asistente IA** no muestra el icono de robot, ocupa todo el ancho, no repite el presupuesto/total de la tarjeta superior y muestra negritas reales sin asteriscos `**` literales.
   - Verifica que no afirma "ahorrar pagando en bolívares a tasa BCV en lugar de USDT".
2. **Copiar consejo y mensajes del Chat:**
   - Toca el icono de copiar (`Icons.copy_outlined`) o mantén presionado el consejo en Inicio -> aparece el `SnackBar` `'Consejo copiado al portapapeles'` y al pegar en cualquier app el texto llega limpio sin `**`.
   - En **Asistente IA**, toca **`Copiar`** al pie de una respuesta (o mantén presionada una burbuja) -> aparece `'Mensaje copiado al portapapeles'`.
3. **Profundización en vivo e idempotencia de `Consultar ->`:**
   - Toca **`Consultar ->`** en Inicio -> se abre el Chat mostrando primero `'Sobre el análisis de hoy: ...'`, aparece el indicador de carga y llega el análisis ampliado en vivo sin hablar de ahorros por brecha BCV vs. USDT.
   - Sin escribir nada, regresa a **Inicio** y vuelve a tocar **`Consultar ->`** -> debe abrir el mismo chat con la respuesta ya cargada, sin duplicar mensajes ni disparar una nueva llamada a Gemini.

---

## 5. Metadatos de Validación
- **Build CI:** `733` | **Run:** `44928504292` | **Commit SHA:** `1ab66fa`
- **Cloudflare Worker (`rindemas-gateway`):** Desplegado en producción (`Version ID: a3975df5-bf8c-4399-b183-9b9b90259531`) con `modo: "insight_inicio"` y la nota cambiaria corregida en el Chat normal.
- **Pruebas automatizadas:** Cubiertas en `test/services/ai_insight_service_test.dart`, `test/widgets/ai_insight_card_test.dart`, `test/providers/chat_provider_test.dart` y `test/screens/chat_screen_test.dart`.
- **Estado:** `Completada ✅` (validada en dispositivo físico por César el 21/11/2026).
