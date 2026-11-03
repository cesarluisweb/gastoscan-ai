# RM-03 — Tercera Reauditoría Adversarial de E0-02 (DeepSeek)

> **Tipo de documento:** Informe íntegro de la tercera reauditoría adversarial independiente sobre el parche de B2, B3, B5, O5, O2 y B4.  
> **Unidad evaluada:** `E0-02` — Dominio monetario, tupla y purga de caché A-07.  
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md`.  
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (A-01 a A-16).  
> **Fecha:** Noviembre de 2026.  
> **Veredicto general:** **RECHAZADO ❌**  
> **Estado de Git:** `HEAD == origin/main == de17323`; cero commits, cero push.  
> **Nota de procedencia:** Este documento consolida de forma fiel los hallazgos, evidencias, severidades y condiciones de aceptación presentados en la tercera reauditoría. No sustituye ni altera informes históricos.

---

## 1. Veredicto y Resumen Ejecutivo

La tercera reauditoría adversarial independiente evaluó el parche implementado en el working tree local para corregir **B2**, **B3**, **B5**, **O5**, **O2** y la cobertura **B4** de la unidad **E0-02**.

**Veredicto: RECHAZADO.**

El parche **no introduce regresiones** sobre los bloqueantes ya cerrados **B1** y **N1**, y corrige efectivamente:

- **B3** en cuanto al **dominio numérico** de `ExchangeRatesData.fromJson`.
- **B5** en cuanto al tratamiento de `tasas_historico_v1` con tipo corrupto.
- **O5** en cuanto a la incorporación de `tasa_cambio_ves_usd` a la purga selectiva A-07.

Sin embargo, la unidad **no puede aceptarse ni cerrarse** porque persisten defectos bloqueantes y nuevos hallazgos que afectan directamente la integridad monetaria:

1. **B2 permanece PARCIAL:** la protección de `SettingsProvider` y `GastoProvider` es incompleta. El modo *fail-closed* sustituye la caché no verificada por **`defaultTasaCambio = 850.0`** y lo presenta como tasa efectiva (**NEW-4**), no resetea `_tasasSonReferencia` (**NEW-2**) y `GastoProvider` conserva el estado anterior en lugar de limpiarlo (**NEW-5**).
2. **NEW-1 es BLOQUEANTE:** la marca persistente de purga puede fijarse **prematuramente** cuando la memoria del proceso ya contiene el mapa depurado pero el disco conserva el mapa corrupto. La prueba de reintento oculta el defecto mediante `reloadFromDisk()`.
3. **B4 permanece PARCIAL/BLOQUEANTE:** las pruebas de `GastoProvider` son **vacuamente verdes** (no observan el estado interno de tasas), el escenario remoto “no finito” solo envía `null` y las pruebas de `fromJson` nunca ejercitan tipos incorrectos.
4. **B3-OBS:** `ExchangeRatesData.fromJson` sigue lanzando `TypeError` ante tipos no numéricos (`String`, `bool`) porque usa *casts* `as num?` en lugar de validación de tipo.
5. **O2 permanece PARCIAL:** el fake de `SharedPreferences` devuelve `null` donde la implementación real lanza `TypeError`, y no modela la mutación en memoria ante fallo de `remove`.

**Consecuencia:** `E0-02` continúa **RECHAZADO**. `E0-03` permanece **NO AUTORIZADA**. No se autoriza commit, push ni validación en CI de este parche como si estuviera aprobado.

---

## 2. Alcance, Método y Limitación de Entorno

### 2.1 Archivos inspeccionados

Producción:

- `lib/services/exchange_rate_service.dart`
- `lib/providers/settings_provider.dart`
- `lib/providers/gasto_provider.dart`
- `lib/core/constants/app_constants.dart`
- `lib/ui/screens/review_expense_screen.dart` (consumidores)
- `lib/ui/screens/currency_calculator_screen.dart` (consumidores)
- `lib/ui/screens/analysis_screen.dart` (consumidores)

Pruebas:

- `test/services/exchange_rate_service_cache_purge_test.dart`
- `test/providers/settings_provider_rate_cache_test.dart`
- `test/providers/gasto_provider_rate_cache_test.dart`

Documentación:

- `docs/rm-03/README.md`
- `docs/rm-03/contrato-v1.2.md`
- `docs/rm-03/decisiones.md`
- `docs/rm-03/estado-actual.md`
- `docs/rm-03/auditorias/primera-auditoria-adversarial-deepseek.md`
- `docs/rm-03/auditorias/reauditoria-postparche-deepseek.md`
- `docs/rm-03/auditorias/segunda-reauditoria-b1-n1-deepseek.md`
- `docs/rm-03/auditorias/implementacion-b2-b3-b5.md`

### 2.2 Método

Auditoría adversarial por **inspección estática** del código, contraste con el contrato v1.2 y las decisiones A-01 a A-16, y análisis del diseño de las pruebas. Se verificó:

- Integridad Git: `HEAD == origin/main == de17323`.
- Siete archivos modificados en el working tree.
- Archivos sin seguimiento en `docs/rm-03/`, `lib/domain/monetary/`, `test/domain/monetary/` y tres suites nuevas.
- SQLite `version: 18` sin cambios.
- `firestore.rules` y `pubspec.yaml` sin diferencias.

### 2.3 Limitación por ausencia de SDK

Se verificó que el SDK local de Flutter/Dart **no está instalado** (`flutter: NO`, `dart: NO`).

Por lo tanto:

- **CERO pruebas Dart ejecutadas.**
- **CERO ejecuciones de `flutter analyze --fatal-warnings`.**
- **CERO ejecuciones de `flutter test`.**
- Todas las suites de este informe fueron **inspeccionadas**, nunca **ejecutadas**.
- El veredicto se fundamenta exclusivamente en inspección estática y en el diseño lógico de las pruebas.

Esta limitación es material: varias pruebas descritas como “cubiertas” por el implementador no demuestran el comportamiento que afirman, y solo su ejecución en CI —junto con aserciones correctas— podría confirmarlo.

---

## 3. Matriz Consolidada de Hallazgos

### 3.1 Bloqueantes previos (B1 a B5)

| ID | Componente / Archivo | Estado | Severidad | Descripción Técnica y Consecuencia |
| :--- | :--- | :--- | :--- | :--- |
| **B1** | `ExchangeRateService.purgarCacheHistoricaInvalida` | **CORREGIDO ✅** | Bloqueante | La decodificación JSON está aislada de la persistencia. Si `setString` falla o lanza, se conserva el historial original y no se fija la marca. Sin regresión observada. |
| **N1** | `ExchangeRateService.getRateForDate` | **CORREGIDO ✅** | Bloqueante | Se exige `isFinite && rate > 1.0` en caché, respuesta remota y fallback histórico, con comportamiento *fail-closed* ante `ensureCacheHistoricaPurgada == -1`. Sin regresión observada. |
| **B2** | `SettingsProvider` y `GastoProvider` | **PARCIAL ⚠️ / BLOQUEANTE** | Bloqueante | La purga previa y la validación numérica fueron incorporadas, pero el *fail-closed* introduce **850.0 como tasa efectiva** (NEW-4), no resetea `_tasasSonReferencia` (NEW-2) y `GastoProvider` conserva tasas previas no verificadas (NEW-5). |
| **B3** | `ExchangeRatesData.fromJson` | **CORREGIDO ✅ (dominio numérico)** | Bloqueante | `raw is num && raw.isFinite && raw > 1.0` por moneda, con `0.0` ante valores fuera de dominio. Persiste **B3-OBS** por tipos incorrectos. |
| **B4** | Suites de pruebas | **PARCIAL ⚠️ / BLOQUEANTE** | Bloqueante | Pruebas de `GastoProvider` vacuamente verdes; escenario remoto no finito solo cubre `null`; `fromJson` no prueba tipos incorrectos; el reintento se “recupera” con `reloadFromDisk()` y enmascara NEW-1. |
| **B5** | `ExchangeRateService.purgarCacheHistoricaInvalida` | **CORREGIDO ✅** | Bloqueante | `tasas_historico_v1` con tipo no `String` se marca para eliminación; si `remove` falla, no se fija la marca y se permite reintento. |

### 3.2 Observaciones solicitadas (O2 y O5)

| ID | Área / Archivo | Estado | Descripción y Riesgo |
| :--- | :--- | :--- | :--- |
| **O2** | `TestSharedPreferences` | **PARCIAL ⚠️** | Modelo `memory`/`disk` y `reloadFromDisk()` implementados, pero `getString/getDouble/getBool` devuelven `null` donde el plugin real lanza `TypeError`; `remove` retorna `false` antes de mutar memoria; no hay inyección de fallo en `setDouble`. |
| **O5** | `ExchangeRateService.purgarCacheHistoricaInvalida` | **CORREGIDO ✅** | `tasa_cambio_ves_usd` se incorporó a la purga: conserva válidos (`isFinite && > 1.0`), elimina inválidos y permite reintento si `remove` falla. Persiste el desacople lectura/escritura de la tasa manual (NEW-3b). |

### 3.3 Nuevos hallazgos (NEW-1 a NEW-6 y B3-OBS)

| ID | Componente / Archivo | Estado | Severidad | Descripción Técnica y Consecuencia |
| :--- | :--- | :--- | :--- | :--- |
| **NEW-1** | `ensureCacheHistoricaPurgada` / `purgarCacheHistoricaInvalida` | **ABIERTO ❌** | **BLOQUEANTE** | Marca de purga prematura por divergencia memoria/disco: tras un fallo de `setString`, la memoria ya contiene el mapa depurado; el segundo intento en el mismo proceso no reescribe, fija la marca y el disco conserva el mapa corrupto. |
| **NEW-2** | `SettingsProvider._tasasSonReferencia` | **ABIERTO ❌** | **BLOQUEANTE** | La rama *fail-closed* no resetea `_tasasSonReferencia` a `true`. Si el estado previo era `false`, la UI presenta las tasas 850 de último recurso como si fueran tasas vivas. |
| **NEW-3** | Umbrales de dominio | **ABIERTO ❌** | Media / Bloqueante | Divergencia entre `> 50.0` (`SettingsProvider`, `getAllTodayRates`, `actualizarTasaAutomatica`) y `> 1.0` (`GastoProvider`, `getRateForDate`, `fromJson`). Una tasa de 45.0 es válida en una ruta y descartada en otra. |
| **NEW-3b** | `setTasaCambio` vs lectura de tasa manual | **ABIERTO ❌** | **BLOQUEANTE** | `setTasaCambio` escribe solo `AppConstants.prefTasaCambio`, pero `loadSettings` prioriza `cached_rate_usd` y `actualizarTasaAutomatica` sobrescribe la clave con la tasa viva. La tasa manual puede quedar ignorada o destruida silenciosamente. |
| **NEW-4** | `AppConstants.defaultTasaCambio` | **ABIERTO ❌** | **BLOQUEANTE** | `850.0` se asigna como tasa efectiva en `SettingsProvider:114,116` y como valor inicial de `_tasaUsd` en `GastoProvider:39`, y fluye a consumidores. Contradice “sin tasa no hay equivalencia” y el propio comentario de la constante. |
| **NEW-5** | `GastoProvider.cargarDatos` | **ABIERTO ❌** | **BLOQUEANTE** | Ante `-1`, solo registra un `debugPrint` y **no limpia** `_tasaUsd`/`_tasaEur`; conserva tasas de una carga anterior potencialmente no verificada. |
| **NEW-6** | `cached_exchange_rates_timestamp` | **ABIERTO ❌** | Media / Bloqueante | Lectura con `prefs.getString` sin comprobación de tipo en `SettingsProvider:107` y `getAllTodayRates:169`. Con un valor no `String`, el plugin real lanza `TypeError` y aborta la carga. |
| **B3-OBS** | `ExchangeRatesData.fromJson` | **ABIERTO ❌** | Observación / Bloqueante | Los *casts* `(json['usd'] as num?)`, `(json['eur'] as num?)`, `(json['usdt'] as num?)` y `(json['esReferencia'] as bool?)` lanzan `TypeError` ante tipos incorrectos. Solo se valida el dominio una vez que el valor ya es `num`. |

---

## 4. B2 — Protección en Proveedores: PARCIAL

### 4.1 Lo que sí quedó implementado

En `SettingsProvider.loadSettings` (`:68-118`):

- Se invoca `ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: prefs)` antes de consumir semillas (`:74-81`).
- Si el resultado es `-1`, se omite la lectura de semillas locales (`:111-118`).
- Las semillas se validan con `raw is num && raw.isFinite && raw > 50.0` (`:86-105`).
- `actualizarTasaAutomatica` rechaza `Infinity` en las tres monedas (`:224-236`).
- `setTasaCambio` rechaza `!isFinite || <= 1.0` (`:293-302`).

En `GastoProvider.cargarDatos` (`:131-154`):

- Se invoca `ensureCacheHistoricaPurgada` antes de leer tasas locales (`:139`).
- Se valida `raw is num && raw.isFinite && raw > 1.0` (`:141-148`).
- `setTasasReferencia` exige `isFinite && > 1.0` (`:68-71`).
- La carga de gastos y presupuestos queda desacoplada de la disponibilidad de tasas.

### 4.2 Por qué sigue siendo PARCIAL

1. **NEW-4 — 850.0 como tasa efectiva:** la rama *fail-closed* de `SettingsProvider` asigna `_tasaCambioVesUsd = AppConstants.defaultTasaCambio` (`:114`) y `_tasaCambioVesUsdt = AppConstants.defaultTasaCambio` (`:116`). El comentario de `AppConstants.defaultTasaCambio` (`app_constants.dart:167-169`) prohíbe presentarlo como tasa vigente, pero el proveedor lo entrega como valor activo.
2. **NEW-2 — `_tasasSonReferencia`:** la rama *fail-closed* no lo actualiza. Si antes el proveedor había fijado `false` en una actualización viva (`:238`), la UI sigue creyendo que las tasas son reales.
3. **NEW-5 — estado anterior en `GastoProvider`:** ante `-1`, el bloque `:149-151` solo registra un mensaje; no restablece `_tasaUsd` ni `_tasaEur`. Una instancia que ya había cargado 88.0 conserva 88.0 aunque la purga falle.
4. **NEW-3 — umbrales divergentes:** `SettingsProvider` usa `> 50.0`; `GastoProvider` usa `> 1.0`. El contrato §2.3 fija `> 1.0`. La misma tasa puede aceptarse en un proveedor y rechazarse en otro.
5. **NEW-3b — tasa manual:** `setTasaCambio` escribe `prefTasaCambio`, pero `loadSettings` prefiere `cached_rate_usd` (`:86`). Una tasa manual guardada puede ser ignorada al reiniciar porque `cached_rate_usd` sigue teniendo el valor automático anterior. Además, `actualizarTasaAutomatica` reescribe `prefTasaCambio` con la tasa viva (`:226`, `:245`) sin distinguir si el usuario había fijado una tasa manual.
6. **Cobertura de monedas:** `GastoProvider` solo lee `cached_rate_usd` y `cached_rate_eur`; no lee `cached_rate_usdt`. `setTasasReferencia` no tiene llamadores en `lib/`, por lo que `_tasaEur` permanece en `0.0` en la práctica y la rama EUR de `getSpentForCategory` (`:619-629`) opera con factores derivados de estado incompleto.

**Conclusión B2:** PARCIAL. La purga previa y el rechazo de no finitos están implementados, pero el *fail-closed* no es íntegro y sustituye lo desconocido por 850.0.

---

## 5. B3 — Dominio Numérico Corregido y B3-OBS Abierto

### 5.1 Corrección efectiva del dominio numérico

`ExchangeRatesData.fromJson` (`exchange_rate_service.dart:33-44`) ahora aplica, de forma independiente por moneda:

```dart
usd: (rawUsd != null && rawUsd.isFinite && rawUsd > 1.0) ? rawUsd : 0.0,
eur: (rawEur != null && rawEur.isFinite && rawEur > 1.0) ? rawEur : 0.0,
usdt: (rawUsdt != null && rawUsdt.isFinite && rawUsdt > 1.0) ? rawUsdt : 0.0,
```

Esto corrige el defecto original (`raw > 0`) y cumple el dominio del contrato §2.3 (`> 1.0` y finito) para valores numéricos. Se verificó que no hay cruce de monedas ni equivalencias silenciosas.

### 5.2 B3-OBS — tipos incorrectos no son *fail-closed*

Los *casts* previos siguen presentes:

```dart
final rawUsd = (json['usd'] as num?)?.toDouble();
final rawEur = (json['eur'] as num?)?.toDouble();
final rawUsdt = (json['usdt'] as num?)?.toDouble();
...
esReferencia: json['esReferencia'] as bool? ?? true,
```

Si el gateway o una carga externa entrega `"usd": "850"` (String), `"usd": true` (bool) o `"esReferencia": "false"` (String), el *cast* lanza `TypeError` en lugar de degradar a `0.0`/`true`. El *fail-closed* solo cubre valores que ya son `num`.

**Evidencia de la brecha de pruebas:** las pruebas `:616-669` solo pasan `double.nan`, `double.infinity`, `double.negativeInfinity`, `0.5`, `1.0`, `-5.0` y valores válidos. Ninguna pasa `String`, `bool`, `null` con tipo incorrecto ni un `Map` anidado.

### 5.3 Alcance real de la corrección

- `ExchangeRatesData.fromJson` **no tiene consumidores en producción** dentro de `lib/`.
- `setTasasReferencia` **tampoco tiene llamadores** en `lib/`.

Por tanto, la corrección de B3 es correcta en el módulo, pero **no demuestra contención global** ni protege todavía a los consumidores reales. Esto coincide con la regla del README: no declarar garantías globales basadas en módulos aislados.

**Conclusión B3:** CORREGIDO en dominio numérico; **B3-OBS ABIERTO** por tipos incorrectos.

---

## 6. B4 — Cobertura de Pruebas: PARCIAL Y BLOQUEANTE

### 6.1 Inventario inspeccionado

| Suite | Pruebas declaradas | Observación |
| :--- | :---: | :--- |
| `test/services/exchange_rate_service_cache_purge_test.dart` | 28 | Cobertura amplia de purga, B1, B5, O5 y `fromJson` numérico. |
| `test/providers/settings_provider_rate_cache_test.dart` | 6 | Escenarios 11, 12, 12b, `setTasaCambio` y `actualizarTasaAutomatica`. |
| `test/providers/gasto_provider_rate_cache_test.dart` | 4 | Escenarios 13, 14, `setTasasReferencia` y purga exitosa. |

Ninguna prueba fue ejecutada. El SDK no está instalado.

### 6.2 Pruebas vacuamente verdes en `GastoProvider`

**Escenario 13 (`gasto_provider_rate_cache_test.dart:58-76`):**

- Monta un store con purga fallida y tasas locales `88.0`/`95.0`.
- Solo afirma `fakeRepo.obtenerGastosCalled == true` y `provider.errorMessage == null`.
- **No observa `_tasaUsd` ni `_tasaEur`.** La prueba pasaría exactamente igual si el proveedor hubiera consumido `88.0` y `95.0`, que es el defecto que dice detectar.

**Escenario 14 (`:78-92`):**

- Store con `double.infinity` en `cached_rate_usd`, `cached_rate_eur` y `prefTasaCambio`.
- La aserción es `provider.getSpentForCategory('Alimentos', moneda: 'EUR').isFinite`.
- El repositorio falso devuelve mapas de categorías **vacíos** (`:26`), por lo que `getSpentForCategory` retorna `0.0` por el `return 0.0` final (`gasto_provider.dart:642`) **sin ejecutar la rama EUR** (`:619-629`). La prueba sería verde incluso con `Infinity` consumido.

**Prueba de `setTasasReferencia` (`:94-111`):**

- Invoca valores inválidos y luego uno válido.
- La única aserción es `spent.isFinite`, con mapas vacíos. No verifica que `_tasaUsd`/`_tasaEur` hayan rechazado los valores; no hay getters públicos para observarlos.

**Consecuencia:** los escenarios 13 y 14 del informe de implementación **no están realmente cubiertos**. La matriz B4 del implementador declara “Cubierto ✅” sin evidencia observable.

### 6.3 Escenario remoto “no finito” incompleto

La prueba `:806-821` se titula “descarta respuestas remotas con valores nulos o no finitos”, pero el cuerpo solo envía:

```dart
http.Response('[{"fecha":"2026-10-01","promedio":null}]', 200)
```

- `null` no es un valor no finito; es ausencia de dato.
- `NaN` no es representable en JSON.
- `Infinity` sí es reproducible con `1e400` en el *payload* (según el comportamiento del *parser*), y **no se probó**.
- Tampoco se probó una respuesta remota con `promedio` de tipo `String`.

La prueba `:518-542` sí cubre `0.5`, pero no `Infinity` ni `1e400`.

### 6.4 `fromJson` sin tipos incorrectos

Como se detalló en §5.2, las pruebas `:616-669` cubren el dominio numérico, pero **no** tipos incorrectos. B3-OBS queda sin cobertura.

### 6.5 El reintento enmascara NEW-1

La prueba `:431-460`:

1. Ejecuta la purga con `throwOnSetString = true`.
2. Verifica que la marca no se fijó y que el disco conserva el JSON original.
3. Llama `store.reloadFromDisk()`.
4. Reintenta y espera éxito.

El `reloadFromDisk()` descarta la memoria mutada y restaura el estado corrupto desde disco. En producción **no existe ese reinicio entre dos llamadas del mismo proceso**. Sin `reloadFromDisk()`, el segundo intento lee la memoria ya depurada, no reescribe, y fija la marca aunque el disco siga corrupto (NEW-1). La prueba, por tanto, no reproduce el escenario real que dice cubrir.

El mismo patrón aparece en `:714-734` (B5) y `:782-800` (O5).

### 6.6 Cobertura de la matriz de 18 escenarios

| Nº | Escenario Declarado | Estado Real por Inspección |
| :---: | :--- | :--- |
| 1 | `setString` falla y se recupera | **Parcial:** cubierto solo con `reloadFromDisk()`, que oculta NEW-1. |
| 2 | Respuesta remota `NaN` | **No cubierto:** solo se envía `null`. |
| 3 | Respuesta remota `Infinity` | **No cubierto:** no se envía `1e400` ni equivalente. |
| 4 | `getAllTodayRates` con semillas no finitas | Cubierto (`:593-615`), pero el fake no reproduce `TypeError`. |
| 5 | `fromJson` con `0.5` | Cubierto. |
| 6 | `fromJson` con `1.0` | Cubierto. |
| 7 | `fromJson` con `-5.0` | Cubierto. |
| 8 | `cached_exchange_rate` inválida | Cubierto. |
| 9 | `tasa_cambio_ves_usd` válida se conserva | Cubierto. |
| 10 | `tasa_cambio_ves_usd` inválida se elimina | Cubierto. |
| 11 | Purga fallida en `SettingsProvider` | Cubierto con aserciones observables (`tasaCambioVesUsd`). |
| 12 | Purga exitosa en `SettingsProvider` | Cubierto. |
| 13 | Purga fallida en `GastoProvider` | **Vacuo:** no observa tasas internas. |
| 14 | `GastoProvider` con `Infinity` | **Vacuo:** mapas vacíos, no ejecuta la rama EUR. |
| 15 | Historial con tipo incorrecto | Cubierto (`:687-712`) con `reloadFromDisk()` en el reintento. |
| 16 | Fallo de `remove` no fija marca | Cubierto (`:289-308`). |
| 17 | Reintento tras fallo transitorio | **Parcial:** depende de `reloadFromDisk()`. |
| 18 | *Fail-closed* de semillas actuales | Cubierto para `ExchangeRateService`; no para la integridad de `GastoProvider`. |

**Conclusión B4:** PARCIAL y BLOQUEANTE. Hay cobertura escrita, pero no cobertura **demostrativa** en los puntos que motivaron el parche.

---

## 7. B5 — Bloqueo por Tipo Corrupto: CORREGIDO

En `purgarCacheHistoricaInvalida` (`:551-560`):

- `tasas_historico_v1` se lee con `prefs.get`, que no lanza por tipo.
- Si `rawVal is! String`, se registra el tipo, se añade la clave a `keysToRemove` y se incrementa `cleanedCount`.
- Ya no se lanza `StateError` incondicional por tipo corrupto.

El borrado se ejecuta en el bucle `:710-721`:

- Si `prefs.remove` retorna `false`, `allWritesSucceeded = false` y se lanza `StateError` (`:723-725`), por lo que la marca no se fija y se permite reintento.
- Si `remove` tiene éxito, la clave corrupta desaparece y la purga puede completarse.

Las pruebas `:687-712` y `:714-734` cubren el caso `int` corrupto y el fallo transitorio de `remove`, aunque la segunda usa `reloadFromDisk()` (ver §6.5).

**Conclusión B5:** CORREGIDO. El defecto de bloqueo permanente quedó resuelto.

---

## 8. O2 — Fake de `SharedPreferences`: PARCIAL

### 8.1 Lo que sí mejoró

`TestSharedPreferences` (`exchange_rate_service_cache_purge_test.dart:14-118`) implementa:

- `memory` y `disk` como mapas separados.
- `setString` muta `memory` antes de la llamada de plataforma y luego lanza o retorna `false` (`:69-81`).
- `setBool` con inyección de excepción y retorno `false` (`:92-103`).
- `reloadFromDisk()` para simular reinicio (`:39-42`).
- `removedKeys`, `setStringValues`, `setBoolValues`, `setDoubleValues` para inspección.

Este modelo es suficiente para B1 y mejora sustancialmente el fake anterior.

### 8.2 Desviaciones respecto al plugin real

1. **`getString/getDouble/getBool` devuelven `null` ante tipo incorrecto** (`:51-66`). El plugin real hace un *cast* (`_preferenceCache[key] as String?`) y lanza `TypeError`. Esta desviación **oculta NEW-6** y cualquier defecto equivalente en los proveedores: una prueba con un `int` en `cached_exchange_rates_timestamp` pasaría con el fake y fallaría en producción.
2. **`remove` retorna `false` antes de mutar `memory`** (`:106-117`). En el plugin real, la caché en memoria se actualiza antes de la persistencia; si la plataforma falla, la memoria puede quedar mutada y el disco no. El fake no modela esa divergencia para `remove`, precisamente la clase de discrepancia que NEW-1 expone para `setString`.
3. **`setDouble` siempre tiene éxito** (`:84-89`): no hay `throwOnSetDouble` ni `returnFalseOnSetDouble`. `getRateForDate` persiste con `setDouble` (`:385`, `:408`, `:428`, `:448`); no se puede probar un fallo de caché en esa ruta.
4. **La escritura en `disk` es síncrona e inmediata**: no hay ventana de persistencia diferida ni orden de operaciones configurable.
5. **`getKeys()` devuelve solo `memory.keys`** (`:45`): tras un fallo de escritura, el fake puede mostrar un universo de claves distinto al real.

**Conclusión O2:** PARCIAL. El fake es útil, pero no es fiel en los puntos que ocultan los defectos abiertos.

---

## 9. O5 — Semilla `tasa_cambio_ves_usd`: CORREGIDO

La rama `key == 'cached_exchange_rate' || key == AppConstants.prefTasaCambio` (`:663-675`):

- Conserva valores `num` finitos y `> 1.0`.
- Elimina `<= 1.0`, no finitos y tipos no numéricos.
- Si `remove` falla, no se fija la marca y se reintenta.

Las pruebas `:740-748`, `:750-780` y `:782-800` cubren conservación, eliminación y reintento. El caso de reintento usa `reloadFromDisk()` (ver §6.5), pero el comportamiento de O5 en sí queda cubierto.

**Conclusión O5:** CORREGIDO, con la salvedad de NEW-3b (desacople entre escritura y lectura de la tasa manual).

---

## 10. NEW-1 — Marca Prematura por Divergencia Memoria/Disco (BLOQUEANTE)

### 10.1 Secuencia del defecto

1. `ensureCacheHistoricaPurgada` invoca `purgarCacheHistoricaInvalida`.
2. La purga detecta entradas inválidas y llama `prefs.setString('tasas_historico_v1', jsonEncode(cleanedMap))` (`:652`).
3. En la implementación real, `setString` actualiza primero la caché en memoria y luego persiste en plataforma. Si la persistencia lanza una excepción (o retorna `false`), la **memoria ya contiene el mapa depurado** y el **disco conserva el mapa corrupto**.
4. `allWritesSucceeded = false` → `purgarCacheHistoricaInvalida` lanza `StateError` → `ensureCacheHistoricaPurgada` retorna `-1` y **no fija la marca**. Correcto hasta aquí.
5. **Segundo intento en el mismo proceso:** `purgarCacheHistoricaInvalida` recorre `prefs.getKeys()` y lee `tasas_historico_v1` desde **memoria** (ya depurado). No hay `mapMutated`, no hay `setString`, no hay fallo. Retorna un conteo válido.
6. `ensureCacheHistoricaPurgada` ejecuta `prefs.setBool(prefKeyCacheHistoricaPurgada, true)` y **fija la marca**.
7. El disco sigue conteniendo el mapa corrupto original, pero la marca en disco dice “purgado”.
8. Tras reiniciar la app, `ensureCacheHistoricaPurgada` lee la marca `true` y retorna `0` sin purgar. **Las entradas corruptas quedan permanentemente en disco.**

### 10.2 Por qué es bloqueante

- Rompe la semántica de la marca persistente: “purgado” deja de significar “el disco está limpio”.
- A-07 exige que las entradas inválidas se purguen; NEW-1 las preserva indefinidamente.
- Los consumidores confían en `purgeResult != -1` para leer caché; en el siguiente arranque la purga “exitosa” habilita la lectura de datos corruptos.
- La prueba `:431-460` no lo detecta porque llama `reloadFromDisk()` entre intentos.

### 10.3 Condición de corrección

La marca solo debe fijarse cuando exista evidencia de que **el disco** quedó en el estado depurado. Opciones válidas:

- Verificar el valor persistido releyéndolo desde una instancia que no dependa de la caché mutada.
- Escribir la marca solo si la operación de escritura del historial confirmó persistencia y no hubo mutaciones en memoria no confirmadas.
- Separar explícitamente el estado “memoria sucia” del estado “disco confirmado” y no confiar en `getKeys()`/`get()` de la misma instancia tras un fallo.
- Añadir una prueba de reintento **sin** `reloadFromDisk()` que reproduzca el mismo proceso y exija que la marca no se fije mientras el disco esté corrupto.

---

## 11. NEW-2 — `_tasasSonReferencia` no se Resetea (BLOQUEANTE)

Declaración y usos en `settings_provider.dart`:

- `bool _tasasSonReferencia = true;` (`:24`).
- `_tasasSonReferencia = false;` en modo vivo (`:238`).
- `_tasasSonReferencia = true;` en modo referencia (`:253`).
- La rama *fail-closed* (`:111-118`) **no lo modifica**.

Escenario de fallo:

1. Una actualización viva exitosa fija `_tasasSonReferencia = false`.
2. En una recarga posterior, la purga falla (`-1`).
3. El proveedor asigna `850.0` a USD y USDT, pero `_tasasSonReferencia` sigue en `false`.
4. La UI y los consumidores interpretan 850.0 como tasa vigente, no como referencia.

Esto agrava NEW-4: no solo se usa 850.0, sino que se oculta su carácter de último recurso.

**Conclusión NEW-2:** ABIERTO y BLOQUEANTE. La rama *fail-closed* debe fijar `_tasasSonReferencia = true` (o el estado explícito de “sin tasa verificada”).

---

## 12. NEW-3 — Umbrales Divergentes (MEDIA / BLOQUEANTE)

| Ruta | Umbral | Evidencia |
| :--- | :---: | :--- |
| `SettingsProvider.loadSettings` | `> 50.0` | `settings_provider.dart:87,94,101` |
| `SettingsProvider.actualizarTasaAutomatica` | `> 50.0` | `:224,229,233,243,247,250` |
| `ExchangeRateService.getAllTodayRates` | `> 50.0` | `exchange_rate_service.dart:75,79,83,150,160-162,172-174` |
| `ExchangeRateService.getRateForDate` | `> 1.0` | `:324-326,339,384,398,407,427,447` |
| `ExchangeRatesData.fromJson` | `> 1.0` | `:38-40` |
| `GastoProvider.cargarDatos` | `> 1.0` | `gasto_provider.dart:142,146` |
| `GastoProvider.setTasasReferencia` | `> 1.0` | `:69-70` |

El contrato §2.3 fija el dominio `isFinite && rate > 1.0`. El umbral `> 50.0` es una defensa anti-obsoleta razonable para tasas VES/USD, pero:

- No está armonizado con el dominio normativo.
- Una tasa de 45.0 es aceptada por `GastoProvider`, `getRateForDate` y `fromJson`, y descartada por `SettingsProvider` y `getAllTodayRates`.
- El comportamiento depende del punto de entrada, no de una única función de validación.

**Conclusión NEW-3:** ABIERTO. Unificar en un validador único y documentar explícitamente si el umbral operativo es `> 1.0` (contrato) o `> 50.0` (defensa anti-obsoleta), sin rutas contradictorias.

---

## 13. NEW-3b — Inconsistencia entre Escritura y Lectura de la Tasa Manual (BLOQUEANTE)

### 13.1 Escritura

`setTasaCambio(double tasa)` (`settings_provider.dart:293-302`):

```dart
_tasaCambioVesUsd = tasa;
final prefs = await SharedPreferences.getInstance();
await prefs.setDouble(AppConstants.prefTasaCambio, _tasaCambioVesUsd);
```

Solo escribe `tasa_cambio_ves_usd`.

### 13.2 Lectura

`loadSettings` (`:86`):

```dart
final rawUsd = prefs.get('cached_rate_usd') ?? prefs.get(AppConstants.prefTasaCambio);
```

Prioriza `cached_rate_usd` sobre la tasa manual.

`GastoProvider.cargarDatos` (`:141`) hace lo mismo:

```dart
final rawUsd = prefs.get('cached_rate_usd') ?? prefs.get(AppConstants.prefTasaCambio);
```

### 13.3 Consecuencias

1. Si `cached_rate_usd` contiene una tasa automática anterior, la tasa manual guardada queda **ignorada** al reiniciar.
2. `actualizarTasaAutomatica` sobrescribe `prefTasaCambio` con la tasa viva (`:226`, `:245`) sin distinguir una tasa fijada manualmente, por lo que la decisión del usuario puede **destruirse silenciosamente**.
3. `SettingsProvider` y `GastoProvider` son `ChangeNotifier` independientes: cambiar la tasa en `SettingsProvider` no actualiza `_tasaUsd` en `GastoProvider` hasta que este recargue.
4. La UI puede mostrar una tasa distinta de la usada en los cálculos, según qué proveedor consulte cada pantalla.

**Conclusión NEW-3b:** ABIERTO y BLOQUEANTE. Es un defecto de integridad financiera: la tasa que el usuario cree haber fijado no es necesariamente la que se aplica.

---

## 14. NEW-4 — Uso de 850.0 como Tasa Efectiva (BLOQUEANTE)

### 14.1 Evidencia

`AppConstants.defaultTasaCambio` (`app_constants.dart:167-169`):

```dart
// Último recurso cuando no hay caché ni red. NUNCA presentarlo como tasa
// vigente: `SettingsProvider.tasasSonReferencia` lo señala en la UI.
static const double defaultTasaCambio = 850.0;
```

Pero:

- `SettingsProvider._tasaCambioVesUsd` se inicializa en 850.0 (`:18`).
- `SettingsProvider._tasaCambioVesUsdt` se inicializa en 850.0 (`:20`).
- La rama *fail-closed* asigna 850.0 a ambas (`:114`, `:116`).
- `GastoProvider._tasaUsd` se inicializa en 850.0 (`:39`).
- `getAllTodayRates` puede devolver 0.0, pero los consumidores vuelven a 850.0.

Consumidores que tratan el valor como tasa efectiva:

- `review_expense_screen.dart:560,569` — *fallback* explícito a `AppConstants.defaultTasaCambio` cuando la tasa es `<= 0`.
- `review_expense_screen.dart:1059,1094,1177` — usan `settings.tasaCambioVesUsd` como tasa de referencia del gasto.
- `currency_calculator_screen.dart:82,88,248` — *fallback* a `defaultTasaCambio`.
- `analysis_screen.dart:36` — usa `1.0` cuando no hay tasa (otra equivalencia silenciosa, preexistente y fuera de E0-02, asignada a E0-03/A-16).

### 14.2 Por qué es bloqueante

- 850.0 es un artefacto histórico asociado a la auto-reparación neutralizada por A-10; no es una tasa observada ni verificada.
- Usarlo como tasa efectiva fabrica equivalencias VES/USD, exactamente lo que RM-03 prohíbe.
- El comentario de la constante reconoce el riesgo, pero el código no lo respeta: no hay estado “sin tasa” que bloquee el cálculo; se sustituye por 850.0.
- NEW-2 agrava el problema al no marcar esas tasas como referencia.

**Conclusión NEW-4:** ABIERTO y BLOQUEANTE. La ausencia de tasa debe representarse como ausencia (nullable/0.0 con estado explícito), no como 850.0.

---

## 15. NEW-5 — Estado Anterior Conservado en `GastoProvider` (BLOQUEANTE)

En `cargarDatos` (`gasto_provider.dart:131-154`):

```dart
final purgeResult = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: prefs);
if (purgeResult != -1) {
  // leer y validar
} else {
  debugPrint('GastoProvider: Purga fallida (-1). Se omite caché local no verificada.');
}
```

La rama `else` **no limpia** `_tasaUsd` ni `_tasaEur`.

Escenario:

1. Primera carga con purga exitosa: `_tasaUsd = 88.0`, `_tasaEur = 95.0`.
2. Segunda carga (o recarga) con purga fallida: se omite la lectura, pero `_tasaUsd` y `_tasaEur` siguen en 88.0/95.0.
3. `getSpentForCategory` sigue usando esas tasas no verificadas para convertir EUR/VES/USD.

Además, cuando una lectura individual es inválida, el código no asigna y conserva el valor previo; en el contexto de una actualización viva eso puede ser deliberado, pero en *fail-closed* contradice el objetivo.

**Conclusión NEW-5:** ABIERTO y BLOQUEANTE. Ante `-1`, `_tasaUsd` y `_tasaEur` deben restablecerse a un estado explícito de “sin tasa” (0.0 o nullable), no conservar valores previos.

---

## 16. NEW-6 — Tipo de `cached_exchange_rates_timestamp` (MEDIA / BLOQUEANTE)

Lecturas sin comprobación de tipo:

- `settings_provider.dart:107`:

```dart
final timestampStr = prefs.getString('cached_exchange_rates_timestamp');
```

- `exchange_rate_service.dart:169`:

```dart
final prevTimestampStr = prefs.getString('cached_exchange_rates_timestamp');
```

En el plugin real, `getString` hace un *cast* a `String?`. Si la clave contiene un `int`, `double`, `bool` o una lista —por corrupción, migración o escritura defectuosa— se lanza `TypeError`.

Consecuencias:

- En `loadSettings`, la excepción no está envuelta en `try/catch` en ese punto; puede abortar la carga antes de `_isInitialized = true` y de `notifyListeners()`.
- En `getAllTodayRates`, la excepción ocurre después de la consulta de red y puede propagarse al llamador.
- El fake devuelve `null` (`:51-54`), por lo que las pruebas no detectan el problema.

**Conclusión NEW-6:** ABIERTO. Usar `prefs.get(key) is String` antes de `getString`, o encapsular con *logging* y degradar a `null`.

---

## 17. B3-OBS — Tipos Incorrectos en `ExchangeRatesData.fromJson`

Ya detallado en §5.2. Se registra formalmente como hallazgo independiente:

- Los *casts* `as num?` y `as bool?` son la única validación de tipo.
- Tipos incorrectos producen `TypeError`, no `0.0`/`true`.
- No hay pruebas con `String`, `bool`, `List` o `Map`.
- La corrección de B3 cubre dominio numérico, no robustez de tipos.

**Conclusión B3-OBS:** ABIERTO. `fromJson` debe validar `is num`/`is bool` explícitamente y degradar de forma *fail-closed*.

---

## 18. Observaciones Adicionales

1. **O1 — Aislamiento memoria vs disco:** sigue abierto y es la causa raíz de NEW-1. El fake modela la divergencia para `setString`, pero el código de producción no la resuelve.
2. **O3 — Fechas efectivas:** `getRateForDate` busca el último día hábil anterior (`:391-410`) y guarda esa tasa bajo la fecha solicitada (`cacheKey`), sin metadato que indique que no es una cotización exacta de ese día. El riesgo de atribución temporal persiste; no se corrigió en este parche.
3. **O4 — Parseo de calendario:** `_isValidCalendarDate` (`:476-488`) valida días reales y rechaza `2026-02-30`; correcto.
4. **O6 — Logging en capas críticas:** la mayoría de los `catch` nuevos registran con `debugPrint`, pero persisten bloques silenciosos como `settings_provider.dart:138` (`catch (_) {}` al decodificar mensajes quincenales). Revisar si alguno afecta capas críticas.
5. **O7 — `GastoModel.toFirestoreMap`:** el método obsoleto que emite campos nulos sigue presente; sin consumidores productivos, pero es una trampa latente.
6. **O8 — Alcance:** H-1, H-2 y S3.2 permanecen fuera de E0-02; ver §19.
7. **`pubspec.lock` ausente:** el informe del implementador afirma que `pubspec.lock` permanece “100% intacto”, pero el archivo **no existe ni está versionado**. `AGENTS.md` exige mantenerlo versionado para compilaciones idénticas. No se puede verificar reproducibilidad de dependencias. Corregir la afirmación documental y consultar a César antes de tocar `pubspec`/`pubspec.lock`.
8. **`ExchangeRatesData.fromJson` sin consumidores:** la corrección de B3 no protege ningún flujo productivo actual. Igual ocurre con `setTasasReferencia`, sin llamadores en `lib/`. La contención global no está demostrada.
9. **`analysis_screen.dart:36`:** usa `1.0` como *fallback* de tasa, una equivalencia silenciosa preexistente. No pertenece a E0-02, pero debe quedar registrada para E0-03/A-16.
10. **Cambios ajenos a E0-02 en el working tree:** `gasto_model.dart`, `gasto_firestore_mapper.dart` y `test/models/gasto_firestore_mapper_test.dart` están modificados por H-2. No se observó regresión en ellos ni se tocaron durante esta auditoría.
11. **Documentación sin seguimiento:** `docs/rm-03/` está sin trackear; los informes son locales hasta que César autorice commit.

---

## 19. Garantías Globales Postergadas (Fuera de Alcance de E0-02)

- **H-1 Global (USDT → USD en adquisición):** permanece abierta en `ExchangeRateService:92,126-129,405-412` y `SettingsProvider:86` (fallback `_tasaCambioVesUsdt = cachedUsdt ?? _tasaCambioVesUsd`). Asignada a **E0-03**.
- **H-2 Presentación (getters y agregaciones):** permanece abierta en `GastoModel:208-209`, `ChatScreen:385`, `DatabaseHelper:682,757` y `CurrencyFormatter:70-74`. Asignada a **E0-03**.
- **S3.2 (`copyWith` en `GastoModel`):** no permite limpiar `totalUsdt`/`tasaUsdt` a `null`. Asignada a **E0-04**.
- **E0-03:** **NO AUTORIZADA** hasta que E0-02 sea aceptada por auditoría adversarial independiente y validada en CI en verde (A-16).

---

## 20. Condiciones Concretas para la Aceptación de E0-02

Para revocar el veredicto **RECHAZADO**, deben cumplirse **todas** las condiciones siguientes:

1. **Resolver NEW-1 (bloqueante):** garantizar que la marca persistente solo se fije cuando el **disco** contenga el estado depurado. Añadir una prueba de reintento en el mismo proceso **sin** `reloadFromDisk()` que demuestre que la marca no se fija mientras el disco siga corrupto.
2. **Resolver NEW-4 (bloqueante):** eliminar el uso de `850.0` como tasa efectiva. Representar la ausencia de tasa con un estado explícito (`null`/`0.0` + `tasasSonReferencia = true`) y bloquear o marcar como pendiente cualquier cálculo que la requiera.
3. **Resolver NEW-2 (bloqueante):** fijar `_tasasSonReferencia = true` en la rama *fail-closed* y en cualquier ruta que use valores por defecto o no verificados.
4. **Resolver NEW-5 (bloqueante):** limpiar `_tasaUsd` y `_tasaEur` en `GastoProvider` cuando la purga retorne `-1`; no conservar tasas de una carga anterior.
5. **Resolver NEW-3b (bloqueante):** unificar la escritura y lectura de la tasa manual. `setTasaCambio` debe persistir de forma coherente con la precedencia de `loadSettings`, `actualizarTasaAutomatica` no debe sobrescribir una tasa manual sin intención explícita, y el cambio debe propagarse a `GastoProvider`.
6. **Resolver NEW-6:** sustituir las lecturas directas de `cached_exchange_rates_timestamp` por lecturas con comprobación de tipo (`prefs.get(key) is String`) o `try/catch` con *logging* y degradación segura.
7. **Resolver NEW-3:** unificar el umbral de dominio en un único validador. Si se mantiene `> 50.0` como defensa anti-obsoleta, debe aplicarse consistentemente y documentarse; si prevalece el contrato §2.3, usar `> 1.0` en todas las rutas.
8. **Resolver B3-OBS:** cambiar los *casts* de `fromJson` por validación `is num`/`is bool`, degradando a `0.0`/`true` ante tipos incorrectos. Añadir pruebas con `String`, `bool`, `List` y `Map`.
9. **Corregir O2:** hacer que el fake lance `TypeError` en `getString/getDouble/getBool` ante tipos incorrectos, mute `memory` antes de un fallo de `remove` y permita inyectar fallos en `setDouble`. Añadir una prueba de tipo corrupto en `cached_exchange_rates_timestamp`.
10. **Corregir B4:** reemplazar las pruebas vacuamente verdes de `GastoProvider` por aserciones observables (getters de tasa o mapas de categoría no vacíos). Incluir respuestas remotas con `1e400`/`Infinity`, tipos incorrectos en `fromJson` y reintentos sin `reloadFromDisk()`.
11. **Preservar B1, N1, B5 y O5:** no introducir regresiones en las correcciones ya aceptadas; mantener sus pruebas.
12. **Validación obligatoria en CI:** ejecutar `flutter analyze --fatal-warnings` y `flutter test` en GitHub Actions y obtener `conclusion: success`. Dado que en local se ejecutaron **cero** pruebas, la aceptación no puede basarse en inspección estática. Antes de tocar `pubspec`/`pubspec.lock`, consultar a César.

---

## 21. Conclusión

La tercera reauditoría confirma avances reales:

- **B1, N1, B5 y O5** están corregidos.
- **B3** está corregido en dominio numérico.
- **O2** mejoró sustancialmente.

Pero el parche **no cierra E0-02**:

- **B2** es parcial y su modo *fail-closed* introduce 850.0 como tasa efectiva.
- **B4** es parcial y contiene pruebas que no demuestran lo que afirman.
- **NEW-1** permite que la marca de purga declare limpio un disco corrupto.
- **NEW-2, NEW-3b, NEW-4 y NEW-5** afectan directamente la integridad monetaria y la trazabilidad de la tasa aplicada.
- **NEW-6** y **B3-OBS** dejan rutas de excepción no controladas.

**Veredicto final: RECHAZADO ❌.**

**E0-02** permanece abierto. **E0-03** no está autorizado. No se autoriza commit, push ni promoción a CI como si el parche estuviera aprobado.

---

## Anexo A — Evidencia de Integridad Git al Momento de la Auditoría

```text
HEAD:        de17323
origin/main: de17323

 M MEMORY.md
 M lib/data/models/gasto_firestore_mapper.dart
 M lib/data/models/gasto_model.dart
 M lib/providers/gasto_provider.dart
 M lib/providers/settings_provider.dart
 M lib/services/exchange_rate_service.dart
 M test/models/gasto_firestore_mapper_test.dart
?? docs/rm-03/
?? lib/domain/monetary/
?? test/domain/monetary/
?? test/providers/gasto_provider_rate_cache_test.dart
?? test/providers/settings_provider_rate_cache_test.dart
?? test/services/exchange_rate_service_cache_purge_test.dart
```

- **Commits:** 0.
- **Push:** 0.
- **SQLite:** `version: 18` sin cambios.
- **`firestore.rules`:** sin diferencias.
- **`pubspec.yaml`:** sin diferencias.
- **`pubspec.lock`:** no existe ni está versionado.
- **Pruebas ejecutadas:** 0.
- **`flutter analyze`:** no ejecutado.
- **SDK Flutter/Dart:** no instalado.
