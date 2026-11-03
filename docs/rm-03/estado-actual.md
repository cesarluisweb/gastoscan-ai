# RM-03 — Estado Actual del Proyecto

> **Fecha de corte de inspección:** Noviembre de 2026.  
> **Rama activa:** `main` (Working Tree local con las correcciones de la cuarta reauditoría U1/U2 de E0-02; quinta reauditoría RECHAZADA; sin commit ni push).  
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md` (íntegro, sin modificaciones).  
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (`A-01` a `A-16` y `D-01` a `D-08` aprobadas, sin modificaciones).  
> **Último informe de implementación:** `docs/rm-03/auditorias/correcciones-cuarta-reauditoria-u1-u2.md` → correcciones de B-01..B-04 y de M-01, M-02, M-05, M-07 y M-08. **M-05 y M-08 se declararon implementadas, pero la quinta reauditoría las considera no resueltas.**  
> **Última auditoría:** Quinta reauditoría adversarial independiente (`auditorias/quinta-reauditoria-u1-u2-deepseek.md`) → **RECHAZADA ❌**. U1/U2 **NO ACEPTADAS NI COMPLETADAS**. E0-02 **NO CERRADO**. Nuevo bloqueante **B-05**; **M-05** y **M-08** continúan sin resolver; **M-02** y **M-07** son parciales. **0 pruebas ejecutadas, 0 `flutter analyze`, 0 CI**.

---

## 1. Estado General de las Etapas (Fase 0)

| Etapa | Descripción | Estado Oficial | Detalle y Referencia |
| :--- | :--- | :--- | :--- |
| **`E0-05a`** | Neutralización de auto-reparación 850/474 | **Completada ✅** | Mergeada en `main` (commit `de17323`). `repararTasasHistoricasIncompletas` neutralizada en `main_screen.dart:132-145` y `sync_service.dart`; `dryRun = true` por defecto en `gasto_repository.dart`. |
| **`E0-01`** | Arnés de pruebas SQLite real en memoria | **Completada ✅** | Mergeada en `main` (commit `de17323`). `sqflite_common_ffi` incorporado en `dev_dependencies` (**A-08**) y validado en CI. |
| **`E0-02`** | Dominio monetario, tupla y purga de caché A-07 | **Quinta reauditoría RECHAZADA ❌ — U1/U2 no completadas** | B-01 a B-04 corregidos según inspección, **no validados por CI**. Nuevo bloqueante **B-05** (test determinista). **M-05** sigue sin resolver (riesgo de pérdida de tasas) y **M-08** también. **M-02** y **M-07** son parciales. U3/U4 no autorizadas. Ver §2.1 y §2.5. |
| **`E0-03`** | Integración en lectores móviles y panel web | **No autorizada ⏸️** | Continúa **NO AUTORIZADA** hasta que E0-02 sea aceptada por auditoría adversarial independiente y validada en CI en verde (**A-16**). Incluye H-1 global y H-2 en presentación, regidas por **D-01 a D-08**. |
| **`E0-04`** | Atomismo `synced=0`, CAS, allowlist de metadatos | **Pendiente ⏳** | Pendiente; requiere E0-02 y E0-03 en verde. Incluye la semántica de limpieza nullable de `copyWith` en `GastoModel` (S3.2). |
| **`E0-05b`** | Diagnósticos read-only `Q01..Q20` sin PII | **Pendiente ⏳** | Pendiente; ejecución en paralelo o tras E0-03 (**A-14**). |
| **Fase 0B** | Guardado sin tasa con sincronización remota | **Bloqueada 🔴** | Bloqueada por diseño normativo (**A-12**, **D-03**, **D-04**). Prohibido habilitar mientras la nube no esté contenida. |
| **Doc RM-03** | Documentación central y persistente del proyecto | **Completada ✅** | Estructura en `docs/rm-03/` activa: `README.md`, `contrato-v1.2.md` (íntegro), `decisiones.md` (`A-01` a `A-16` y `D-01` a `D-08`), `estado-actual.md` e historial en `auditorias/`. |

---

## 2. Estado Técnico Detallado de E0-02

### 2.1 Veredicto vigente

**E0-02: QUINTA REAUDITORÍA RECHAZADA ❌ — U1 Y U2 NO ACEPTADAS NI COMPLETADAS.**  
La quinta reauditoría adversarial independiente (`auditorias/quinta-reauditoria-u1-u2-deepseek.md`) evaluó el working tree local y emitió **RECHAZADO**. El diseño de U2 sigue siendo correcto y no requiere rediseño; el rechazo obedece a:

- **B-05 (nuevo bloqueante determinista):** `test/providers/gasto_provider_rate_cache_test.dart:110-137` llama a `cargarDatos` sin `await` en un callback que no es `async`; la aserción se evalúa antes de que se carguen los totales y el test no puede pasar.
- **M-05 no resuelto:** la rescisión de operaciones pendientes solo cubre escrituras internas de `ExchangeRateService`. Una tasa manual guardada desde `SettingsProvider` no rescinde un `remove` pendiente, y la purga borra claves sin revalidar su valor actual. Puede perder una tasa válida recién persistida.
- **M-08 no resuelto:** el reset estático no cancela ni espera purgas en vuelo y el `finally` de `ensure` limpia incondicionalmente `_activePurgeFuture`, permitiendo purgas concurrentes tras un reset.

**Estado de los hallazgos previos:** B-01 a B-04 están corregidos **según inspección estática**, pero **no validados por CI**. M-01 está resuelto en los tres consumidores. M-02 y M-07 son parciales. M-03 y M-04 siguen diferidos a U3/U4. M-06 mantiene una mitigación incompleta.

**Validación:** **113 pruebas inspeccionadas, 0 ejecutadas**. No hay SDK local de Flutter/Dart; no se ejecutó `flutter analyze` ni `flutter test`; no se disparó CI.

Las unidades **U3** (modelo de tres vías por moneda, precedencia manual y erradicación de 850 en proveedores) y **U4** (integración visual de pantallas) continúan pendientes y **no autorizadas**; **no deben comenzar hasta resolver la compuerta de esta reauditoría**. E0-02 **permanece abierto**. **No hay autorización para commit ni push.**

### 2.2 Corregidos e Implementados (U1 y U2)

- **B1 (Corregido en `ExchangeRateService`):** Aislamiento estricto de decodificación JSON vs persistencia `setString`.
- **N1 (Corregido en `ExchangeRateService.getRateForDate`):** Validación estricta de dominio (`isValidMonetaryRate`) en todos los puntos de consumo de tasas por fecha. Comportamiento *fail-closed* ante purga incompleta (`ensureCacheHistoricaPurgada == -1`).
- **B5 (Corregido en `ExchangeRateService.purgarCacheHistoricaInvalida`):** `tasas_historico_v1` con tipo no `String` se trata como dato corrupto eliminable sin bloqueo permanente.
- **O5 (Corregido en `ExchangeRateService.purgarCacheHistoricaInvalida`):** `tasa_cambio_ves_usd` incorporada a la purga selectiva A-07.
- **U1 / NEW-3 y M-01 (Corregido en `lib/domain/monetary/rate_market.dart` y consumidores):** Predicado canónico `isValidMonetaryRate(dynamic value)` conforme a **D-08**, aplicado en `ExchangeRateService`, `SettingsProvider` y `GastoProvider`. En la quinta reauditoría se verificó que `rate_quote_input.dart:76`, `monetary_resolution.dart:175` y `database_helper.dart:1720-1725` ya usan el predicado canónico. Residuales: la consulta SQL de `database_helper.dart:1709` conserva `tasa_cambio > 1.0` y `database_helper.dart:1721` conserva el fallback 850 (reparación dormida, `dryRun=true` por defecto). El remanente `> 50.0` de `review_expense_screen.dart:247-255` corresponde a U3/U4.
- **U1 / B3-OBS y M-02 (Parcial en `ExchangeRatesData.fromJson`):** Deserialización defensiva sin *casts* directos (`as num?`, `as bool?`). Una fecha ausente, no `String` o no parseable asigna epoch 0 (`DateTime.fromMillisecondsSinceEpoch(0)`) y fuerza `esReferencia: true`. **Limitación vigente:** `DateTime.tryParse('2026-02-30')` normaliza a `2026-03-02`, por lo que una fecha imposible puede aceptarse como válida y conservar `esReferencia: false`. No tiene consumidores en producción (solo tests).
- **U1 / NEW-6 (Corregido parcialmente en `SettingsProvider` y `ExchangeRateService`):** Lectura segura de `cached_exchange_rates_timestamp` comprobando tipo `String` antes de parsear. El timestamp corrupto se purga si no es `String` o no es parseable; **M-04 sigue abierto** porque `DateTime.tryParse` normaliza fechas imposibles como `2026-02-30`.
- **U2 / NEW-1 (Corregido en `ExchangeRateService`):** Sistema de operaciones pendientes `PendingPurgeOperation` para escrituras (`setString`) y eliminaciones (`remove`), y confirmación persistente estricta de la marca `setBool(prefKeyCacheHistoricaPurgada, true)`. Resuelve la divergencia memoria/disco para escrituras internas; permite reintentos deterministas en el mismo proceso sin invocar `reloadFromDisk()`. **M-05 sigue abierto** para escrituras externas a `ExchangeRateService` y para el TOCTOU entre escaneo y borrado.
- **O2 (Corregido en `TestSharedPreferences`):** Fidelidad de tipos con `TypeError` en getters `getString`, `getDouble`, `getBool`, mutación síncrona en memoria previa a plataforma en `remove`, y soporte para fallos en `setDouble`.

### 2.3 Pendientes de U3 y U4 (Bloquean el Cierre Definitivo de E0-02)

- **NEW-2 — `_tasasSonReferencia` en fail-closed:** pendiente de modelado de 3 estados independientes por moneda (U3 / D-06).
- **NEW-3b — Precedencia de tasa manual vs automática:** desacople entre `setTasaCambio` (`prefTasaCambio`) y `cached_rate_usd` pendiente de unificación (U3 / D-05).
- **NEW-4 — 850.0 como tasa efectiva en proveedores y pantallas:** la app **NO está lista para distribución** mientras `SettingsProvider`, `GastoProvider`, `ReviewExpenseScreen` y `CurrencyCalculatorScreen` mantengan fallbacks a 850.0. Su eliminación requiere el modelo de 3 estados de U3 y el ajuste visual de U4 (D-01 a D-07).
- **NEW-5 — Limpieza de estado previo en `GastoProvider` ante `-1`:** asignación a estado explícito «sin tasa» pendiente de U3 (D-06).
- **B2 / B4 — Cobertura y validación integral:** requiere validación en CI en verde una vez completadas las unidades.

### 2.4 Asuntos Formalmente Fuera de Alcance de E0-02 (Permanecen Abiertos)

- **H-1 Global (USDT $\rightarrow$ USD en adquisición):** Rutas de fallback en `ExchangeRateService:92,126-129,405-412` y `SettingsProvider:86`. Se mantiene abierto formalmente y diferido a la unidad **E0-03**.
- **H-2 Presentación (Getters y agregaciones):** Getters en `GastoModel:208-209`, `ChatScreen:385`, `DatabaseHelper:682,757` y `CurrencyFormatter:70-74` continúan derivando USDT desde USD. Se mantiene abierto formalmente y diferido a la unidad **E0-03**.
- **S3.2 (`copyWith` en `GastoModel`):** `copyWith` no permite limpiar campos nulables (`totalUsdt`, `tasaUsdt`). Queda pendiente para **E0-04**.
- **E0-03:** Permanece **NO AUTORIZADA** hasta la aceptación de E0-02 por la auditoría adversarial y la validación en CI.

### 2.5 Quinta reauditoría adversarial U1/U2 (`auditorias/quinta-reauditoria-u1-u2-deepseek.md`)

- **Veredicto:** **RECHAZADO ❌**. U1/U2 **NO ACEPTADAS NI COMPLETADAS**. E0-02 **NO CERRADO**.
- **B-01 a B-04:** corregidos **según inspección estática**, pero **no validados por CI**. B-02 conserva una discrepancia de conteo: una eliminación de mapa histórico completo suma N entradas en el primer intento y 1 en el reintento.
- **B-05 (nuevo bloqueante):** `test/providers/gasto_provider_rate_cache_test.dart:110-137` llama a `cargarDatos` sin `await` en un callback no `async`. La aserción se evalúa con los totales vacíos, `getSpentForCategory` devuelve `0.0` y el test espera `80.0`. Fallo determinista; `flutter test` no puede pasar.
- **M-01:** resuelto en `rate_quote_input.dart:76`, `monetary_resolution.dart:175` y `database_helper.dart:1720-1725`. Residuales dormidos: SQL `tasa_cambio > 1.0` en `database_helper.dart:1709` y fallback 850 en `:1721`.
- **M-02:** **parcial**. `fromJson` usa epoch 0 para fecha ausente/no parseable, pero `DateTime.tryParse('2026-02-30')` normaliza a `2026-03-02` y puede conservar `esReferencia: false`. Sin consumidores en producción.
- **M-03 y M-04:** no resueltos, diferidos a U3/U4. `review_expense_screen.dart:247-255` conserva `<= 50.0`; el timestamp se valida solo con `DateTime.tryParse`.
- **M-05:** **no resuelto**. La rescisión `_onKeyWriteConfirmed` solo cubre escrituras internas de `ExchangeRateService`. `SettingsProvider.setTasaCambio` escribe `prefTasaCambio` sin rescindir un `remove` pendiente, y el replay posterior puede borrar la tasa manual. Además, el bucle de borrado `exchange_rate_service.dart:894-908` no revalida el valor actual antes de `prefs.remove` (TOCTOU). El test de M-05 es vacuo: `getAllTodayRates` reproduce primero el `remove` pendiente y la escritura fresca ocurre después.
- **M-06:** mitigación incompleta. El estado estático sigue indexado solo por clave y depende de M-08.
- **M-07:** **parcial**. Los tests 13/14 usan montos reales y distinguen 100.0 de 42.105/NaN, pero no ejercitan `setTasasReferencia`; esa cobertura queda solo en B-05, que falla.
- **M-08:** **no resuelto**. `resetPendingPurgeOperationsForTesting` pone `_activePurgeFuture = null` sin cancelar ni esperar una purga en vuelo; el `finally` de `ensure` limpia incondicionalmente la referencia y puede borrar la de una purga más nueva, habilitando purgas concurrentes tras un reset.
- **N-01 a N-08:** registrados en el informe de la quinta reauditoría. Incluyen B-05, las dos causas raíz de M-05, el conteo de B-02, el `bool` ignorado en `setTasaCambio`, inconsistencias documentales, fechas imposibles en `fromJson` y residuales SQL/850.
- **Validación:** **113 pruebas inspeccionadas, 0 ejecutadas**. Cero `flutter analyze`, cero `flutter test`, cero CI.
- **Git:** cero commits, cero push. Working tree local únicamente.

### 2.6 Historial de la cuarta reauditoría (resultados originales)

> **Nota:** esta subsección conserva el resultado original de la cuarta reauditoría. No debe confundirse con el estado corregido posterior ni con el veredicto vigente de §2.5.

- **Informe:** `auditorias/cuarta-reauditoria-u1-u2-deepseek.md`. **Veredicto original: RECHAZADO ❌**.
- **Bloqueantes originales:** **B-01** (import faltante de `ExchangeRateService`), **B-02** (tres aserciones de conteo que esperaban `1` y recibían `0`), **B-03** (prueba obsoleta `<= 50.0`), **B-04** (`MissingPluginException` por `SharedPreferences` sin mock).
- **Recomendaciones originales:** **M-01** (unicidad real de D-08), **M-02** (frescura inventada en `fromJson`), **M-03** (`> 50.0` residual), **M-04** (`DateTime.tryParse` permisivo), **M-05** (rescate de `remove` pendiente), **M-06** (estado estático), **M-07** (cobertura vacua de tests 13/14), **M-08** (aislamiento entre pruebas).
- **Validación original:** **72 pruebas inspeccionadas, 0 ejecutadas**. Sin SDK local; sin CI.

### 2.7 Correcciones de la cuarta reauditoría: estado de validación

- **B-01:** import explícito presente en `test/providers/gasto_provider_rate_cache_test.dart:7`. Corregido por inspección; no validado por CI.
- **B-02:** `PendingPurgeOperation.entriesCleanedCount` y replay con `cleanedCount += op.entriesCleanedCount`. El test de `disk` existe (`exchange_rate_service_cache_purge_test.dart:1235-1277`). Corregido en lo esencial; discrepancia N vs 1 en eliminación de mapa completo.
- **B-03:** test reescrito con `0.5`, `1.0`, `NaN` y conservación de `40.0`/`43.2` (`exchange_rate_service_test.dart:168-196`). Corregido por inspección.
- **B-04:** `SharedPreferences.setMockInitialValues({})` en `setUp` (`settings_provider_rate_cache_test.dart:51-59`) y test de 60/65/62 (`:157-170`). Corregido por inspección; el título del test sigue siendo inexacto.
- **M-01:** corregido en los tres consumidores; residuales SQL/850 fuera del alcance inmediato.
- **M-02:** parcial; no cubre fechas imposibles.
- **M-05 y M-08:** **NO resueltos**. No deben declararse cerrados.
- **M-07:** parcial.
- **Inventario:** el total auditado en la quinta reauditoría es de **113 pruebas**, no 115. La tabla histórica de `correcciones-cuarta-reauditoria-u1-u2.md:100-112` contiene cifras por suite desalineadas.
- **`scratch/check_syntax.js`:** el archivo **no existe actualmente**. La afirmación de haberlo ejecutado no es reproducible y no debe usarse como evidencia de validación.
- **`ExchangeRatesData.fromJson`:** comportamiento actual = epoch 0 para fecha ausente/no parseable; las fechas imposibles aún pueden normalizarse vía `DateTime.tryParse`. La descripción anterior que mencionaba `DateTime.now()` está obsoleta.
- **Compuerta:** U3/U4 **no deben comenzar** hasta que se corrijan B-05, M-05 y M-08, la sexta reauditoría emita veredicto favorable, CI esté en verde y César autorice expresamente. **No hay autorización para commit ni push.**

---

## 3. Decisiones de Política Monetaria Aprobadas (`D-01` a `D-08`) y Próximo Paso Inmediato

### 3.1 Estado de las decisiones `D-01` a `D-08`
Las decisiones **`D-01` a `D-08`** han sido **APROBADAS** por el propietario del producto y registradas formalmente en [`docs/rm-03/decisiones.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/decisiones.md#L189), manteniendo 100% vigentes las decisiones `A-01` a `A-16` y el `contrato-v1.2.md`:

1. **`D-01` y `D-02` (Eliminación de `850.0`, exactitud por fecha efectiva y referencias):**
   - Prohibido usar `AppConstants.defaultTasaCambio = 850.0` como tasa efectiva o fallback (`NEW-4`).
   - La clasificación de una tasa depende de su `fechaEfectiva` respecto a la fecha del gasto: `actualizada` (obtenida y validada en vivo), `exacta` (`fechaEfectiva == fechaGasto` o último cierre hábil oficial inmediato verificado, incluso si proviene de caché) y `referencia` (`fechaEfectiva` anterior que no cumple cierre hábil inmediato).
   - Las referencias conservan su fecha efectiva y fuente real, exigen confirmación al guardar el gasto y muestran advertencia reforzada si superan 5 días de antigüedad (`O3`).
2. **`D-03` y `D-04` (Ausencia de tasa, independencia por mercado y vigencia de `A-01`):**
   - `USD`, `EUR` y `USDT` son mercados estrictamente independientes; prohibido sustituir una moneda con la tasa de otra.
   - En Fase 0A (`SQLite v18`), se mantiene vigente `A-01` y `contrato-v1.2.md`: no se guardan gastos nuevos con tuples incompletos ni equivalencias `null`. Si falta una tasa, se busca exclusivamente la última tasa válida del mismo mercado o se exige ingreso manual en `"Ajustar tasas"` / conexión. El modo *standby* queda diferido a `0A.1` / Fase 0B.
3. **`D-05` (Tasas automáticas vs. tasa manual global vs. tasa manual por gasto — `NEW-3b`):**
   - Se distinguen explícitamente: (1) última tasa automática registrada, (2) tasa manual global configurada por el usuario, y (3) tasa manual de un gasto individual.
   - La tasa manual global conserva su procedencia manual y persiste al reiniciar prevaleciendo sobre cachés automáticas anteriores mientras no haya red; cuando vuelve Internet se actualiza con la cotización en vivo validada. La tasa manual de un gasto individual jamás se sobrescribe, y ninguna tasa manual se convierte automáticamente en tasa `BCV`, `EUR oficial` o `USDT P2P`.
4. **`D-06` (Tres estados independientes por moneda y fallos de purga — `NEW-2`, `NEW-5`, `B2`):**
   - `USD`, `EUR` y `USDT` registran independientemente los estados `actualizada`, `referencia` y `sinTasa` (sin usar un único booleano global). El estado `sinTasa` nunca se etiqueta como `referencia`.
   - Si la purga falla (`-1`), no se consumen tasas no verificadas del disco (`A-07`); las tasas ya validadas en memoria durante la sesión activa se conservan como `referencia` cuando corresponda; las monedas sin tasa verificada quedan en `sinTasa`. Una tasa en vivo validada actualiza la memoria aunque falle su persistencia local, y la marca de purga solo se fija tras confirmar limpieza persistente en disco (`NEW-1`).
5. **`D-07` (Denominaciones visuales canónicas):**
   - Utilizar `"Última tasa registrada"` (con fecha y fuente), `"Tasa manual"` (procedencia manual) y `"Sin tasa disponible"` (`—`). Confirmación al guardar el gasto, sin banners intrusivos en la calculadora.
6. **`D-08` (Criterio canónico de validez numérica — `NEW-3`):**
   - El criterio único en todas las rutas es `val is num && val.isFinite && val > 1.0` (eliminando el umbral divergente de `50.0` como criterio general). Esta validación numérica no sustituye la validación de mercado, procedencia, fecha efectiva ni correspondencia entre monedas.

### 3.2 Hoja de ruta obligatoria para las próximas tareas
1. **Estado vigente de las unidades:**
   - **`E0-02` continúa ABIERTA**. La quinta reauditoría emitió **RECHAZADO ❌**.
   - **U1 y U2 no están formalmente aceptadas ni completadas.** B-01 a B-04 están corregidos según inspección, pero no validados por CI. **B-05**, **M-05** y **M-08** siguen pendientes; M-02 y M-07 son parciales.
   - **U3 y U4 no deben comenzar** hasta que se corrijan B-05, M-05 y M-08, la sexta reauditoría emita veredicto favorable y CI esté en verde.
   - **`E0-03` continúa NO AUTORIZADA ⏸️.**
2. **Corregir B-05, M-05 y M-08** y añadir las pruebas rojo→verde descritas en `auditorias/quinta-reauditoria-u1-u2-deepseek.md`.
3. **Someter el árbol corregido a una sexta reauditoría adversarial independiente.**
4. **No autorizar commit, push ni CI** hasta que exista veredicto favorable y César lo autorice expresamente. `E0-03` sigue bloqueada.

---

## 4. Estado de Validación y Entorno Técnico

- **Entorno Local:** Sin SDK de Flutter ni Dart (`Get-Command flutter, dart` falló). Sin `gh`.
- **Herramientas Ejecutadas en esta tarea:** solo lectura e inspección estática. **No se ejecutó** `node scratch/check_syntax.js` (el archivo no existe), **ni** `flutter analyze`, **ni** `flutter test`, **ni** CI.
- **Validación de la quinta reauditoría:** inspección estática exclusivamente. **113 pruebas inspeccionadas, 0 ejecutadas**.
- **Estado de CI:** Ningún commit nuevo ha sido enviado a CI. `HEAD` en `origin/main` permanece en `de17323`.
- **Restricciones de Integridad Verificadas:**
  - SQLite: `version: 18` inalterado en `DatabaseHelper`.
  - Firestore: `firestore.rules` 100% intacto.
  - Dependencias: `pubspec.yaml` intacto. **`pubspec.lock` no existe ni está versionado** (condición preexistente).
  - Git: Cero commits, cero push. Sin autorización para commit ni push.

---

## 5. Historial de Auditorías en `docs/rm-03/auditorias/`

1. [`primera-auditoria-adversarial-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/primera-auditoria-adversarial-deepseek.md): Informe original de la primera auditoría adversarial independiente. Veredicto: RECHAZADO.
2. [`reauditoria-postparche-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/reauditoria-postparche-deepseek.md): Informe original de la reauditoría postparche independiente. Veredicto: RECHAZADO.
3. [`segunda-reauditoria-b1-n1-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/segunda-reauditoria-b1-n1-deepseek.md): Reconstrucción técnica estructurada y veredicto de la segunda reauditoría adversarial (B1/N1 corregidos; B2, B3, B4, B5 y O1-O8 pendientes). Veredicto: RECHAZADO.
4. [`informe-consolidacion-documentacion-rm-03.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/informe-consolidacion-documentacion-rm-03.md): Informe de consolidación de la documentación central y persistente de RM-03.
5. [`implementacion-b2-b3-b5.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/implementacion-b2-b3-b5.md): Informe de implementación del parche focalizado de corrección de B2, B3, B5, O5, O2 y suites B4. Estado: PARCHE IMPLEMENTADO, PENDIENTE DE REAUDITORÍA.
6. [`tercera-reauditoria-b2-b3-b5-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/tercera-reauditoria-b2-b3-b5-deepseek.md): Tercera reauditoría adversarial independiente. B1, N1, B3 (dominio numérico), B5 y O5 corregidos; B2/B4/O2 parciales; NEW-1 a NEW-6 y B3-OBS abiertos. Veredicto: **RECHAZADO ❌**.
7. [`implementacion-u1-u2.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/implementacion-u1-u2.md): Informe técnico de implementación de las unidades U1 y U2. Corrección de NEW-1, NEW-3, NEW-6, B3-OBS y O2. Estado: implementación descrita, **sin veredicto de aceptación**.
8. [`cuarta-reauditoria-u1-u2-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/cuarta-reauditoria-u1-u2-deepseek.md): Cuarta reauditoría adversarial independiente sobre U1 (D-08) y U2 (NEW-1 + O2). Cuatro bloqueantes (B-01 compilación, B-02 conteo de reintento, B-03 prueba obsoleta `<= 50.0`, B-04 `SharedPreferences` sin mock) y ocho observaciones (M-01 a M-08). 72 pruebas inspeccionadas, 0 ejecutadas. Veredicto: **RECHAZADO ❌**. U1/U2 no aceptadas.
9. [`correcciones-cuarta-reauditoria-u1-u2.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/correcciones-cuarta-reauditoria-u1-u2.md): Informe de corrección de los 4 bloqueantes (B-01 a B-04) y recomendaciones M-01, M-02, M-05, M-07 y M-08. 115 pruebas inspeccionadas, 0 ejecutadas. Estado: **CORRECCIONES IMPLEMENTADAS, PENDIENTE DE QUINTA REAUDITORÍA.** (Cifra documentada en ese informe; el conteo real verificado en la quinta reauditoría es **113**, no 115.)
10. [`quinta-reauditoria-u1-u2-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/quinta-reauditoria-u1-u2-deepseek.md): Quinta reauditoría adversarial independiente. B-01 a B-04 corregidos por inspección; nuevo bloqueante B-05 (test determinista sin `await`); M-05 y M-08 no resueltos; M-02 y M-07 parciales; N-01 a N-08. **113 pruebas inspeccionadas, 0 ejecutadas**, 0 CI. Veredicto: **RECHAZADO ❌**. U1/U2 no aceptadas ni completadas.
