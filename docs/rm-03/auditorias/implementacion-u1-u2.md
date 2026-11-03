# RM-03 — Informe Técnico de Implementación: Unidades U1 y U2

> **Documento:** Informe técnico de implementación de las unidades U1 y U2 (Fase 0A).  
> **Fecha:** Noviembre de 2026.  
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md`.  
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (A-01 a A-16 y D-01 a D-08).  
> **Veredicto de implementación:** **U1 Y U2 IMPLEMENTADAS, PENDIENTES DE REAUDITORÍA.**  
> **Veredicto de la cuarta reauditoría (posterior):** **RECHAZADO ❌** — ver `docs/rm-03/auditorias/cuarta-reauditoria-u1-u2-deepseek.md`. Este documento describe la implementación; **no constituye aceptación** de las unidades.
> **Estado de Git:** Cero commits, cero push. Modificaciones confinadas exclusivamente al working tree local.  
> **Estado de E0-02:** **NO CERRADO** (pendiente de auditoría adversarial independiente y validación en CI).

---

## 1. Propósito y Alcance de la Tarea

El presente informe documenta la implementación de las unidades **U1** y **U2** del plan técnico de RM-03, resolviendo de forma rigurosa los siguientes hallazgos y defectos detectados en la tercera reauditoría adversarial:

1. **NEW-1 (Bloqueante):** Marca de purga persistente fijada prematuramente por divergencia entre la caché en memoria y el almacenamiento físico en disco de `SharedPreferences`.
2. **NEW-3 (Media / Bloqueante):** Umbrales numéricos divergentes entre servicios y proveedores (`> 50.0` vs. `> 1.0`).
3. **NEW-6 (Media / Bloqueante):** Lectura insegura de `cached_exchange_rates_timestamp` con `getString` directo sin comprobación previa de tipo `String`.
4. **B3-OBS (Bloqueante de robustez):** *Casts* inseguros (`as num?`, `as bool?`) en `ExchangeRatesData.fromJson` que causaban `TypeError` ante tipos no numéricos o anómalos.
5. **O2 (Fidelidad del arnés de pruebas):** Fake `TestSharedPreferences` que devolvía `null` donde el plugin real lanza `TypeError`, no modelaba la mutación en memoria previa al fallo de `remove`, y carecía de soporte para inyectar fallos en `setDouble`.

---

## 2. Implementación de U1 — Validador Canónico D-08

### 2.1 Función Única de Dominio (`isValidMonetaryRate`)
Se incorporó en `lib/domain/monetary/rate_market.dart` la función pura canónica conforme a la Decisión **D-08**:

```dart
bool isValidMonetaryRate(dynamic value) {
  if (value is! num) return false;
  if (!value.isFinite) return false;
  return value > 1.0;
}
```

**Comportamiento certificado por diseño:**
- `0.5`: inválido (`false`).
- `1.0`: inválido (`false`).
- `0` / `0.0`: inválido (`false`).
- Negativos (`-5.0`, `-1.0`): inválidos (`false`).
- `NaN`: inválido (`false`).
- `Infinity` y `-Infinity`: inválidos (`false`).
- `45.0` y `380.0`: válidos (`true`).
- Enteros mayores a 1 (`45`, `2`): válidos (`true`).
- No numéricos (`String`, `bool`, `Map`, `List`, `null`): inválidos (`false`) sin lanzar excepción.

### 2.2 Aplicación Uniforme y Sustitución de Umbrales Divergentes
Se sustituyeron las comprobaciones manuales basadas en `> 50.0` **en los módulos incluidos en el alcance de U1** (servicio y proveedores listados abajo), adoptando `isValidMonetaryRate` conforme a D-08.

> **Corrección documental (cuarta reauditoría):** la afirmación original de que el umbral se eliminó «por completo … en todos los puntos de producción» era **demasiado amplia**. `lib/ui/screens/review_expense_screen.dart:247-255` conserva comparaciones `> 50.0` para USD, EUR y USDT. Ese remanente pertenece al alcance posterior **U3/U4** (modelo de tres estados y ajuste visual de pantallas) y no fue modificado por U1 ni por esta corrección documental.

- `lib/services/exchange_rate_service.dart`:
  - `getAllTodayRates`: lectura de semillas `cached_rate_usd`, `cached_rate_eur`, `cached_rate_usdt` y valores de retorno.
  - `_fetchUsdLiveRate`, `_fetchEurLiveRate`, `_fetchUsdtLiveRate`, `_fetchUrlDouble`: validación de respuestas de red y fallbacks.
  - `getRateForDate`: validación de tasas por fecha en caché y respuestas remotas.
  - `purgarCacheHistoricaInvalida`: filtrado en `tasas_historico_v1`, `cached_exchange_rate`, `prefTasaCambio` y `cached_rate_*`.
- `lib/providers/settings_provider.dart`:
  - `loadSettings`: lectura de semillas de SharedPreferences.
  - `actualizarTasaAutomatica`: filtrado de tasas vivas y de referencia.
  - `setTasaCambio`: validación de tasa manual ingresada por el usuario.
- `lib/providers/gasto_provider.dart`:
  - `cargarDatos`: lectura de tasas de caché local.
  - `setTasasReferencia`: validación de tasas inyectadas.

### 2.3 Deserialización Defensiva en `ExchangeRatesData.fromJson` (B3-OBS)
Se reescribió `ExchangeRatesData.fromJson` para erradicar cualquier *cast* directo (`as num?`, `as bool?`):
- `usd`, `eur`, `usdt`: aceptan exclusivamente valores evaluados positivamente por `isValidMonetaryRate(raw)`. Todo tipo incorrecto (`String`, `bool`, `List`, `Map`) o valor fuera de dominio (`0.5`, `1.0`, negativos, `NaN`, infinitos) degrada estrictamente a `0.0`.
- `esReferencia`: evalúa si `raw is bool`; si no es booleano (ej. String, int, null), degrada de forma segura a `true`.
- `fecha`: evalúa si `raw is String`; solo si es String invoca `DateTime.tryParse`, degradando a `DateTime.now()` sin invocar `.toString()` ciego sobre objetos anómalos.

### 2.4 Manejo Seguro y Purga de Timestamp de Caché (NEW-6)
- En `SettingsProvider.loadSettings` y `ExchangeRateService.getAllTodayRates`, se eliminó la invocación directa de `prefs.getString('cached_exchange_rates_timestamp')`. Se verifica `prefs.get(...) is String` antes de interpretar la fecha. Si el tipo no es String o la fecha es inválida, se trata como metadato ausente (`null` o epoch 0) sin provocar `TypeError`.
- En `ExchangeRateService.purgarCacheHistoricaInvalida`, se incorporó `cached_exchange_rates_timestamp` a la purga selectiva A-07: si la clave contiene un valor no String o una cadena no interpretable como fecha, se purga físicamente como metadato corrupto, confirmando su persistencia en disco y permitiendo reintentos.

---

## 3. Implementación de U2 — Resiliencia de Purga (NEW-1)

### 3.1 Causa Raíz Identificada
`SharedPreferences` en Android/iOS actualiza primero su caché en memoria (`_preferenceCache`) y posteriormente ejecuta la llamada asíncrona al canal de plataforma. Ante un fallo de I/O o excepción en plataforma:
- La memoria del proceso mostraba el mapa depurado o la clave eliminada.
- El almacenamiento persistente (disco/XML) conservaba los datos corruptos originales.
- En una segunda invocación en el mismo proceso, la inspección leía la memoria limpia, no ejecutaba escrituras y procedía a fijar la marca persistente `tasas_cache_historica_purgada_v1 = true`, sellando un disco permanentemente corrupto.

### 3.2 Modelo de Operaciones Pendientes (`PendingPurgeOperation`)
Para neutralizar la divergencia memoria/disco, se diseñó e implementó un registro determinista de mutaciones pendientes en `ExchangeRateService`:

```dart
enum PendingPurgeMutationType {
  setString,
  remove,
}

class PendingPurgeOperation {
  final String key;
  final PendingPurgeMutationType type;
  final String? stringPayload;

  const PendingPurgeOperation.setString({
    required this.key,
    required this.stringPayload,
  }) : type = PendingPurgeMutationType.setString;

  const PendingPurgeOperation.remove({
    required this.key,
  })  : type = PendingPurgeMutationType.remove,
        stringPayload = null;
}
```

Campos y control en `ExchangeRateService`:
- `_pendingPurgeOperations`: `Map<String, PendingPurgeOperation>` que almacena por clave la mutación física requerida y el payload exacto a persistir.
- `_purgeMarkPendingConfirmation`: booleano que registra si la persistencia física de la marca `tasas_cache_historica_purgada_v1` falló o aún no ha sido confirmada por la plataforma.

### 3.3 Tratamiento de Mutaciones
1. **Escritura pendiente (`setString`):**
   Antes de invocar `prefs.setString`, se registra la operación con su payload exacto. Si la llamada retorna `false` o lanza excepción, la operación permanece en el registro. En el siguiente intento dentro del mismo proceso, el reintento vuelve a enviar físicamente ese mismo payload a disco, independientemente de lo que refleje la memoria.
2. **Eliminación pendiente (`remove`):**
   Antes de invocar `prefs.remove`, se registra la operación de eliminación. Si la plataforma falla, la operación permanece registrada. En el reintento se vuelve a invocar físicamente `prefs.remove` para forzar el borrado en disco, aunque la clave ya no figure en `prefs.getKeys()`.
3. **Marca pendiente (`setBool`):**
   `ensureCacheHistoricaPurgada` no considera completada la purga por el simple hecho de que `prefs.get` devuelva `true` en memoria. Si `_purgeMarkPendingConfirmation` es `true` o `_pendingPurgeOperations` no está vacío, se rechaza la salida anticipada y se reintenta la confirmación física en disco.

### 3.4 Condiciones Estrictas para Confirmar la Purga
La purga solo retorna éxito (`count >= 0`) y fija la marca persistente cuando:
1. Todas las escrituras de mapas históricos fueron confirmadas en plataforma.
2. Todas las eliminaciones de claves corruptas fueron confirmadas en plataforma.
3. `_pendingPurgeOperations.isEmpty == true`.
4. `prefs.setBool(prefKeyCacheHistoricaPurgada, true)` retornó `true` sin lanzar excepción.
5. `_purgeMarkPendingConfirmation` se establece en `false`.

Si cualquiera de estas condiciones falla, el método retorna `-1`, conserva las operaciones pendientes para el próximo intento en el mismo proceso y no sella la purga.

---

## 4. Fake `TestSharedPreferences` (O2)

Se actualizó `TestSharedPreferences` en `test/services/exchange_rate_service_cache_purge_test.dart` para reproducir fielmente el contrato del plugin real `shared_preferences: ^2.2.3`:
1. **Getters tipados con cast estricto:** `getString`, `getDouble` y `getBool` ejecutan `memory[key] as T?`. Lanzan `TypeError` real ante tipos incompatibles (reproduciendo fallos de producción y garantizando que las pruebas no oculten defectos como NEW-6).
2. **Orden de operaciones en `remove`:** `memory.remove(key)` se ejecuta antes de evaluar la inyección de fallos en plataforma (`throwOnRemove`, `returnFalseOnRemove`), reproduciendo la divergencia memoria/disco de SharedPreferences.
3. **Inyección de fallos en `setDouble`:** se incorporaron las banderas `throwOnSetDouble` y `returnFalseOnSetDouble`.
4. **Reintentos en el mismo proceso:** las pruebas demostrativas de NEW-1 se ejecutan sobre la misma instancia de `TestSharedPreferences` sin invocar `reloadFromDisk()`.

---

## 5. Matriz de Pruebas Implementadas

Se implementaron y aislaron pruebas unitarias exhaustivas:

| Suite / Grupo | Escenarios Cubiertos | Tipo de Verificación |
| :--- | :--- | :--- |
| **`NEW-1` (Purga)** | **Escenario A:** `setString` falla en disco, memoria queda mutada; reintento sin `reloadFromDisk` persiste JSON depurado en disco y fija marca. | Inspección estática y diseño de arnés. |
| **`NEW-1` (Purga)** | **Escenario B:** `remove` falla en disco, memoria muta; reintento sin `reloadFromDisk` repite eliminación física en disco y no fija marca antes. | Inspección estática y diseño de arnés. |
| **`NEW-1` (Purga)** | **Escenario C:** `setBool` falla en disco, memoria contiene `true`; reintento no sale anticipadamente y confirma marca en disco. | Inspección estática y diseño de arnés. |
| **`NEW-1` (Purga)** | **Escenario D:** Recuperación e idempotencia confirmadas: llamadas posteriores no repiten operaciones innecesarias en disco. | Inspección estática y diseño de arnés. |
| **`B3-OBS` (`fromJson`)** | Tipos incorrectos (`String`, `bool`, `Map`, `List`), valores fuera de dominio (`0.5`, `1.0`, `-5.0`, `NaN`, infinitos) y válidos (`45.0`, `380.0`) evaluados independientemente para `usd`, `eur` y `usdt`. Tipos anómalos en `fecha` y `esReferencia`. | Inspección estática y diseño de arnés. |
| **`NEW-6` (Timestamp)** | Lectura de `cached_exchange_rates_timestamp` con tipos no String en `SettingsProvider` y `ExchangeRateService`. Purga de timestamp corrupto en `purgarCacheHistoricaInvalida`. | Inspección estática y diseño de arnés. |
| **`O2` (Fake)** | `getString`, `getDouble`, `getBool` lanzando `TypeError` ante tipos incompatibles; `setDouble` con fallos; mutación en memoria de `remove` previa a plataforma. | Inspección estática y diseño de arnés. |
| **`D-08` (`rate_market_test.dart`)** | Pruebas unitarias completas de `isValidMonetaryRate`: `0.5`, `1.0`, `0.0`, negativos, `NaN`, `Infinity`, `-Infinity`, `45.0`, `380.0`, tipos no numéricos y enteros. Cobertura de `allowedSourcesForMarket`. | Inspección estática y diseño de arnés. |
| **`SettingsProvider`** | Purga fallida (-1), purga exitosa con tasas válidas (D-08, ej. 45.0), descarte de <= 1.0 (D-08), timestamp corrupto no String (NEW-6), rechazo de tasas manuales fuera de dominio. | Inspección estática y diseño de arnés. |

---

## 6. Riesgos Residuales y Tareas Fuera de Alcance

1. **La aplicación NO está lista para distribución a usuarios finales:**  
   Los consumidores en la interfaz gráfica (`ReviewExpenseScreen:560,569`, `CurrencyCalculatorScreen:82,88,248`, `MoreScreen`) conservan todavía fallbacks de conveniencia y referencias a `AppConstants.defaultTasaCambio = 850.0`. La eliminación y sustitución definitiva de estos fallbacks por el estado explícito de «sin tasa» y confirmación de referencias requiere completar **U3** (modelo de tres vías `actualizada` / `referencia` / `sinTasa` e independencia por moneda) y **U4** (integración visual de pantallas).  
   En el mismo alcance U3/U4 queda el remanente de comparaciones `> 50.0` de `review_expense_screen.dart:247-255`, que no fue erradicado por U1 (ver corrección documental en §2.2).
2. **Precedencia de Tasa Manual (NEW-3b):**  
   Queda pendiente de U3 la unificación de persistencia entre `prefTasaCambio` y `cached_rate_usd` para que la tasa manual prevalezca sobre cachés automáticas anteriores offline sin ser pisada silenciosamente.
3. **Garantías Globales Diferidas:**  
   - **H-1 Global (USDT $\rightarrow$ USD en adquisición):** diferido a **E0-03**.
   - **H-2 Presentación (Getters y agregaciones):** diferido a **E0-03**.
   - **S3.2 (`copyWith` en `GastoModel`):** diferido a **E0-04**.
4. **Validación de Pruebas en CI:**  
   Al no disponer del SDK local de Flutter ni Dart, todas las pruebas han sido preparadas con máximo rigor mediante inspección estática y no se declaran como ejecutadas localmente. La confirmación real de paso exige ejecución remota en GitHub Actions CI tras el veredicto adversarial.

---

## 7. Inventario de Archivos Modificados y Creados

### Archivos de Producción Modificados:
- `lib/domain/monetary/rate_market.dart`: predicado canónico `isValidMonetaryRate(dynamic value)`.
- `lib/services/exchange_rate_service.dart`:
  - `ExchangeRatesData.fromJson` defensivo contra `TypeError` (B3-OBS).
  - Sustitución de umbrales `> 50.0` por `isValidMonetaryRate` en este módulo.
  - Lectura segura de `cached_exchange_rates_timestamp` (NEW-6).
  - Modelo de operaciones pendientes `PendingPurgeOperation` y marcas de purga física (NEW-1).
  - Purga de timestamp corrupto en `purgarCacheHistoricaInvalida`.
- `lib/providers/settings_provider.dart`:
  - Sustitución de umbrales `> 50.0` por `isValidMonetaryRate` (D-08).
  - Lectura segura de `cached_exchange_rates_timestamp` evitando `TypeError` (NEW-6).
  - `setTasaCambio` con `isValidMonetaryRate`.
- `lib/providers/gasto_provider.dart`:
  - Sustitución de validaciones numéricas por `isValidMonetaryRate` (D-08).

### Archivos de Pruebas Modificados y Creados:
- `test/services/exchange_rate_service_cache_purge_test.dart`:
  - Fake `TestSharedPreferences` con fidelidad de tipos y mutación en memoria (O2).
  - Pruebas de NEW-1 (Escenarios A, B, C, D).
  - Pruebas de B3-OBS (`fromJson`).
  - Pruebas de NEW-6 (timestamp).
  - Pruebas de O2.
- `test/providers/settings_provider_rate_cache_test.dart`:
  - Pruebas armonizadas con D-08 (45.0 aceptado, <= 1.0 rechazado) y NEW-6.
- `test/domain/monetary/rate_market_test.dart` *(Nuevo)*:
  - Suite unitaria exhaustiva para `isValidMonetaryRate` y `allowedSourcesForMarket`.

### Archivos de Documentación:
- `docs/rm-03/auditorias/implementacion-u1-u2.md` *(Nuevo)*.
- `docs/rm-03/estado-actual.md` *(Actualizado)*.
- `MEMORY.md` *(Actualizado)*.

---

## 8. Estado de Git y Conclusión

- **Rama:** `main`.
- **Commits:** Cero commits realizados.
- **Push:** Cero push realizados.
- **SQLite v18:** 100% inalterado.
- **Firestore y dependencias:** 100% inalterados.
- **Veredicto:** **U1 Y U2 IMPLEMENTADAS, PENDIENTES DE REAUDITORÍA.**
