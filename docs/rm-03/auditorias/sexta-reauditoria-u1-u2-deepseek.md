# RM-03 — Sexta Reauditoría Adversarial Independiente (U1/U2 — E0-02)

> **Documento:** Dictamen de la 6.ª reauditoría adversarial (DeepSeek).
> **Unidad:** `E0-02` — Dominio monetario, tupla y purga de caché A-07.
> **Fecha:** 4 de noviembre de 2026.
> **Contrato:** `docs/rm-03/contrato-v1.2.md` · **Decisiones:** `A-01`…`A-16`, `D-01`…`D-08`.
> **Veredicto: RECHAZADO ❌**
> **Estado de E0-02: NO CERRADO.** U1/U2 **NO ACEPTADAS**. U3/U4 **NO AUTORIZADAS**.
> **Validación:** inspección estática + `node scripts/check_syntax.js`. **0 `flutter test`, 0 `flutter analyze`, 0 CI** (no hay SDK local).

---

## 0. Método y límites

Este dictamen distingue tres niveles de evidencia:

1. **Defecto demostrado por construcción** (flujo, orden de operaciones, firmas). No depende de ejecutar.
2. **Comando ejecutado por el auditor:** únicamente `node scripts/check_syntax.js` (reproducible, ver §2) y conteo `Select-String` de declaraciones `test(`.
3. **No ejecutado:** `flutter test`, `flutter analyze`, GitHub Actions. Cuando afirmo que un test "falla", es inferencia determinista a partir del código, no una corrida.

No se modificó ningún archivo (modo Plan / auditoría de solo lectura).

---

## 1. Veredicto ejecutivo

**RECHAZADO ❌.**

El parche resuelve **B-05** de forma determinista y **M-08** en lo esencial. Sin embargo, **introduce un bloqueante nuevo y determinista**: la revalidación TOCTOU de M-05 se colocó en un punto donde se aplica a claves marcadas por **motivos estructurales** (fecha de calendario imposible, tipo no `String` del mapa histórico), y el predicado escalar `isValidMonetaryRate` las considera "válidas" y **omite su borrado**. Efecto doble:

- **Regresión de A-07/B5**: caché con fechas imposibles y `tasas_historico_v1` de tipo numérico **nunca se purgan**.
- **`flutter test` en rojo seguro**: al menos **5 pruebas** de `exchange_rate_service_cache_purge_test.dart` fallan por aserción (no por flakiness).
- Peor aún: `ensureCacheHistoricaPurgada` **fija la marca persistente** aunque la clave corrupta siga en disco, de modo que el early-return idempotente (`rawMark == true`) impide reintentar para siempre.

| Elemento | Resultado |
| :--- | :--- |
| B-05 | ✅ **Resuelto** (async/await + getters observables + aritmética 80.0 correcta) |
| M-05 | ❌ **Parcial, con regresión introducida** (§4) |
| M-08 | ✅ **Resuelto en lo esencial** (§5), con residuales |
| B-02 | ⚠️ **Parcial**: unificado solo en la ruta mapa-vacío; doble conteo persiste en rutas `String` corruptas (§6) |
| NEW-1 | ✅ Implementado |
| NEW-2 | ⚠️ Implementado, pero **contradice D-06.3** (§8) |
| NEW-3 / D-08 | ✅ Predicado canónico exacto |
| NEW-3b / D-05 | ⚠️ Solo en `SettingsProvider`; `GastoProvider` mantiene precedencia automática (§8) |
| NEW-4 / D-01 | ✅ Sin 850.0 activo |
| NEW-5 | ✅ Implementado y probado |
| NEW-6 / B3-OBS | ✅ Implementado y probado |
| Conteo de pruebas | ✅ **122 exactas** (verificado por archivo) |
| `scripts/check_syntax.js` | ✅ Reproducible y en verde |

---

## 2. Integridad del repositorio

| Verificación | Resultado |
| :--- | :--- |
| `HEAD` | `5fb357b` (`fix(monetary): eliminar fallback 850.0…`) |
| `origin/main` | `5fb357b` — sin commits nuevos ni push |
| Working tree | 9 archivos `M` + `scripts/check_syntax.js` (`??`) |
| `lib/core/constants/app_constants.dart` y `lib/providers/gasto_provider.dart` | **No están en el working tree**: ya fueron commitados en `5fb357b`. El informe §3 los presenta como modificaciones locales (imprecisión documental, no funcional). |
| `pubspec.yaml` / `firestore.rules` / SQLite v18 | Sin cambios (correcto) |
| `node scripts/check_syntax.js` | **Ejecutado por el auditor**: 7/7 `[PASS]` → `ALL FILES BALANCED AND SYNTACTICALLY SOUND!` (N-06 parcialmente cerrado) |

---

## 3. BLOQUEANTE NUEVO — R-01: la revalidación TOCTOU rompe A-07

**Ubicación:** `lib/services/exchange_rate_service.dart:947-958`

```dart
for (final k in keysToRemove) {
  if (_purgeGeneration != currentGen) break;

  // M-05 (TOCTOU): Revalidar si la clave ahora tiene un valor válido en disco antes de borrarla
  final currentVal = prefs.get(k);
  if (k == 'cached_exchange_rates_timestamp') {
    if (currentVal is String && DateTime.tryParse(currentVal) != null) continue;
  } else if (isValidMonetaryRate(currentVal)) {
    continue;                      // ← omite el borrado por "valor válido"
  }
  ...
}
```

`keysToRemove` no solo contiene claves con **valor** inválido. También contiene claves marcadas por **metadatos** inválidos:

| Origen de la marca | Línea | Valor típico | `isValidMonetaryRate` | Resultado |
| :--- | :--- | :--- | :--- | :--- |
| `cached_rate_<MONEDA>_<fecha imposible>` | `:926-936` | `40.0` (numérico válido) | **true** | **NO se borra** |
| `tasas_historico_v1` con tipo no `String` | `:779-783` | `12345` (int) | **true** | **NO se borra** |
| `tasas_historico_v1` String vacío / no-JSON / no-Map | `:785-808` | `String` | false | Se borra (pero **cuenta doble**, §6) |
| `cached_exchange_rates_timestamp` corrupto | `:917-925` | `int`/`String` inválido | false / rama propia | Se borra |

Además, el escaneo **incrementa `cleanedCount` antes de borrar** en las tres ramas de `tasas_historico_v1` (`:782`, `:787`, `:801`, `:807`), por lo que el conteo se reporta incluso cuando el borrado se omite.

### 3.1 Fallos deterministas demostrados

| # | Prueba | Esperado | Real por construcción |
| :---: | :--- | :--- | :--- |
| 1 | `cache_purge_test.dart:146` "Purga selectivamente…" | `cleanedCount == 7` (`:183`); `cached_rate_EUR_fecha_invalida == null` (`:199`) | **6**; la clave sobrevive con `20.0` |
| 2 | `:248` "Purga fechas imposibles…" | `cleanedCount == 5` (`:269`); tres claves `null` (`:272-274`) | **2** (solo el mapa); las 3 claves sobreviven con `40/45/41` |
| 3 | `:717` "B5: tipo no String…" | `removedKeys.contains('tasas_historico_v1')` (`:725`) y `disk` sin la clave (`:726-727`) | La clave **permanece** (int `12345` es numérico válido) |
| 4 | `:744` "B5: Recuperación obligatoria…" | `res1 == -1` (`:752`), `res2 == 1` y `disk` limpio (`:759-761`) | `res1 == 1` (¡marca fijada con la clave corrupta aún en disco!) |
| 5 | `:997` "Escenario B…" | `res1 == -1` (`:1011`), memoria sin la clave (`:1013`), operación pendiente (`:1019`) | `res1 == 0`; la clave sigue en memoria y en disco; sin operación pendiente |

**Consecuencia crítica:** en los casos 3-5, `ensureCacheHistoricaPurgada` observa `_pendingPurgeOperations.isEmpty` y `allWritesSucceeded == true`, fija `tasas_cache_historica_purgada_v1 = true` y retorna ≥ 0. A partir de ahí, el early-return de `:624-627` devuelve `0` para siempre: **la corrupción queda permanentemente blindada contra purga**. Esto incumple A-07 ("se purgan las entradas con metadatos incoherentes / fechas no válidas") y contradice el propio test del parche.

**Corolario sobre la instrucción 2:** B-05 está resuelto, pero **`flutter test` no puede pasar** por esta regresión. El informe de implementación afirma "listo para CI" sin haber ejecutado la suite (correctamente declarado en §5, pero incompatible con el estado real del código).

---

## 4. M-05 — evaluación adversarial

### 4.1 Lo que sí funciona

- `onKeyWriteConfirmed` es pública (`:586`) y se invoca en `SettingsProvider.setTasaCambio` (`:329-332`) y en las dos ramas de `actualizarTasaAutomatica` (`:247-250`, `:270-273`) **solo si `setDouble` retorna `true`**.
- El replay revalida antes de `remove` (`:737-749`) y **rescinde** la operación si el valor actual es válido. La prueba `:1406` sí ejercita esta rama y **es no vacua** (sin ella, el `remove` exitoso borraría 65.0 y la aserción de disco fallaría).
- La prueba de integración `settings_provider_rate_cache_test.dart:227` reproduce el escenario real "purga fallida → tasa manual → `ensure`" y verifica que `60.0` sobrevive en disco.

### 4.2 Defectos y vaciedades

| ID | Severidad | Hallazgo | Evidencia |
| :--- | :---: | :--- | :--- |
| **R-01** | **Bloqueante** | La revalidación TOCTOU se aplica indiscriminadamente y rompe la purga selectiva (§3) | `exchange_rate_service.dart:947-958` |
| **M5-a** | Media | La rescisión del replay se basa en `prefs.get()` (caché **en memoria**), no en persistencia confirmada. Si `setDouble` muta memoria y falla en plataforma, la operación pendiente se descarta **sin** limpiar el valor corrupto del disco y sin reescribir el válido → valor corrupto + marca fijada → residuo permanente | `:740-748`, `settings_provider.dart:329-333` |
| **M5-b** | Media | `actualizarTasaAutomatica` sigue **ignorando el `bool`** de `setDouble` para `cached_rate_usd`, `cached_rate_eur`, `cached_rate_usdt` y `cached_exchange_rates_timestamp` (`:251`, `:256`, `:260`, `:264`), y no notifica esas claves. Contradice "rescindir en todas las rutas" del informe | `settings_provider.dart` |
| **M5-c** | Baja | Prueba "Ruta B (TOCTOU)" **vacua**: el valor ya es `58.0` **antes** de iniciar la purga, por lo que la clave ni siquiera entra en `keysToRemove`. Pasaría con la revalidación comentada | `cache_purge_test.dart:1428-1440` |
| **M5-d** | Baja | Prueba `:1334` "Tasa fresca… rescinde remove pendiente" **no prueba la rescisión**: el replay de `ensure` (dentro de `getAllTodayRates`) elimina la operación con éxito antes de la escritura fresca. Pasaría aunque `onKeyWriteConfirmed` fuera vacío | `:1334-1378` |
| **M5-e** | Baja | La prueba `:1380` sí distingue la API por la aserción `:1397`, pero el resto del escenario quedaría cubierto por la revalidación del replay | `:1380-1404` |

**Nota técnica:** el TOCTOU descrito en la 5.ª reauditoría **no es alcanzable** en el tramo escaneo→primer `remove`: entre `:767` y `:962` no existe ningún `await` previo (el escaneo es totalmente síncrono). Solo hay ventana real entre borrados sucesivos (i ≥ 2), que es justo lo que la revalidación cubre. Es decir: se añadió una guarda correcta en el lugar correcto, pero **con un predicado que no entiende el motivo de la marca**.

---

## 5. M-08 — evaluación

**Resuelto en lo esencial.** Verificado por construcción:

- `_purgeGeneration` monotónico (`:564`), incrementado en `reset` (`:578`).
- Comprobaciones en `ensure` (`:636`, `:643`, `:664`) y en `purgar` (`:710`, `:719`, `:725`, `:752`, `:875`, `:896`, `:948`, `:963`, `:977`).
- `finally` condicional con `identical` (`:688-690`). Una purga A que termina tras un reset **no pisa** la futura B.
- La prueba `:1448` es determinista y no vacua: la purga queda suspendida en `await prefs.remove` **después** de registrar la operación pendiente (`:960`), el reset limpia el mapa e incrementa la generación, y la continuación aborta con `StateError` → `-1`.

Residuales (no bloqueantes):

| ID | Severidad | Hallazgo |
| :--- | :---: | :--- |
| M8-a | Baja | `reset` no espera la futura en vuelo: las escrituras **físicas** ya emitidas siguen ejecutándose contra el store después del reset. El aislamiento es del estado estático, no del disco. |
| M8-b | Baja | No hay prueba de la rama `identical(...) == false` (purga A terminando sobre la futura B). El `finally` condicional queda sin cobertura directa. |
| M8-c | Media | `settings_provider_rate_cache_test.dart:165` usa `SettingsProvider` real, cuyo `loadSettings` lanza `actualizarTasaAutomatica()` **sin `await`** (`:166`). Deja futuros vivos que mutan el `SharedPreferences` mock y el estado de purga tras el test. En `flutter_test` el `HttpClient` simulado devuelve 400 y el efecto es benigno, pero es exactamente el patrón que M-08 prohíbe ("ningún test deja futuros sin `await`"). |

---

## 6. B-02 — conteo de entradas

| Ruta | Comportamiento | Veredicto |
| :--- | :--- | :--- |
| Mapa depurado **no** vacío (`setString`) | `cleanedCount += entriesCleanedInMap` solo tras `saved == true`; replay usa `op.entriesCleanedCount` | ✅ Correcto |
| Mapa depurado **vacío** (`remove` completo) | `PendingPurgeOperation.remove(entriesCleanedCount: entriesCleanedInMap)`; suma en primer intento y en replay | ✅ Correcto **pero sin prueba dedicada** |
| `tasas_historico_v1` no `String` / vacío / no-Map / JSON inválido | `cleanedCount++` en el escaneo (`:782`, `:787`, `:801`, `:807`) **y otra vez** al borrar (`:966`) | ❌ **Doble conteo** (2 por una sola clave) si el borrado ocurre; y en el caso numérico no se borra pero **sí se cuenta** (§3) |

Conclusión: B-02 está resuelto **solo en la ruta que el informe declara**; la unidad de conteo sigue siendo inconsistente entre ramas. No es bloqueante por sí solo, pero refuta la afirmación de "unificación completa".

---

## 7. NEW-1 a NEW-6 (verificación puntual)

| ID | Resultado | Evidencia |
| :--- | :--- | :--- |
| NEW-1 | ✅ | `_pendingPurgeOperations`, `_purgeMarkPendingConfirmation`, replay físico (`:714-765`), marca solo tras confirmación (`:648-676`) |
| NEW-2 | ⚠️ | `_tasasSonReferencia = true` en fail-closed (`settings_provider.dart:138`). **D-06.3 prohíbe etiquetar `sinTasa` como `referencia`**; en esa rama las tres monedas quedan en `0.0` = `sinTasa`. Requiere adjudicación explícita (o el estado triple de D-06, diferido a U3/U4) |
| NEW-3 | ✅ | `rate_market.dart:72-76` = `val is num && val.isFinite && val > 1.0`, aplicado en `fromJson`, servicio, ambos providers |
| NEW-3b | ⚠️ | Correcto en `SettingsProvider` (`:91-102`, `:329-333`, `:252`). **`GastoProvider.cargarDatos:180` sigue prefiriendo `cached_rate_usd` sobre `prefTasaCambio`**: con caché automática 48.0 y manual 55.0, GastoProvider usa 48.0, contra D-05 ("unificación … en `SettingsProvider` y `GastoProvider`"). Además, si `cached_rate_usd` existe pero es inválido, el `??` no cae a la tasa manual válida → `0.0` |
| NEW-4 | ✅ | `_tasaCambioVesUsd/_Eur/_Usdt = 0.0`, fail-closed 0.0, `_tasaUsd/_tasaEur = 0.0`; `defaultTasaCambio` con `@Deprecated` (`app_constants.dart:171`). Sin uso como tasa efectiva; solo permanece como parámetro por defecto de `repararTasasHistoricas` (neutralizada, `dryRun=true`) |
| NEW-5 | ✅ | `gasto_provider.dart:184-193`; pruebas `gasto_provider_rate_cache_test.dart:101` y `:72` |
| NEW-6 | ✅ | `exchange_rate_service.dart:242-244`, `settings_provider.dart:121-126`; pruebas `cache_purge_test.dart:1213`, `:1227` |

---

## 8. Comportamiento numérico de D-01 a D-08

| Decisión | Estado real | Nota |
| :--- | :--- | :--- |
| **D-01** | ✅ 850.0 eliminado de rutas activas | `database_helper:1709` conserva `tasa_cambio > 1.0` y fallback 850 (dormido, `dryRun=true`) |
| **D-02** | ⏸️ No implementado | No hay clasificación `exacta/referencia` por `fechaEfectiva`. `loadSettings` deja `_tasasSonReferencia = true` salvo actualización viva; una caché del mismo día se etiqueta referencia. Declarado fuera de alcance, pero el informe no lo dice con esa precisión |
| **D-03** | ✅ Ausencia = `0.0` | Falta el estado nominal `sinTasa` (UI, U3/U4) |
| **D-04** | ⏸️ Parcial | `settings_provider.dart:118` mantiene `cachedUsdt ?? _tasaCambioVesUsd` (H-1, E0-03) |
| **D-05** | ⚠️ Parcial | Ver NEW-3b: divergencia `SettingsProvider` vs `GastoProvider` |
| **D-06** | ❌ No implementado | Sigue habiendo **un único `bool`** global y `sinTasa` se etiqueta `referencia` en fail-closed (contradicción directa con D-06.2 y D-06.3) |
| **D-07** | ⏸️ No implementado | Etiquetas de UI (E0-03) |
| **D-08** | ✅ Exacto | `isValidMonetaryRate` idéntico al texto de la decisión y aplicado de forma uniforme en el alcance E0-02 |

---

## 9. Inventario de pruebas — exacto

Conteo por regex `^\s*(test|testWidgets)\(`:

| Suite | Documentado | Real |
| :--- | ---: | ---: |
| `gasto_provider_rate_cache_test.dart` | 5 | **5** |
| `settings_provider_rate_cache_test.dart` | 9 | **9** |
| `exchange_rate_service_test.dart` | 15 | **15** |
| `exchange_rate_service_cache_purge_test.dart` | 47 | **47** |
| `rate_market_test.dart` | 8 | **8** |
| `rate_quote_input_test.dart` | 14 | **14** |
| `resolve_persisted_expense_test.dart` | 11 | **11** |
| `build_new_expense_tuple_test.dart` | 11 | **11** |
| `resumen_lente_monetario_test.dart` | 2 | **2** |
| **Total** | **122** | **122** ✅ |

El conteo documental es ahora exacto. Pero **"122 inspeccionadas" ≠ "122 en verde"**: 5 de esas 47 fallan por R-01.

---

## 10. Observaciones adicionales (no bloqueantes, registradas)

| ID | Severidad | Hallazgo |
| :--- | :---: | :--- |
| **N-09** | Media | `SettingsProvider.loadSettings` usa getters tipados (`getBool`/`getString`/`getDouble`) en `:77`, `:91`, `:141-148` **sin `try/catch`**. El fake O2 ahora reproduce fielmente el `TypeError` del plugin ante tipo corrupto; una sola clave mal tipada (p. ej. `guardar_fotos_local: "true"`) hace **caer el arranque**. Es la misma clase de defecto que NEW-6, no cubierta |
| N-10 | Baja | `setTasasReferencia` es `void` y no llama `notifyListeners()`; la UI no se entera del cambio (hoy sin consumidores en `lib/`) |
| N-11 | Baja | `getRateForDate` acepta fechas imposibles (`2026-02-30`) que `DateTime.tryParse` normaliza; M-02 sigue parcial |
| N-12 | Baja | `gasto_provider_rate_cache_test.dart` importa `../services/exchange_rate_service_cache_purge_test.dart` para reutilizar `TestSharedPreferences`: acopla suites e incorpora su `main()` al grafo de compilación |
| N-13 | Baja | El informe §3 lista como "working tree" dos archivos ya commiteados; y §1 atribuye a B-02 una prueba dedicada a la eliminación de mapa completo que **no existe** |

---

## 11. Correcciones exigidas

### 11.1 R-01 (obligatorio, bloqueante)

1. **No aplicar la revalidación escalar a claves marcadas por motivo estructural.** Opciones válidas:
   - Revalidar solo `cached_exchange_rate`, `tasa_cambio_ves_usd` y `cached_rate_<MONEDA>` (sin fecha) —las únicas que representan un **valor** de tasa—; o
   - Guardar en la marca el **motivo** (`valorInvalido` vs `fechaInvalida` vs `tipoInvalido`) y revalidar con el predicado correspondiente.
2. **No fijar la marca de purga** si `cleanedCount` incluye claves no borradas: separar "detectadas" de "confirmadas" y condicionar el éxito a `confirmadas == detectadas`.
3. Añadir pruebas que hoy fallan y que deben pasar: fecha imposible con valor numérico válido, `tasas_historico_v1` numérico, y el Escenario B.

### 11.2 B-02 (obligatorio para cerrar la afirmación)

4. Mover el `cleanedCount++` de las ramas `:782`, `:787`, `:801`, `:807` al punto de borrado confirmado (una sola unidad), o documentar y probar la semántica de "entrada depurada" para los tres casos.
5. Añadir la prueba de **eliminación de mapa completo** con fallo y reintento (primer intento N, reintento N).

### 11.3 M-05 (obligatorio para cerrar con evidencia real)

6. No rescindir una operación pendiente por un valor que solo existe en la caché en memoria: o bien se confirma también la escritura física del valor nuevo, o se mantiene la operación de limpieza hasta confirmación.
7. Revisar el `bool` de `setDouble` en `actualizarTasaAutomatica` para `cached_rate_usd/eur/usdt` y `cached_exchange_rates_timestamp`, y notificar `onKeyWriteConfirmed` cuando corresponda.
8. Reescribir la prueba "TOCTOU" para que la escritura ocurra **entre** el escaneo y el borrado (p. ej. segunda clave en `keysToRemove` cuyo `remove` inyecte la escritura), y la prueba `:1334` para que el replay **no** resuelva la operación antes de la escritura fresca.

### 11.4 Documentación

9. Corregir §3 del informe de implementación (archivos ya commiteados) y §1 en lo relativo a la prueba de B-02.
10. Declarar expresamente que D-02, D-06 y D-07 quedan diferidas, y **resolver la contradicción NEW-2 vs D-06.3** por decisión de César (no por interpretación del agente).

---

## 12. Condiciones verificables para cambiar el veredicto

1. **R-01 corregido** y las 47 pruebas de la suite de purga pasan, incluidas las 5 hoy rojas.
2. **Suite completa en verde** (`flutter test`) con `test_results.txt` del artefacto de CI como evidencia, no solo las suites monetarias.
3. **`flutter analyze --fatal-warnings --no-fatal-infos`** con salida 0 (el `@Deprecated` de `defaultTasaCambio` genera avisos de uso que deben quedar como `info`, no como `warning`).
4. **M-05 con pruebas rojo→verde reales** para replay y TOCTOU, sin vaciedad (verificar que fallen si se elimina la guarda).
5. **B-02** con unidad de conteo única y prueba de mapa completo.
6. **Documentación coherente** con el estado real del working tree.
7. **Séptima reauditoría adversarial favorable** y validación de César en *Rinde Más Dev*.

---

## 13. Conclusión

**RECHAZADO ❌.**

B-05 y M-08 quedan cerrados con evidencia sólida, y el conteo de 122 pruebas es exacto. Pero el parche introduce un **bloqueante nuevo y determinista**: la guarda TOCTOU de M-05, correcta en intención, se aplica a claves marcadas por metadatos y **suprime la purga de caché con fechas imposibles y de `tasas_historico_v1` mal tipado**, fijando además la marca de purga sobre datos corruptos. Eso incumple A-07, rompe B5 y deja `flutter test` en rojo por construcción.

E0-02 **no se cierra**. U1/U2 **no se aceptan**. U3/U4 **no se autorizan**. Sin autorización para commit ni push.
