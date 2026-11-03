# RM-03 — Informe Técnico de Correcciones de la Cuarta Reauditoría (U1/U2)

> **Documento:** Informe técnico de correcciones tras la cuarta reauditoría adversarial independiente (DeepSeek).  
> **Unidad:** `E0-02` — Dominio monetario, tupla y purga de caché A-07 (Unidades U1 y U2).  
> **Fecha:** Noviembre de 2026.  
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md`.  
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (`A-01` a `A-16` y `D-01` a `D-08`).  
> **Auditoría atendida:** `docs/rm-03/auditorias/cuarta-reauditoria-u1-u2-deepseek.md` (Veredicto: RECHAZADO).  
> **Estado de implementación:** **CORRECCIONES IMPLEMENTADAS, PENDIENTE DE QUINTA REAUDITORÍA INDEPENDIENTE.**  
> **Estado de Git:** Cero commits, cero push. Modificaciones confinadas exclusivamente al working tree local.  
> **Estado de E0-02:** **NO CERRADO** (pendiente de auditoría adversarial independiente favorable y validación en CI).  
> **Validación local:** Inspección estática exclusiva (cero `flutter test`, cero `flutter analyze`; entorno sin SDK local).

---

## 1. Resumen Ejecutivo de la Tarea

La cuarta reauditoría adversarial independiente evaluó las unidades U1 y U2 implementadas en el working tree local y emitió un veredicto de **RECHAZADO ❌**. Dicho veredicto no cuestionó la arquitectura central de U2 (diseño de operaciones pendientes, fail-closed y confirmación en disco, la cual fue calificada como sólida y sin necesidad de rediseño), sino que se fundamentó en **cuatro bloqueantes técnicos y deterministas (B-01 a B-04)** que impedían la compilación o causaban fallos en la suite de pruebas, acompañados de recomendaciones medias y bajas (M-01 a M-08).

En la presente tarea se intervinieron puntualmente los archivos de producción y pruebas para resolver con rigor los cuatro bloqueantes y las cinco recomendaciones prioritarias de U1/U2, preservando intactos todos los invariantes normativos y sin comenzar las unidades U3/U4.

---

## 2. Matriz de Hallazgos y Correcciones

| ID | Severidad | Estado | Ubicación Principal | Cambio Concreto Realizado |
| :--- | :--- | :--- | :--- | :--- |
| **B-01** | **Bloqueante** | **Resuelto** | `test/providers/gasto_provider_rate_cache_test.dart` | Añadido el import explícito `import 'package:gastoscan_ai/services/exchange_rate_service.dart';`. Resuelve el error de compilación (`undefined_identifier: ExchangeRateService`) en L80/L115 sin recurrir a exports transitivos. |
| **B-02** | **Bloqueante** | **Resuelto** | `lib/services/exchange_rate_service.dart`<br>`test/services/exchange_rate_service_cache_purge_test.dart` | Implementada la **Opción A**: `PendingPurgeOperation` almacena `entriesCleanedCount`. Al confirmarse exitosamente en disco el reintento de una operación pendiente (`setString` o `remove`), se incrementa `cleanedCount += op.entriesCleanedCount`. Se actualizó el docstring de `purgarCacheHistoricaInvalida` definiendo exactamente qué representa el contador. Se verificó que las expectativas L463, L739 y L805 se satisfacen deterministamente y se añadió una prueba de validación física de `disk`. |
| **B-03** | **Bloqueante** | **Resuelto** | `test/services/exchange_rate_service_test.dart` | Se reescribió la prueba de L158 eliminando el umbral obsoleto `<= 50.0`. Ahora utiliza valores verdaderamente inválidos bajo **D-08** (`0.5`, `1.0`, `NaN`) y fue renombrada a `ignora valores no validos (<= 1.0, NaN) en cache previa bajo D-08`. Se añadió un caso de prueba independiente que demuestra que tasas válidas bajo D-08 (ej. `40.0` y `43.2`) sí se conservan cuando la red falla. |
| **B-04** | **Bloqueante** | **Resuelto** | `test/providers/settings_provider_rate_cache_test.dart` | Añadido `SharedPreferences.setMockInitialValues({})` en el `setUp` de la suite. Esto inicializa el canal de plataforma antes de las llamadas a `getInstance()` de `ExchangeRateService.getAllTodayRates` y `SettingsProvider.actualizarTasaAutomatica`, erradicando `MissingPluginException` y permitiendo verificar la aplicación correcta de las tasas 60/65/62. |
| **M-01** | Media | **Resuelto** | `lib/domain/monetary/rate_quote_input.dart`<br>`lib/domain/monetary/monetary_resolution.dart`<br>`lib/data/datasources/local/database_helper.dart` | Sustituidas las comprobaciones duplicadas inline (`!valor.isFinite || valor <= 1.0`, `!rOrig.isFinite || rOrig <= 1.0`, `nuevaTasa <= 1.0`) por el predicado canónico `isValidMonetaryRate`. En `database_helper.dart:1719`, esto erradica el comportamiento inseguro de `NaN <= 1.0` (que evaluaba a `false` permitiendo que valores no numéricos eludieran el fallback) y garantiza finitud y rango en SQLite sin ciclos de dependencias. |
| **M-02** | Media | **Resuelto** | `lib/services/exchange_rate_service.dart`<br>`test/services/exchange_rate_service_cache_purge_test.dart` | Se eliminó la fabricación de frescura en `ExchangeRatesData.fromJson`: si `fecha` es nula, no interpretable o anómala, se asigna epoch 0 (`DateTime.fromMillisecondsSinceEpoch(0)`) y se fuerza `esReferencia: true`. Se añadieron pruebas unitarias específicas para `{'fecha': 12345, 'esReferencia': false}` y para entradas sin fecha. Se constató que `fromJson` carece de consumidores en producción (`lib/`), quedando confinado a pruebas y utilidades. |
| **M-05** | Media | **Resuelto** | `lib/services/exchange_rate_service.dart`<br>`test/services/exchange_rate_service_cache_purge_test.dart` | Se incorporó el método `_onKeyWriteConfirmed(String key)` en `ExchangeRateService`, invocado inmediatamente después de confirmar la persistencia exitosa en disco de una tasa fresca en `getAllTodayRates` y `getRateForDate`. Esto rescinde selectivamente la operación `PendingPurgeOperation.remove` para esa clave específica, impidiendo que una purga posterior borre una tasa válida recién adquirida. Se añadió un caso de prueba exhaustivo que reproduce la secuencia sin `reloadFromDisk()`. |
| **M-07** | Baja | **Resuelto** | `test/providers/gasto_provider_rate_cache_test.dart` | Se reconfiguró `FakeGastoRepositoryForProvider` con montos reales y no vacíos (`USD: 100.0`, `VES: 4000.0`). Los tests 13 y 14 ahora observan el comportamiento real y determinista de `provider.getSpentForCategory('Alimentos', moneda: 'EUR')`: al rechazarse la tasa no verificada (95.0 en test 13) o no finita (Infinity en test 14), `effEur` permanece en 0.0 y el cálculo devuelve exactamente el monto base en USD (100.0), diferenciándose con precisión de una conversión indebida (`4000 / 95 = 42.105` o `0.0/NaN`). Se evitó la exposición innecesaria de getters de producción. |
| **M-08** | Baja | **Resuelto** | `lib/services/exchange_rate_service.dart`<br>Suites de pruebas de servicios y providers | Se amplió `ExchangeRateService.resetPendingPurgeOperationsForTesting()` para limpiar `_activePurgeFuture = null` además de `_pendingPurgeOperations` y `_purgeMarkPendingConfirmation`. Se aseguró la invocación de este reset en `setUp` y `tearDown` en las cuatro suites pertinentes (`gasto_provider_rate_cache_test`, `settings_provider_rate_cache_test`, `exchange_rate_service_test` y `exchange_rate_service_cache_purge_test`). |
| **M-03** | Media | **No resuelto (Diferido a U3/U4)** | `lib/ui/screens/review_expense_screen.dart:247-255` | El umbral residual `> 50.0` se conserva en la pantalla de revisión de gastos por ser alcance exclusivo de la unidad posterior U3/U4 (modelo de tres vías e integración visual). La aclaración documental que delimita este alcance fue incorporada en `implementacion-u1-u2.md:53`. |
| **M-04** | Media-baja | **No resuelto (Fuera de criterio U1/U2)** | `lib/services/exchange_rate_service.dart:862` | La normalización permisiva de `DateTime.tryParse` sobre cadenas como `"2026-02-30"` afecta únicamente al metadato informativo de timestamp, no altera tasas de cambio ni compromete cálculos financieros. Queda documentada para refinamiento en etapas posteriores. |
| **M-06** | Baja | **Mitigado (Sin impacto en producción)** | `lib/services/exchange_rate_service.dart:557` | El registro estático de operaciones pendientes opera sobre la instancia única de `SharedPreferences` de la aplicación en producción. En el arnés de pruebas, el aislamiento entre tests queda 100% blindado mediante `setUp`/`tearDown` (M-08). |

---

## 3. Detalle Técnico de Modificaciones por Archivo

### 3.1 `lib/services/exchange_rate_service.dart`
1. **`PendingPurgeOperation` (L71-90):**
   - Incorporado el campo inmutable `final int entriesCleanedCount`.
   - Inicializado por defecto en `1` para operaciones de eliminación (`remove`) y parametrizado para mutaciones de mapas serializados (`setString`).
2. **`ExchangeRatesData.fromJson` (L34-63):**
   - Si `json['fecha']` no es `String` o `DateTime.tryParse` devuelve `null`, se asigna `DateTime.fromMillisecondsSinceEpoch(0)` (epoch 0) y se impone obligatoriamente `esReferencia: true`, erradicando la fabricación de frescura (M-02).
3. **Rescisión de `remove` pendiente ante tasa fresca (M-05):**
   - Incorporado el método auxiliar `@visibleForTesting static void _onKeyWriteConfirmed(String key) { _pendingPurgeOperations.remove(key); }`.
   - Invocado tras cada escritura exitosa confirmada (`setDouble` / `setString`) en `getAllTodayRates` (gateway y cascada directa DolarAPI/Yadio) y en `getRateForDate` (históricos DolarAPI y Fawaz Ahmed).
4. **Reseteo completo de estado estático (M-08):**
   - `resetPendingPurgeOperationsForTesting()` limpia ahora `_activePurgeFuture = null` junto con `_pendingPurgeOperations` y `_purgeMarkPendingConfirmation`.
5. **Contrato de conteo en `purgarCacheHistoricaInvalida` (B-02 / Opción A):**
   - En el bucle de reintento de operaciones pendientes (L695-725), al confirmarse exitosamente en disco una operación de tipo `setString` o `remove`, se incrementa `cleanedCount += op.entriesCleanedCount`.
   - En la detección de claves corruptas, `PendingPurgeOperation.setString` almacena `entriesCleanedInMap` y `PendingPurgeOperation.remove` almacena `1`.
   - Se actualizó el docstring del método para documentar que retorna el número total de entradas eliminadas o depuradas confirmadas físicamente en disco durante la llamada (incluyendo reintentos previos exitosos).

### 3.2 `lib/domain/monetary/rate_quote_input.dart`
- En L76, sustituida la comprobación `if (!valor.isFinite || valor <= 1.0)` por `if (!isValidMonetaryRate(valor))` (M-01). El archivo ya importaba `rate_market.dart`.

### 3.3 `lib/domain/monetary/monetary_resolution.dart`
- Añadido el import `import 'rate_market.dart';`.
- En L174, sustituida la comprobación `} else if (!rOrig.isFinite || rOrig <= 1.0) {` por `} else if (!isValidMonetaryRate(rOrig)) {` (M-01).

### 3.4 `lib/data/datasources/local/database_helper.dart`
- Añadido el import `import '../../../domain/monetary/rate_market.dart';`.
- En `repararTasasHistoricasIncompletas` (L1719-1735), se sustituyó `if (nuevaTasa <= 1.0)` y `if (nuevaTasa > 1.0)` por `if (!isValidMonetaryRate(nuevaTasa))` e `if (isValidMonetaryRate(nuevaTasa))`, protegiendo la actualización frente a `NaN` o valores no finitos (M-01). Se preserva `_dbVersion = 18` inalterado.

### 3.5 `test/providers/gasto_provider_rate_cache_test.dart`
- Incorporado el import explícito `import 'package:gastoscan_ai/services/exchange_rate_service.dart';` (B-01) y `import 'package:shared_preferences/shared_preferences.dart';`.
- Configurado `FakeGastoRepositoryForProvider` con totales de prueba reales (`USD: 100.0`, `VES: 4000.0`).
- Incorporado `setUp` con `SharedPreferences.setMockInitialValues({})` y `resetPendingPurgeOperationsForTesting()`, y `tearDown` de aislamiento (M-08).
- Escenarios 13 y 14 actualizados con aserciones deterministas de comportamiento observable mediante `getSpentForCategory('Alimentos', moneda: 'EUR')`, comprobando que ante tasas rechazadas el cálculo recurre fielmente a la moneda base (100.0) y no a conversiones erróneas (M-07).

### 3.6 `test/providers/settings_provider_rate_cache_test.dart`
- Incorporados los imports de `shared_preferences.dart` y `exchange_rate_service.dart`.
- Añadido `SharedPreferences.setMockInitialValues({})` y `resetPendingPurgeOperationsForTesting()` en `setUp`, y `tearDown` correspondiente (B-04 y M-08).

### 3.7 `test/services/exchange_rate_service_test.dart`
- Incorporado aislamiento estático con `resetPendingPurgeOperationsForTesting()` en `setUp` y `tearDown` en los grupos `getRateForDate Tests` y `esReferencia Tests` (M-08).
- Reescribo el test de L158 con valores inválidos bajo D-08 (`0.5`, `1.0`, `NaN`) y renombrado acordemente (B-03).
- Añadido test separado que verifica que tasas válidas (`40.0`, `43.2`) se conservan en caché cuando la red falla (B-03).

### 3.8 `test/services/exchange_rate_service_cache_purge_test.dart`
- Añadido `tearDown` con `resetPendingPurgeOperationsForTesting()` (M-08).
- Actualizado el test de `fromJson` para validar que fechas ausentes o corruptas degradan a epoch 0 y fuerzan `esReferencia: true` (M-02).
- Verificadas las aserciones de conteo en L463, L739 y L805 bajo el contrato de la Opción A (B-02).
- Añadido grupo `B-02: Comprobación estricta del estado físico de disk tras reintento de operaciones pendientes` con un test de múltiples fallos concurrentes (`setString` y `remove`) y validación de `store.disk`.
- Añadido grupo `M-05: Rescisión de operación remove pendiente ante confirmación de tasa fresca` con test determinista de flujo completo sin `reloadFromDisk()`.

---

## 4. Pruebas Añadidas y Estado de Ejecución

### 4.1 Inventario de Pruebas Diseñadas y Corregidas

| Suite | Pruebas Totales | Pruebas Añadidas / Modificadas | Propósito de la Verificación |
| :--- | ---: | :--- | :--- |
| `test/providers/gasto_provider_rate_cache_test.dart` | 4 | 4 modificadas | B-01 (import), M-07 (cobertura observable en getSpentForCategory), M-08 (aislamiento en setUp). |
| `test/providers/settings_provider_rate_cache_test.dart` | 6 | 2 modificadas | B-04 (setMockInitialValues), M-08 (aislamiento en setUp/tearDown). |
| `test/services/exchange_rate_service_test.dart` | 15 | 2 modificadas/añadidas | B-03 (reescritura de prueba <= 50.0 a <= 1.0; test de conservación de 40.0/43.2), M-08 (aislamiento). |
| `test/services/exchange_rate_service_cache_purge_test.dart` | 42 | 4 añadidas/modificadas | B-02 (test de validación física de disk en reintento), M-02 (test fromJson epoch 0), M-05 (test de rescisión de remove ante tasa fresca), M-08 (tearDown). |
| `test/domain/monetary/rate_market_test.dart` | 8 | 0 (intactas) | Validador puro D-08. |
| `test/domain/monetary/rate_quote_input_test.dart` | 11 | 0 (intactas) | Validación tipada de procedencia y mercado. |
| `test/domain/monetary/resolve_persisted_expense_test.dart` | 15 | 0 (intactas) | Resolución de lentes monetarios. |
| `test/domain/monetary/build_new_expense_tuple_test.dart` | 10 | 0 (intactas) | Construcción de tuplas y bloqueo EUR+BS_USDT. |
| `test/domain/monetary/resumen_lente_monetario_test.dart` | 4 | 0 (intactas) | Agregaciones monetarias puras. |

**Total de pruebas en el arnés monetario de E0-02:** **115 pruebas inspeccionadas.**

### 4.2 Declaración Expresa de Honestidad de Validación
- **Pruebas ejecutadas en esta máquina:** **0**.
- **Pruebas inspeccionadas estáticamente:** **115**.
- **Herramientas locales ejecutadas:**
  - `node scratch/check_syntax.js`: balanceo de símbolos y análisis sintáctico de los 8 archivos modificados. Resultado: **ALL FILES BALANCED AND SYNTACTICALLY SOUND!**
  - `powershell scripts/check_rules.ps1`: verificación de límites de reglas Antigravity. Resultado: **PASO con advertencias (0 errores)**.
- **Validaciones no ejecutadas (imposibles localmente):** `flutter analyze --fatal-warnings`, `flutter test`, compilación Gradle / Android. Estas validaciones corresponden estrictamente al pipeline de GitHub Actions CI.

---

## 5. Verificación de Invariantes del Proyecto

- **Esquema SQLite:** `_dbVersion = 18` inalterado en `DatabaseHelper.dart`. Cero migraciones de esquema añadidas.
- **Unidades U3 y U4:** Cero líneas de código implementadas de U3/U4. El default de presentación `850.0` y el booleano `_tasasSonReferencia` continúan en su estado preexistente, pendientes de sus unidades formalmente autorizadas.
- **Firestore Rules y Dependencias:** `firestore.rules` 100% intacto. `pubspec.yaml` 100% intacto. `pubspec.lock` no versionado (condición preexistente).
- **Control de Versiones:** Cero commits realizados. Cero push ejecutados. Árbol de trabajo listo para revisión.

---

## 6. Estado Git al Cierre de la Tarea

```text
M MEMORY.md
M lib/data/datasources/local/database_helper.dart
M lib/data/models/gasto_firestore_mapper.dart
M lib/data/models/gasto_model.dart
M lib/providers/gasto_provider.dart
M lib/providers/settings_provider.dart
M lib/services/exchange_rate_service.dart
M test/models/gasto_firestore_mapper_test.dart
M test/services/exchange_rate_service_test.dart
?? docs/rm-03/
?? lib/domain/monetary/
?? test/domain/monetary/
?? test/providers/gasto_provider_rate_cache_test.dart
?? test/providers/settings_provider_rate_cache_test.dart
?? test/services/exchange_rate_service_cache_purge_test.dart
```

---

## 7. Conclusión y Próximos Pasos

Todos los defectos bloqueantes (B-01 a B-04) y las recomendaciones pertinentes (M-01, M-02, M-05, M-07, M-08) identificadas en la cuarta reauditoría adversarial han sido resueltos y verificados sintácticamente. Las unidades U1 y U2 quedan listas para ser sometidas a una **quinta reauditoría adversarial independiente**.

**Las unidades U1 y U2 permanecen NO COMPLETADAS. E0-02 no se considera cerrado. U3 y U4 no deben comenzar hasta obtener un veredicto favorable en la nueva auditoría y confirmación de CI en verde.**
