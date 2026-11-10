# RM-03 — Séptima Reauditoría Adversarial Independiente (U1/U2 — E0-02)

## 0. Método y límites de la verificación

- Sin SDK de Flutter/Dart local: no se ejecutó `flutter test` ni `flutter analyze`.
- Verificación realizada por inspección estática, trazado de flujos, semántica del lenguaje Dart y conteo determinista.
- `node scripts/check_syntax.js` ejecutado: **PASS 7/7**. Es un validador de balance de llaves/corchetes, **no** un analizador semántico de Dart; por tanto no puede detectar el defecto de identidad de `Future` descrito abajo.
- Estado Git verificado: `HEAD == origin/main == 676344b`; el parche sigue en el working tree, sin commits ni push nuevos.
- Conteo por declaración `test(`: **127 pruebas** en los 9 archivos.

---

## 1. Veredicto Ejecutivo

# RECHAZADO ❌

El código de producción de **D-05**, **M5-a** y **R-01** está correctamente corregido. Sin embargo, la compuerta **no puede cerrarse** por dos motivos:

1. **Bloqueante determinista en M-08:** el test `finally condicional no pisa _activePurgeFuture...` (`test/services/exchange_rate_service_cache_purge_test.dart:1529`) contiene aserciones de identidad que son **falsas por semántica de Dart** y fallarán deterministamente en CI.
2. **Inconsistencia documental:** el inventario oscila entre 126 y 127 pruebas, existe un dictamen `septima-reauditoria` ya “ACEPTADO” con 126 pruebas, y el informe de implementación afirma cosas que el código no cumple (identidad `activePurgeFuture == futureB` y `scripts/check_syntax.js` como archivo modificado).

Además, el nuevo test de D-05 reintroduce el problema de higiene de M-08 al usar `SettingsProvider` directo en lugar de `TestableSettingsProvider`, disparando un `actualizarTasaAutomatica()` no esperado desde `loadSettings`.

---

## 2. Evaluación detallada

### 2.1. D-05 / NEW-3b — Código ✅ / Prueba ⚠️

**Código correcto.**

- `SettingsProvider.actualizarTasaAutomatica`, rama `esReferencia` (`lib/providers/settings_provider.dart:287-300`):
  - Calcula `isManual` desde memoria o disco.
  - Si `isManual` y la tasa es válida, **no escribe** `prefTasaCambio` ni `cached_rate_usd`; conserva la tasa manual en memoria y disco.
  - Solo la rama `!allRates.esReferencia` (`:260-271`) sustituye la tasa y desactiva la bandera.
- `setTasaCambio` (`:351-368`):
  - Solo persiste `pref_es_tasa_manual_usd = true` y actualiza `_esTasaManualUsd` si `prefs.setDouble(prefTasaCambio, ...)` retornó `true`.
  - Si falla la escritura, no activa la bandera. Cumple exactamente lo exigido.

**Prueba D-05** (`test/providers/settings_provider_rate_cache_test.dart:289-342`):

- Cubre: arranque offline, sincronización fallida, segundo arranque tras `reloadFromDisk`, recuperación con tasa viva y fallo de `setTasaCambio`.
- Lógicamente es correcta y debería pasar.
- **Observación de higiene:** usa `SettingsProvider` directo (`:298`, `:317`), no `TestableSettingsProvider`. `loadSettings` ejecuta `actualizarTasaAutomatica()` sin `await` (`settings_provider.dart:184`). Esto reintroduce el patrón que M-08 debía eliminar y añade una carrera potencial con las sincronizaciones explícitas del test. Debe usarse `TestableSettingsProvider` (ya existe en `:38-50`) o esperar/desactivar la sincronización de fondo.
- **Observación menor:** en la rama viva (`:269`) y en `setTasaCambio` (`:362`) no se comprueba el retorno de `setBool('pref_es_tasa_manual_usd', ...)`. Si esa escritura falla, disco y memoria pueden divergir. No bloquea el requisito literal, pero es una fragilidad real.

**Dictamen D-05:** cerrado a nivel de código; prueba funcional pero con higiene mejorable.

---

### 2.2. M-05 / M5-a — ✅ Resuelto

**Código correcto.**

- En el replay de `_pendingPurgeOperations` (`lib/services/exchange_rate_service.dart:740-758`) se eliminó la revalidación por `prefs.get()`.
- Para una operación `remove`, el replay ejecuta directamente `prefs.remove(op.key)`.
- La única vía de rescisión es `onKeyWriteConfirmed(key)` (`:589-591`), invocada solo tras confirmación física (`ok == true`).
- Todos los escritores de `cached_rate_usd`, `cached_exchange_rate`, `prefTasaCambio`, `cached_rate_eur`, `cached_rate_usdt` y timestamp llaman a `_onKeyWriteConfirmed` después de una escritura exitosa (`:156-173`, `:197-229`, `:460-532`; `settings_provider.dart:265-285`, `:359-361`).

**Prueba M5-a** (`test/services/exchange_rate_service_cache_purge_test.dart:1440-1468`):

- No es vacua: deja memoria en `60.0` y disco en `-5.0` con `returnFalseOnSetDouble = true`.
- Verifica que el replay ejecuta `remove` físico, limpia el disco, retorna `1`, deja `pendingPurgeOperations` vacío y fija la marca.
- La prueba de rescisión positiva por `onKeyWriteConfirmed` está en `:1414-1438`.

**Dictamen M5-a:** resuelto de forma determinista.

---

### 2.3. M-08 — Código ✅ / Prueba de generación ✅ / Prueba de `finally` ❌

**Código correcto.**

- `_purgeGeneration` (`:567`), captura de generación (`:639`), comprobaciones (`:646`, `:667`) y `finally` condicional (`:687-694`) están bien implementados.
- El `finally` solo anula `_activePurgeFuture` si sigue siendo la misma `purgeTask`.

**Prueba de generación** (`:1497-1527`): **no vacua y correcta.**

- `returnFalseOnRemove = false` elimina la causa alternativa del `-1`.
- El `Completer` pausa la purga dentro de `remove`.
- El `reset` cambia la generación.
- Al reanudar, la purga retorna `-1`, no fija la marca y no deja pendientes.
- Esta prueba sí discrimina el token de generación.

**Prueba de `finally` condicional** (`:1529-1579`): **FALLO DETERMINISTA.**

El defecto es semántico, no de estilo:

1. `ensureCacheHistoricaPurgada` está declarada `async` (`lib/services/exchange_rate_service.dart:618`). Toda función `async` de Dart crea y retorna una **nueva Future externa**.
2. `_activePurgeFuture` se asigna a `purgeTask`, que es la Future **interna** de la IIFE `() async { ... }()` (`:641`, `:686`).
3. En el test:
   - `futureB` (`:1556`) es la Future **externa** retornada por la llamada.
   - `activePurgeFuture` (`:1557`) es la Future **interna** `purgeTaskB`.
   - Por tanto, `identical(activePurgeFuture, futureB)` es **`false`** en `:1558` y `:1567`.
4. En `:1570-1571`, `futureC` también es una Future externa nueva (la rama `return await _activePurgeFuture!` de `:635-637` vuelve a envolver), por lo que `identical(futureC, futureB)` es **`false`**.

Consecuencia: el test falla deterministamente en `:1558` antes de llegar al resto de las aserciones. El informe de implementación (`implementacion-u1-u4-e0-02.md:19`) afirma que la prueba verifica “que `activePurgeFuture` sigue siendo idéntico a `futureB`”; esa afirmación es **falsa con la firma actual**.

**Corrección necesaria (una de dos):**

- Refactorizar `ensureCacheHistoricaPurgada` para que retorne directamente la Future interna y adjunte la limpieza con `whenComplete`, de modo que `futureB == purgeTaskB`; o
- Reescribir el test para no exigir identidad con la Future externa: verificar que `activePurgeFuture` no es nulo, que no es la Future interna de A, y que C retorna el mismo valor sin lanzar una purga redundante. La aserción de identidad contra `futureB` debe eliminarse o compararse contra la Future interna expuesta.

**Dictamen M-08:** código correcto; prueba de generación cerrada; prueba de `finally` **no cerrada y bloqueante**.

---

### 2.4. R-01 — ✅ Resuelto

**Código correcto.**

- La revalidación TOCTOU (`lib/services/exchange_rate_service.dart:937-966`) está restringida a claves de tasa diaria activa (`cached_exchange_rate`, `prefTasaCambio`, `cached_rate_usd/eur/usdt`) y a claves `cached_rate_*` con fecha de calendario válida.
- Las claves con corrupción estructural **nunca se omiten**:
  - Fecha de calendario imposible (`!_isValidCalendarDate`) → no se aplica el `continue` de valor válido.
  - `tasas_historico_v1` no String, JSON inválido o vacío → se marca para eliminación sin revalidación que lo blinde.
- El timestamp solo se omite si es String y fecha parseable.

**Cobertura de pruebas:**

- `:255` fechas imposibles en `tasas_historico_v1` y `cached_rate_*`.
- `:724` y `:751` `tasas_historico_v1` con tipo `int` corrupto.
- `:1470` TOCTOU con tasa válida escrita durante la purga.

**Dictamen R-01:** resuelto de forma determinista.

---

### 2.5. Veracidad documental, Git e inventario — ❌ Inconsistente

Se detectan las siguientes inexactitudes:

| Documento | Inexactitud |
| :--- | :--- |
| `docs/rm-03/estado-actual.md:4` | Dice **127 pruebas**. |
| `docs/rm-03/estado-actual.md:66` | Dice **126 pruebas** en la suite monetaria. Contradice la línea 4 y el informe. |
| `docs/rm-03/estado-actual.md:84` | Describe el informe de implementación como de **126 pruebas**, cuando el informe dice 127. |
| `docs/rm-03/estado-actual.md:85` | Registra una **séptima reauditoría ya “ACEPTADA CON OBSERVACIONES”** con 126 pruebas. El snapshot actual se somete de nuevo como séptima reauditoría con 127 pruebas y el dictamen previo fue RECHAZADO. El archivo `septima-reauditoria-u1-u2-deepseek.md` está commiteado y contradice el estado actual. |
| `docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md:19` | Afirma que la prueba de `finally` verifica identidad con `futureB`. Es falso: la aserción falla por la semántica `async`. |
| `docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md:61` | Lista `scripts/check_syntax.js` como modificación del working tree. `git status` muestra que está **sin modificar** y ya versionado. |
| `docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md:8` | Declara el parche “VALIDADO DETERMINISTAMENTE”. No es cierto mientras el test de M-08 falle deterministamente. |

**Estado Git real:**

- `HEAD == origin/main == 676344b`.
- Working tree modificado en:
  - `lib/providers/settings_provider.dart`
  - `lib/services/exchange_rate_service.dart`
  - `test/providers/settings_provider_rate_cache_test.dart`
  - `test/services/exchange_rate_service_cache_purge_test.dart`
  - `docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md`
  - `docs/rm-03/estado-actual.md`
  - `DOC_BITACORA_MARKETING.md`
  - `MEMORY.md`
- `scripts/check_syntax.js`: sin cambios.
- No hay commits ni push nuevos de este parche.

**`check_syntax.js`:** PASS 7/7, pero solo valida balance de delimitadores. No es evidencia de corrección semántica.

---

## 3. Inventario de pruebas por archivo

| Archivo | `test(` declaradas | Observación |
| :--- | ---: | :--- |
| `test/providers/gasto_provider_rate_cache_test.dart` | 6 | NEW-3b / D-05 cubierto en `:214`. |
| `test/providers/settings_provider_rate_cache_test.dart` | 11 | D-05 cubierto en `:289`; higiene M-08 por `actualizarTasaAutomatica()` no esperado. |
| `test/services/exchange_rate_service_test.dart` | 15 | Sin hallazgos deterministas. |
| `test/services/exchange_rate_service_cache_purge_test.dart` | 49 | **1 fallo determinista:** `finally condicional...` en `:1529`. |
| `test/domain/monetary/rate_market_test.dart` | 8 | Sin hallazgos deterministas. |
| `test/domain/monetary/rate_quote_input_test.dart` | 14 | Sin hallazgos deterministas. |
| `test/domain/monetary/resolve_persisted_expense_test.dart` | 11 | Sin hallazgos deterministas. |
| `test/domain/monetary/build_new_expense_tuple_test.dart` | 11 | Sin hallazgos deterministas. |
| `test/domain/monetary/resumen_lente_monetario_test.dart` | 2 | Sin hallazgos deterministas. |
| **Total** | **127** | **127 declaradas; 1 fallo determinista detectado por inspección estática.** |

El conteo aritmético de 127 es correcto. Lo que no es correcto es presentarlo como una suite verde: una de las 127 pruebas no puede pasar con la implementación actual.

---

## 4. Autorización o bloqueo de paso a E0-03 (U3/U4)

# BLOQUEADO ⛔

No se autoriza el paso a **E0-03 (U3/U4)** hasta que se cumplan estas condiciones:

1. **Corregir el test de `finally` de M-08** para que sus aserciones de identidad sean válidas:
   - o se refactoriza `ensureCacheHistoricaPurgada` para retornar la Future interna directamente; o
   - se reescribe la prueba sin comparar `identical` contra la Future externa.
2. **Eliminar la higiene pendiente en el test D-05:** usar `TestableSettingsProvider` o esperar/desactivar `actualizarTasaAutomatica()` en `loadSettings`.
3. **Corregir la documentación:**
   - Unificar 127 pruebas en `estado-actual.md` y en el informe.
   - Resolver la contradicción del dictamen `septima-reauditoria-u1-u2-deepseek.md` (126 pruebas / ACEPTADO).
   - Corregir la afirmación sobre `scripts/check_syntax.js` como archivo modificado.
   - Corregir la afirmación de que la prueba de `finally` verifica identidad con `futureB`.
4. **Commit, push y CI en verde** (`flutter analyze`, `flutter test`, build), con evidencia de `conclusion: success`.

**D-02, D-06 y D-07** quedan aceptados como diferidos a E0-03 conforme a la autorización expresa del prompt. **D-05** no está diferido y su código está cerrado; el bloqueo actual es por la prueba M-08 y la integridad documental, no por D-05, M5-a ni R-01.
