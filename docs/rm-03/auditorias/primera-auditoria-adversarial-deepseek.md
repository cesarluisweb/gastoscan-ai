# Auditoría adversarial independiente — Cierre E0-02 (RM-03)

## 0. Alcance y método

- Revisión **solo lectura**. No modifiqué archivos, no implementé correcciones, no hice commit ni push.
- Estado real del working tree:
  - Modificados: `MEMORY.md`, `lib/data/models/gasto_model.dart`, `lib/services/exchange_rate_service.dart`.
  - Nuevos sin seguimiento: 6 archivos en `lib/domain/monetary/` y 5 archivos de prueba en `test/domain/monetary/` y `test/services/`.
- **No hay SDK de Flutter/Dart instalado localmente** (`flutter` y `dart` no existen en PATH). Por tanto **no ejecuté ninguna prueba ni `flutter analyze`**. Todo lo que afirmo sobre pruebas es por inspección del código.
- No encontré en el repositorio el documento de la auditoría previa de DeepSeek; contrasté contra la especificación v1.2 y contra los puntos H-1, H-2, H-3 y A-07 descritos en la solicitud.

---

## 1. Veredicto general

# RECHAZADO

Las tres correcciones puntuales solicitadas están **sustancialmente bien aplicadas en las líneas exactas**:

- H-1: eliminado `?? gasto.tasaCambio` en la lente VES de `resolvePersistedExpense`.
- H-2: `fromMap` ya no fabrica `totalUsdt` ni `tasaUsdt`.
- H-3: eliminada la heurística de endpoint y conservada la validación tipada.

Sin embargo, la unidad **no puede cerrarse** en este estado porque:

1. Hay una prueba nueva que, por inspección, **no puede pasar** con la implementación actual (CI quedaría en rojo).
2. La implementación de A-07 puede **borrar entradas históricas legítimas** ante una sola entrada mal tipada.
3. Persisten rutas equivalentes a H-1 y H-2 fuera de las líneas corregidas, que neutralizan la garantía global.
4. El cambio de `fromMap` introduce un riesgo de sincronización: puede escribir `null` sobre valores remotos no nulos en Firestore.

---

## 2. Estado real de la validación

### Pruebas ejecutadas y superadas
**Ninguna.** No hay Flutter/Dart local. No se ejecutó `flutter test` ni `flutter analyze`.

### Pruebas preparadas pero no ejecutadas
- `test/domain/monetary/build_new_expense_tuple_test.dart`
- `test/domain/monetary/rate_quote_input_test.dart`
- `test/domain/monetary/resolve_persisted_expense_test.dart`
- `test/domain/monetary/resumen_lente_monetario_test.dart`
- `test/services/exchange_rate_service_cache_purge_test.dart`
- Suite existente del proyecto.

### Defecto demostrado por inspección del código
La prueba `test/services/exchange_rate_service_cache_purge_test.dart:63`:

```dart
expect(prefs.getDouble('cached_exchange_rate'), isNull);
```

no puede satisfacerse. El método `purgarCacheHistoricaInvalida` solo procesa:
- la clave exacta `tasas_historico_v1`, y
- claves que empiezan por `cached_rate_`.

`cached_exchange_rate` **no empieza por `cached_rate_`** y nunca se añade a `keysToRemove`. Permanece con `-5.0`. Si la suite se ejecuta, esa aserción falla.

### Riesgos que requieren CI
- Compilación real de los nuevos archivos (`sealed class`, switches exhaustivos, imports).
- `flutter analyze --fatal-warnings`.
- Totalidad de la suite, incluida la prueba anterior.
- Comportamiento real de `SharedPreferences` con los mocks.

---

## 3. Hallazgos clasificados por severidad

### S1 — Bloqueante

#### S1.1. A-07: `cached_exchange_rate` no se purga, pero la prueba exige que sí
- **Archivo/método:** `lib/services/exchange_rate_service.dart`, `purgarCacheHistoricaInvalida`, líneas 449–543; rama `cached_rate_` en 515–534.
- **Prueba:** `test/services/exchange_rate_service_cache_purge_test.dart:24` y `:63`.
- **Evidencia:** el bucle solo entra en `key == 'tasas_historico_v1'` o `key.startsWith('cached_rate_')`. `cached_exchange_rate` no cumple ninguna condición.
- **Impacto:** CI rojo. Además, contradice la documentación del propio método (“Entradas con valores <= 1.0”) y el informe de Gemini (“se valida la eliminación de claves corruptas, valores <= 1.0”).
- **Corrección esperada:** incluir `cached_exchange_rate` (y valorar `tasa_cambio_ves_usd`) en la purga, o corregir la prueba y el contrato. Dado que `cached_exchange_rate` se usa como semilla en `getAllTodayRates:60`, lo coherente es purgarlo si es inválido.

---

### S2 — Alta

#### S2.1. A-07: una sola entrada mal tipada borra TODO `tasas_historico_v1`
- **Archivo/método:** `lib/services/exchange_rate_service.dart`, `purgarCacheHistoricaInvalida`, líneas 489–497 y 511–514.
- **Evidencia:**
  ```dart
  final rate = (val['valor'] ?? val['rate'] ?? val['promedio']) as num?;
  final source = (val['source'] ?? val['fuente']) as String?;
  ```
  Si `val['valor']` es un `String`, o `val['source']` es un `num`, el cast lanza `TypeError`. La excepción se propaga fuera del `forEach` y la captura externa `catch (_)` añade **la clave completa** a `keysToRemove`. Se elimina todo el mapa histórico, incluidas entradas válidas.
- **Impacto:** pérdida de historial legítimo, exactamente lo que A-07 debía evitar. Agravado por el `catch (_)` silencioso.
- **Corrección esperada:** validar tipos con `is num` / `is String` sin casts que lancen, y descartar solo la entrada inválida, nunca la clave completa por un error de una entrada.

#### S2.2. H-1: persisten rutas equivalentes que sustituyen USDT por USD
La línea corregida (`monetary_resolution.dart:161–162`) es correcta, pero la garantía “ninguna ruta sustituye `tasaUsdt` por `tasaCambio`” no se cumple globalmente:

- `lib/providers/settings_provider.dart:86`
  ```dart
  _tasaCambioVesUsdt = cachedUsdt ?? _tasaCambioVesUsd;
  ```
  Si no hay USDT cacheado, usa la tasa USD como USDT P2P.

- `lib/services/exchange_rate_service.dart:126–129`
  ```dart
  } else if ((usdtRate == null || usdtRate <= 50.0) && (usdRate != null && usdRate > 50.0)) {
    usdtRate = usdRate;
  }
  ```

- `lib/services/exchange_rate_service.dart:92`
  ```dart
  usdt: (gUsdt != null && gUsdt > 50.0) ? gUsdt : (usdtRate ?? gUsd),
  ```

- `lib/services/exchange_rate_service.dart:263–264`
  ```dart
  final usdRate = (data['USD']?['rate'] as num?)?.toDouble();
  if (usdRate != null && usdRate > 50.0) return usdRate;
  ```
  `_fetchUsdtLiveRate` devuelve la tasa USD de Yadio como si fuera USDT P2P.

- `lib/services/exchange_rate_service.dart:405–412`
  ```dart
  if (monedaClean == 'USDT') {
    final usdHistorical = await getRateForDate(isoDate, moneda: 'USD', ...);
    if (usdHistorical > 0) {
      await prefs.setDouble(cacheKey, usdHistorical);
      return usdHistorical;
    }
  }
  ```
  Guarda una tasa USD bajo la clave `cached_rate_USDT_<fecha>`. A-07 la conserva porque es `> 1.0` y tiene fecha válida.

- La prueba existente `test/services/exchange_rate_service_test.dart:45–57` **afirma explícitamente** este fallback histórico USDT→USD. Es comportamiento deliberado y actual, no un accidente.

- `lib/ui/screens/chat_screen.dart:385`
  ```dart
  'total_usdt': double.parse(((g.totalUsdt ?? g.totalUsd) / 100.0).toStringAsFixed(2)),
  ```

- `lib/domain/monetary/monetary_resolution.dart` ya no lo hace, pero los datos que llegan desde estas rutas ya vienen contaminados antes de persistirse.

**Impacto:** la corrección de H-1 evita la fabricación en lectura, pero no evita que se persista una tasa USDT falsa desde la capa de adquisición. Según `dinero-datos.md:9`, la paridad 1:1 USD/USDT solo aplica a pagos directos en `DIVISA`; usar la tasa USD oficial como USDT P2P es una sustitución de mercado, no una paridad permitida.

#### S2.3. H-2: los getters del modelo reintroducen exactamente los fallbacks eliminados de `fromMap`
- **Archivo:** `lib/data/models/gasto_model.dart:208–209`
  ```dart
  double get totalUsdtDisplay => (totalUsdt ?? totalUsd) / 100.0;
  double get tasaUsdtDisplay => (tasaUsdt != null && tasaUsdt! > 0) ? tasaUsdt! : tasaCambio;
  ```
- Aunque `fromMap` ya preserva `null`, cualquier consumidor que use estos getters vuelve a fabricar USDT desde USD o la tasa USDT desde `tasaCambio`.
- Consumidores directos:
  - `lib/ui/widgets/expense_card.dart:102–103`
  - `lib/ui/widgets/currency_radiography_card.dart:50–52`
  - `lib/ui/widgets/daily_evolution_card.dart:61–63`
  - `lib/ui/widgets/purchase_radiography_card.dart:37–39`
  - `lib/ui/screens/review_expense_screen.dart:358–359`
  - `lib/ui/screens/chat_screen.dart:385`
  - `lib/data/datasources/local/database_helper.dart:682,757`
- **Impacto:** la corrección de `fromMap` es correcta, pero la garantía “no fabricar equivalencias” queda neutralizada en la capa de presentación y agregación. Es el mismo defecto H-2, desplazado de sitio.
- **Matiz:** son fallbacks preexistentes, no introducidos por el parche; pero el parche no los elimina y el informe no los menciona. E0-03 los reemplazará, pero hasta entonces la unidad no puede afirmar que H-2 está cerrado de extremo a extremo.

---

### S3 — Media

#### S3.1. Regresión potencial en sincronización: `toPayload` puede escribir `null` sobre valores remotos
- **Archivos:**
  - `lib/data/models/gasto_firestore_mapper.dart:21,24` → `'total_usdt': gasto.totalUsdt`, `'tasa_usdt': gasto.tasaUsdt`.
  - `lib/data/datasources/remote/firestore_gastos_remote_data_source.dart:39–45` → `.set(payload, SetOptions(merge: true))`.
  - `lib/services/sync_service.dart:175–197` → solo sube gastos con `synced = 0`.
- **Antes del parche:** una fila local con `total_usdt` NULL se cargaba con `totalUsdt = total_usd` y `tasaUsdt = tasa_cambio`; el push enviaba esos valores sintéticos.
- **Después del parche:** se envía `null`. En Firestore, un `set(..., merge: true)` con `null` escribe el campo como `null`; no lo omite. Un gasto legacy con `synced = 0` y `total_usdt` NULL puede borrar el valor no nulo que existía en la nube.
- **Impacto:** pérdida de una columna secundaria remota. No es una columna verificada según v1.2, pero sigue siendo un dato persistido. E0-04 debería resolver la semántica de sync; E0-02 no debería introducir esta escritura sin guarda.

#### S3.2. `copyWith` no puede limpiar campos nulables
- **Archivo:** `lib/data/models/gasto_model.dart:158,161` y siguientes.
  ```dart
  totalUsdt: totalUsdt ?? this.totalUsdt,
  tasaUsdt: tasaUsdt ?? this.tasaUsdt,
  ```
- Con `fromMap` produciendo `null` reales, cualquier flujo que necesite propagar un `null` sobre un valor existente (por ejemplo, aplicar un documento remoto con `total_usdt: null` sobre una fila local con valor) no puede hacerlo mediante `copyWith`.
- Es preexistente, pero el cambio de `fromMap` lo hace relevante para E0-04. Requiere un centinela o un método específico de actualización.

#### S3.3. A-07: la marca persistente se fija aunque fallen las eliminaciones
- **Archivo:** `lib/services/exchange_rate_service.dart:436–438` y `538–540`.
  ```dart
  final count = await purgarCacheHistoricaInvalida(prefsInstance: prefs);
  await prefs.setBool(prefKeyCacheHistoricaPurgada, true);
  ...
  for (final k in keysToRemove) {
    await prefs.remove(k);
  }
  ```
- `prefs.remove` y `prefs.setString` devuelven `Future<bool>`, pero el resultado se ignora. Si una eliminación falla, `purgar` termina “correctamente”, `ensure` marca la purga como completada y la entrada inválida queda para siempre.
- **Impacto:** no cumple “la marca persistente solo se establece después de una limpieza completada correctamente”.

#### S3.4. A-07: validación de fechas solo por regex, no por calendario
- **Archivo:** `lib/services/exchange_rate_service.dart:456,477,521`.
- `^\d{4}-\d{2}-\d{2}$` acepta `2026-13-40`, `2026-02-30`, etc. Esas entradas se conservan como “válidas”.
- La auditoría pedía analizar específicamente fechas malformadas. La implementación solo cubre el formato, no la existencia real de la fecha.
- En `RateQuoteInput` sí se añadió validación de calendario (`rate_quote_input.dart:43–54`), pero no en A-07.

---

### S4 — Baja / observaciones

#### S4.1. Orden en `buildNewExpenseTuple`: se validan cotizaciones antes del bloqueo EUR + BS_USDT
- **Archivo:** `lib/domain/monetary/expense_tuple.dart:92–129` (validaciones) y `139–145` (bloqueo).
- La especificación §1.3 dice “devuelve inmediatamente” para `EUR + bsUsdt`. Con tres cotizaciones válidas, T-63 pasa; pero con una cotización inválida el usuario recibe `cotizacionInvalida` en vez de `combinacionMonedaLiquidacionNoSoportada`. No debilita la regla, pero el orden no es el literal de v1.2.

#### S4.2. `_isValidCalendarDate` es una adición no adjudicada
- **Archivo:** `lib/domain/monetary/rate_quote_input.dart:43–54,81–84`.
- v1.2 especifica solo `_isoDateRegex`. La implementación es más estricta (rechaza `2026-02-30`). No es un debilitamiento; es una mejora, pero conviene documentarla como desviación consciente.

#### S4.3. Concurrencia de `ensureCacheHistoricaPurgada`
- Dos llamadas simultáneas pueden ver la marca en `false`, ejecutar ambas la purga y fijar la marca. No corrompe datos, pero no es estrictamente “ejecución única”. El peor caso es una doble iteración y posibles `remove` duplicados. Bajo riesgo.

#### S4.4. Alcance de A-07: purga claves diarias además de `tasas_historico_v1`
- v1.2 §6.1, punto 4, menciona explícitamente `tasas_historico_v1`. La implementación también elimina claves `cached_rate_*`. Es razonable (son caché de tasas inválidas), pero es una expansión de alcance que debe confirmarse contra la auditoría previa. Si el contrato solo autorizaba `tasas_historico_v1`, hay sobreextensión.

#### S4.5. `tasas_historico_v1` no se escribe ni se lee en producción
- Solo aparece en el método de purga y en la prueba. La purga asume un esquema de mapa (`valor/rate/promedio` + `source/fuente`) que no está documentado ni validado contra datos reales. El riesgo de S2.1 es especialmente relevante porque no hay evidencia de producción que confirme el formato.

#### S4.6. Precisión del informe de Gemini
- El informe dice “se eliminó la condición `dateStr.compareTo('2023-01-03') < 0`”. Esa condición no existía en `HEAD`; el método es nuevo. La afirmación se refiere a una edición intermedia, no al diff final.
- El informe dice “Cero mutaciones sobre registros locales o remotos de usuarios”. La purga sí muta `SharedPreferences` en el dispositivo (aunque solo caché, no registros financieros). Conviene precisar.
- La lista de “Archivos Modificados” omite `expense_tuple.dart`, `metodo_liquidacion.dart`, `rate_market.dart` y `resumen_lente_monetario.dart`, aunque están descritos en el cuerpo.

---

## 4. Evidencia por hipótesis

### H-1 — Fallback de tasa USDT

| Comprobación | Resultado |
| :--- | :--- |
| `resolvePersistedExpense` lente VES usa `gasto.tasaUsdt` sin `?? tasaCambio` | **PASA** — `monetary_resolution.dart:161–162` |
| `tasaUsdt` ausente → `pendiente` | **PASA** — `monetary_resolution.dart:171–193`; prueba `resolve_persisted_expense_test.dart:157–173` |
| No hay otras rutas equivalentes | **FALLA** — `settings_provider.dart:86`, `exchange_rate_service.dart:92,126–129,263–264,405–412`, `chat_screen.dart:385` |
| No se persiste una tasa USDT fabricada desde USD | **FALLA** — `getRateForDate` guarda USD bajo clave USDT; A-07 la conserva |

**Conclusión H-1:** correcto en el resolver; incompleto en la garantía global. La prueba de H-1 construye el `GastoModel` manualmente, no vía `fromMap`; para H-1 es aceptable porque evalúa el resolver, pero no cubre la ruta de datos contaminados.

### H-2 — `GastoModel.fromMap`

| Comprobación | Resultado |
| :--- | :--- |
| Constructor y tipos | `totalUsdt`, `totalEur`, `tasaUsdt`, `tasaEur` ya eran nulables; `totalUsd` y `tasaCambio` siguen no nulables con defaults (`0`, `1.0`) |
| `fromMap` preserva `null` | **PASA** — `gasto_model.dart:106,109` |
| `toMap` preserva `null` | **PASA** — `gasto_model.dart:64,67` |
| Tests atraviesan `fromMap` | **PASA para H-2** — `resolve_persisted_expense_test.dart:189,211,235,247` |
| Sin fallbacks entre monedas en el modelo | **FALLA** — `gasto_model.dart:208–209` |
| Sin valores por defecto artificiales | **PARCIAL** — `tasaCambio` sigue con `1.0` y `totalUsd` con `0`; el resolver los trata como inválidos, pero los getters los usan |
| Sin regresiones en otros flujos | **RIESGO** — push de `null` a Firestore (`S3.1`), `copyWith` (`S3.2`), agregados de `database_helper` con fallback (`:682,757`) |

**Conclusión H-2:** la deserialización/serialización de `totalUsdt` y `tasaUsdt` está corregida y probada. La garantía de “no fabricar” no está cerrada por los getters y consumidores.

### H-3 — Validación de cotizaciones

| Comprobación | Resultado |
| :--- | :--- |
| Heurística `_isEndpointValidForSource` eliminada | **PASA** — no hay coincidencias en `lib/domain/monetary/` |
| Descriptor no vacío | **PASA** — `rate_quote_input.dart:70–73` |
| Validación tipada mercado/fuente | **PASA** — `rate_quote_input.dart:60–68`; `rate_market.dart:31–57` |
| Fechas, dominio, confirmación, manuales | **PASA** — `rate_quote_input.dart:75–126` |
| No se debilitó otra regla | **PASA** — se añadió validación de calendario, más estricta |
| T-64, T-65, T-66 | **PREPARADAS**, no ejecutadas; por inspección, coherentes con la implementación |

**Conclusión H-3:** cerrado correctamente. Única observación: la validación de calendario es una adición no adjudicada (S4.2).

### A-07 — Limpieza de caché histórica

| Comprobación | Resultado |
| :--- | :--- |
| Solo elimina entradas autorizadas | **FALLA** — `cached_exchange_rate` no se elimina; una entrada mal tipada elimina todo el mapa |
| Fechas malformadas | **PARCIAL** — formato sí; fechas imposibles no |
| Entradas históricas legítimas antiguas | **PASA** — se conservan si `> 1.0` y formato válido; prueba `:57–59,72` |
| Marca solo tras limpieza correcta | **FALLA** — `remove`/`setString` no verificados (`:507,538–540`) |
| Fallos parciales | **RIESGO** — la marca queda fijada aunque una eliminación falle |
| Concurrencia | **RIESGO BAJO** — doble purga posible; sin corrupción demostrada |
| Idempotencia | **PASA** en `ensure`; prueba `:78–103` |
| Efecto en `getAllTodayRates` | **PASA** en lo esencial; no borra semillas válidas |
| Efecto en `getRateForDate` | **PARCIAL** — borra claves `<= 1.0`, pero tras la marca una nueva entrada `0.5` sería aceptada porque `getRateForDate:309` solo exige `> 0` |
| No borra por antigüedad | **PASA** — no hay comparación con 2023 |

**Conclusión A-07:** **no cerrado**. Hay un fallo de prueba garantizado y un riesgo real de sobreborrado.

### Alcance e integridad

| Comprobación | Resultado |
| :--- | :--- |
| Esquema SQLite en 18 | **PASA** — `database_helper.dart:45,68` (`version: 18`); no hay símbolo `_dbVersion`, pero el valor es 18 |
| Sin migraciones ni cambios de esquema | **PASA** — `git diff` no incluye `database_helper.dart` |
| Sin cambios en reglas Firestore | **PASA** — `git status` no incluye `firestore.rules` |
| Sin cambios en `pubspec.yaml` | **PASA** — no aparece en el diff |
| Sin datos de usuarios modificados en el repo | **PASA** — no hay cambios en datos; en runtime la purga toca caché de `SharedPreferences`, no registros financieros |
| E0-03 no implementado anticipadamente | **PASA** — no hay imports de `domain/monetary` en pantallas, providers ni panel web; solo se referencian entre sí los archivos del dominio |
| E0-01 compatible | **PASA** — `sqflite_common_ffi` sigue en `dev_dependencies`; arnés intacto |
| E0-05a compatible | **PASA** — `dryRun = true` por defecto en `gasto_provider`, `gasto_repository`, `database_helper`; auto-reparaciones neutralizadas en `main_screen` y `sync_service`; sin diffs |

---

## 5. Posibles regresiones introducidas

1. **Firestore: `null` sobre valores remotos no nulos.**  
   `fromMap` ahora devuelve `null` real y `toPayload` lo envía con `SetOptions(merge: true)`. Un gasto legacy con `synced = 0` puede borrar `total_usdt`/`tasa_usdt` remotos. Es la regresión más importante introducida por el cambio de H-2.

2. **Cambio de totales para filas legacy.**  
   Filas con `total_usdt` o `tasa_usdt` NULL pasan de `persistidoNoVerificado`/`calculadoNoVerificado` a `pendiente`. Es el comportamiento conservador que exige v1.2, pero reduce los totales mostrados hasta que E0-03 integre los nuevos agregadores. Debe comunicarse a César.

3. **A-07 puede impedir la carga de tasas si lanza una excepción.**  
   `ensureCacheHistoricaPurgada` se invoca al inicio de `getAllTodayRates`. Si `prefs.getString('tasas_historico_v1')` o `prefs.getDouble(...)` lanzan por un tipo inesperado, la excepción sube y la actualización de tasas falla antes de la red. Probabilidad baja, impacto alto.

4. **Pérdida de historial por una entrada mal tipada.**  
   S2.1: un solo `valor` String o `source` numérico elimina todo `tasas_historico_v1`.

5. **`copyWith` no propaga `null`.**  
   Cualquier flujo de actualización que dependa de `copyWith` conservará el valor anterior. No es una regresión inmediata porque E0-04 no está implementado, pero queda como trampa para esa unidad.

6. **No se encontraron errores de compilación por inspección**, pero esto **debe confirmarlo CI**. No puedo afirmar que compile.

---

## 6. Pruebas adicionales necesarias

### A-07
1. Corregir y ejecutar la prueba de `cached_exchange_rate`; decidir si también debe cubrir `tasa_cambio_ves_usd`.
2. `tasas_historico_v1` con una entrada de `valor` String entre varias válidas → solo se elimina la inválida, la clave sobrevive.
3. `tasas_historico_v1` con `source` numérico → solo se elimina la inválida.
4. Fechas imposibles (`2026-13-40`, `2026-02-30`) en `tasas_historico_v1` y en `cached_rate_*`.
5. Inyección de un store que devuelva `false` en `remove` → la marca **no** debe quedar fijada.
6. Dos llamadas concurrentes a `ensureCacheHistoricaPurgada` → una sola purga efectiva, sin corrupción.
7. Segunda llamada directa a `purgarCacheHistoricaInvalida` sobre datos ya limpios → retorna 0 y no muta nada.

### H-2
8. `totalUsdtDisplay` y `tasaUsdtDisplay` con `totalUsdt`/`tasaUsdt` nulos → deben devolver `null`/no fabricar, o existir una decisión explícita de que E0-03 los reemplaza.
9. Ciclo `fromMap → toPayload` con `total_usdt: null` y `tasa_usdt: null` → el payload conserva `null` (ya cubierto parcialmente), y prueba de sync que verifique que un `null` local no borra un valor remoto no nulo.
10. `copyWith` con intención de limpiar `totalUsdt`, `tasaUsdt`, `totalEur`, `tasaEur` → actualmente no es posible; prueba que documente el comportamiento esperado.
11. Agregados de `database_helper:682,757` con `total_usdt` NULL → deben alinearse con `resolvePersistedExpense` o quedar explícitamente fuera de E0-02.

### H-1
12. `settings_provider` sin `cached_rate_usdt` → `tasaCambioVesUsdt` no debe ser igual a la tasa USD.
13. `getAllTodayRates` con fallo de USDT y éxito de USD → `usdt` no debe ser `usd` (actualmente lo es).
14. `getRateForDate('fecha', moneda: 'USDT')` sin histórico paralelo → no debe devolver ni cachear la tasa USD (actualmente lo hace; la prueba existente lo afirma).
15. `resolvePersistedExpense` con `tasaUsdt <= 1.0` y con `tasaUsdt == tasaCambio` (fila legacy migrada) → decidir y probar `pendiente` o ambigüedad.

### H-3 / tupla
16. T-63 con cotizaciones inválidas → decidir si debe prevalecer `combinacionMonedaLiquidacionNoSoportada` (orden “inmediato”) o `cotizacionInvalida`.
17. Prueba de compilación/análisis en CI (`flutter analyze --fatal-warnings`).

---

## 7. Recomendación sobre el cierre de E0-02

**No cerrar E0-02 todavía.** Requiere otro parche focalizado, no un rediseño:

### Parche mínimo obligatorio
1. **A-07 / S1.1:** incluir `cached_exchange_rate` (y valorar `tasa_cambio_ves_usd`) en la purga, o corregir la prueba y el contrato. Tal como está, CI no puede quedar verde.
2. **A-07 / S2.1:** sustituir los casts `as num?` / `as String?` por comprobaciones `is num` / `is String` y eliminar solo la entrada inválida, nunca la clave completa.
3. **A-07 / S3.3:** verificar los `bool` de `remove`/`setString`; si algo falla, no fijar la marca y reportar el fallo.
4. **A-07 / S3.4:** validar calendario real, no solo regex, o documentar que el contrato solo exige formato.

### Decisión necesaria antes de cerrar
5. **H-1 residual:** decidir si E0-02 puede declarar H-1 cerrado solo para `resolvePersistedExpense`, dejando las rutas de adquisición (`settings_provider`, `getAllTodayRates`, `getRateForDate`) para una unidad posterior. Si la respuesta es “H-1 significa ninguna ruta”, entonces E0-02 no está cerrado y requiere otro parche.
6. **H-2 residual:** decidir si los getters `totalUsdtDisplay`/`tasaUsdtDisplay` y los widgets se corrigen ahora o se sustituyen en E0-03. Mientras existan, la afirmación “H-2 cerrado” es solo parcial.
7. **Sync:** añadir una guarda para que `toPayload`/`upsertGasto` no escriba `null` sobre un valor remoto no nulo, o adelantar la semántica de E0-04. Sin esto, el cambio de `fromMap` puede degradar datos en la nube.

### Criterio de cierre
- CI en verde con la suite completa, incluida la prueba de A-07 corregida.
- Reauditoría de A-07 con los casos de sobreborrado y fallo parcial.
- Confirmación explícita de César sobre el alcance de H-1/H-2 residual y sobre la regresión de sync.

**En resumen:** las líneas H-1, H-2 y H-3 están bien corregidas; el problema es que la unidad se entrega con una prueba que no puede pasar y con A-07 incompleto. Con el parche anterior, E0-02 podría pasar a “APROBADO CON OBSERVACIONES”; en el estado actual, **RECHAZADO**.

----

Aquí está lo que te pido que hagas:
