# RM-03 — Segunda Reauditoría Adversarial de E0-02 (DeepSeek)

> **Tipo de documento:** Resumen técnico estructurado y veredicto de la segunda reauditoría adversarial independiente.  
> **Nota de procedencia:** Este documento reconstruye formalmente los hallazgos técnicos respaldados por el pliego y contexto operativo de la tarea RM-03. No finge ser una transcripción textual íntegra de sesión, preservando con rigor técnico los defectos evaluados, su estado y las condiciones de aceptación.  
> **Veredicto general:** **RECHAZADO ❌**  
> **Unidad evaluada:** E0-02 (Dominio monetario, tupla y purga de caché A-07 en `lib/services/exchange_rate_service.dart`).

---

## 1. Veredicto y Resumen Ejecutivo

La segunda reauditoría adversarial independiente evaluó el estado de la unidad **E0-02** tras la implementación de las correcciones sobre los bloqueantes B1 y N1.

**Veredicto: RECHAZADO.**

Aunque los bloqueantes **B1** (destrucción del historial ante excepciones de `prefs.setString`) y **N1** (consumo de tasas no finitas o `<= 1.0` en `getRateForDate`) fueron resueltos en `ExchangeRateService`, la unidad no puede darse por aprobada ni cerrarse debido a la persistencia de defectos bloqueantes pendientes (**B2**, **B3**, **B5**), cobertura de pruebas insuficiente (**B4**) y observaciones de contención abiertas (**O1 a O8**).

---

## 2. Matriz de Hallazgos Bloqueantes (B1 a B5)

| ID | Componente / Archivo | Estado | Severidad | Descripción Técnica y Consecuencia |
| :--- | :--- | :--- | :--- | :--- |
| **B1** | `ExchangeRateService.purgarCacheHistoricaInvalida` | **CORREGIDO ✅** | Bloqueante | **Aislamiento de persistencia en purga:** Previamente, si `prefs.setString` fallaba o lanzaba excepción, el `catch` exterior asumía corrupción del JSON y borraba el mapa histórico íntegro en disco, fijando la marca de purga. Se corrigió separando estrictamente la decodificación de la escritura; ante fallo de persistencia, el historial original se preserva intacto en disco. |
| **N1** | `ExchangeRateService.getRateForDate` | **CORREGIDO ✅** | Bloqueante | **Validación de dominio en punto de consumo:** Previamente se aceptaban tasas de caché o remotas con cualquier valor `> 0` (incluyendo `0.5`, `NaN` o `Infinity`). Se corrigió exigiendo `isFinite && rate > 1.0` y adoptando comportamiento *fail-closed* (si la purga retorna `-1`, se bloquea el uso de caché no verificada). |
| **B2** | `SettingsProvider` y `GastoProvider` | **PENDIENTE ⏸️** | Bloqueante | **Consumo de tasas no finitas o caché no verificada:** `SettingsProvider` (`_tasaCambioVesUsd`, `_tasaCambioVesUsdt`, `_tasaCambioVesEur`) y `GastoProvider` aún carecen de guardas completas contra valores no finitos (`NaN`, `Infinity`) y pueden consumir claves de `SharedPreferences` sin comprobar si la purga A-07 completó satisfactoriamente. |
| **B3** | `ExchangeRatesData.fromJson` | **PENDIENTE ⏸️** | Bloqueante | **Aceptación de tasas fuera de dominio en deserialización:** El constructor de fábrica `ExchangeRatesData.fromJson` no valida que las tasas numéricas sean finitas y estrictamente `> 1.0`, permitiendo que cargas externas o del gateway inyecten tasas corruptas en la memoria viva de la app. |
| **B4** | `test/services/exchange_rate_service_cache_purge_test.dart` | **PENDIENTE ⏸️** | Bloqueante | **Cobertura de pruebas insuficiente:** La suite de pruebas no verifica: (1) reintentos exitosos de purga tras fallo temporal de I/O, (2) respuestas remotas no finitas (`NaN`, `Infinity`), ni (3) el rechazo explícito de tasas `<= 1.0` o inválidas dentro de `ExchangeRatesData.fromJson`. |
| **B5** | `ExchangeRateService.purgarCacheHistoricaInvalida` | **PENDIENTE ⏸️** | Bloqueante | **Bloqueo permanente por lectura de tipo corrupto:** La lectura de `prefs.getString('tasas_historico_v1')` o de la marca de purga se realiza fuera de bloques `try/catch` defensivos. Si una clave contiene un tipo distinto de `String` (ej. `int` o `bool`), se lanza un `TypeError` no capturado que bloquea permanentemente la ejecución de la purga. |

---

## 3. Matriz de Observaciones (O1 a O8)

| ID | Área / Archivo | Estado | Descripción y Riesgo |
| :--- | :--- | :--- | :--- |
| **O1** | `ExchangeRateService` | Observación | **Aislamiento memoria vs almacenamiento:** Necesidad de garantizar que los estados volátiles en memoria no enmascaren discrepancias con las claves persistidas en disco de `SharedPreferences`. |
| **O2** | Suite de pruebas / Fakes | Observación | **Limitación del fake de `SharedPreferences`:** Los mocks/fakes de pruebas actuales no reproducen la divergencia entre el estado en memoria y la persistencia física en disco ante fallos transitorios de I/O o excepciones simuladas de escritura. |
| **O3** | Coherencia temporal | Observación | **Fechas efectivas de tasas:** Toda tasa devuelta debe corresponder a su fecha efectiva real, evitando marcar como exactas cotizaciones del último día hábil sin metadato explícito. |
| **O4** | Validación de fechas | Observación | **Parseo estricto de calendario:** La validación de fechas históricas debe mantenerse sobre días reales de calendario (descartando `2026-02-30`, etc.), evitando regex ingenuos. |
| **O5** | `SharedPreferences` | Observación | **Semilla `tasa_cambio_ves_usd` no cubierta:** La clave de semilla predeterminada `tasa_cambio_ves_usd` no forma parte de la purga selectiva de caché, pudiendo servir de fallback silencioso corrupto si no se sanea. |
| **O6** | Logging en capas críticas | Observación | **Registro de excepciones capturadas:** Conforme a las reglas del proyecto (`AGENTS.md`), no se deben silenciar excepciones en bloques `catch (_) {}` en capas críticas como `SharedPreferences`; debe registrarse el error con contexto mediante `debugPrint`. |
| **O7** | `GastoModel.toFirestoreMap` | Observación | **Riesgo latente de método obsoleto:** `toFirestoreMap` en `GastoModel:84-88` continúa emitiendo campos nulos en lugar de omitirlos como `GastoFirestoreMapper.toPayload`. Aunque no tiene consumidores productivos hoy, representa una trampa técnica latente. |
| **O8** | Límites de alcance de E0-02 | Observación | **Postergación formal de H-1, H-2 y S3.2:** La sustitución de tasas USD por USDT (H-1 global), los getters en `GastoModel` y consumidores de presentación (H-2) y la limpieza nullable de `copyWith` (S3.2) quedan confirmados como fuera del alcance de E0-02 y formalmente asignados a E0-03 y E0-04. |

---

## 4. Estado de Garantías Globales Postergadas (Fuera de Alcance E0-02)

- **H-1 Global (USDT $\rightarrow$ USD):** Permanece abierta en `ExchangeRateService:92,126-129,405-412` y `SettingsProvider:86`. Su resolución corresponde a la unidad **E0-03**.
- **H-2 Presentación (Getters y agregaciones):** Permanece abierta en `GastoModel:208-209`, `ChatScreen:385`, `DatabaseHelper:682,757` y `CurrencyFormatter:70-74`. Su resolución corresponde a la unidad **E0-03**.
- **S3.2 (`copyWith` en `GastoModel`):** Permanece abierta en `GastoModel:158,161`. Su resolución corresponde a la unidad **E0-04**.

---

## 5. Condiciones Concretas para la Aceptación de E0-02

Para revocar el veredicto **RECHAZADO** y autorizar el cierre formal de E0-02, el equipo de desarrollo debe cumplir estrictamente las siguientes condiciones:

1. **Resolver B2:** Proteger `SettingsProvider` y `GastoProvider` para que rechacen tasas no finitas y no consuman caché local si `ensureCacheHistoricaPurgada` retornó `-1`.
2. **Resolver B3:** Agregar validación de dominio (`rate.isFinite && rate > 1.0`) en la deserialización de `ExchangeRatesData.fromJson`.
3. **Resolver B5:** Proteger las lecturas de `prefs.getString` y `prefs.getBool` en `ExchangeRateService` con comprobación de tipo previa (`prefs.get(key) is String`) o encapsulamiento en `try/catch` defensivo con logging.
4. **Completar suite de pruebas B4:** Incorporar en `exchange_rate_service_cache_purge_test.dart` los casos de prueba para reintento de purga, respuestas no finitas y validaciones de `fromJson`.
5. **Sanear O5:** Incorporar la verificación y saneamiento de la clave `tasa_cambio_ves_usd` dentro del ciclo de purga de caché.
6. **Validación en CI:** Una vez implementado el parche, la suite completa debe compilar sin advertencias fatales (`flutter analyze --fatal-warnings`) y superar todos los tests (`flutter test`) en GitHub Actions CI.
