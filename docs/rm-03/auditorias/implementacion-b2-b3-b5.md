# RM-03 — Informe Técnico de Implementación: Corrección de B2, B3, B5, O5, O2 y Cobertura B4

> **Documento:** Informe de implementación de parche técnico focalizado sobre E0-02 (Fase 0A).  
> **Fecha:** Noviembre de 2026.  
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md` (`RM-03 Fase 0A v1.2`).  
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (A-01 a A-16).  
> **Veredicto de implementación:** **PARCHE IMPLEMENTADO, PENDIENTE DE REAUDITORÍA INDEPENDIENTE.**  
> **Estado de Git:** Cero commits, cero push. Modificaciones confinadas exclusivamente al working tree local.

---

## 1. Estado Inicial Inspeccionado

Antes de realizar modificaciones, se contrastaron los informes de auditoría adversarial independiente de DeepSeek:
1. `docs/rm-03/auditorias/primera-auditoria-adversarial-deepseek.md`: Veredicto RECHAZADO (S1.1, S2.1, S3.3, S3.4).
2. `docs/rm-03/auditorias/reauditoria-postparche-deepseek.md`: Veredicto RECHAZADO (S3.3 / B1 y N1 bloqueantes).
3. `docs/rm-03/auditorias/segunda-reauditoria-b1-n1-deepseek.md`: Veredicto RECHAZADO (B1 y N1 corregidos; B2, B3, B5 bloqueantes pendientes, B4 cobertura insuficiente, O1–O8 observaciones abiertas).

El working tree inicial contenía modificaciones no commiteadas de E0-02 sobre:
- `MEMORY.md`
- `lib/data/models/gasto_firestore_mapper.dart`
- `lib/data/models/gasto_model.dart`
- `lib/services/exchange_rate_service.dart`
- `test/models/gasto_firestore_mapper_test.dart`
- Archivos sin seguimiento en `lib/domain/monetary/`, `test/domain/monetary/`, `docs/rm-03/` y `test/services/exchange_rate_service_cache_purge_test.dart`.

Se constató que el SDK local de Flutter/Dart **no está instalado** en la máquina del usuario (`Get-Command flutter, dart` retornó código 1).

---

## 2. Hallazgos Confirmados por Inspección de Código

1. **B2 en `SettingsProvider` (`lib/providers/settings_provider.dart`):**
   - En `loadSettings`, las semillas de tasas de SharedPreferences (`cached_rate_usd`, `cached_rate_eur`, `cached_rate_usdt`, `tasa_cambio_ves_usd`) se leían de forma inmediata sin invocar previamente `ExchangeRateService.ensureCacheHistoricaPurgada`.
   - La guarda numérica existente descartaba valores `<= 50.0`, pero en Dart `double.nan <= 50.0` evalúa a `false`, permitiendo la asignación inadvertida de `NaN`.
   - En `actualizarTasaAutomatica`, la condición `allRates.usd > 50.0` aceptaba `double.infinity`, ya que `double.infinity > 50.0` evalúa a `true`.
   - El método `setTasaCambio(double tasa)` no validaba finitud ni cota inferior (`isFinite && tasa > 1.0`).

2. **B2 en `GastoProvider` (`lib/providers/gasto_provider.dart`):**
   - En `cargarDatos`, se leían `cached_rate_usd`, `cached_rate_eur` y `tasa_cambio_ves_usd` sin verificar previamente si la purga A-07 había completado satisfactoriamente.
   - La condición `cachedUsd > 1.0` aceptaba `double.infinity`.
   - En `setTasasReferencia(tasaUsd, tasaEur)`, la guarda `> 0` permitía la inyección de `Infinity` o tasas fuera de dominio como `0.5`.

3. **B3 en `ExchangeRatesData.fromJson` (`lib/services/exchange_rate_service.dart`):**
   - El constructor `fromJson` filtraba con `raw > 0`, rechazando negativos y no finitos, pero aceptando valores absurdos como `0.5` y `1.0`, en contradicción con el dominio monetario normativo de v1.2 (`rate.isFinite && rate > 1.0`).

4. **B5 en `ExchangeRateService.purgarCacheHistoricaInvalida` (`lib/services/exchange_rate_service.dart`):**
   - Si `tasas_historico_v1` contenía un valor de tipo inesperado (distinto de `String`, ej. un `int` serializado erróneamente), la guarda `if (rawVal is! String)` asignaba `allWritesSucceeded = false`.
   - Esto provocaba que `purgarCacheHistoricaInvalida` lanzara `StateError`, y en consecuencia `ensureCacheHistoricaPurgada` capturara el error y retornara `-1` indefinidamente en cada arranque, bloqueando permanentemente la purga y el consumo de caché en toda la aplicación.

5. **O5 — Semilla principal `tasa_cambio_ves_usd` (`AppConstants.prefTasaCambio`):**
   - La purga selectiva solo procesaba `tasas_historico_v1`, `cached_exchange_rate` y claves que comenzaban por `cached_rate_`.
   - `tasa_cambio_ves_usd` (la clave oficial definida en `AppConstants.prefTasaCambio`) es consumida activamente por `SettingsProvider` y `GastoProvider` y no estaba cubierta por la purga A-07.

6. **O2 — Limitación del fake de SharedPreferences (`test/services/exchange_rate_service_cache_purge_test.dart`):**
   - El fake previo utilizaba un único mapa `data`, no distinguiendo entre la mutación inmediata en la memoria del proceso y la persistencia física en el almacenamiento de plataforma de Android.

---

## 3. Archivos Modificados y Nuevos

### Archivos de Producción Modificados:
- [`lib/services/exchange_rate_service.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/exchange_rate_service.dart):
  - Validación de dominio estricto en `ExchangeRatesData.fromJson` (`raw.isFinite && raw > 1.0`).
  - Tratamiento de `tasas_historico_v1` con tipo corrupto como clave corrupta eliminable (B5), evitando el bloqueo permanente.
  - Incorporación de `AppConstants.prefTasaCambio` (`tasa_cambio_ves_usd`) a la purga selectiva A-07 (O5).
- [`lib/providers/settings_provider.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/settings_provider.dart):
  - Invocación obligatoria de `ExchangeRateService.ensureCacheHistoricaPurgada` en `loadSettings` antes de leer semillas locales (B2).
  - Comportamiento *fail-closed*: si la purga retorna `-1`, omisión total de semillas locales no verificadas y adopción de valores por defecto seguros (`defaultTasaCambio`, `0.0`).
  - Validación estricta de tipo y dominio (`is num && isFinite && > 50.0`) al consumir semillas.
  - Blindaje de `actualizarTasaAutomatica` contra `Infinity` (`isFinite && > 50.0`).
  - Validación de dominio en `setTasaCambio` (`tasa.isFinite && tasa > 1.0`).
  - Parámetro opcional `{SharedPreferences? prefsInstance}` en `loadSettings` para pruebas unitarias deterministas.
- [`lib/providers/gasto_provider.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/gasto_provider.dart):
  - Invocación de `ensureCacheHistoricaPurgada` antes de leer tasas locales en `cargarDatos` (B2).
  - Comportamiento *fail-closed*: si la purga retorna `-1`, no se consumen tasas locales no verificadas.
  - Validación estricta `is num && isFinite && > 1.0` al leer tasas locales.
  - Validación estricta en `setTasasReferencia` (`isFinite && > 1.0`), rechazando `Infinity`, `NaN`, `0.5` y negativos.
  - Carga desacoplada: las fallas de purga o lectura de tasas no impiden la carga de gastos, presupuestos y categorías.
  - Parámetro opcional `{SharedPreferences? prefsInstance}` en `cargarDatos` para pruebas unitarias.

### Archivos de Pruebas Modificados y Nuevos:
- [`test/services/exchange_rate_service_cache_purge_test.dart`](file:///c:/Development/Control%20de%20gastos%20VE/test/services/exchange_rate_service_cache_purge_test.dart):
  - Rediseño de `TestSharedPreferences` con modelo explícito de dos estados (`memory` y `disk`) y método `reloadFromDisk()` (O2).
  - Pruebas negativas y de dominio para `ExchangeRatesData.fromJson` (`0.5`, `1.0`, `-5.0`, `NaN`, `Infinity`, validación independiente).
  - Pruebas de recuperación de B5 ante tipos corruptos en `tasas_historico_v1` en dos ejecuciones consecutivas.
  - Pruebas de cobertura completa de O5 para `tasa_cambio_ves_usd` (conservación válida, purga de 0.0, negativos, no finitos, tipos corruptos, fallo de remove y reintento).
  - Pruebas de reintento exitoso tras fallo transitorio en `setString`.
  - Pruebas de respuestas remotas no finitas en `getRateForDate`.
- [`test/providers/settings_provider_rate_cache_test.dart`](file:///c:/Development/Control%20de%20gastos%20VE/test/providers/settings_provider_rate_cache_test.dart) *(Nuevo)*:
  - Escenario 11: Purga fallida (-1) -> no consume caché local, adopta defaults.
  - Escenario 12: Purga exitosa -> consume tasas locales válidas, descarta `<= 50.0`, `NaN`, `Infinity`.
  - `setTasaCambio`: rechazo de `NaN`, `Infinity`, `<= 1.0`.
  - `actualizarTasaAutomatica`: no asigna `Infinity`.
- [`test/providers/gasto_provider_rate_cache_test.dart`](file:///c:/Development/Control%20de%20gastos%20VE/test/providers/gasto_provider_rate_cache_test.dart) *(Nuevo)*:
  - Escenario 13: Purga fallida (-1) -> omite caché local no verificada.
  - Escenario 14: No asigna `Infinity` proveniente de caché ni de `setTasasReferencia`.
  - Carga de gastos desacoplada de la disponibilidad de tasas.

---

## 4. Causa Raíz de B2, B3 y B5

### Causa Raíz de B2:
- Los proveedores `SettingsProvider` y `GastoProvider` fueron construidos originalmente con lecturas directas síncronas de `SharedPreferences` para acelerar el primer cuadro de renderizado de la UI.
- Al agregarse la purga A-07 en `ExchangeRateService`, los proveedores continuaron consultando SharedPreferences directamente sin invocar la purga previa ni evaluar el resultado `-1`.
- Además, los filtros existentes usaban comparaciones parciales (`<= 50.0` y `> 1.0`) que ignoran la semántica IEEE-754 de `NaN` (para el cual cualquier comparación `<, <=, >, >=` es `false`) e `Infinity` (para el cual `Infinity > 1.0` es `true`).

### Causa Raíz de B3:
- En `ExchangeRatesData.fromJson`, la deserialización evaluaba `raw > 0` con el propósito de descartar ceros o valores negativos, pero no contrastaba contra el dominio normativo `> 1.0` fijado en v1.2, permitiendo la propagación de valores decimales sub-unitarios (`0.5`) o unitarios (`1.0`).

### Causa Raíz de B5:
- En `ExchangeRateService.purgarCacheHistoricaInvalida`, la rama que validaba `tasas_historico_v1` clasificó erróneamente un tipo inesperado (`rawVal is! String`) como un fallo transitorio de persistencia (`allWritesSucceeded = false`) en lugar de tratarlo como un dato corrupto en la clave. Al no poder convertirse en `String`, cada ejecución volvía a lanzar `StateError`, convirtiendo el error en un bloqueo permanente que impedía fijar la marca persistente de purga.

---

## 5. Correcciones Aplicadas

1. **B2 — SettingsProvider:**
   - Se incorporó la ejecución obligatoria de `ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: prefs)` al inicio de `loadSettings`.
   - Si `purgeResult == -1`, no se lee ninguna semilla de SharedPreferences; las variables adoptan de forma determinista `AppConstants.defaultTasaCambio`, `0.0` y `_ultimaActualizacionTasas = null`.
   - Si `purgeResult != -1`, cada semilla se valida con `raw is num && raw.isFinite && raw > 50.0`.
   - Se preservó estrictamente el fallback USD $\rightarrow$ USDT (`_tasaCambioVesUsdt = cachedUsdt ?? _tasaCambioVesUsd`), respetando el límite de alcance H-1.
   - En `actualizarTasaAutomatica` y `setTasaCambio`, se añadieron verificaciones explícitas de `isFinite && > 50.0` y `tasa.isFinite && tasa > 1.0`.

2. **B2 — GastoProvider:**
   - En `cargarDatos`, se invoca `ensureCacheHistoricaPurgada`. Ante `-1`, se omite la lectura de tasas locales.
   - Las tasas leídas se validan con `raw is num && raw.isFinite && raw > 1.0`.
   - En `setTasasReferencia`, se exige `isFinite && > 1.0`.

3. **B3 — ExchangeRatesData.fromJson:**
   - Se sustituyó `raw > 0` por `raw != null && raw.isFinite && raw > 1.0` de forma independiente para `usd`, `eur` y `usdt`, asignando `0.0` a cualquier valor inválido o no finito.

4. **B5 — Recuperación ante tipo corrupto:**
   - Si `rawVal is! String` en `tasas_historico_v1`, la clave se añade a `keysToRemove` y se incrementa `cleanedCount`.
   - La operación de eliminación física pasa por `prefs.remove(k)`. Si `remove` tiene éxito, la clave corrupta se elimina, la purga se completa y la marca se fija, desbloqueando el servicio. Si `remove` falla transitoriamente, `allWritesSucceeded = false`, lanzando `StateError` y permitiendo un reintento seguro en el siguiente ciclo.

---

## 6. Incorporación de `tasa_cambio_ves_usd` a la Protección A-07 (O5)

- Se confirmó mediante inspección que `AppConstants.prefTasaCambio` (`'tasa_cambio_ves_usd'`) almacena la tasa de cambio de referencia oficial VES/USD en `SettingsProvider` y `GastoProvider`.
- Se integró `key == AppConstants.prefTasaCambio` dentro de la rama de purga de semillas en `purgarCacheHistoricaInvalida`:
  - Valores numéricos válidos (`isFinite && > 1.0`) se conservan intactos.
  - Valores `<= 1.0` (incluyendo `0.0`, `-5.0`, `1.0`), valores no finitos (`NaN`, `Infinity`, `-Infinity`) y valores con tipos no numéricos (ej. `String`, `bool`) se añaden a `keysToRemove`.
  - La eliminación se ejecuta mediante `prefs.remove`. Si `remove` falla, no se establece la marca persistente y se permite el reintento.

---

## 7. Diseño del Fake (O2) y Pruebas Nuevas

### Modelo de dos estados en `TestSharedPreferences` (O2):
- **`memory`:** Mapa en memoria que refleja la caché síncrona accesible por los lectores de `SharedPreferences`.
- **`disk`:** Mapa que representa el almacenamiento físico persistido por la plataforma subyacente.
- Al invocar `setString(key, value)`, la mutación se aplica inmediatamente a `memory`. Si `throwOnSetString` es verdadero, se lanza la excepción antes de escribir en `disk`.
- El método `reloadFromDisk()` descarta las mutaciones volátiles en `memory` y las restaura desde `disk`, simulando de forma realista el reinicio del proceso o la recarga tras fallo de I/O.
- Las aserciones de pruebas distinguen expresamente entre `store.disk[...]` y `store.getString(...)`, eliminando afirmaciones infundadas sobre persistencia en disco.

---

## 8. Matriz de Cobertura de Pruebas (B4)

| Nº | Escenario Exigido | Suite / Archivo | Estado de Implementación |
| :---: | :--- | :--- | :---: |
| 1 | `setString` falla y posteriormente se recupera | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 2 | Respuesta remota `NaN` en `getRateForDate` | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 3 | Respuesta remota `Infinity` en `getRateForDate` | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 4 | `getAllTodayRates` recibe valores no finitos | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 5 | `fromJson` recibe `0.5` | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 6 | `fromJson` recibe `1.0` | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 7 | `fromJson` recibe `-5.0` | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 8 | Semilla `cached_exchange_rate` inválida no se utiliza | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 9 | Semilla `tasa_cambio_ves_usd` válida se conserva | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 10 | Semilla `tasa_cambio_ves_usd` inválida se elimina conforme a A-07 | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 11 | Purga fallida en `SettingsProvider` no consume caché local | `test/providers/settings_provider_rate_cache_test.dart` | **Cubierto ✅** |
| 12 | Purga exitosa en `SettingsProvider` solo consume tasas válidas | `test/providers/settings_provider_rate_cache_test.dart` | **Cubierto ✅** |
| 13 | Purga fallida en `GastoProvider` no consume caché local | `test/providers/gasto_provider_rate_cache_test.dart` | **Cubierto ✅** |
| 14 | `GastoProvider` recibe `Infinity` -> no asigna esa tasa | `test/providers/gasto_provider_rate_cache_test.dart` | **Cubierto ✅** |
| 15 | Historial de tipo incorrecto puede recuperarse | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 16 | Fallo de `remove` no fija la marca | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 17 | Reintento tras fallo transitorio completa la purga | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |
| 18 | Fail-closed con semillas actuales (ninguna semilla no verificada se consume) | `test/services/exchange_rate_service_cache_purge_test.dart` | **Cubierto ✅** |

---

## 9. Pruebas Realmente Ejecutadas vs No Ejecutadas

### Pruebas Realmente Ejecutadas:
- **`scripts/check_rules.ps1`:** Ejecutado localmente mediante PowerShell. Resultado: **PASO con advertencias** (las advertencias corresponden al tamaño de archivo de una regla externa no modificada `material-3/SKILL.md`).

### Pruebas No Ejecutadas en Local:
- **`flutter analyze --fatal-warnings`:** **NO EJECUTADO.** El SDK de Flutter/Dart no está instalado en la máquina local del usuario.
- **`flutter test`:** **NO EJECUTADO.** Ninguna prueba de Dart fue ejecutada localmente.
- Todas las pruebas de las suites (`test/domain/monetary/`, `test/services/`, `test/providers/`, `test/models/`) quedan preparadas con rigor sintáctico para su ejecución exclusiva en GitHub Actions CI.

---

## 10. Hallazgos que Permanecen Abiertos y Fuera de Alcance

Conforme al pliego de la tarea, los siguientes asuntos permanecen formalmente fuera del alcance de este parche:
1. **H-1 Global (Sustitución de USDT por USD en adquisición):** Las rutas de fallback en `ExchangeRateService:92,126-129,405-412` y `SettingsProvider:86` permanecen abiertas y formalmente asignadas a la unidad **E0-03**.
2. **H-2 Presentación (Getters y agregaciones):** Getters en `GastoModel:208-209`, `ChatScreen:385`, `DatabaseHelper:682,757` y `CurrencyFormatter:70-74` continúan derivando USDT desde USD cuando es nulo; su reemplazo corresponde a la unidad **E0-03**.
3. **S3.2 (`copyWith` en `GastoModel`):** La imposibilidad de limpiar campos nulables (`totalUsdt`, `tasaUsdt`) regresándolos a `null` queda pendiente para la unidad **E0-04**.
4. **Discrepancia en `resolvePersistedExpense`:** No se alteró el resolver en memoria; se mantiene intacto según el contrato adjudicado v1.2.
5. **Cambios previos de H-2:** Se preservaron intactos los archivos `lib/data/models/gasto_model.dart`, `lib/data/models/gasto_firestore_mapper.dart` y `test/models/gasto_firestore_mapper_test.dart`.

---

## 11. Estado Final del Working Tree y Restricciones Operativas

- **Esquema SQLite:** Permanece inalterado en `version: 18` (`DatabaseHelper`). No se agregaron migraciones ni se modificaron tablas.
- **Reglas de Firestore (`firestore.rules`):** Permanecen 100% intactas.
- **Dependencias (`pubspec.yaml` y `pubspec.lock`):** Permanecen 100% intactas.
- **Commits y Push:** **CERO commits, CERO push.** Ninguna operación de mutación de historial Git fue ejecutada. Todo el trabajo reside estrictamente en el working tree local.
- **E0-02:** **NO se declara cerrado.** El parche queda listo para la tercera reauditoría adversarial independiente por parte de DeepSeek.
