# RM-03 — Quinta Reauditoría Adversarial Independiente (U1/U2)

> **Documento:** Informe de la quinta reauditoría adversarial independiente (DeepSeek).
> **Unidad:** `E0-02` — Dominio monetario, tupla y purga de caché A-07 (Unidades U1 y U2).
> **Fecha:** Noviembre de 2026.
> **Repositorio:** `C:\Development\Control de gastos VE`.
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md` (íntegro, sin modificaciones).
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (`A-01` a `A-16` y `D-01` a `D-08`, sin modificaciones).
> **Auditoría atendida:** `docs/rm-03/auditorias/correcciones-cuarta-reauditoria-u1-u2.md` (Gemini).
> **Veredicto:** **RECHAZADO ❌**.
> **Estado de E0-02:** **NO CERRADO**. U1 y U2 **NO ACEPTADAS** y **NO COMPLETADAS**.
> **Validación:** Inspección estática exclusiva. **0 pruebas ejecutadas, 0 `flutter analyze`, 0 CI**.

---

## 0. Declaración de método y límites

Este informe distingue de forma estricta entre:

1. **Defectos demostrados por inspección estática:** se derivan del flujo del código, de las firmas, de las condiciones de carrera y del orden de las operaciones. No dependen de una ejecución concreta.
2. **Pruebas ejecutadas:** **ninguna**. No hay SDK de Flutter/Dart ni `gh` en el entorno local. No se ejecutó `flutter test`, `flutter analyze` ni GitHub Actions.

Cuando se afirma que un test “falla” o “no puede pasar”, se trata de una inferencia determinista por construcción del código, no de una corrida local. La validación en CI sigue pendiente y es condición de aceptación.

No se modificó código, pruebas, contrato ni decisiones durante la auditoría. La persistencia de este informe y de `estado-actual.md` se realizó después, como tarea documental separada.

---

## 1. Veredicto ejecutivo

**RECHAZADO ❌.**

La arquitectura central de U2 (operaciones pendientes, confirmación física, *fail-closed* y purga selectiva) sigue siendo sólida y no requiere rediseño. El rechazo obedece a dos causas independientes:

1. **B-05 (nuevo bloqueante):** `test/providers/gasto_provider_rate_cache_test.dart:110-137` llama a `cargarDatos` sin `await` en un callback que no es `async`. La aserción se evalúa antes de que se carguen los totales y el test no puede pasar.
2. **M-05 no resuelto:** la rescisión de operaciones pendientes solo cubre escrituras hechas dentro de `ExchangeRateService`. Una tasa manual guardada desde `SettingsProvider` no rescinde un `remove` pendiente, y la purga elimina claves sin revalidar su valor actual. Esto puede borrar una tasa válida recién persistida, lo que obliga a **RECHAZADO** según la regla de persistencia de tasas.

| Elemento | Resultado |
| :--- | :--- |
| B-01 | ✅ Resuelto por inspección |
| B-02 | ✅ Resuelto en lo esencial, con observación de conteo |
| B-03 | ✅ Resuelto por inspección |
| B-04 | ✅ Resuelto por inspección, con título de test obsoleto |
| B-05 (nuevo) | ❌ **Bloqueante determinista** |
| M-01 | ✅ Resuelto en los tres consumidores, con residuales fuera de alcance |
| M-02 | ⚠️ Parcial: cubre fecha ausente/no parseable; no fechas imposibles |
| M-03 | ⏸️ No resuelto, diferido a U3/U4 |
| M-04 | ⏸️ No resuelto, diferido (metadato) |
| M-05 | ❌ **No resuelto; bloqueante por pérdida de tasa** |
| M-06 | ⚠️ Mitigación incompleta; depende de M-08 |
| M-07 | ⚠️ Parcial |
| M-08 | ❌ No resuelto |

**U1 y U2 permanecen NO COMPLETADAS.** E0-02 sigue abierto. U3 y U4 no están autorizadas.

---

## 2. Integridad del repositorio y alcance del cambio

### 2.1 Git

| Verificación | Resultado |
| :--- | :--- |
| `HEAD` | `de17323f233e44f26b895bc09a94bd86fae47cad` |
| `origin/main` | `de17323f233e44f26b895bc09a94bd86fae47cad` |
| Commits nuevos | Ninguno (`git log de17323..HEAD` vacío) |
| Push | Ninguno |
| `firestore.rules` | Sin cambios |
| `pubspec.yaml` | Sin cambios |
| `pubspec.lock` | **Ausente** (condición preexistente; viola AGENTS.md) |
| SQLite | `version: 18` intacto en `database_helper.dart:46,69` |
| U3/U4 | No implementadas: `_tasasSonReferencia` sigue siendo un único `bool` (`settings_provider.dart:25,242,257`) y `_tasaUsd = AppConstants.defaultTasaCambio` sigue en `gasto_provider.dart:40` |
| `database_helper.dart` | Diff de solo **+4/−3**, sin reformateo masivo; `git ls-files --eol` reporta `i/lf w/lf` |
| `scratch/check_syntax.js` | **No existe**; la afirmación documental de haberlo ejecutado no es reproducible |

### 2.2 Archivos modificados en el working tree

- `MEMORY.md`
- `lib/data/datasources/local/database_helper.dart`
- `lib/data/models/gasto_firestore_mapper.dart`
- `lib/data/models/gasto_model.dart`
- `lib/providers/gasto_provider.dart`
- `lib/providers/settings_provider.dart`
- `lib/services/exchange_rate_service.dart`
- `test/models/gasto_firestore_mapper_test.dart`
- `test/services/exchange_rate_service_test.dart`

### 2.3 Archivos no versionados

- `docs/rm-03/`
- `lib/domain/monetary/` (6 archivos)
- `test/domain/monetary/` (5 archivos)
- `test/providers/gasto_provider_rate_cache_test.dart`
- `test/providers/settings_provider_rate_cache_test.dart`
- `test/services/exchange_rate_service_cache_purge_test.dart`

El alcance es coherente con U1/U2. No hay indicios de implementación encubierta de U3/U4.

---

## 3. Bloqueantes originales B-01 a B-04

| ID | Afirmación de Gemini | Verificación | Estado | Evidencia |
| :--- | :--- | :--- | :--- | :--- |
| **B-01** | Import explícito de `ExchangeRateService` añadido | El import existe y resuelve el identificador usado en los tests | ✅ Resuelto | `test/providers/gasto_provider_rate_cache_test.dart:7` |
| **B-02** | Reintentos incrementan `cleanedCount` y se validó `disk` | El replay incrementa el contador solo tras éxito confirmado; el test de disco existe | ✅ Resuelto en lo esencial | `exchange_rate_service.dart:695-727`; `exchange_rate_service_cache_purge_test.dart:1235-1277` |
| **B-03** | Test obsoleto `<= 50.0` reemplazado por valores inválidos D-08 | Usa `0.5`, `1.0`, `NaN`; añade conservación de `40.0`/`43.2` | ✅ Resuelto | `exchange_rate_service_test.dart:168-181,183-196` |
| **B-04** | `setMockInitialValues({})` elimina `MissingPluginException` | Está en `setUp`; el test recorre la ruta real y afirma 60/65/62 | ✅ Resuelto | `settings_provider_rate_cache_test.dart:51-59,157-170` |

### 3.1 Observación sobre B-02: conteo inconsistente al eliminar un mapa completo

El contador es coherente cuando la operación pendiente es un `setString` de un mapa depurado: guarda `entriesCleanedInMap` y lo suma al confirmar. Pero cuando `tasas_historico_v1` se elimina **entero** porque el mapa depurado queda vacío:

- En el primer intento se suma `entriesCleanedInMap` (por ejemplo, N entradas).
- La operación pendiente se registra como `remove` con `entriesCleanedCount: 1` (`exchange_rate_service.dart:895`).
- En un reintento exitoso se suma **1**, no N.

No afecta a la persistencia ni a la seguridad, pero el contrato del contador no es uniforme entre intentos. Es un hallazgo de observabilidad (N-04), no un bloqueante.

### 3.2 Nota sobre B-04

El cuerpo del test de `settings_provider_rate_cache_test.dart:157-170` es correcto y prueba la asignación de 60/65/62 tras eliminar el `MissingPluginException`. Sin embargo, su título (“actualizarTasaAutomatica no asigna Infinity a las tasas activas”) no describe lo que el cuerpo hace. Es una inconsistencia documental, no un fallo funcional.

---

## 4. B-05 (nuevo bloqueante): test determinista que no puede pasar

**Ubicación:** `test/providers/gasto_provider_rate_cache_test.dart:110-137`.

```dart
110: test('setTasasReferencia rechaza Infinity, NaN, 0.5, 1.0 y valores negativos', () {
111:   final provider = GastoProvider(repository: fakeRepo, autoLoad: false);
...
129:   provider.cargarDatos(prefsInstance: TestSharedPreferences({
130:     ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
131:   }));
132:   provider.setTasasReferencia(tasaUsd: 45.0, tasaEur: 50.0);
134:   final spent = provider.getSpentForCategory('Alimentos', moneda: 'EUR');
135:   expect(spent.isFinite, isTrue);
136:   expect(spent, equals(80.0));
137: });
```

### 4.1 Por qué falla de forma determinista

1. El callback del test **no es `async`** y no hay `await` en la línea 129.
2. `GastoProvider.cargarDatos` es asíncrono. Su primera suspensión ocurre en `ensureCacheHistoricaPurgada` (`gasto_provider.dart:140`).
3. Al volver al cuerpo del test, `_totalesPorCategoria` y `_totalesPorCategoriaVes` siguen vacíos.
4. `getSpentForCategory('Alimentos', moneda: 'EUR')` con `_tasaEur = 50.0` y `_tasaUsd = 45.0` entra en la rama `effEur > 0 && effUsd > 0` (`gasto_provider.dart:625-627`), usa el mapa USD vacío y retorna `0.0` (`gasto_provider.dart:643`).
5. `expect(0.0, equals(80.0))` falla. No depende del orden de microtareas: el cuerpo síncrono termina antes de que se ejecute cualquier continuación de `await`.

Además, el test reasigna `fakeRepo` en la línea 123, pero el `provider` fue construido en la línea 111 con la instancia anterior. La reasignación no afecta al provider; como ambas instancias tienen los mismos datos (`USD: 100.0`, `VES: 4000.0`), el resultado esperado seguiría siendo 80.0 si se añadiera el `await`, pero la reasignación es código muerto respecto al provider.

### 4.2 Corolario

El único test que llama a `setTasasReferencia` es este. Por tanto, la cobertura real de la validación de `setTasasReferencia` es **cero** hasta que B-05 se corrija. El fallo de CI es seguro: `.github/workflows/build_apk.yml:84` ejecuta `flutter test` y falla ante cualquier test rojo.

---

## 5. Recomendaciones M-01 a M-08

| ID | Estado real | Evidencia y comentario |
| :--- | :--- | :--- |
| **M-01** | ✅ Resuelto en los tres consumidores | `rate_quote_input.dart:76`, `monetary_resolution.dart:175`, `database_helper.dart:1720-1725` usan `isValidMonetaryRate`. Residuales: la consulta SQL de `database_helper.dart:1709` sigue con `tasa_cambio > 1.0`, y el fallback `850` permanece en `database_helper.dart:1721` (reparación sin invocación de producción; `dryRun=true` por defecto). |
| **M-02** | ⚠️ Parcial | `fromJson` asigna epoch 0 y `esReferencia: true` si la fecha falta o no es parseable (`exchange_rate_service.dart:45-55`). Pero `DateTime.tryParse('2026-02-30')` normaliza a `2026-03-02`, por lo que una fecha imposible se acepta como válida y conserva `esReferencia: false`. La afirmación documental de que también cubre fechas “anómalas” es inexacta. Sin consumidores en producción: el único uso está en tests. |
| **M-03** | ⏸️ No resuelto, diferido | `review_expense_screen.dart:247-255` conserva `<= 50.0` para USD, EUR y USDT. Es un defecto de lógica financiera en pantalla, delimitado a U3/U4 por la documentación. No se acepta como cerrado. |
| **M-04** | ⏸️ No resuelto, diferido | `exchange_rate_service.dart:866` valida el timestamp solo con `DateTime.tryParse`; no usa `_isValidCalendarDate`. Impacto limitado al metadato informativo, pero sigue abierto. |
| **M-05** | ❌ **No resuelto** | Ver análisis detallado en §5.1. |
| **M-06** | ⚠️ Mitigación incompleta | `_pendingPurgeOperations`, `_purgeMarkPendingConfirmation` y `_activePurgeFuture` siguen siendo estáticos (`exchange_rate_service.dart:555,558,561`). El mapa está indexado solo por clave, no por instancia de `SharedPreferences`; en producción hay una sola instancia, pero en tests con varios stores puede haber contaminación. La afirmación de “aislamiento 100% blindado” depende de M-08, que no está resuelto. |
| **M-07** | ⚠️ Parcial | Los tests 13 y 14 usan montos reales y distinguen 100.0 de 42.105/NaN (`gasto_provider_rate_cache_test.dart:69-108`). Pero el test 13 prueba el *fail-closed* por purga `-1`, no el rechazo de una tasa por el validador; el test 14 prueba la ruta de lectura de Infinity. Ninguno ejercita `setTasasReferencia`; eso queda solo en B-05, que falla. |
| **M-08** | ❌ No resuelto | Ver análisis detallado en §5.2. |

### 5.1 Análisis detallado de M-05: la rescisión no cubre las rutas reales de pérdida

La implementación añadida es:

```dart
582: static void _onKeyWriteConfirmed(String key) {
583:   _pendingPurgeOperations.remove(key);
584: }
```

Se invoca tras `setDouble`/`setString` confirmados dentro de `ExchangeRateService` (`:157-229`, `:461`, `:487`, `:510`, `:532`). El problema es doble.

#### Ruta A — Replay de un `remove` pendiente tras una escritura manual válida

1. La purga detecta `tasa_cambio_ves_usd` corrupta y la añade a `keysToRemove` (`exchange_rate_service.dart:853-859`).
2. Registra la operación pendiente y llama a `prefs.remove` (`:895-897`). Si la plataforma devuelve `false` o lanza, la operación queda en `_pendingPurgeOperations`, la purga lanza `StateError` (`:910-911`) y `ensure` retorna `-1`.
3. El usuario guarda una tasa manual válida, por ejemplo 60.0, con `SettingsProvider.setTasaCambio` (`settings_provider.dart:297-305`). Esa ruta escribe `prefTasaCambio` y **no llama** a `_onKeyWriteConfirmed`; además, ignora el `bool` que retorna `setDouble` (línea 304).
4. En la misma sesión, abrir la pantalla de revisión llama a `getAllTodayRates` (`review_expense_screen.dart:243`), que a su vez llama a `ensureCacheHistoricaPurgada` (`exchange_rate_service.dart:114`).
5. `ensure` no ve la marca confirmada (la purga anterior falló) y ejecuta el replay de operaciones pendientes (`:696-727`). El `remove` de `tasa_cambio_ves_usd` ahora sí tiene éxito y **borra el 60.0 recién guardado**.
6. La siguiente carga cae al fallback de 850 o a una caché obsoleta (`settings_provider.dart:87-91`).

No es un caso teórico de laboratorio: es el flujo “fallo de disco en purga → guardo tasa manual → abro revisión”. La operación pendiente existe precisamente porque el sistema ya contempla fallos de `remove`; la escritura manual es una ruta de producción normal.

#### Ruta B — TOCTOU entre el escaneo y el borrado

La purga construye `keysToRemove` leyendo los valores en `:733-892`, y después ejecuta el borrado en `:894-908`:

```dart
894: for (final k in keysToRemove) {
895:   _pendingPurgeOperations[k] = PendingPurgeOperation.remove(...);
896:   try {
897:     final removed = await prefs.remove(k);
```

No hay relectura del valor antes de `remove`. Si entre el escaneo y el `remove` de una clave se confirma una escritura válida (por ejemplo, una tasa manual de `SettingsProvider`), el `remove` borra el valor nuevo. `_onKeyWriteConfirmed` no puede evitarlo porque la clave aún no está en `_pendingPurgeOperations`: está solo en la lista local `keysToRemove`. La rescisión llega tarde y por el objeto equivocado.

#### Ruta C — Sobrescritura de un mapa histórico con un payload obsoleto

Si `tasas_historico_v1` se depura y se guarda con `prefs.setString(key, payload)` (`:840`), cualquier escritura concurrente más reciente del mismo mapa se pierde, porque `payload` se calculó sobre una instantánea anterior. Hoy no hay ningún escritor de `tasas_historico_v1` en `lib/` (solo la purga lo lee), por lo que esta ruta está **dormida**; se convertiría en real si U3/U4 o una importación histórica añaden escrituras.

#### El test de M-05 es vacuo

`exchange_rate_service_cache_purge_test.dart:1285-1329` no demuestra la rescisión:

1. Falla el `remove` de `cached_rate_usd` y queda la operación pendiente (`:1291-1295`).
2. Se pone `returnFalseOnRemove = false` (`:1298`).
3. `getAllTodayRates` (`:1304`) llama primero a `ensure` (`exchange_rate_service.dart:114`), que **reproduce el `remove` pendiente con éxito** y borra el valor corrupto antes de la escritura fresca. La operación pendiente desaparece.
4. Después se escribe 60.0 y se invoca `_onKeyWriteConfirmed`, pero el mapa ya está vacío.
5. La aserción `pendingPurgeOperations.containsKey('cached_rate_usd') == false` (`:1313`) pasaría aunque `_onKeyWriteConfirmed` fuera un método vacío.

El test prueba que el replay funciona, no que la rescisión protege una escritura fresca. Es una prueba de una ruta distinta a la que dice cubrir.

**Conclusión M-05:** no resuelto. Puede afectar la persistencia de tasas; por la regla del encargo, esto obliga a **RECHAZADO**.

### 5.2 Análisis detallado de M-08: el reset de estado estático no es seguro

```dart
574: static void resetPendingPurgeOperationsForTesting() {
575:   _pendingPurgeOperations.clear();
576:   _purgeMarkPendingConfirmation = false;
577:   _activePurgeFuture = null;
578: }
```

Y en `ensure`:

```dart
665: _activePurgeFuture = purgeTask;
666: try {
667:   return await purgeTask;
668: } finally {
669:   _activePurgeFuture = null;
670: }
```

Problemas:

1. **Reset durante una purga en vuelo:** `reset` pone `_activePurgeFuture = null` sin cancelar ni esperar la purga. Esa purga sigue viva y puede repoblar `_pendingPurgeOperations`, cambiar `_purgeMarkPendingConfirmation` o borrar claves de su store después del reset. El siguiente test arranca con estado contaminado.
2. **`finally` incondicional:** si tras un reset se registra una purga B, la purga A que termina después ejecuta `_activePurgeFuture = null` y borra la referencia de B. Una llamada C puede entonces iniciar una tercera purga concurrente con B. Dos purgas simultáneas comparten el mapa estático y pueden pisarse.
3. **No hay token de generación:** nada distingue una operación de la generación anterior de una actual. `reset` no puede invalidar las continuaciones pendientes.
4. **B-05 es un ejemplo de higiene rota:** deja un `cargarDatos` sin `await`. En este caso concreto el store tiene la marca de purga en `true`, por lo que `ensure` retorna 0 y no hay purga en vuelo; pero el patrón demuestra que la suite no garantiza que todas las futuras estén resueltas antes del `tearDown`.

M-08 es fundamentalmente un problema de aislamiento de tests, no de producción, porque `resetPendingPurgeOperationsForTesting` solo se invoca desde tests. Pero invalida la afirmación de M-06 de que el aislamiento está “100% blindado” y hace que la suite no sea una base fiable para la compuerta.

---

## 6. Inventario real de pruebas y limitaciones de ejecución

### 6.1 Conteo real

| Suite | Documentado | Real (regex `test(`/`testWidgets(`) |
| :--- | ---: | ---: |
| `gasto_provider_rate_cache_test.dart` | 4 | 4 |
| `settings_provider_rate_cache_test.dart` | 6 | 6 |
| `exchange_rate_service_test.dart` | 15 | 15 |
| `exchange_rate_service_cache_purge_test.dart` | 42 | 42 |
| `rate_market_test.dart` | 8 | 8 |
| `rate_quote_input_test.dart` | 11 | **14** |
| `resolve_persisted_expense_test.dart` | 15 | **11** |
| `build_new_expense_tuple_test.dart` | 10 | **11** |
| `resumen_lente_monetario_test.dart` | 4 | **2** |
| **Total** | **115** | **113** |

La tabla de `correcciones-cuarta-reauditoria-u1-u2.md:100-112` no coincide con el código. El total documentado (115) es incorrecto; el real es **113**. Las cifras por suite también están desalineadas.

### 6.2 Limitaciones

- No se ejecutó ninguna prueba. No hay `flutter`, `dart` ni `gh`.
- No se ejecutó `flutter analyze --fatal-warnings --no-fatal-infos` ni `flutter test`.
- No se disparó CI. El workflow relevante es `.github/workflows/build_apk.yml:81,84`.
- La suite no es ejecutable de forma fiable mientras B-05 esté presente: el test fallará y, además, el `cargarDatos` no esperado puede completarse después del test.
- El test de M-05 no prueba la rescisión; el de B-02 solo cubre el caso `setString` + `remove` de una entrada, no la eliminación de un mapa completo.
- No hay ningún test que reproduzca la pérdida de una tasa manual por replay de un `remove` pendiente, ni el TOCTOU entre escaneo y borrado.
- `gasto_provider_rate_cache_test.dart` importa `../services/exchange_rate_service_cache_purge_test.dart` (línea 8) para reutilizar `TestSharedPreferences`. Funciona, pero acopla dos suites y hace que un fallo de compilación en la suite importada afecte a la de providers.

---

## 7. Hallazgos nuevos N-01 a N-08

| ID | Severidad | Hallazgo | Evidencia |
| :--- | :--- | :--- | :--- |
| **N-01** | **Bloqueante** | B-05: test síncrono con `cargarDatos` sin `await`; espera 80.0 y obtiene 0.0 | `gasto_provider_rate_cache_test.dart:110-137` |
| **N-02** | **Alta** | `SettingsProvider` escribe `prefTasaCambio` y `cached_rate_*` sin rescindir operaciones pendientes; `_onKeyWriteConfirmed` es privado y solo se usa dentro de `ExchangeRateService` | `settings_provider.dart:230-243,304`; `exchange_rate_service.dart:582-584` |
| **N-03** | **Alta** | El bucle de borrado no revalida el valor actual antes de `prefs.remove`; una escritura válida entre el escaneo y el borrado se pierde | `exchange_rate_service.dart:894-908` |
| **N-04** | Baja | B-02: el contador de una eliminación de mapa completo vale N en el primer intento y 1 en el reintento | `exchange_rate_service.dart:829-838,895` |
| **N-05** | Media | `setTasaCambio` ignora el `bool` de `prefs.setDouble`; un fallo de persistencia es silencioso y no genera operación pendiente | `settings_provider.dart:304` |
| **N-06** | Baja | Documentación inconsistente: 115 vs 113 tests; `scratch/check_syntax.js` inexistente aunque se afirma ejecutado; `estado-actual.md` lista B-01..B-04 y M-01..M-08 como pendientes en §2.1 y como corregidos en §2.5; `implementacion-u1-u2.md:72` sigue diciendo `DateTime.now()`; el test de `settings_provider` se llama “no asigna Infinity” pero afirma 60/65/62 | `correcciones...:112-118`; `estado-actual.md:34-36,70-74`; `implementacion-u1-u2.md:72`; `settings_provider_rate_cache_test.dart:157-170` |
| **N-07** | Baja | `fromJson` acepta fechas imposibles que `DateTime.tryParse` normaliza (`2026-02-30` → `2026-03-02`) y conserva `esReferencia: false` | `exchange_rate_service.dart:45-55` |
| **N-08** | Baja | La consulta SQL de reparación conserva `tasa_cambio > 1.0` y el fallback 850; hoy no hay invocación de producción con `dryRun=false` | `database_helper.dart:1709,1721`; `gasto_provider.dart:246-253` |

N-07 y N-08 no son bloqueantes por sí solos: N-07 no tiene consumidores de producción y N-08 está dormido. Se registran para que no se pierdan al cerrar U3/U4.

---

## 8. Correcciones requeridas

### 8.1 B-05 (obligatorio)

En `test/providers/gasto_provider_rate_cache_test.dart:110`:

1. Declarar el callback como `async`.
2. Hacer `await provider.cargarDatos(...)` en la línea 129.
3. Construir el provider después de la reasignación de `fakeRepo` (línea 123) o eliminar esa reasignación si no aporta nada.
4. Idealmente, afirmar el estado tras cada llamada inválida a `setTasasReferencia`, no solo el resultado final. Si no hay getters públicos de tasas, valorar un getter de solo lectura o una aserción indirecta que no dependa de una asignación posterior.

### 8.2 M-05 (obligatorio)

1. **Revalidar antes de borrar:** en el bucle `:894-908`, releer el valor actual de `k` y omitir el `remove` si ya es válido o si cambió respecto de la instantánea del escaneo. Lo mismo aplica al `setString` de `tasas_historico_v1` (`:840`): comparar una versión/hash antes de sobrescribir.
2. **Serializar escrituras y purga:** introducir un mutex/generación única para todas las escrituras de tasas (`prefTasaCambio`, `cached_rate_*`, `tasas_historico_v1`) y la purga, de modo que el escaneo y el borrado no se intercalen con una escritura confirmada.
3. **Rescindir en todas las rutas:** exponer una API pública controlada (por ejemplo, `ExchangeRateService.notifyRatePersisted(key)`) y llamarla desde `SettingsProvider.setTasaCambio` y `SettingsProvider.actualizarTasaAutomatica` solo cuando `setDouble` retorne `true`. Revisar también el resultado booleano en `setTasaCambio`.
4. **Añadir tests que fallen con el código actual:**
   - Replay: purga con `remove` fallido sobre `prefTasaCambio` → `setTasaCambio(60.0)` → `ensure` → afirmar que 60.0 sigue en `disk` y en memoria.
   - TOCTOU: purga con un `remove` diferido → escribir una tasa válida entre el escaneo y el borrado → afirmar que no se borra.
   - Asegurar que el test de M-05 actual no pase por el replay previo de `ensure`; si se usa `getAllTodayRates`, se está probando otra cosa.

### 8.3 M-08 (obligatorio para una suite fiable)

1. Añadir un contador de generación: cada purga captura la generación al iniciar y, antes de mutar estado estático, comprueba que sigue siendo la actual.
2. En `finally`, limpiar `_activePurgeFuture` solo si `identical(_activePurgeFuture, purgeTask)`.
3. Hacer que `reset` invalide la generación y, si es posible, sea `async` para esperar la futura en vuelo; o prohibir el reset mientras haya una purga activa.
4. Garantizar que ningún test deje futuros sin `await` (B-05 es el caso actual).

### 8.4 Documentación y observabilidad

1. Corregir el inventario a **113** pruebas y ajustar las cifras por suite.
2. Eliminar la afirmación de `scratch/check_syntax.js` o restaurar el script y dejar evidencia reproducible.
3. Unificar `estado-actual.md` §2.1/§2.2 con §2.5; no puede listar B-01..B-04 como pendientes y como corregidos a la vez.
4. Corregir `implementacion-u1-u2.md:72` (`DateTime.now()` ya no es el comportamiento).
5. Renombrar el test de `settings_provider_rate_cache_test.dart:157` para que describa lo que realmente afirma (asignación de 60/65/62), o añadir el caso Infinity que el título promete.
6. Aclarar en el docstring de B-02 si una eliminación de mapa completo cuenta como 1 clave o N entradas, y hacer que el primer intento y el reintento usen la misma unidad.

---

## 9. Condiciones verificables para cambiar el veredicto

El veredicto solo puede pasar a **ACEPTADO** o **ACEPTADO CON OBSERVACIONES** cuando se cumplan, con evidencia:

1. **B-05 corregido:** `gasto_provider_rate_cache_test.dart` con callback `async`, `await` en `cargarDatos`, y el test pasa en CI.
2. **Suite completa en verde:** `flutter test` sin fallos en todas las suites, no solo en las monetarias, con `test_results.txt` como evidencia.
3. **Análisis estático en verde:** `flutter analyze --fatal-warnings --no-fatal-infos` con salida 0.
4. **M-05 cerrado con pruebas rojo→verde:** los dos escenarios de pérdida (replay y TOCTOU) deben fallar con el código actual y pasar tras la corrección; el test de M-05 debe ejercitar realmente `_onKeyWriteConfirmed` o el mecanismo que lo sustituya.
5. **M-08 cerrado:** reset con generación/token, `finally` condicional, y ninguna futura sin `await` en tests.
6. **Documentación coherente:** 113 pruebas, sin afirmaciones no reproducibles, `estado-actual.md` sin contradicciones.
7. **Sexta reauditoría adversarial favorable** y validación de César en *Rinde Más Dev*.

Mientras tanto:

- U1 y U2 permanecen **NO COMPLETADAS**; no deben marcarse como `Completada ✅`.
- E0-02 permanece abierto.
- U3 y U4 no están autorizadas y no deben iniciarse.
- No hay autorización para commit ni push.

---

## 10. Conclusión

Las correcciones de Gemini resuelven los cuatro bloqueantes originales y mejoran de forma real M-01, M-07 y parte de M-02. Sin embargo, la quinta reauditoría encuentra un bloqueante nuevo y determinista (B-05) y confirma que M-05 no cubre las rutas de escritura manual ni el TOCTOU de la purga. M-08 tampoco cierra el aislamiento estático.

**Veredicto: RECHAZADO ❌.** No se aceptan U1/U2. No se autoriza U3/U4, commit ni push.
