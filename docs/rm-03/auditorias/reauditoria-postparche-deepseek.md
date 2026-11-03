# RM-03 — Reauditoría adversarial independiente de E0-02 (postparche)

> Auditoría estrictamente de solo lectura. No se modificó, creó, commiteó ni pusheó nada.  
> No se ejecutaron `flutter analyze` ni `flutter test`: el SDK de Flutter/Dart no está instalado localmente. Todo lo que sigue es **inspección de código y del diff real**, no evidencia de CI.

---

## 1. Veredicto

## RECHAZADO

El parche corrige de forma real S1.1, S2.1, S3.1 (ruta activa), S3.4 y el cerrojo de concurrencia. Sin embargo, quedan **dos defectos bloqueantes**:

1. **Pérdida total del mapa histórico si `prefs.setString` lanza una excepción** (`exchange_rate_service.dart:566-577` + `610-615`): el `catch` exterior interpreta el fallo de escritura como JSON corrupto, añade la clave a `keysToRemove` y borra el mapa completo, incluidas las entradas válidas. Además, la marca de purga puede quedar fijada, haciendo la pérdida permanente.
2. **La caché inválida se sigue usando** en `getRateForDate` (`:309`, `:351`, `:365`, `:374`, `:394`) porque acepta cualquier valor `> 0`, aunque A-07 define `<= 1.0` como inválido. Un fallo de purga, o un valor corrupto escrito después de fijar la marca, produce cálculos monetarios con tasas absurdas (p. ej. 0,5 VES/USD).

No se puede declarar E0-02 cerrado ni aceptado para producción con esos dos caminos abiertos.

---

## 2. Matriz de hallazgos

| ID | Estado | Severidad | Archivo y líneas | Evidencia | Consecuencia |
|---|---|---|---|---|---|
| S1.1 | CORREGIDO | — | `test/services/exchange_rate_service_cache_purge_test.dart:63,102-104,196-214`; `lib/services/exchange_rate_service.dart:578-584` | Existe la rama `key == 'cached_exchange_rate'`; elimina no numéricos, no finitos y `<= 1.0`; la prueba ahora es coherente con la implementación. | El fallo garantizado de la auditoría anterior queda resuelto por inspección. |
| S2.1 | CORREGIDO | — | `lib/services/exchange_rate_service.dart:521-560` | `try/catch` por entrada; comprobaciones `is num`, `is Map`, `is String`; no hay casts que lancen (`(val['valor'] ?? ...) as num?` desapareció). | Una entrada mal tipada se descarta individualmente; las válidas del mismo mapa se conservan. |
| S2.2 | NO CORREGIDO (fuera de alcance) | ALTA | `lib/services/exchange_rate_service.dart:92,126-129,405-412`; `lib/providers/settings_provider.dart:86` | Persisten los fallbacks USDT→USD en adquisición y en `SettingsProvider`. | H-1 global sigue abierto; debe cerrarse en E0-03. No es una regresión de este parche. |
| S2.3 | NO CORREGIDO (fuera de alcance) | ALTA | `lib/data/models/gasto_model.dart:208-209`; `lib/ui/screens/chat_screen.dart:385`; `lib/data/datasources/local/database_helper.dart:682,757`; `lib/core/utils/currency_formatter.dart:70-74` | Getters y consumidores siguen derivando USDT desde USD. | H-2 en presentación/agregación sigue abierto; no es una regresión de este parche. |
| S3.1 | CORREGIDO (ruta activa) | — | `lib/data/models/gasto_firestore_mapper.dart:39-46`; `lib/data/datasources/remote/firestore_gastos_remote_data_source.dart:38-46`; `lib/services/sync_service.dart:175-197` | `toPayload` omite opcionales nulos; el único consumidor productivo es `upsertGasto` con `SetOptions(merge: true)`; los ítems se hidratan en `database_helper.dart:580-605,626-632`. | El merge ya no sobrescribe con `null` en la ruta activa. |
| S3.1-b | NUEVO | BAJA | `lib/data/models/gasto_model.dart:84-88` | `toFirestoreMap()` sigue incluyendo todos los nulos y es público; solo se usa en `test/services/sync_service_delete_account_test.dart:294-312`. | Trampa latente si alguien lo usa como payload remoto en el futuro; hoy no hay consumidor productivo. |
| S3.2 | NO CORREGIDO (fuera de alcance) | MEDIA | `lib/data/models/gasto_model.dart:158,161` | `copyWith` usa `x ?? this.x`; no permite limpiar `totalUsdt`/`tasaUsdt` a `null`. | Sigue pendiente; el informe no lo declara cerrado. |
| S3.3 | PARCIAL | BLOQUEANTE | `lib/services/exchange_rate_service.dart:566-577,610-618` | Si `setString` **lanza**, el `catch` exterior (`:573`) añade la clave a `keysToRemove` (`:575`); luego `remove` (`:611`) borra el mapa completo. `allWritesSucceeded` sigue en `true`, por lo que no hay `StateError`; `ensure` fija la marca (`:468`). | Pérdida definitiva del historial válido. Contradice “se conserva el historial original si falla la escritura”. Reproducible con un fake cuyo `setString` lance. |
| S3.4 | CORREGIDO | — | `lib/services/exchange_rate_service.dart:433-452`; `lib/domain/monetary/rate_quote_input.dart:43-54` | Regex `YYYY-MM-DD` + normalización con `DateTime` y comparación `año/mes/día`; años bisiestos e imposibles (`2026-02-30`, `2026-13-40`) rechazados. | La validación de calendario real está implementada. Detalle menor: lógica duplicada y año `0000` aceptado. |
| N1 | NUEVO | BLOQUEANTE | `lib/services/exchange_rate_service.dart:309,351,365,374,394` | `getRateForDate` acepta caché/remoto con `> 0`; A-07 define inválido `<= 1.0`. | Tras una purga fallida o un valor corrupto escrito después de la marca, se usa una tasa 0,5/∞. Error monetario de órdenes de magnitud. |
| N2 | NUEVO | ALTA | `lib/services/exchange_rate_service.dart:56,306,470-475` | Los llamadores ignoran el `-1` de `ensure`; `ensure` captura todo sin `debugPrint`. | La purga fallida es silenciosa y el servicio continúa con caché sucia (ver N1). Incumple AGENTS.md sobre no silenciar `catch` en SharedPreferences. |
| N3 | NUEVO | ALTA | `lib/services/exchange_rate_service.dart:61-65` | Los filtros `<= 50.0` no rechazan `NaN` ni `Infinity`. | Si la purga falla, un `NaN`/`Infinity` puede llegar a `ExchangeRatesData`; `Infinity` además pasa el `> 0` de N1. |
| N4 | NUEVO | MEDIA | `lib/services/exchange_rate_service.dart:542-551` | Exige `source` no vacío; una entrada con `valor` numérico válido pero sin `source`/`fuente` se elimina. | Posible sobrepurga de entradas legadas válidas. `tasas_historico_v1` no tiene escritor/lector actual, por lo que el impacto es de caché, pero el contrato v1.2 debe confirmarlo. |
| N5 | NUEVO | MEDIA | `lib/services/exchange_rate_service.dart:457,506` | `prefs.getBool(mark)` y `prefs.getString('tasas_historico_v1')` están fuera de `try`; un tipo corrupto lanza `TypeError`. | La lectura de tasas puede romperse o la purga reintentarse indefinidamente sin éxito. No hay pérdida de datos, pero A-07 falla de forma no controlada. |
| N6 | NUEVO | MEDIA | `lib/services/exchange_rate_service.dart:470-475,556-559,573` | `catch (_)` sin registro. | Fallos invisibles; incumple la regla del proyecto de registrar errores en capas críticas. |
| N7 | NUEVO | MEDIA | `test/services/exchange_rate_service_cache_purge_test.dart` | Faltan pruebas de: `setString` que lanza, `setString` que retorna `false`, `NaN`/`Infinity`, `source` ausente, marca corrupta, consumidor tras `-1`, integración `getAllTodayRates`/`getRateForDate`. | CI no detectaría B1/N1/N3. |
| N8 | NUEVO | BAJA | `lib/data/models/gasto_model.dart:91,94,104`; `lib/data/models/gasto_firestore_mapper.dart:22-24` | `fromMap` convierte `total_usd` ausente en `0` y `tasa_cambio` ausente en `1.0`; `toPayload` siempre escribe ambos. | Un mapa parcial podría empujar `0`/`1.0` sobre Firestore. Es preexistente, no introducido por este parche. |
| N9 | NUEVO | BAJA | `MEMORY.md:10-12` | Declara “S1.1 & A-07 resuelto”, “S3.3 & S4.3 resuelto” y “sin alterar datos de usuarios”. | A-07 y S3.3 son parciales (B1/N1); S4.3 no figura en la lista auditada; A-07 sí muta SharedPreferences (caché). |

---

## 3. Auditoría A-07

### A. Preservación de datos

- **Entrada mal tipada:** correctamente aislada. `decoded.forEach` tiene `try/catch` por entrada (`:521-560`); `rawRate` y `rawSource` se validan con `is num`/`is String` (`:539-540`). Una entrada con `valor: 'no_es_un_numero'` o `source: 99999` se descarta sin borrar el resto. Esto resuelve S2.1.
- **Entradas válidas del mismo mapa:** se copian a `cleanedMap` (`:531`, `:547`) y se reescriben con `setString` (`:566`). Se conservan.
- **`source` mal tipado:** se descarta solo esa entrada; no arrastra a las demás.
- **Historiales anteriores a 2023:** no hay corte por fecha; `_isValidCalendarDate` solo exige fecha real. `2022-05-01` y `cached_rate_USD_2022-10-15` se conservan (prueba `:59-61,75,99-100,113`).
- **Excepción por una sola entrada:** el `try/catch` interno evita el borrado del mapa. **Excepción:** si `setString` lanza, el `catch` exterior (`:573`) borra el mapa completo (B1).
- **Sobrepurga por `source`:** una entrada con tasa numérica válida pero sin `source`/`fuente` se elimina (`:542-551`). El contrato v1.2 debe confirmar si eso es “corrupto”; si no lo es, es sobrepurga (N4).
- **Caso límite:** si una entrada tiene `valor: 0` y `rate: 40.0`, el `??` elige `0` y la elimina; igual con `source: ''` y `fuente: 'x'`. Es un caso raro, pero el criterio debería ser “primer valor válido”, no “primer valor no nulo”.

### B. Fallos de persistencia

| Escenario | Comportamiento real | Integridad |
|---|---|---|
| `prefs.remove` retorna `false` | `allWritesSucceeded = false` (`:612-613`); al final lanza `StateError` (`:617-618`). La clave inválida **permanece**. | No se fija la marca; se reintenta. Pero el dato inválido sigue disponible para `getRateForDate` (N1). |
| `prefs.setString` retorna `false` | `allWritesSucceeded = false` (`:567-569`); no se añade la clave a `keysToRemove`; el mapa original permanece; al final lanza `StateError`. | Correcto por inspección: no se pierde el historial. **No hay prueba de este caso.** |
| `prefs.setString` **lanza** | El `catch` exterior (`:573`) añade la clave a `keysToRemove` (`:575`); después `remove` (`:611`) borra el mapa completo. `allWritesSucceeded` sigue `true`; no hay `StateError`; `ensure` fija la marca (`:468`). | **Pérdida total y permanente del historial válido.** B1. |
| `prefs.setBool` retorna `false` | `ensure` retorna `-1` sin fijar la marca (`:468-471`). | Correcto; se reintenta. |
| Purga parcial | Las claves inválidas se van borrando una a una; si una falla, las anteriores ya se borraron y se lanza. | Reintento seguro para las claves inválidas; no se pierden válidas salvo B1. |
| Marca persistente | Solo se fija si `purgar` retorna y `setBool` es `true` (`:467-471`). | Correcto en el caso normal; **incorrecto en B1**, porque `purgar` puede “retornar” tras borrar el mapa. |

**Respuesta directa:** un fallo de `remove` deja el dato inválido en disco y el servicio lo sigue usando; un fallo de `setString` que retorna `false` conserva el mapa original; un fallo de `setString` que lanza **destruye el mapa completo**. La marca no es garantía suficiente de integridad.

### C. Uso después de un fallo

- `getAllTodayRates` (`:56`) ignora el resultado de `ensure`. Luego lee semillas (`:60-65`) y filtra `<= 50.0`. Ese filtro protege de `0.5`, pero **no** de `NaN` (porque `NaN <= 50.0` es `false`) ni de `Infinity`. Si la purga falló, un `NaN`/`Infinity` puede propagarse a `ExchangeRatesData`.
- `getRateForDate` (`:306`) ignora el `-1`. Para fechas no actuales lee `cached_rate_${moneda}_$isoDate` y acepta cualquier `> 0` (`:309`). Por tanto:
  - Si la purga falló y la clave contenía `0.5`, se devuelve `0.5`.
  - Si la marca ya estaba fijada y posteriormente se escribió un `0.5` (p. ej. desde un `promedio` remoto anómalo en `:351-352`), se devuelve `0.5`.
  - Si la clave contenía `Infinity`, `Infinity > 0` es `true` y se devuelve `Infinity`.
- **Consecuencia:** un gasto histórico en USD se convierte a VES multiplicando por `0.5` o `∞`; el resultado es un valor monetario inventado, exactamente lo que la fase 0 quiere evitar.
- **Clasificación:** BLOQUEANTE (N1), con N2/N3 como agravantes.

### D. Clave `cached_exchange_rate`

- **Qué representa:** es la semilla histórica de **USD/VES**. Se escribe junto a `cached_rate_usd` (`:81`, `:112`) y se lee como fallback de USD (`:60`). El historial de git lo confirma: en `f845d67` y `65566da` ya era la tasa USD/BCV.
- **¿Eliminar `<= 1.0`, no numéricos y no finitos respeta v1.2?** Sí. Una tasa VES/USD válida es `> 1.0`; un `-5.0`, `0.0`, `NaN`, `Infinity` o un `String` no es una tasa utilizable. No se encontró ningún otro consumidor que le dé otra semántica.
- **¿Puede eliminar una tasa válida?** No por el umbral; el riesgo sería que una versión antigua hubiera guardado ahí una tasa no-VES, pero el historial y los escritores actuales lo desmienten.
- **Observación:** la purga conserva `1.0 < valor <= 50.0`, pero `getAllTodayRates` los descarta después (`:61`). No es un problema, solo una inconsistencia de umbrales.

### E. Concurrencia e idempotencia

- `_activePurgeFuture` se asigna después de crear `purgeTask` (`:478`) y se limpia en `finally` (`:480-483`). El closure captura todas las excepciones y retorna `-1`, por lo que **no queda un Future fallido reutilizable**.
- Dos llamadas simultáneas comparten la misma purga; la segunda espera y recibe el mismo resultado (`:461-463`). La prueba `:235-253` cubre este caso por inspección.
- La marca se fija solo tras una purga que retorna (`:467-471`). La comprobación inicial de la marca (`:456-459`) es correcta para el caso normal.
- **Caveat:** si dos llamadas usan **instancias distintas** de `SharedPreferences`, la segunda espera la purga de la primera y no purga su propia instancia. En producción `getInstance()` es único; en pruebas podría enmascarar. BAJA.
- **Idempotencia:** `purgarCacheHistoricaInvalida` sobre datos limpios retorna `0` y no muta (`:610-620`); la prueba `:255-270` lo cubre. `ensure` es idempotente por la marca (`:272-297`).
- **B1 rompe la idempotencia segura:** una purga que “triunfa” borrando el mapa no es idempotente en el sentido de preservar datos.

### F. Fechas

- `_isValidCalendarDate` (`:433-452`): regex `^\d{4}-\d{2}-\d{2}$`, rango `m 1..12`, `d 1..31`, y normalización con `DateTime` + comparación de `year/month/day`.
- Años bisiestos: `2024-02-29` válido; `2026-02-29` inválido. Meses de 30/31 días: `2026-04-31` inválido. `2026-13-40` inválido. Correcto.
- La misma función se usa para claves individuales (`:592`) y para claves del mapa (`:524`). Semántica consistente.
- Detalles menores: `0000-01-01` se acepta (DateTime año 0); la lógica está duplicada en `rate_quote_input.dart:43-54`; no hay `try/catch` en la versión de `rate_quote_input`, pero `DateTime` no lanza para los rangos permitidos.

---

## 4. Auditoría Firestore (S3.1)

### Consumidores de `toPayload`

| Consumidor | Ubicación | Comportamiento |
|---|---|---|
| `FirestoreGastosRemoteDataSource.upsertGasto` | `firestore_gastos_remote_data_source.dart:38-46` | Único consumidor productivo. `set(payload, SetOptions(merge: true))`. |
| `SyncService.syncToFirestore` | `sync_service.dart:175-197` | Llama a `upsertGasto` para gastos no sincronizados; los ítems vienen hidratados (`database_helper.dart:580-605,626-632`). |
| `softDeleteGasto` | `firestore_gastos_remote_data_source.dart:49-60` | No usa `toPayload`; escribe solo `uuid`, `eliminado_en`, `actualizado_en` con `merge: true`. |
| `eliminarCuentaYDatos` | `sync_service.dart:458-475` | Borra documentos; no escribe payload. |
| `toFirestoreMap` | `gasto_model.dart:84-88` | Sigue incluyendo nulos; solo se usa en una prueba. No es ruta productiva (S3.1-b). |

### Omisión de nulos

- Se omiten exactamente los opcionales aprobados: `total_usdt`, `total_eur`, `tasa_usdt`, `tasa_eur`, `fuente_tasa_cambio`, `fecha_tasa_cambio`, `ocr_text`, `eliminado_en` (`gasto_firestore_mapper.dart:39-46`).
- Los campos obligatorios siguen presentes: `uuid`, `fecha`, `comercio`, `moneda`, `total_original`, `total_usd`, `tasa_cambio`, `categoria`, `creado_en`, `actualizado_en`, `items`. Todos son no-null en `GastoModel` (`gasto_model.dart:5-27`).
- `items` siempre se envía; como los gastos no sincronizados se hidratan con sus ítems, no se borran ítems remotos en la ruta normal. Si en el futuro se construyera un `GastoModel` sin ítems, el merge los vaciaría; no es el caso actual.

### `merge: true`

- Firestore ignora las claves ausentes en un `set(..., merge: true)`. La omisión de nulos preserva los valores remotos no nulos.
- La prueba `test/models/gasto_firestore_mapper_test.dart:141-193` simula el merge con `Map..addAll(payload)`. **Eso demuestra que las claves nulas no están en el payload**, pero **no** demuestra el comportamiento real de Firestore, ni las reglas, ni la llamada `upsertGasto`. Es una simulación válida del contrato de merge, no una prueba de integración.

### Otros caminos de escritura

- No hay otro `set` de gastos con `toPayload`.
- `toFirestoreMap` sigue siendo un camino latente que envía nulos; hoy no tiene consumidor productivo. Si se decide mantenerlo, debería alinearse con `toPayload` o marcarse obsoleto.

### Ausencia de campo como valor predeterminado

- `fromMap` convierte `total_usd` ausente en `0` y `tasa_cambio` ausente en `1.0` (`gasto_model.dart:91,94,104`). Como `toPayload` siempre escribe esos campos, un modelo construido desde un mapa parcial podría empujar `0`/`1.0` sobre Firestore. Es preexistente (N8), no lo introduce este parche, pero conviene tenerlo presente.

---

## 5. Auditoría de pruebas

### Lo que existe y fue inspeccionado

- `test/services/exchange_rate_service_cache_purge_test.dart` (8 pruebas):
  - purga selectiva con válidas, antiguas y corruptas (`:51-117`);
  - valor `String` en el mapa (`:119-137`);
  - `source` numérico (`:139-155`);
  - fechas imposibles y bisiestas (`:157-194`);
  - `cached_exchange_rate` inválida/válida (`:196-214`);
  - fallo de `remove` y no fijación de marca (`:216-233`);
  - concurrencia (`:235-253`);
  - idempotencia directa y del wrapper (`:255-297`).
- `test/models/gasto_firestore_mapper_test.dart` (5 pruebas): payload, `eliminado_en`, omisión de nulos, simulación de merge, `fromPayload`.
- `test/domain/monetary/*`: H-1, H-2, `RateQuoteInput`, `buildNewExpenseTuple`, resumen de lentes.
- `test/services/exchange_rate_service_test.dart`: regresión de `getAllTodayRates`/`getRateForDate`, incluido el fallback histórico USDT→USD (fuera de alcance).

### Ejecución real

- **Ninguna prueba fue ejecutada.** No hay SDK de Flutter/Dart local.
- **`flutter analyze` no fue ejecutado.**
- **`scripts/check_rules.ps1`** fue reportado como exitoso por el implementador; esta auditoría no lo ejecutó.
- No se usó `test_results.txt` como evidencia.

### Lo que las pruebas demuestran por inspección

- S1.1: la prueba ya no es incoherente con la implementación; la rama `cached_exchange_rate` existe y la aserción `expect(prefs.getDouble('cached_exchange_rate'), isNull)` es alcanzable.
- S2.1: las pruebas de `String` y `source` numérico cubren el caso de entrada mal tipada.
- S3.4: las fechas imposibles y bisiestas están cubiertas.
- Concurrencia e idempotencia: cubiertas.
- S3.1: la omisión de nulos está cubierta a nivel de mapa; el merge es una simulación.

### Pruebas faltantes (N7)

1. `setString` que **lanza** (B1): debe verificar que el mapa original sigue intacto y que la marca no se fija.
2. `setString` que retorna `false`: debe verificar que el mapa original sigue intacto y que se lanza `StateError`.
3. `NaN`/`Infinity` en `cached_rate_*`, `cached_exchange_rate` y el mapa.
4. `cached_exchange_rate` no numérico (p. ej. `String`).
5. `source` ausente o vacío con tasa numérica válida: decidir si se conserva o se elimina según v1.2.
6. Marca de purga corrupta (tipo no bool) y `tasas_historico_v1` con tipo no String.
7. `getRateForDate` después de `ensure == -1`: debe **no** devolver `0.5`/`Infinity`.
8. `getAllTodayRates` después de `ensure == -1` con `NaN`/`Infinity`.
9. Integración: que `getAllTodayRates` y `getRateForDate` invoquen la purga.
10. Firestore: prueba con emulador o mock de `upsertGasto` que verifique `SetOptions(merge: true)`; la simulación actual no lo cubre.
11. `toPayload` a partir de un `GastoModel` deserializado con `fromMap` (la prueba de merge lo construye manualmente).
12. `toFirestoreMap` (o su eliminación).

### Calidad de las pruebas existentes

- La primera prueba usa `expect(cleanedCount, greaterThanOrEqualTo(4))` (`:90`) aunque el conteo exacto es 7; es una aserción débil, aunque las comprobaciones posteriores de preservación sí detectarían una sobrepurga de las entradas concretas.
- La prueba de fallo de `remove` (`:216-233`) usa solo `cached_rate_usdt` (clave diaria), no un mapa histórico; no prueba la integridad del mapa.
- La prueba de concurrencia es correcta y relevante.
- `expect(() => future, throwsA(...))` es válido: el matcher `Throws` de `package:matcher` maneja Functions que retornan `Future` (`matchAsync`), por lo que no es un defecto.

---

## 6. Estado de garantías globales

| Garantía | Estado | Evidencia | Comentario |
|---|---|---|---|
| H-1 local al resolver | CORREGIDO | `lib/domain/monetary/monetary_resolution.dart:161-162` | `rOrig = gasto.tasaUsdt` sin `?? tasaCambio`; si falta, `pendiente`. Prueba `resolve_persisted_expense_test.dart:157-173`. |
| H-1 global de adquisición | NO CORREGIDO (fuera de alcance) | `exchange_rate_service.dart:92,126-129,405-412`; `settings_provider.dart:86` | Sigue el fallback USDT→USD. Debe cerrarse en E0-03. |
| H-2 en deserialización | CORREGIDO | `gasto_model.dart:106,109` | `fromMap` conserva `null` en `totalUsdt`/`tasaUsdt`; `toMap` también. Pruebas `resolve_persisted_expense_test.dart:175-252`. |
| H-2 en getters y presentación | NO CORREGIDO (fuera de alcance) | `gasto_model.dart:208-209`; `chat_screen.dart:385`; `database_helper.dart:682,757`; `currency_formatter.dart:70-74` | Los consumidores siguen derivando USDT desde USD. |
| S3.2 `copyWith` | NO CORREGIDO (fuera de alcance) | `gasto_model.dart:158,161` | No permite limpiar campos nullable; no fue tocado por el parche. |

**Sobre el informe del implementador:** `MEMORY.md:13` sí aclara que “H-1 y H-2 no se declaran globalmente cerrados”, lo cual es correcto. Pero `MEMORY.md:10-12` sobredeclara “S1.1 & A-07 resuelto” y “S3.3 & S4.3 resuelto”. A-07 y S3.3 son parciales por B1/N1; S4.3 no aparece en la lista auditada. También dice “sin alterar datos de usuarios”, aunque A-07 muta SharedPreferences (caché), no datos financieros.

---

## 7. Condiciones concretas para aceptar E0-02

Priorizadas, sin refactorizaciones generales ni cambios de alcance:

1. **[BLOQUEANTE] Aislar el `try/catch` del `jsonDecode` en `purgarCacheHistoricaInvalida`.**
   - Archivo: `lib/services/exchange_rate_service.dart:510-577`.
   - Mover `prefs.setString(...)` (`:566`) fuera del `try` que captura el JSON, o añadir un `catch` específico que haga `allWritesSucceeded = false` y **nunca** `keysToRemove.add(key)`.
   - Añadir prueba con un `SharedPreferences` fake cuyo `setString` lance; afirmar que `tasas_historico_v1` conserva sus entradas válidas y que la marca no se fija.

2. **[BLOQUEANTE] Validar el dominio en `getRateForDate`.**
   - Archivo: `lib/services/exchange_rate_service.dart:309,351,365,374,394`.
   - Cambiar `> 0` por `isFinite && > 1.0` (o el mínimo de dominio que defina v1.2).
   - Añadir prueba: caché `0.5`/`Infinity` no debe devolverse; debe caer a red o `0.0`.
   - Considerar usar `ensure == -1` para omitir la caché y registrar el fallo.

3. **[ALTA] Endurecer los filtros de `getAllTodayRates`.**
   - Archivo: `lib/services/exchange_rate_service.dart:61,63,65`.
   - Cambiar `rate <= 50.0` por `!rate.isFinite || rate <= 50.0` en USD, EUR y USDT.

4. **[MEDIA] Confirmar la semántica de `source` en v1.2.**
   - Archivo: `lib/services/exchange_rate_service.dart:542-551`.
   - Si el contrato no exige `source`, conservar la entrada con tasa numérica válida; si lo exige, documentarlo y mantener la prueba actual.
   - Revisar el caso `valor: 0` + `rate: 40` y `source: ''` + `fuente: 'x'`.

5. **[MEDIA] Proteger las lecturas de tipos corruptos.**
   - Archivo: `lib/services/exchange_rate_service.dart:457` (`getBool`) y `:506` (`getString`).
   - Usar `prefs.get(key)` + comprobación de tipo, o envolver en `try/catch` que no borre datos.

6. **[MEDIA] Registrar los fallos capturados.**
   - Archivo: `lib/services/exchange_rate_service.dart:470-475,556-559,573`.
   - Añadir `debugPrint` con contexto, conforme a AGENTS.md.

7. **[MEDIA] Completar la suite de pruebas** con los 12 casos faltantes de la sección 5, especialmente `setString` throw/false, no finitos, `source` ausente, consumidor tras `-1` e integración Firestore.

8. **[BAJA] Decidir sobre `toFirestoreMap`** (`gasto_model.dart:84-88`): eliminarlo, marcarlo obsoleto o alinearlo con `toPayload`. No es bloqueante porque no tiene consumidor productivo.

9. **[BAJA] Revisar los valores por defecto de `fromMap`** (`gasto_model.dart:91,94,104`) y la escritura incondicional de `total_usd`/`tasa_cambio` en `toPayload` (`gasto_firestore_mapper.dart:22-24`). Preexistente; no bloquea este parche, pero es un riesgo de “valor predeterminado” en sincronización.

10. **Ejecutar CI completo** (`flutter analyze --fatal-warnings`, `flutter test`) y reauditar A-07. No commit, push ni E0-03 hasta que B1 y N1 estén cerrados y CI esté verde.

---

## 8. Integridad del repositorio

- **Versión SQLite:** `18` en `lib/data/datasources/local/database_helper.dart:45,68`. Sin cambios en el diff.
- **`firestore.rules`:** sin modificaciones (`git diff --name-only HEAD -- firestore.rules` vacío). Las reglas siguen siendo permisivas por `uid` y no exigen campos concretos, por lo que la omisión de nulos no rompe creates.
- **`pubspec.yaml` / `pubspec.lock`:** sin modificaciones. `sqflite_common_ffi: ^2.3.3` sigue presente; `shared_preferences: ^2.2.3`; `cloud_firestore: ^5.4.3`.
- **Working tree (estado real):**
  - Modificados: `MEMORY.md`, `lib/data/models/gasto_firestore_mapper.dart`, `lib/data/models/gasto_model.dart`, `lib/services/exchange_rate_service.dart`, `test/models/gasto_firestore_mapper_test.dart`.
  - Nuevos sin seguimiento: `lib/domain/monetary/` (6 archivos), `test/domain/monetary/` (4 archivos), `test/services/exchange_rate_service_cache_purge_test.dart`.
- **Sin integración de E0-03:** no hay imports de `domain/monetary` fuera del propio dominio (`resumen_lente_monetario.dart` y `expense_tuple.dart` solo se importan entre sí). La app productiva no usa aún `resolvePersistedExpense`/`buildNewExpenseTuple`.
- **E0-01/E0-05a intactas:** `sqflite_common_ffi` presente; `repararTasasHistoricasIncompletas` conserva `dryRun = true` por defecto (`gasto_repository.dart:67-74`); la auto-reparación sigue neutralizada en `main_screen.dart:135-137` y documentada en `sync_service.dart:713-715,857-859`.
- **La auditoría no realizó modificaciones:** solo se usaron `git status`, `git diff`, `git grep`, lecturas y búsquedas. No se creó, editó ni borró ningún archivo. No hubo commits ni push.
</USER_REQUEST>