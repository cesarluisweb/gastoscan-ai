# RM-03 — Informe Técnico de Implementación: Unidades U1 a U4 (Saneamiento de E0-02)

> **Documento:** Informe de implementación del parche de saneamiento sobre E0-02 (Fase 0A).  
> **Fecha:** Noviembre de 2026.  
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md` (`RM-03 Fase 0A v1.2`).  
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (`A-01` a `A-16` y `D-01` a `D-08`).  
> **Auditoría previa:** Octava reauditoría adversarial (`docs/rm-03/auditorias/octava-reauditoria-u1-u2-deepseek.md`) — **ACEPTADO CON OBSERVACIONES ⚠️**.  
> **Veredicto de implementación:** **ACEPTADO TÉCNICAMENTE EN WORKING TREE (E0-02 PENDIENTE DE VALIDACIÓN 🧪 EN CI; E0-03 AUTORIZADO CONDICIONALMENTE ⚠️ TRAS CI EN VERDE).**  
> **Estado de Git:** Base en `origin/main` (`676344b`). Modificaciones estrictamente confinadas al working tree local.

---

## 1. Resumen de Hallazgos y Bloqueantes Resueltos en este Parche

| ID Hallazgo | Componente | Severidad Previa | Corrección Aplicada | Archivo Modificado |
| :--- | :--- | :---: | :--- | :--- |
| **D-05 / NEW-3b** | `SettingsProvider` (`actualizarTasaAutomatica` y `setTasaCambio`) | **Bloqueante** | En la rama offline (`esReferencia`), `actualizarTasaAutomatica` valida si existe una tasa manual global activa (`_esTasaManualUsd`) y la preserva intacta en memoria y disco sin sobrescribirla con la caché automática anterior. Solo una tasa en vivo válida (`!allRates.esReferencia`) puede sustituirla y desactivar la bandera. En `setTasaCambio`, `pref_es_tasa_manual_usd` solo se persiste si la escritura en disco de la tasa confirmó (`ok == true`), y la bandera en memoria se sincroniza con el resultado de `setBool`. En `settings_provider_rate_cache_test.dart`, se utiliza `TestableSettingsProvider` para silenciar la sincronización de fondo no esperada en `loadSettings`. | `lib/providers/settings_provider.dart`, `test/providers/settings_provider_rate_cache_test.dart` |
| **M-05 / M5-a** | `ExchangeRateService.purgarCacheHistoricaInvalida` (replay) | **Bloqueante** | En el bucle de replay de `_pendingPurgeOperations`, se eliminó la rescisión por lectura de la caché en memoria (`prefs.get()`). La única vía autorizada para rescindir un `remove` pendiente por tasa fresca es `onKeyWriteConfirmed(key)`, invocada tras confirmación física de plataforma (`ok == true`). El replay ejecuta directamente `prefs.remove(op.key)` en disco. Si `setDouble` mutó memoria pero falló en disco (`returnFalseOnSetDouble = true`), la operación pendiente permanece y no se fija la marca de purga. | `lib/services/exchange_rate_service.dart`, `test/services/exchange_rate_service_cache_purge_test.dart` |
| **M-08** | `ExchangeRateService` y suite de purga | **Bloqueante / Pruebas no discriminantes** | Se expuso `@visibleForTesting static Future<int>? get activePurgeFuture`. Se corrigió la prueba de `finally` condicional con `Completer` para pausar la purga A y B, capturar la Future interna `taskB` de `activePurgeFuture` durante el vuelo de B, y verificar asertivamente que tras terminar A, `activePurgeFuture` sigue siendo idéntico a `taskB` (un `finally` incondicional fallaría al ponerlo en `null`). Además se verificó que una llamada C concurrente reutiliza `taskB` sin lanzar otra tarea, y que al terminar B, `activePurgeFuture` se limpia a `null`. La prueba de generación se reescribió con `returnFalseOnRemove = false` para verificar que la generación es la causa directa del retorno `-1` y la no persistencia de la marca. | `lib/services/exchange_rate_service.dart`, `test/services/exchange_rate_service_cache_purge_test.dart` |
| **R-01** | `ExchangeRateService` (`keysToRemove`) | Bloqueante neutralizado | La revalidación TOCTOU de `isValidMonetaryRate` se restringió exclusivamente a claves de tasa diaria activa (`cached_exchange_rate`, `prefTasaCambio`, `cached_rate_usd/eur/usdt`). Las claves con corrupción estructural (fechas de calendario imposibles `!_isValidCalendarDate`, o `tasas_historico_v1` mal tipado) **NUNCA se omiten del borrado**, garantizando el cumplimiento estricto de A-07 y B5. | `lib/services/exchange_rate_service.dart` |
| **B-02** | `ExchangeRateService.purgarCacheHistoricaInvalida` | Observación / Conteo | Se eliminó el `cleanedCount++` prematuro en el escaneo de `tasas_historico_v1`. El incremento ocurre exclusivamente una vez confirmada físicamente la remoción en disco. Cuando `cleanedMap.isEmpty` (eliminación de mapa histórico completo corrupto), registra `entriesCleanedInMap` como `entriesCleanedCount` tanto en primer intento como en replay. | `lib/services/exchange_rate_service.dart`, `test/services/exchange_rate_service_cache_purge_test.dart` |
| **B-05** | `test/providers/gasto_provider_rate_cache_test.dart` | Bloqueante determinista | Callback `() async {`, invocación explícita con `await provider.cargarDatos()`, aserción directa sobre getters `provider.tasaUsd` y `provider.tasaEur` en cada paso determinista. | `test/providers/gasto_provider_rate_cache_test.dart` |
| **NEW-3b** | `GastoProvider.cargarDatos` | Bloqueante | Unificación de precedencia de lectura: ante reinicio sin red, `GastoProvider` evalúa `pref_es_tasa_manual_usd` y da precedencia a la tasa manual global (`prefTasaCambio`) sobre cachés automáticas anteriores (`cached_rate_usd`). | `lib/providers/gasto_provider.dart`, `test/providers/gasto_provider_rate_cache_test.dart` |
| **N-09** | `SettingsProvider.loadSettings` | Observación | Lectura defensiva con helpers seguros (`_safeGetBool`, `_safeGetString`, `_safeGetDouble`) que verifican el tipo con `is` antes de invocar getters tipados de SharedPreferences. Ante tipos corruptos (ej. String en bool o int en String), adopta el default sin lanzar `TypeError`. | `lib/providers/settings_provider.dart`, `test/providers/settings_provider_rate_cache_test.dart` |
| **NEW-1** | `ExchangeRateService.ensureCacheHistoricaPurgada` | Bloqueante | Rastreo en memoria de mutaciones físicas pendientes (`_pendingPurgeOperations` y `_purgeMarkPendingConfirmation`). La marca persistente solo se fija tras confirmar el disco (`_pendingPurgeOperations.isEmpty`). | `lib/services/exchange_rate_service.dart` |
| **NEW-4** | `850.0` como tasa efectiva | Bloqueante | Eliminado el uso de `850.0` como tasa activa. En `SettingsProvider` y `GastoProvider`, valores iniciales y ramas *fail-closed* asignan `0.0` (sin tasa). `AppConstants.defaultTasaCambio` anotada con `@Deprecated` (`D-01`). | `lib/core/constants/app_constants.dart`, `lib/providers/settings_provider.dart`, `lib/providers/gasto_provider.dart` |
| **NEW-5** | Estado anterior retenido en `GastoProvider` | Bloqueante | Ante `purgeResult == -1` o excepción, `_tasaUsd` y `_tasaEur` se restablecen deterministamente a `0.0`. | `lib/providers/gasto_provider.dart` |
| **NEW-6 / B3-OBS** | Deserialización y timestamp | Bloqueante | Lectura segura `is String` en timestamp y deserialización defensiva en `fromJson` ante tipos no String degradando a 0.0 y `esReferencia = true`. | `lib/services/exchange_rate_service.dart` |
| **O2** | Fake `TestSharedPreferences` | Observación | Modelo de dos estados (memory y disk). `remove` muta memoria antes del fallo de plataforma. Inyección de callback `onKeyRemovedAsync` con `Completer` para concurrencia determinista no vacua. | `test/services/exchange_rate_service_cache_purge_test.dart` |

---

## 2. Inventario Real y Exacto de Pruebas Monetarias (127 pruebas)

Conteo estricto de declaraciones `test(` verificado mediante consulta determinista en PowerShell:

| Suite de Pruebas | Conteo Previo | Pruebas Añadidas / Modificadas | Conteo Actual Real | Propósito y Discriminación |
| :--- | :---: | :---: | :---: | :--- |
| `test/providers/gasto_provider_rate_cache_test.dart` | 5 | +1 | **6** | Prevalencia de tasa manual global sobre caché automática antigua al reiniciar (`NEW-3b / D-05`). |
| `test/providers/settings_provider_rate_cache_test.dart` | 10 | +1 | **11** | Persistencia de tasa manual en offline, fallo de sincronización y reinicio; safe getters (`N-09`, `D-05`). |
| `test/services/exchange_rate_service_test.dart` | 15 | 0 | **15** | Comportamiento del servicio de tasas. |
| `test/services/exchange_rate_service_cache_purge_test.dart` | 49 | 0 (3 reescritas) | **49** | Discriminación M5-a (`returnFalseOnSetDouble`), generación `M-08` no vacua y `finally` condicional con inspección de `activePurgeFuture` idéntico a `taskB`. |
| `test/domain/monetary/rate_market_test.dart` | 8 | 0 | **8** | Dominio y mercados de tasas. |
| `test/domain/monetary/rate_quote_input_test.dart` | 14 | 0 | **14** | Validación de inputs de tasas. |
| `test/domain/monetary/resolve_persisted_expense_test.dart` | 11 | 0 | **11** | Resolución monetaria de gastos guardados. |
| `test/domain/monetary/build_new_expense_tuple_test.dart` | 11 | 0 | **11** | Construcción de tuples de gasto. |
| `test/domain/monetary/resumen_lente_monetario_test.dart` | 2 | 0 | **2** | Agregación de lente monetario. |
| **Total Suite Monetaria** | **126** | **+1** | **127** | **127 pruebas en total (0 ejecutadas localmente sin SDK).** |

---

## 3. Delimitación de Estado en Git

- **`HEAD` / `origin/main`:** Commit `676344b` (`docs(play): registrar estado de revision de acceso a produccion`).
- **Commits previos que integraron la estructura base de U1/U2:** `5fb357b` y `3afc559`.
- **`scripts/check_syntax.js`:** Versionado en el repositorio y sin modificaciones en el working tree (`PASS 7/7`).
- **Modificaciones actuales en el Working Tree Local:**
  - `lib/providers/settings_provider.dart`: Cierre de **D-05** (preservación de tasa manual en `actualizarTasaAutomatica` offline, persistencia condicional en `setTasaCambio` y sincronización con `setBool`).
  - `lib/services/exchange_rate_service.dart`: Cierre de **M5-a** (eliminación de rescisión por memoria en replay) y getter `activePurgeFuture` (**M-08**).
  - `test/services/exchange_rate_service_cache_purge_test.dart`: Prueba determinista para **M5-a**, prueba discriminante de generación (**M-08**) y prueba discriminante de `finally` condicional (**M-08** con inspección de `taskB`).
  - `test/providers/settings_provider_rate_cache_test.dart`: Prueba determinista para **D-05** usando `TestableSettingsProvider` (higiene M-08).
  - `docs/rm-03/auditorias/septima-reauditoria-u1-u2-deepseek.md`: Registro íntegro del dictamen de la 7.ª reauditoría.
  - `docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md`: Informe de implementación integral corregido.
  - `docs/rm-03/estado-actual.md`: Sincronización del estado de RM-03 a 127 pruebas.
  - `DOC_BITACORA_MARKETING.md` y `MEMORY.md`: Bitácoras y memoria inmediata actualizadas.

---

## 4. Asuntos Formalmente Fuera de Alcance (Diferidos a E0-03 y E0-04)

- **D-02 (Exactitud por fecha efectiva):** Clasificación nominal `actualizada / exacta / referencia` según fecha del gasto vs fecha de la tasa. Diferida a **E0-03**.
- **D-06 (Modelo de tres estados independientes por moneda):** Reemplazo del booleano global `_tasasSonReferencia` por enum de tres vías (`actualizada`, `referencia`, `sinTasa`) por moneda. Diferida a **E0-03**.
- **D-07 (Denominaciones visuales en UI):** "Última tasa registrada", "Tasa manual", "Sin tasa disponible" en pantallas y widgets. Diferida a **E0-03**.
- **H-1 Global (Fallback USDT -> USD en adquisición):** Líneas de fallback en `ExchangeRateService` y `SettingsProvider`. Asignada a **E0-03**.
- **H-2 Presentación (Getters y agregaciones en UI):** Getters en `GastoModel`, `ChatScreen`, `CurrencyCalculatorScreen`, etc. Asignada a **E0-03**.
- **S3.2 (`copyWith` en `GastoModel`):** Limpieza de campos nulables. Asignada a **E0-04**.
- **Fase 0B y SQLite v19:** Permanecen **BLOQUEADAS** normativamente (`A-01`, `A-12`).

---

## 5. Estado de Validación y Conclusión

- **Entorno local:** Sin SDK de Flutter ni Dart local. Cero ejecuciones fingidas de `flutter test`.
- **`node scripts/check_syntax.js`:** Ejecutado localmente. Resultado: **ALL FILES BALANCED AND SYNTACTICALLY SOUND!** (7/7 archivos validados en balance de delimitadores).
- **`scripts/check_rules.ps1`:** Ejecutado localmente. Resultado: **PASO con advertencias**.
- **Veredicto actual:** Aceptado técnicamente en working tree (8.ª reauditoría ⚠️). Listo para commit, push y confirmación de CI en verde para dar cierre definitivo a `E0-02` y habilitar `E0-03`.
