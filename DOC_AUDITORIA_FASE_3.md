# Documento Técnico: Fase 3 de Auditoría Integral (Rinde Más)

Fecha: 15 de Octubre de 2026  
Estado: `Pendiente de validación 🧪` (CI en verde ✅, 240 tests pasando, disponible para validación por César)

---

## 1. Resumen Ejecutivo de Cambios

Se implementaron las 7 tareas priorizadas de calidad, integridad financiera, experiencia y arquitectura de la Fase 3:

| ID | Módulo / Archivos | Descripción del Cambio |
|:---|:---|:---|
| **`FIN-07`** | `lib/ui/widgets/summary_card.dart` | Cálculo exacto de días totales y restantes del mes basado en `anio` y `mes` seleccionados por el usuario, evitando mezclar días del mes actual (`now`) con meses históricos. |
| **`FIN-08`** | `lib/core/utils/amount_parser.dart`<br>`lib/ui/screens/review_expense_screen.dart` | `validatePositiveAmount` y `tryParsePositiveAmount` exigiendo valores estrictamente mayores a cero (`> 0`) en formularios y desglose de ítems, impidiendo gastos negativos o cero. |
| **`UX-03`** | `lib/providers/gasto_provider.dart`<br>`lib/ui/screens/expense_history_screen.dart` | Búsqueda global a lo largo de todo el historial financiero (cross-month). Al buscar, se oculta el selector de mes y se muestra el conteo global de resultados encontrados. |
| **`UX-05`** | `lib/ui/screens/chat_screen.dart`<br>`lib/ui/screens/more_screen.dart`<br>`lib/ui/screens/main_screen.dart`<br>`lib/ui/screens/dashboard_screen.dart` | Unificación total de navegación al asistente de IA mediante `Navigator.push`. Se eliminó la subvista embebida fragmentada en Más, garantizando que el botón Atrás siempre regrese a la pantalla de origen y la barra inferior permanezca visible. |
| **`SEC-12`** | `workers/`<br>`.agents/rules/gateway-cloudflare.md`<br>`docs/GATEWAY.md` | Código fuente del Cloudflare Worker versionado e integrado formalmente bajo `workers/`, con `README.md`, `package.json`, `wrangler.toml` e `.gitignore` protegiendo caché `.wrangler/`. |
| **`OCR-01`** | `lib/core/utils/image_hash_service.dart`<br>`lib/data/datasources/local/database_helper.dart`<br>`lib/providers/scan_queue_provider.dart` | Algoritmo SHA-256 nativo (sin dependencias externas) que deduplica comprobantes idénticos tanto en lotes múltiples como contra la cola activa (`pending`/`processing`/`ready`). |
| **`AI-01`** | `lib/ui/screens/chat_screen.dart`<br>`test/screens/chat_screen_test.dart` | 5 chips analíticos especializados (fugas, recorte, precios, patrones y compras pendientes), inyección de `tasa_usdt` en contexto de Gemini y mensaje de bienvenida explícito sobre capacidades. |

---

## 2. Detalle de Implementación

### 2.1 FIN-07: Días en Meses Históricos
- Se parametrizó `targetYear = anio ?? now.year` y `targetMonth = mes ?? now.month`.
- Los días totales del mes se calculan con `DateTime(targetYear, targetMonth + 1, 0).day`.
- Si el mes es pasado, `daysRemaining` es 0 y se muestra el mensaje de cierre de período en lugar de ritmo diario activo.
- Si el mes es actual, conserva el cálculo dinámico de días faltantes y ritmo diario.

### 2.2 FIN-08: Validación de Montos Positivos
- Se añadieron las utilidades `tryParsePositiveAmount` y `validatePositiveAmount`.
- Los campos de texto en `ReviewExpenseScreen` validan con `validatePositiveAmount(val)`.
- En `_guardarGasto()` se incorporó un guardián que rechaza cualquier intento de guardar montos menores o iguales a cero.
- En la edición de ítems individuales se protege la cantidad (`> 0`) y el precio unitario (`>= 0`).

### 2.3 UX-03: Búsqueda Global en Historial
- `GastoProvider.obtenerTodosLosGastos()` provee acceso a todos los gastos sin filtrar por mes.
- Al escribir en el buscador de `ExpenseHistoryScreen`, se consultan todos los gastos históricos y se ordenan cronológicamente.
- Se sustituye el `MonthSelectorBar` por una etiqueta informativa con el conteo de resultados en todo el historial.
- Al editar o eliminar un gasto encontrado, la caché de búsqueda global se invalida automáticamente.

### 2.4 UX-05: Unificación de Navegación del Chat
- Apertura estandarizada con `Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen(showBackButton: true)))`.
- `ChatScreen` gestiona el botón de retroceso (`Icons.arrow_back`), detiene el reconocimiento por voz si estaba activo y ejecuta `Navigator.maybePop()`.

### 2.5 SEC-12: Versionado del Worker
- Carpeta `workers/` con código fuente completo de `rindemas-gateway`.
- `.gitignore` actualizado para ignorar `.wrangler/` y `node_modules/`.
- Reglas `.agents/rules/gateway-cloudflare.md` actualizadas y validadas con `check_rules.ps1`.

### 2.6 OCR-01: Deduplicación SHA-256
- `ImageHashService`: Implementación FIPS 180-4 de SHA-256 en Dart puro.
- Migración SQLite v16: Añadida columna `image_hash TEXT` e índice `idx_scan_queue_image_hash`.
- `ScanQueueProvider`: Deduplicación en `enqueue` y `enqueueMultiple` para omitir imágenes duplicadas antes de OCR o llamadas de red.

### 2.7 AI-01: Chat IA Analítico y USDT
- 5 chips analíticos diferenciados (`kDefaultChatSuggestions`):
  1. *«¿Qué gastos pequeños están sumando más de lo que parece?»* (Fugas/gastos hormiga).
  2. *«¿Qué gastos podría reducir sin afectar lo esencial?»* (Recorte inteligente).
  3. *«¿Qué productos o gastos me han subido de precio?»* (Comparativa e inflación).
  4. *«¿En qué días o momentos del mes suelo gastar más?»* (Patrones temporales).
  5. *«¿Qué suelo comprar cada mes que aún no he comprado?»* (Planificación de compras recurrentes).
- Se suprimieron botones de acción directa en chips para prevenir contaminación accidental de datos.
- Inyección de `'tasa_usdt': settings.tasaCambioVesUsdt` en `contextData` para respuestas exactas sobre la tasa USDT.
- Mensaje de bienvenida inicial comunicando explícitamente el abanico de capacidades del asistente.
- Barra inferior preservada visible con ocultamiento reactivo al desplegar el teclado.

---

## 3. Guía de Pruebas Paso a Paso para César

### Prueba 1: Días en Mes Histórico (FIN-07)
1. Abrir la pantalla de Inicio o Gastos.
2. Navegar en el selector de meses hacia un mes pasado (ej. Febrero o Septiembre).
3. **Verificar:** La tarjeta de resumen no dice "Faltan X días" correspondientes al mes actual; muestra "Te sobraron $X en este período" o el balance histórico correcto.

### Prueba 2: Validación de Montos > 0 (FIN-08)
1. Presionar "+" para registrar un gasto manual.
2. Ingresar `0`, `-50` o dejar vacío el monto.
3. Intentar guardar.
4. **Verificar:** El formulario muestra el error de validación "Debe ser mayor a 0" y no permite registrar el gasto.

### Prueba 3: Búsqueda Global Cross-Month (UX-03)
1. Ir a la pestaña de Gastos.
2. Tocar el ícono de lupa para buscar.
3. Ingresar el nombre de un comercio o producto comprado en un mes distinto al seleccionado (ej. un gasto de hace varios meses).
4. **Verificar:** El gasto aparece en los resultados, el selector de mes se oculta y aparece la etiqueta "Búsqueda en todo el historial (X resultados)".

### Prueba 4: Navegación del Chat IA (UX-05)
1. Abrir el chat desde el botón de la barra superior del Dashboard.
2. Tocar el botón Atrás.
3. **Verificar:** Regresa directamente al Dashboard sin saltos de pestañas y con la barra inferior visible.
4. Ir a la pestaña Más y tocar "Asistente IA".
5. Tocar el botón Atrás.
6. **Verificar:** Regresa a la pantalla Más con fluidez.

### Prueba 5: Deduplicación en Cola de Escaneo (OCR-01)
1. Seleccionar una misma foto de comprobante 2 veces consecutivas o en el mismo lote de galería.
2. **Verificar:** La cola de escaneo solo procesa una única vez el comprobante y omite el duplicado idéntico.

### Prueba 6: Chat IA Analítico y USDT (AI-01)
1. Abrir el Asistente IA.
2. **Verificar:** El saludo inicial explica que puede analizar finanzas, aconsejar ahorro, registrar gastos o agregar a la lista de compras.
3. **Verificar:** Aparecen los 5 chips analíticos deslizables horizontalmente.
4. Tocar cualquiera de los chips (ej. *«¿Qué gastos pequeños están sumando más de lo que parece?»*).
5. **Verificar:** Se envía el mensaje automáticamente y la IA responde usando los gastos locales sin contaminar la lista ni agregar compras de prueba.
6. Preguntar: *"¿A cuánto está la tasa USDT?"*
7. **Verificar:** Responde con la cotización exacta configurada/cacheada en la app.
