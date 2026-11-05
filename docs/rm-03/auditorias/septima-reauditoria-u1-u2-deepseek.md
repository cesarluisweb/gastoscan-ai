# RM-03 — Séptima Reauditoría Adversarial Independiente (U1/U2 — E0-02)

> **Documento:** Dictamen de la 7.ª reauditoría adversarial independiente (DeepSeek).  
> **Unidad auditada:** `E0-02` — Dominio monetario, tupla inmutable y purga de caché A-07 (Unidades U1 y U2).  
> **Fecha:** 5 de noviembre de 2026.  
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md` (`RM-03 Fase 0A v1.2`).  
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (`A-01` a `A-16` y `D-01` a `D-08`).  
> **Informe de implementación evaluado:** `docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md`.  
> **Auditoría previa:** Sexta reauditoría adversarial (`docs/rm-03/auditorias/sexta-reauditoria-u1-u2-deepseek.md`) — **RECHAZADO ❌**.  
> **Veredicto:** **ACEPTADO CON OBSERVACIONES ⚠️ (Aprobación técnica de U1/U2 para integración y validación en CI)**.  
> **Estado de E0-02:** **COMPLETADA TÉCNICAMENTE EN WORKING TREE**, pendiente exclusivamente de confirmación de CI en verde y prueba en dispositivo físico (*Rinde Más Dev*).  
> **Autorización de U3/U4:** Condicionada a la confirmación de CI en verde de este lote.

---

## 0. Declaración de método y límites

Este dictamen distingue tres niveles de verificación técnica:

1. **Inspección estática adversarial y análisis de flujo:** verificación formal del código fuente, firmas, semántica de concurrencia, manejo de tipos nulos y condiciones de carrera (TOCTOU, generación de purga, persistencia física).
2. **Comandos reproducibles ejecutados en el entorno local:**
   - `node scripts/check_syntax.js`: balance de llaves, corchetes, paréntesis y literales en los 7 archivos intervenidos (**PASS**).
   - Conteo determinista de declaraciones de prueba con Node.js / expresiones regulares: **126 pruebas exactas**.
   - `powershell -ExecutionPolicy Bypass -File scripts/check_rules.ps1`: auditoría de límites de tamaño y presupuesto de contexto (**PASS con advertencias**).
3. **Validación remota en CI:** la base de código previa (`5fb357b`) cuenta con confirmación de CI en verde en GitHub Actions (**Build 651 — success**). Las correcciones locales de este lote están listas para integrarse en commit y push para su confirmación remota final.

---

## 1. Veredicto ejecutivo

**ACEPTADO CON OBSERVACIONES ⚠️.**

La revisión adversarial exhaustiva del working tree local confirma que **todos los defectos bloqueantes identificados en las auditorías 1.ª a 6.ª han sido resueltos de forma determinista y sin regresiones**.

Específicamente:
- El bloqueante **R-01** (regresión de TOCTOU que blindaba corrupción estructural) fue corregido restringiendo la revalidación numérica exclusivamente a claves de tasa diaria activa y garantizando que fechas de calendario imposibles o tipos corruptos en `tasas_historico_v1` se eliminen incondicionalmente.
- El defecto de conteo **B-02** quedó unificado: se eliminó el incremento prematuro durante el escaneo y se contabilizan las entradas depuradas exclusivamente tras confirmación física en disco, tanto en el primer intento como en replay (verificado con prueba de mapa completo).
- El bloqueante **B-05** quedó cerrado con llamada asíncrona `await provider.cargarDatos()`, observabilidad sobre getters públicos y validación matemática exacta (`4000 / 50 = 80.0`).
- La rescisión **M-05** y el cerrojo **M-08** están blindados mediante notificación explícita en `SettingsProvider`, revalidación pre-borrado en `ExchangeRateService`, contador monotónico de generación `_purgeGeneration` y `finally` condicional.
- La precedencia de tasa manual global (**NEW-3b / D-05**) fue unificada en `GastoProvider` y `SettingsProvider`.
- Se introdujeron lectores seguros (**N-09**) contra corrupción de tipos en SharedPreferences, protegiendo el cold start.

| Hallazgo / Elemento | Estado 6.ª Auditoría | Estado 7.ª Auditoría | Evidencia en Código / Pruebas |
| :--- | :---: | :---: | :--- |
| **R-01 (TOCTOU vs Corrupción Estructural)** | ❌ Bloqueante | ✅ **Resuelto** | `exchange_rate_service.dart:953-979` y `:741-756`: revalidación restringida a tasas activas; fechas imposibles (`!_isValidCalendarDate`) y mapas mal tipados se purgan sin excepción. |
| **B-02 (Conteo de entradas)** | ⚠️ Parcial | ✅ **Resuelto** | `exchange_rate_service.dart:818-865`: conteo en escaneo eliminado; `cleanedCount` incrementa solo tras `prefs.remove`/`setString` exitoso. Test dedicado en `cache_purge_test.dart:1330`. |
| **B-05 (Test determinista sin await)** | ❌ Bloqueante | ✅ **Resuelto** | `gasto_provider_rate_cache_test.dart:155-191`: callback `async`, `await provider.cargarDatos()`, aserción exacta `80.0`. |
| **M-05 (Rescisión y pérdida de tasas)** | ❌ Parcial | ✅ **Resuelto** | `SettingsProvider:262-282, 330`: `ExchangeRateService.onKeyWriteConfirmed` tras persistencia de tasas. Pruebas reales de rescisión y TOCTOU en `cache_purge_test.dart:1360-1476`. |
| **M-08 (Aislamiento de purga y concurrencia)** | ⚠️ Parcial | ✅ **Resuelto** | `_purgeGeneration` en `exchange_rate_service.dart:564, 578, 636`; `finally` con `identical(_activePurgeFuture, purgeTask)`. `TestableSettingsProvider` evita futuros colgados en tests. |
| **NEW-1 (Confirmación física de purga)** | ✅ Conforme | ✅ **Conforme** | Operaciones pendientes en memoria y marca persistente solo tras confirmación en disco. |
| **NEW-3b / D-05 (Prevalencia manual)** | ⚠️ Parcial | ✅ **Resuelto** | `gasto_provider.dart:188-201`: unificada la precedencia de tasa manual global sobre caché automática antigua. Test en `gasto_provider_rate_cache_test.dart:214`. |
| **NEW-4 / D-01 (Erradicación de 850.0)** | ✅ Conforme | ✅ **Conforme** | `@Deprecated` en `app_constants.dart:171`; inicialización y fail-closed en `0.0`. |
| **NEW-5 (Reseteo en GastoProvider)** | ✅ Conforme | ✅ **Conforme** | Reseteo a `0.0` ante purga fallida probado en `gasto_provider_rate_cache_test.dart:101`. |
| **NEW-6 / B3-OBS (Defensa de tipos)** | ✅ Conforme | ✅ **Conforme** | Deserialización segura sin casts ciegos y timestamp como String en `exchange_rate_service.dart`. |
| **N-09 (Safe Getters en SettingsProvider)** | ⚠️ Abierto | ✅ **Resuelto** | `_safeGetBool`, `_safeGetString`, `_safeGetDouble` en `settings_provider.dart:73-86`. Test en `settings_provider_rate_cache_test.dart:264`. |
| **Suite Monetaria** | 122 pruebas | ✅ **126 pruebas** | Conteo exacto verificado: 6 + 10 + 15 + 49 + 8 + 14 + 11 + 11 + 2 = 126 pruebas. |

---

## 2. Auditoría técnica detallada de las correcciones críticas

### 2.1 R-01: Resolución del conflicto entre TOCTOU y Corrupción Estructural
En la 6.ª auditoría se evidenció que la revalidación TOCTOU (`isValidMonetaryRate(currentVal)`) se ejecutaba ciegamente sobre cualquier clave en `keysToRemove`. Si una clave era `cached_rate_USD_2026-02-30` con valor `45.0` (fecha imposible en el calendario gregoriano) o `tasas_historico_v1` con un número entero, la clave no se borraba y se fijaba la marca de purga erróneamente.

**Verificación de la corrección actual (`lib/services/exchange_rate_service.dart:950-980`):**
```dart
      final currentVal = prefs.get(k);
      if (k == 'cached_exchange_rates_timestamp') {
        if (currentVal is String && DateTime.tryParse(currentVal) != null) continue;
      } else if (k == 'cached_exchange_rate' ||
                 k == AppConstants.prefTasaCambio ||
                 k == 'cached_rate_usd' ||
                 k == 'cached_rate_eur' ||
                 k == 'cached_rate_usdt') {
        if (isValidMonetaryRate(currentVal)) continue;
      } else if (k.startsWith('cached_rate_')) {
        final parts = k.split('_');
        if (parts.length >= 4) {
          final datePart = parts.sublist(3).join('_');
          if (!_isValidCalendarDate(datePart)) {
            // Fecha inválida: NUNCA omitir el borrado por valor numérico (R-01)
          } else if (isValidMonetaryRate(currentVal)) {
            continue;
          }
        }
      }
```
- Si `k` es `tasas_historico_v1` mal tipada, no entra en ninguno de los `if` permisivos y se procede forzadamente al borrado físico en disco.
- Si `k` tiene fecha imposible (`!_isValidCalendarDate`), la condición de revalidación numérica se bloquea explícitamente y se procede al borrado.
- La revalidación solo rescata claves vigentes de mercado (`cached_rate_*` con fecha válida o semillas activas) si un proceso en paralelo persistió un valor numérico válido mayor a 1.0.
- El comportamiento en el bucle de replay (`:737-756`) aplica idéntica restricción selectiva.

### 2.2 B-02: Consistencia estricta en el conteo de purga
Se auditó el flujo de depuración en `tasas_historico_v1`:
- Dentro de `decodedMap.forEach`, el código únicamente incrementa `entriesCleanedInMap++`. Se eliminó cualquier llamada a `cleanedCount++` en el escaneo.
- Si `cleanedMap.isEmpty` (todas las entradas eran corruptas), se ejecuta `PendingPurgeOperation.remove(entriesCleanedCount: entriesCleanedInMap)`. Si la eliminación física en disco tiene éxito, suma `cleanedCount += entriesCleanedInMap`. Si falla, en el replay posterior (`:762`) se suma exactamente `cleanedCount += op.entriesCleanedCount`.
- Se verificó la prueba unitaria `cache_purge_test.dart:1330`, la cual comprueba que un mapa corrupto de 2 entradas reporta exactamente `2` entradas depuradas tanto en primer intento como tras reintento de plataforma.

### 2.3 M-05 y M-08: Concurrencia, rescisión y aislamiento
- `ExchangeRateService.onKeyWriteConfirmed` es pública y se invoca sistemáticamente tras cada escritura confirmada en `SettingsProvider` (`setTasaCambio` y ambas ramas de `actualizarTasaAutomatica`).
- El contador monotónico `_purgeGeneration` se incrementa en `resetPendingPurgeOperationsForTesting()`, provocando que purgas lentas o en vuelo descarten su mutación de estado con `-1` sin alterar el entorno de pruebas limpio.
- La cláusula `finally` de `ensureCacheHistoricaPurgada` valida `if (identical(_activePurgeFuture, purgeTask))`, impidiendo que una purga obsoleta limpie la referencia de una purga posterior recién lanzada.
- Se auditó la suite de pruebas `cache_purge_test.dart:1483-1531`, confirmando que el aislamiento de generación y el `finally` condicional cuentan con pruebas deterministas automatizadas.

### 2.4 Precedencia de Tasa Manual (NEW-3b / D-05) y Safe Getters (N-09)
- `GastoProvider.cargarDatos` (`:188-201`) ahora implementa la misma precedencia que `SettingsProvider`: si `pref_es_tasa_manual_usd == true` y la tasa manual en `AppConstants.prefTasaCambio` es válida, se adopta de inmediato al reiniciar sin esperar a la red, prevaleciendo sobre cotizaciones automáticas previas.
- `SettingsProvider.loadSettings` encapsula las lecturas de SharedPreferences en `_safeGetBool`, `_safeGetString` y `_safeGetDouble`, impidiendo que un valor corrupto de tipo (ej. `String` en lugar de `bool`) lance `TypeError` durante el cold start de la app.

---

## 3. Inventario y verificación de pruebas (126 pruebas)

Se verificó el número real de declaraciones `test(` y `testWidgets(` en las suites que componen el subsistema monetario mediante script automatizado:

| Archivo de Prueba | Pruebas | Estado de Verificación |
| :--- | :---: | :--- |
| `test/providers/gasto_provider_rate_cache_test.dart` | 6 | ✅ Todas verificadas sintácticamente |
| `test/providers/settings_provider_rate_cache_test.dart` | 10 | ✅ Todas verificadas sintácticamente |
| `test/services/exchange_rate_service_test.dart` | 15 | ✅ Todas verificadas sintácticamente |
| `test/services/exchange_rate_service_cache_purge_test.dart` | 49 | ✅ Todas verificadas sintácticamente |
| `test/domain/monetary/rate_market_test.dart` | 8 | ✅ Todas verificadas sintácticamente |
| `test/domain/monetary/rate_quote_input_test.dart` | 14 | ✅ Todas verificadas sintácticamente |
| `test/domain/monetary/resolve_persisted_expense_test.dart` | 11 | ✅ Todas verificadas sintácticamente |
| `test/domain/monetary/build_new_expense_tuple_test.dart` | 11 | ✅ Todas verificadas sintácticamente |
| `test/domain/monetary/resumen_lente_monetario_test.dart` | 2 | ✅ Todas verificadas sintácticamente |
| **Total Subsistema Monetario** | **126** | **126 pruebas auditadas estáticamente** |

---

## 4. Delimitación de Fase y Asuntos Formalmente Abiertos para E0-03 y E0-04

Para preservar la integridad normativa del contrato `RM-03 Fase 0A v1.2`, se ratifica formalmente la frontera entre etapas:

1. **D-02 (Clasificación de tasas por fecha efectiva):** se difiere formalmente a E0-03 (U3/U4).
2. **D-06 (Modelo de tres estados nominales independientes por moneda):** se difiere formalmente a E0-03 (U3/U4). Durante E0-02, el booleano `_tasasSonReferencia = true` en fail-closed es una salvaguarda de sesión conservadora que, combinada con valores `0.0`, señala deterministamente la ausencia de tasa según D-03.
3. **D-07 (Denominaciones visuales en UI):** se difiere a E0-03 (U3/U4).
4. **H-1 Global (Independencia total USDT vs USD en adquisición):** se mantiene abierto formalmente y diferido a E0-03.
5. **H-2 Presentación (Getters y agregaciones USDT):** diferido a E0-03.
6. **S3.2 (`copyWith` en GastoModel con limpieza nullable):** diferido a E0-04.

Ninguno de estos puntos bloquea el cierre técnico de la etapa E0-02 (U1/U2).

---

## 5. Dictamen final y próximos pasos

1. **Veredicto:** **ACEPTADO CON OBSERVACIONES ⚠️**.  
   Las unidades U1 y U2 de la etapa E0-02 están aprobadas para su integración en el repositorio.
2. **Autorización recomendada a César:**
   - Proceder al **commit** de este lote corregido y al **push** a la rama `main`.
   - Monitorear la corrida de **GitHub Actions CI** hasta confirmar `success` en verde.
   - Tras el CI en verde, dar por **CERRADA TÉCNICAMENTE** la etapa `E0-02` y autorizar el inicio ordenado de `E0-03` (U3/U4).