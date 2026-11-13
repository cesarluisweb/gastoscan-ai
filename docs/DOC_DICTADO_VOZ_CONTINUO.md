# Documento Técnico: Dictado Continuo por Voz y Blindaje Temporal

- **Estado:** Implementado y Verificado ✅
- **Fecha:** 13 de noviembre de 2026
- **Módulos afectados:**
  - Móvil (Flutter): `lib/ui/widgets/voice_expense_sheet.dart`, `lib/ui/screens/chat_screen.dart`, `lib/data/datasources/remote/gemini_service.dart`, `lib/ui/screens/review_expense_screen.dart`, `lib/providers/gasto_provider.dart`
  - Gateway (Cloudflare Workers): `workers/src/index.js`
  - Suite de Pruebas: `test/widgets/voice_expense_sheet_test.dart`, `workers/test/quota.test.js`
- **Commits asociados:**
  - Móvil: `1fdd815` (CI Build 692, run 43428721902)
  - Gateway Worker: `6709639` (Despliegue `6a737593-e444-4ff4-a232-fd126e9ac0e1`)

---

## 1. Problemas Identificados y Causa Raíz

### 1.1. Borrado de texto tras pausas al dictar
- **Comportamiento observado:** Al dictar un gasto y hacer un silencio breve para pensar, al retomar la palabra se borraba todo lo reconocido anteriormente y solo aparecía lo nuevo.
- **Causa raíz:** En Android, el plugin nativo `speech_to_text: 7.5.0` puede emitir eventos `onResult` donde `val.recognizedWords` reinicia su búfer interno desde una cadena vacía tras una pausa intermedia (incluso dentro de `pauseFor: 10s`). El código capturaba `previousText` únicamente una vez al iniciar la sesión del micrófono, por lo que cualquier reinicio nativo de `recognizedWords` sobrescribía el `TextEditingController`. Adicionalmente, el callback `onStatus('notListening')` marcaba de forma prematura `_isListening = false` antes de recibir resultados finales rezagados.

### 1.2. Gastos dictados guardados pero invisibles en la lista
- **Comportamiento observado:** El usuario dictaba un gasto, revisaba y pulsaba "Guardar Gasto". Aparecía el SnackBar de guardado exitoso, pero el registro no figuraba en la lista de gastos.
- **Causa raíz doble:**
  1. **Alucinación de fechas en Gemini:** En `modo: 'dictado_gasto'`, el esquema de `registrar_gasto` requería `fecha` en formato `YYYY-MM-DD`, pero ni el cliente ni el Worker le proporcionaban la fecha actual de referencia (`fecha_hoy`). Gemini alucinaba fechas de ejemplo (como años anteriores o fechas arbitrarias).
  2. **Filtro mensual rígido en `GastoProvider`:** Al guardar en SQLite, el gasto se persistía con la fecha alucinada (ej. de otro mes), mientras que la pantalla de Gastos permanecía filtrando el mes actual seleccionado (`_selectedYear` / `_selectedMonth`), ocultándolo visualmente.

---

## 2. Solución Arquitectónica

### 2.1. Acumulación Continua de Segmentos de Voz
Se implementó un patrón de buffer en dos capas tanto en `VoiceExpenseSheet` como en `ChatScreen`:
- `_committedText`: Texto confirmado de frases o segmentos hablados previamente.
- `_currentSegmentText`: Texto que está siendo reconocido activamente en la ráfaga actual.
- Funciones puras auxiliares:
  - `joinSpeechParts(a, b)`: Concatena segmentos asegurando un único espacio limpio intermedio.
  - `shouldCommitPreviousSpeechSegment(previous, current)`: Detecta heurísticamente si el motor nativo reinició el reconocimiento (por ejemplo, si el nuevo texto es más corto y no comparte prefijo con el anterior).

### 2.2. Anclaje Temporal Determinístico (Regla de Oro de IA)
*"La inteligencia artificial interpreta; el código determinista calcula."*
- **En Cloudflare Worker (`workers/src/index.js`):**
  - Se inyecta `fechaReferenciaHoy` (`contextData.fecha_hoy` o fecha oficial de Venezuela UTC-4 vía `getVenezuelaDateString()`).
  - Se agregan instrucciones al prompt de `dictado_gasto` para resolver referencias relativas:
    - *"hoy"* / sin fecha $\rightarrow$ `fechaReferenciaHoy`
    - *"ayer"* / *"anoche"* $\rightarrow$ 1 día antes
    - *"antier"* / *"anteayer"* $\rightarrow$ 2 días antes
    - *"hace X días"* $\rightarrow$ resta aritmética exacta
    - Días de la semana $\rightarrow$ anclados a la fecha actual sin permitir fechas futuras ni años viejos.
- **En la App Flutter (`GeminiService.resolveSpokenExpenseDate`):**
  - Capa de defensa local ante respuestas de red: si el texto dictado no incluye referencias de tiempo explícitas (ayer, antier, días de la semana, meses o patrones de fecha), se fuerza estrictamente la fecha de hoy, neutralizando cualquier alucinación del LLM.

### 2.3. Alineación Reactiva del Filtro Mensual al Guardar
En `GastoProvider.agregarGasto`:
- Se parsea la fecha del nuevo gasto (`YYYY-MM-DD`).
- Se actualizan automáticamente `_selectedYear` y `_selectedMonth` para que coincidan con la fecha del gasto guardado.
- Al ejecutarse `cargarDatos()`, la vista navega y renderiza inmediatamente el período donde el gasto fue registrado.

---

## 3. Pruebas y Verificación

1. **Pruebas Automatizadas Unitarias y de Widget:**
   - `test/widgets/voice_expense_sheet_test.dart`:
     - Prueba de concatenación limpia y detección de reinicio de segmento (`shouldCommitPreviousSpeechSegment`).
     - Pruebas determinísticas de fechas en `GeminiService.resolveSpokenExpenseDate` ("ayer", "antier", "hace 3 días", sin mención de fecha).
     - Prueba de widget con `FakeSpeechToText` simulando pausas y confirmando que no se pierde texto previo.
2. **Pruebas en Gateway:**
   - `workers/test/quota.test.js`: 13 pruebas unitarias en Node.js pasando al 100%.
   - Endpoint `/health` verificado en producción con estado 200 OK.
3. **Validación en Dispositivo Físico:**
   - Verificado con éxito por César en *Rinde Más Dev* (`rindemas-dev-apk`, Build 692, commit `1fdd815`).
