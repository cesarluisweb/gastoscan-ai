# RM-03 — Cuarta Reauditoría Adversarial de E0-02: U1 y U2 (DeepSeek)

> **Tipo de documento:** Informe íntegro de la cuarta reauditoría adversarial independiente sobre las unidades U1 (validador canónico D-08) y U2 (resiliencia de purga NEW-1 + fake O2).  
> **Unidad evaluada:** `E0-02` — Dominio monetario, tupla y purga de caché A-07.  
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md`.  
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (`A-01` a `A-16` y `D-01` a `D-08`).  
> **Informe evaluado:** `docs/rm-03/auditorias/implementacion-u1-u2.md`.  
> **Fecha:** 2 de noviembre de 2026.  
> **Veredicto general:** **RECHAZADO ❌**  
> **Estado de Git:** `HEAD == origin/main == de17323`; cero commits, cero push.  
> **Modo de validación:** Inspección estática exclusivamente. **72 pruebas inspeccionadas, 0 ejecutadas.** Cero `flutter analyze`, cero `flutter test` (SDK no instalado).

---

## A. Veredicto ejecutivo

**RECHAZADO.**

No por la arquitectura de U2 —que es sólida y no exige rediseño— sino porque el árbol actual **no compila** y **tres pruebas fallan de forma determinista**, además de una cuarta que lanza una excepción de plataforma. Un push en este estado produce CI en rojo con seguridad.

| # | Bloqueante | Naturaleza |
| :--- | :--- | :--- |
| **B-01** | `ExchangeRateService` indefinido en `test/providers/gasto_provider_rate_cache_test.dart` | Error de compilación |
| **B-02** | 3 aserciones de conteo esperan `1` donde el contrato devuelve `0` (L463, L739, L805) | Fallo determinista |
| **B-03** | Prueba obsoleta `<= 50.0` en `test/services/exchange_rate_service_test.dart:158` | Fallo determinista |
| **B-04** | `actualizarTasaAutomatica` sin `SharedPreferences` mockeado → `MissingPluginException` | Fallo determinista |

**Lo que sí está bien y no debe rehacerse:**

- `rate_market.dart` es una función pura, sin imports, sin ciclos, con semántica exacta de D-08.
- El núcleo NEW-1 de U2 (reintento de `setString`/`remove`/`setBool`, *single-flight*, limpieza en `finally`, confirmación física de la marca, *fail-closed* en los tres consumidores) cumple las condiciones de U2. **No hace falta `reloadFromDisk()`**: su ausencia es una decisión correcta, no un defecto.
- El fake O2 es fiel al modelo memoria/disco del plugin real para las cuatro mutaciones y los getters tipados.

**Sobre el informe de Gemini:** el documento declara honestamente las suites como *«Inspección estática y diseño de arnés»* (L157-158), coherente con que no se ejecutaron. Pero su afirmación de L50 —*«Se eliminó por completo el umbral obsoleto `> 50.0` … en todos los puntos de producción»*— es **falsa**: sigue vivo en `review_expense_screen.dart:247-255`. La corrección documental de esa frase se registra en este mismo repositorio (§H).

---

## B. Matriz de hallazgos

| ID | Sev. | Ubicación | Evidencia | Efecto |
| :--- | :--- | :--- | :--- | :--- |
| **B-01** | **Bloqueante** | `test/providers/gasto_provider_rate_cache_test.dart:80,115` | 6 imports (L1-6); ninguno de `exchange_rate_service.dart`. El archivo importado (`exchange_rate_service_cache_purge_test.dart`) tiene `import` en L7 pero **cero `export`** (verificado por grep). En Dart los imports no son transitivos. | `undefined_identifier: ExchangeRateService`. `flutter test` no compila la suite; `flutter analyze` falla. |
| **B-02** | **Bloqueante** | `test/services/exchange_rate_service_cache_purge_test.dart:463,739,805` | Ver §D.5. | 3 tests fallan esperando `1`, reciben `0`. |
| **B-03** | **Bloqueante** | `test/services/exchange_rate_service_test.dart:158-171` | Siembra `40.0/43.2/40.0`, cliente 500, espera `0.0`. Bajo D-08 esos valores son válidos (`> 1.0`), la purga los conserva y `getAllTodayRates` los devuelve (L218-224). | `Expected: <0.0> Actual: <40.0>`. Contradice D-08 y a las pruebas nuevas. |
| **B-04** | **Bloqueante** | `test/providers/settings_provider_rate_cache_test.dart:149-162` | No hay `setMockInitialValues` en el archivo (L43-51 solo crea el fake de SecureStorage). `actualizarTasaAutomatica` llama `getAllTodayRates` (L222) → `getInstance()` (service L106) y otra vez (L223). | `MissingPluginException` → `catch` (L259) → `exito=false`; el test espera `true`. |
| **M-01** | Media | `rate_quote_input.dart:76`, `monetary_resolution.dart:174`, `database_helper.dart:1719` | Predicados inline duplicados (`!isFinite \|\| <= 1.0`) en vez de `isValidMonetaryRate`. | D-08 no es «fuente única real»; riesgo de divergencia futura. Equivalente hoy para `double`. |
| **M-02** | Media | `exchange_rate_service.dart:45-50` | `fecha` inválida/ausente → `DateTime.now()`; con `esReferencia:false` produce «fecha fresca inventada + no-referencia». El test L1115-1125 solo verifica `isA<DateTime>()`. Sin consumidores de producción (solo tests). | Riesgo latente D-02: un dato sin fecha puede declararse actual. |
| **M-03** | Media | `review_expense_screen.dart:247-255` | `if (tUsd <= 50.0 && …)` en producción. | Contradice el informe (L50). Es alcance U3/U4, no bloquea U1/U2, pero la afirmación debe corregirse. |
| **M-04** | Media-baja | `exchange_rate_service.dart:818` | `DateTime.tryParse` normaliza fechas imposibles (`"2026-02-30"` → 2026-03-02, comportamiento documentado de Dart). | Timestamp imposible no se purga; inconsistente con `_isValidCalendarDate` usado para claves. |
| **M-05** | Media | `exchange_rate_service.dart:846-860` + consumidores | Un `remove` pendiente no se rescinde cuando `getAllTodayRates` escribe luego una tasa fresca válida. Secuencia real en §D.2. | El siguiente `ensure` borra una tasa recién obtenida. Se recupera en el siguiente fetch; no corrompe dinero. |
| **M-06** | Baja | `exchange_rate_service.dart:520` | `static final _pendingPurgeOperations` no ligado a una instancia de `SharedPreferences`. | Replay contra otro store en pruebas/multiusuario. |
| **M-07** | Baja | `gasto_provider_rate_cache_test.dart:58-92` | Tests 13/14 solo verifican `errorMessage == null` y `isFinite` con agregados vacíos (`{}` → 0.0). | Falsa sensación de cobertura de las protecciones B2. |
| **M-08** | Baja | suites de providers | No llaman `ExchangeRateService.resetPendingPurgeOperationsForTesting()` (existe en L539) en `setUp`. | Estado estático entre tests; hoy enmascarado, *flaky* a futuro. |

---

## C. Auditoría U1 — Validador canónico D-08

### C.1 Núcleo correcto

`lib/domain/monetary/rate_market.dart:72-76`:

```dart
bool isValidMonetaryRate(dynamic value) {
  if (value is! num) return false;
  if (!value.isFinite) return false;
  return value > 1.0;
}
```

- Sin `import` en todo el archivo → imposible ciclo con servicios/providers.
- Semántica exacta: `num`, finito, `> 1.0`. Rechaza `1`, `0.5`, `0`, negativos, `NaN`, `±Infinity`, `String`, `bool`, `Map`, `List`, `null`.
- `rate_market_test.dart` (8 tests) cubre todos esos bordes, incluidos enteros (`45`, `2`) y `1.0001`. Es cobertura adecuada y el archivo está correctamente nombrado `_test.dart` dentro de `test/domain/monetary/`, por lo que CI lo recogerá.
- Consumido correctamente en `exchange_rate_service`, `settings_provider` y `gasto_provider` (grep: ~50 usos), incluida la purga selectiva y `fromJson`.

### C.2 M-01 — D-08 no es realmente único

- `rate_quote_input.dart:76`: `if (!valor.isFinite || valor <= 1.0) {`
- `monetary_resolution.dart:174`: `} else if (!rOrig.isFinite || rOrig <= 1.0) {`
- `database_helper.dart:1719`: `if (nuevaTasa <= 1.0) {` (más el `WHERE tasa_cambio <= 1.0` de L1686).

Hoy son **equivalentes** a D-08 para `double` tipado, así que no hay bug funcional ni de dinero. Pero la decisión D-08 exige un predicado único; tener tres copias significa que un cambio futuro de umbral (p. ej. adoptar un piso por moneda) se aplicará en unos sitios y no en otros. No es bloqueante, pero **no puede declararse «unicidad real»**.

Además, `database_helper.dart:1719` compara `nuevaTasa <= 1.0` sin comprobar finitud: `NaN <= 1.0` es `false`, así que un `NaN` **pasa** ese filtro. Es código preexistente (no tocado por U1), pero demuestra exactamente el riesgo de la duplicación.

### C.3 M-02 — `fromJson` inventa frescura

```dart
if (rawFecha is String) {
  parsedFecha = DateTime.tryParse(rawFecha) ?? DateTime.now();
} else {
  parsedFecha = DateTime.now();
}
final bool parsedEsReferencia = (rawEsReferencia is bool) ? rawEsReferencia : true;
```

Reproducción lógica: `ExchangeRatesData.fromJson({'fecha': 12345, 'esReferencia': false})` devuelve `fecha = ahora` y `esReferencia = false`. Es decir: **«actualizada ahora mismo» sin ninguna evidencia temporal**.

Es incoherente con el resto del servicio, que usa el centinela epoch 0 cuando no hay dato (`getAllTodayRates`, L222). El test L1113-1131 no detecta la combinación porque solo pasa `fecha` (sin `esReferencia:false`) y solo comprueba el tipo.

Mitigante real: `fromJson` **no tiene consumidores de producción** (grep: solo tests). Por eso Media y no bloqueante. Acción recomendada: o eliminar `fromJson` si no se usa, o usar epoch 0 y forzar `esReferencia: true` cuando la fecha no sea interpretable.

### C.4 M-03 — El `> 50.0` residual

`review_expense_screen.dart:247-255` mantiene el umbral en pantalla de revisión de compras, que es producción. El informe lo niega en L50 y lo reconoce en L165 (U3/U4). No bloquea U1/U2, pero la afirmación de erradicación total debe corregirse en el documento.

### C.5 Cobertura D-08

La suite cubre los bordes del predicado y `allowedSourcesForMarket` (8 tests). No cubre la integración del predicado con `fromJson` en el caso `fecha` inválida + `esReferencia:false` (§C.3), ni verifica que los tres módulos con predicado inline sigan el canónico (§C.2). Son carencias de cobertura, no defectos del predicado.

---

## D. Auditoría U2 — NEW-1 y resiliencia de purga

### D.1 El núcleo cumple las condiciones

Verificado en `ensureCacheHistoricaPurgada` (L567-629) y `purgarCacheHistoricaInvalida` (L642-867):

1. **Idempotencia real, no de memoria:** solo retorna `0` si `rawMark is bool && true && !_purgeMarkPendingConfirmation && _pendingPurgeOperations.isEmpty` (L575-579). No se fía de la marca en memoria.
2. **Marca pendiente:** `_purgeMarkPendingConfirmation = true` **antes** de `setBool` (L599) y se limpia solo tras confirmación (L615). Si `setBool` devuelve `false` o lanza, retorna `-1` (L608-612).
3. **Reintento de mutaciones:** replay de `setString`/`remove` (L650-681) y de `setBool` con payload; si una falla, `allWritesSucceeded=false` y la op permanece pendiente.
4. **Nunca marca éxito con pendientes:** L593-596.
5. **Single-flight:** `_activePurgeFuture` (L584-586, 623-628) con limpieza en `finally`, incluidas llamadas concurrentes.
6. **Fail-closed en los tres consumidores:** `getAllTodayRates` (L116-131), `SettingsProvider.loadSettings` (L78-122) y `GastoProvider.cargarDatos`.
7. **Sin borrado indiscriminado:** las claves válidas se conservan; las inválidas se eliminan selectivamente.

**Sobre `reloadFromDisk()`:** no es necesario. El modelo O2 ya modela memoria mutada + disco intacto, y el replay reaplica contra `prefs` sin releer. Exigirlo sería un cambio de arquitectura sin beneficio demostrado. Correcto no añadirlo.

### D.2 M-05 — Un `remove` pendiente puede borrar una tasa fresca

Secuencia verificable con el código actual:

1. `cached_rate_usd = -5.0` (inválida) → `purgarCacheHistoricaInvalida` registra `PendingPurgeOperation.remove` (L847) y `prefs.remove` devuelve `false` → queda pendiente, `ensure` devuelve `-1`.
2. `getAllTodayRates` ve `purgeResult == -1` y omite semillas (correcto). El gateway responde `usd = 60.0` y escribe `cached_rate_usd = 60.0` en disco (L149-150).
3. Nadie rescinde la op pendiente de `cached_rate_usd`.
4. Siguiente `ensure`: replay del `remove` → **borra el 60.0 recién escrito**; luego fija la marca y devuelve `0`.
5. Si en esa llamada la red falla, el resultado es `usd = 0.0` y `esReferencia = true`.

Impacto: se pierde una lectura válida y se degrada a «sin tasa» hasta el siguiente fetch exitoso. No hay cálculo con tasa equivocada, pero es un comportamiento contrario a la intención de «no destruir datos válidos». Severidad Media; corregible invalidando `_pendingPurgeOperations[key]` cuando `setDouble`/`setString` confirman una escritura nueva sobre esa clave.

### D.3 M-06 — Estado estático no ligado a instancia

`_pendingPurgeOperations` (L520), `_purgeMarkPendingConfirmation` (L523) y `_activePurgeFuture` (L526) son estáticos. El replay se aplica contra el `prefsInstance` que reciba la llamada, sin comprobar que sea el mismo store donde se originó la op. En producción hay un único store, así que el riesgo es bajo; en pruebas y ante escenarios multiusuario puede reaplicar operaciones sobre un almacén distinto.

### D.4 M-04 — Parseo laxo del timestamp

`exchange_rate_service.dart:818`:

```dart
if (rawVal is! String || DateTime.tryParse(rawVal) == null) {
```

`DateTime.tryParse` acepta y **normaliza** componentes fuera de rango (`"2026-02-30"` → 2 de marzo de 2026; `"2020-01-42"` → 11 de febrero de 2020; comportamiento documentado de Dart). Por tanto, un timestamp con fecha imposible **no se purga**, mientras que las claves de caché sí exigen `_isValidCalendarDate`. Impacto limitado a metadato (`ultimaActualizacionTasas` puede mostrar una fecha normalizada); no afecta a tasas ni a dinero.

### D.5 B-02 — El contrato de conteo y las pruebas no coinciden

`purgarCacheHistoricaInvalida` inicializa `cleanedCount = 0` (L644). El bloque de replay (L650-681) **no incrementa** el contador; solo elimina de `_pendingPurgeOperations`. La exploración posterior (L683+) itera `prefs.getKeys()`, que en el fake devuelve `memory.keys` (L47), y el fake **ya borró la clave de memoria** en el primer intento fallido (L118, antes de devolver `false` en L122-123).

Por tanto, en el reintento:

- 463 (`setString`): la memoria ya contiene el JSON limpio de la primera ejecución (fake muta memoria antes de lanzar, L73) → no hay nada que limpiar → `0`, se espera `1`.
- 739 (`tasas_historico_v1`): clave ya ausente de memoria → `0`, se espera `1`.
- 805 (`tasa_cambio_ves_usd`): clave ya ausente de memoria → `0`, se espera `1`.

Nótese que L692/L714 sí pasan porque el conteo ocurre en la misma llamada. La suite NEW-1 (L1005-1035) usa la semántica correcta (`0` tras replay), lo que confirma que el propio autor aplicó dos contratos distintos.

**Esto es un desajuste prueba-contrato, no un bug de seguridad.** El dato queda correctamente purgado en disco; lo único incorrecto es el número reportado y la expectativa del test. Recomendación: contar la op de replay confirmada como depurada (incrementar en éxito) **o** cambiar las tres aserciones a `equals(0)` y verificar el efecto en `disk` + la marca. Elegir una y documentarla en el docstring de L639.

---

## E. Auditoría O2 y de las pruebas

### E.1 Fidelidad del fake (adecuada)

`TestSharedPreferences` (L14-128):

| Aspecto | Implementación | Fidelidad |
| :--- | :--- | :--- |
| `setString`/`setDouble`/`setBool` | muta `memory` → lanza/`false` → escribe `disk` | Alta (reproduce el orden del plugin) |
| `remove` | `memory.remove` → lanza/`false` → `disk.remove` | Alta |
| Getters tipados | `as String?` / `as double?` / `as bool?` → `TypeError` | Alta (reproduce el plugin) |
| `getKeys` | `memory.keys` | Alta (el plugin real lee la caché en memoria) |
| Constructor | siembra `memory` y `disk` | Correcto |
| `reloadFromDisk` | presente y usado en L432 | Útil para simular reinicio |

Limitaciones: no implementa `reload()`, `clear()`, `setStringList`, `getInt`; ninguna se usa en el código bajo prueba. No es un defecto para O2.

### E.2 Inventario y estado de ejecución

| Suite | Tests | Estado real |
| :--- | ---: | :--- |
| `exchange_rate_service_cache_purge_test.dart` | 40 | Inspeccionada, **no ejecutada** |
| `exchange_rate_service_test.dart` | 14 | Inspeccionada, **no ejecutada** |
| `settings_provider_rate_cache_test.dart` | 6 | Inspeccionada, **no ejecutada** |
| `gasto_provider_rate_cache_test.dart` | 4 | Inspeccionada, **no ejecutada** |
| `rate_market_test.dart` | 8 | Inspeccionada, **no ejecutada** |

Total: **72 tests, 0 ejecutados**. No hay `test_results.txt` local que consultar. Cualquier afirmación de «verde» sería inventada.

### E.3 Cobertura engañosa (M-07)

Test 13 (`gasto_provider_rate_cache_test.dart:58`) afirma verificar que no se consume caché no verificada, pero solo comprueba `provider.errorMessage == null`. Test 14 solo comprueba `spent.isFinite` con `obtenerTotalesPorCategoria → {}`, es decir, `0.0`, que es finito con cualquier tasa. **Ninguno observa las tasas internas** (`_tasaUsd`/`_tasaEur` son privadas y no hay getter). Tal como están, no detectarían una regresión de B2.

### E.4 Acoplamiento entre suites (M-08)

Los tests de providers importan `TestSharedPreferences` desde la suite del servicio. Eso es aceptable, pero es exactamente lo que produjo B-01: se asumió que el import traía también `ExchangeRateService`. Además, ninguna suite resetea `_pendingPurgeOperations`, `_purgeMarkPendingConfirmation` ni `_activePurgeFuture` entre tests, pese a existir `resetPendingPurgeOperationsForTesting()` (L539).

---

## F. Integridad del repositorio

| Comprobación | Resultado |
| :--- | :--- |
| `HEAD` | `de17323f233e44f26b895bc09a94bd86fae47cad` |
| `origin/main` | `de17323…` (idéntico) |
| Commits/push del agente | Ninguno |
| Archivos modificados | `MEMORY.md`, `gasto_firestore_mapper.dart`, `gasto_model.dart`, `gasto_provider.dart`, `settings_provider.dart`, `exchange_rate_service.dart`, `gasto_firestore_mapper_test.dart` |
| Sin seguimiento | `docs/rm-03/`, `lib/domain/monetary/`, `test/domain/monetary/`, y las 3 suites nuevas de providers/servicio |
| Esquema SQLite | `database_helper.dart` no figura modificado → `version: 18` intacta |
| `firestore.rules` / `pubspec.yaml` | Sin modificar |
| `android/` | Sin cambios |
| `pubspec.lock` | **No existe y no está versionado** (condición preexistente del repo, no imputable a U1/U2; viola AGENTS.md §2 y debería resolverse aparte) |
| Escrituras de esta auditoría | Ninguna sobre código (solo lecturas y `git` de solo lectura) |

Conclusión de integridad: el árbol refleja trabajo no commiteado de U1/U2 y de H-2 (mapper/model), sin señales de trabajo prematuro de U3 (el default 850 sigue en `_tasaUsd = 850` y `_tasasSonReferencia` sigue siendo un único bool).

---

## G. Condiciones concretas para cambiar el veredicto

### G.1 Obligatorias (bloquean CI)

1. **B-01** — Añadir a `test/providers/gasto_provider_rate_cache_test.dart`:
   `import 'package:gastoscan_ai/services/exchange_rate_service.dart';`
   Alternativa descartada: `export` desde la suite de purga (acopla suites y no arregla el diseño).

2. **B-02** — Unificar el contrato de conteo en `purgarCacheHistoricaInvalida`:
   - Opción A (recomendada por semántica): incrementar `cleanedCount` cuando una op de replay se confirma en disco, y actualizar el docstring de L639.
   - Opción B: dejar el contrato actual y cambiar L463/L739/L805 a `equals(0)`, verificando adicionalmente `disk` y la marca.
   En ambos casos, añadir un test que pruebe el reintento **sin** depender del número, sino del estado de `disk`.

3. **B-03** — Reescribir `exchange_rate_service_test.dart:158-171`: usar valores realmente inválidos bajo D-08 (`0.5`, `1.0`, `NaN`) y renombrar el test. Dejar `40.0/43.2` como caso de **conservación** válida.

4. **B-04** — En `settings_provider_rate_cache_test.dart`, añadir `SharedPreferences.setMockInitialValues({})` en `setUp` (o inyectar `prefsInstance` en `actualizarTasaAutomatica`, cambio de API opcional). El test debe seguir verificando que 60/65/62 se aplican.

### G.2 Recomendadas antes de marcar la unidad como cerrada

5. **M-01** — Sustituir los predicados inline de `rate_quote_input.dart:76`, `monetary_resolution.dart:174` y `database_helper.dart:1719` por `isValidMonetaryRate`, o documentar explícitamente por qué no aplica. Sin esto no puede afirmarse «D-08 único».
6. **M-02** — `fromJson`: usar epoch 0 y forzar `esReferencia: true` cuando `fecha` no sea interpretable; añadir el test de la combinación `{'fecha': 12345, 'esReferencia': false}`. Si no hay consumidores, evaluar eliminarlo.
7. **M-03** — Corregir en `implementacion-u1-u2.md` la frase de L50 (el `> 50.0` sobrevive en `review_expense_screen.dart`, alcance U3/U4). **Ya corregida documentalmente** en esta misma tarea.
8. **M-05** — Rescindir `_pendingPurgeOperations[key]` cuando una escritura nueva y confirmada de `getAllTodayRates`/`getRateForDate` recae sobre esa clave.
9. **M-07/M-08** — Añadir getters `@visibleForTesting` de tasas en `GastoProvider` para que los tests 13/14 observen el valor real, y resetear el estado estático de `ExchangeRateService` en `setUp`.
10. **M-04** — Validar el timestamp con `_isValidCalendarDate` además de `DateTime.tryParse` (bajo impacto, metadato).

### G.3 Protocolo de verificación

- Push a `main` y monitorización con **una sola** ejecución de `scripts/wait_ci.ps1` (sin `gh run watch` ni polling turno a turno).
- Evidencia exigida: `conclusion: success` de `flutter analyze` y de `flutter test`, más `test_results.txt` con 0 fallos.
- Solo entonces la unidad pasa a **Pendiente de validación 🧪** (es tarea crítica: dinero/divisas).
- **`Completada ✅` solo lo marca César** tras probar el artefacto `rindemas-dev-apk`.

---

## H. Corrección documental asociada

El informe `implementacion-u1-u2.md` afirmaba en su §2.2 (L50) que el umbral `> 50.0` se había eliminado «por completo … en todos los puntos de producción». Esa afirmación era **demasiado amplia**: `lib/ui/screens/review_expense_screen.dart:247-255` conserva comparaciones `> 50.0` para las tasas de USD, EUR y USDT.

- El remanente pertenece al alcance posterior **U3/U4** (modelo de tres estados y ajuste visual de pantallas), no a U1.
- No se modificó el código en esta tarea; solo se corrigió el texto del informe de implementación.
- Los servicios y proveedores listados en §2.2 de ese informe sí fueron migrados a `isValidMonetaryRate`.

---

## I. Conclusión

**U1 y U2 no quedan aceptadas.** El diseño de U2 es correcto y no requiere cambios arquitectónicos; el predicado D-08 es correcto en su núcleo pero incompleto en unicidad; el arnés de pruebas contiene un error de compilación y tres fallos deterministas que impiden cualquier validación honesta en CI.

**Estado:** `E0-02` continúa **RECHAZADO ❌**. `E0-03` y `U3/U4` no deben comenzar hasta resolver la compuerta de esta reauditoría. **No hay autorización para commit ni push.**

---

## J. Documentos relacionados

- `docs/rm-03/README.md`
- `docs/rm-03/contrato-v1.2.md`
- `docs/rm-03/decisiones.md`
- `docs/rm-03/estado-actual.md`
- `docs/rm-03/auditorias/implementacion-u1-u2.md`
- `docs/rm-03/auditorias/tercera-reauditoria-b2-b3-b5-deepseek.md`
