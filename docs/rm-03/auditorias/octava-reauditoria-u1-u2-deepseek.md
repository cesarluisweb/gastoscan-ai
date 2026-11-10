# RM-03 — Octava Reauditoría Adversarial Independiente (U1/U2 — E0-02)

## 0. Método y límites

- Sin SDK de Flutter/Dart local: no se ejecutó `flutter test` ni `flutter analyze`.
- Validación por inspección estática, semántica formal de Dart, trazado de flujos y conteo determinista.
- `node scripts/check_syntax.js`: **PASS 7/7**.
- Conteo por declaración `test(`: **127 pruebas** en los 9 archivos.
- Git: `HEAD == origin/main == 676344b`; el parche permanece en el working tree, sin commits ni push nuevos. `scripts/check_syntax.js` está versionado y **sin modificaciones**.

---

## 1. Veredicto Ejecutivo

# ACEPTADO CON OBSERVACIONES ⚠️

Los tres bloqueantes de la 7.ª reauditoría quedan resueltos:

1. **M-08:** la prueba de `finally` ya no compara Futures externas; captura `taskA`/`taskB` desde `activePurgeFuture` y verifica la identidad sobre la Future interna. La aserción es correcta por semántica de Dart y discrimina un `finally` incondicional.
2. **D-05:** el test usa `TestableSettingsProvider` con `disableAutoSyncOnLoad`, silenciando la sincronización de fondo; el código comprueba el retorno de `setBool` en ambas ramas.
3. **Documentación:** el inventario está unificado a 127 pruebas, la 7.ª reauditoría figura como **RECHAZADO ❌** y `scripts/check_syntax.js` se reporta correctamente como versionado sin modificaciones.

Las observaciones restantes son menores y no bloquean el cierre técnico, pero deben atenderse antes de declarar la compuerta “Completada ✅” en CI.

---

## 2. Análisis punto por punto

### 2.1. M-08 — Prueba de `finally` condicional — ✅ Resuelto

**Ubicación:** `test/services/exchange_rate_service_cache_purge_test.dart:1529-1588`.

Verificación de cada requisito:

| Requisito | Evidencia | Resultado |
| :--- | :--- | :--- |
| Eliminar `identical(activePurgeFuture, futureB)` y `identical(futureC, futureB)` | El test ya no usa `futureB` ni `futureC` en aserciones de identidad; captura `taskA` y `taskB` desde `activePurgeFuture` (`:1547`, `:1564`). | ✅ |
| `taskB` captura la Future interna mientras B está pausada con `completerB` | `storeB.onKeyRemovedAsync` espera `completerB.future` (`:1559-1561`); `ensureCacheHistoricaPurgada` asigna `_activePurgeFuture = purgeTask` antes del primer `await` externo (`exchange_rate_service.dart:686`). `taskB` es la Future interna. | ✅ |
| Tras A (`resA == -1`), `identical(activePurgeFuture, taskB)` es `true` | El `finally` de A compara `identical(_activePurgeFuture, purgeTaskA)` (`:691`); como `_activePurgeFuture` es `taskB`, no lo anula. El test lo verifica en `:1574-1575`. | ✅ |
| Un `finally` incondicional fallaría la prueba | Si A hiciera `_activePurgeFuture = null`, la aserción `isNotNull` de `:1574` fallaría y `identical(null, taskB)` sería falsa. La prueba discrimina el defecto. | ✅ |
| C completa sin purga redundante y B limpia al final | `futureC` se engancha a `taskB` (`:1578`); se verifica que `activePurgeFuture` sigue siendo `taskB` (`:1579`); `resB == 1`, `resC == 1` y `activePurgeFuture == null` (`:1585-1587`). | ✅ |

**Prueba de generación** (`:1497-1527`): sigue siendo no vacua. `returnFalseOnRemove = false` elimina la causa alternativa del `-1`; el `Completer` pausa dentro de `remove`; el `reset` cambia la generación; la purga retorna `-1` y no fija la marca. ✅

**Conclusión M-08:** bloqueante resuelto. La prueba es determinista y discrimina correctamente el `finally` condicional.

---

### 2.2. D-05 — Higiene y verificación de `setBool` — ✅ Resuelto con observaciones menores

**Test** (`test/providers/settings_provider_rate_cache_test.dart:289-342`):

- `provider1` y `provider2` son `TestableSettingsProvider` (`:298`, `:317`).
- `TestableSettingsProvider.disableAutoSyncOnLoad` es `true` por defecto (`:41`) y su override devuelve `false` cuando `client == null` (`:44-48`). Por tanto, `loadSettings()` ya no dispara `actualizarTasaAutomatica()` en segundo plano.
- Las llamadas explícitas con `client` sí ejecutan `super.actualizarTasaAutomatica`, cubriendo offline, recarga, recuperación viva y fallo de `setTasaCambio`.

**Código**:

| Punto | Evidencia | Resultado |
| :--- | :--- | :--- |
| Rama viva: `setBool(false)` comprobado | `settings_provider.dart:269-272`: `final okBool = await prefs.setBool(..., false); if (okBool) { _esTasaManualUsd = false; }` | ✅ |
| `setTasaCambio`: `setBool(true)` comprobado | `settings_provider.dart:364-365`: `final okBool = await prefs.setBool(..., true); _esTasaManualUsd = okBool;` | ✅ |
| Preservación offline de la tasa manual | `settings_provider.dart:287-300`: rama `esReferencia` conserva `_tasaCambioVesUsd` y no escribe `prefTasaCambio` si `isManual` y válida. | ✅ |
| Solo tasa viva sustituye y desactiva | `settings_provider.dart:260-273`: rama `!allRates.esReferencia` escribe la tasa viva y desactiva la bandera si `setBool` confirma. | ✅ |
| Fallo de `setDouble` no activa la bandera | `settings_provider.dart:361-369`: si `ok == false`, no llama a `setBool` y deja `_esTasaManualUsd = false`. | ✅ |

**Observaciones menores (no bloqueantes):**

1. No hay test dedicado para `returnFalseOnSetBool = true` en `SettingsProvider`. El fake lo soporta (`TestSharedPreferences:104-115`), pero solo se usa en la suite de purga. Sería recomendable cubrir ambas ramas de `okBool`.
2. En la rama viva, si `setBool(false)` falla, `_esTasaManualUsd` permanece `true` mientras `_tasaCambioVesUsd` ya contiene la tasa viva. Es una inconsistencia semántica menor: en memoria la tasa es viva, pero la bandera dice “manual”. No corrompe datos ni viola el requisito literal, pero conviene documentarlo o reintentar.
3. En `setTasaCambio`, si `setBool(true)` falla, `_esTasaManualUsd = false` aunque la tasa manual sí se persistió en disco. En el siguiente arranque, si la bandera en disco quedó `false`, la tasa manual podría ser ignorada frente a la caché automática. Es un caso de fallo de disco poco frecuente, pero conviene cubrirlo.

**Conclusión D-05:** bloqueante de higiene resuelto; código y prueba principales correctos.

---

### 2.3. Consistencia documental — ✅ Resuelta con observación de precisión

**Conteo exacto:**

| Suite | `test(` declaradas |
| :--- | ---: |
| `test/providers/gasto_provider_rate_cache_test.dart` | 6 |
| `test/providers/settings_provider_rate_cache_test.dart` | 11 |
| `test/services/exchange_rate_service_test.dart` | 15 |
| `test/services/exchange_rate_service_cache_purge_test.dart` | 49 |
| `test/domain/monetary/rate_market_test.dart` | 8 |
| `test/domain/monetary/rate_quote_input_test.dart` | 14 |
| `test/domain/monetary/resolve_persisted_expense_test.dart` | 11 |
| `test/domain/monetary/build_new_expense_tuple_test.dart` | 11 |
| `test/domain/monetary/resumen_lente_monetario_test.dart` | 2 |
| **Total** | **127** |

**Documentos:**

- `docs/rm-03/estado-actual.md:4`, `:7`, `:19`, `:48`, `:66` y `:85` reflejan **127 pruebas**.
- `estado-actual.md:84` registra la 7.ª reauditoría como **RECHAZADO ❌**, con el motivo correcto (identidad de Future externa, higiene D-05 e inconsistencia documental).
- `docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md:48` mantiene “Conteo Previo 126 / +1 / 127”, que es correcto como evolución histórica, no como contradicción.
- `implementacion-u1-u4-e0-02.md:56` reporta `scripts/check_syntax.js` como **versionado y sin modificaciones**, lo cual coincide con `git status`.
- `implementacion-u1-u4-e0-02.md:17` y `:19` describen correctamente `TestableSettingsProvider` y la captura de `taskB`.
- `docs/rm-03/auditorias/septima-reauditoria-u1-u2-deepseek.md` ahora contiene el dictamen **RECHAZADO ❌** de la 7.ª reauditoría. Sus líneas 134-137 describen la inconsistencia 126/127 como hallazgo histórico de esa auditoría; no contradicen el estado actual, que ya está unificado a 127.

**Observación de precisión:** el informe sigue diciendo “VALIDADO DETERMINISTAMENTE” y el script imprime “SYNTACTICALLY SOUND”. En rigor, `check_syntax.js` solo valida balance de delimitadores, no sintaxis Dart completa ni semántica. La validación determinista es la inspección estática de este dictamen, no una ejecución de la suite. Conviene matizar esa frase para no confundirla con un `flutter test` verde.

**Conclusión documental:** consistencia resuelta; queda una precisión de lenguaje menor.

---

## 3. Inventario de las 127 pruebas

| Archivo | Declaradas | Estado en esta auditoría |
| :--- | ---: | :--- |
| `test/providers/gasto_provider_rate_cache_test.dart` | 6 | Sin hallazgos deterministas; NEW-3b/D-05 cubierto en `:214`. |
| `test/providers/settings_provider_rate_cache_test.dart` | 11 | D-05 en `:289` con `TestableSettingsProvider`; higiene resuelta. |
| `test/services/exchange_rate_service_test.dart` | 15 | Sin hallazgos deterministas. |
| `test/services/exchange_rate_service_cache_purge_test.dart` | 49 | M5-a `:1440` y M-08 `:1497`/`:1529` correctos; sin fallo determinista detectado. |
| `test/domain/monetary/rate_market_test.dart` | 8 | Sin hallazgos deterministas. |
| `test/domain/monetary/rate_quote_input_test.dart` | 14 | Sin hallazgos deterministas. |
| `test/domain/monetary/resolve_persisted_expense_test.dart` | 11 | Sin hallazgos deterministas. |
| `test/domain/monetary/build_new_expense_tuple_test.dart` | 11 | Sin hallazgos deterministas. |
| `test/domain/monetary/resumen_lente_monetario_test.dart` | 2 | Sin hallazgos deterministas. |
| **Total** | **127** | **127 declaradas; 0 fallos deterministas detectados por inspección estática.** |

---

## 4. Cierre de la compuerta E0-02 y autorización de E0-03

### E0-02

- **Cierre técnico en working tree: ACEPTADO ⚠️.**
- Los bloqueantes de la 7.ª reauditoría están resueltos: M-08 determinista, D-05 con higiene y `setBool` comprobado, documentación unificada a 127.
- **No se declara “Completada ✅”** todavía: falta commit, push y CI en verde (`flutter analyze`, `flutter test`, build). E0-02 permanece en **“Pendiente de validación 🧪”** hasta que CI confirme y César valide en dispositivo físico si corresponde.

### E0-03 (U3/U4)

# AUTORIZADO CONDICIONALMENTE ⚠️

Se autoriza el inicio de E0-03 **solo después** de:

1. Commitear y pushear este parche.
2. Confirmar CI en verde (`conclusion: success`).
3. Verificar que no aparezcan nuevos fallos deterministas en la ejecución real de la suite.

Mientras esas condiciones no se cumplan, E0-03 permanece en espera conforme a **A-16**. La autorización no es un “Completada ✅” retroactivo de E0-02; es la habilitación para iniciar U3/U4 una vez verde el CI de este lote.

**Diferimientos aceptados:** D-02, D-06 y D-07 quedan diferidos a E0-03 conforme a la autorización expresa del prompt. **D-05** no está diferido: su código y prueba principal quedan cerrados en E0-02, con las observaciones menores indicadas.
