# RM-03 — Estado Actual del Proyecto

> **Fecha de corte de inspección:** Noviembre de 2026.  
> **Rama activa:** `main` (`HEAD == origin/main == b58965a`; CI Build 665 en verde).  
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md` (íntegro, sin modificaciones).  
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (`A-01` a `A-16` y `D-01` a `D-08` aprobadas, sin modificaciones).  
> **Último informe de implementación:** `docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md` → resolución integral de D-05, M5-a, M-08, R-01, B-02, B-05, NEW-3b, N-09 y suite de 127 pruebas.  
> **Última auditoría:** Octava reauditoría adversarial independiente (`docs/rm-03/auditorias/octava-reauditoria-u1-u2-deepseek.md`) — **ACEPTADO CON OBSERVACIONES ⚠️**.  
> **Próximo hito:** Validación en dispositivo físico (*Rinde Más Dev*) para visto bueno de César en `E0-02` e inicio formal de `E0-03` (U3/U4).

---

## 1. Estado General de las Etapas (Fase 0)

| Etapa | Descripción | Estado Oficial | Detalle y Referencia |
| :--- | :--- | :--- | :--- |
| **`E0-05a`** | Neutralización de auto-reparación 850/474 | **Completada ✅** | Mergeada en `main` (commit `de17323`). `repararTasasHistoricasIncompletas` neutralizada en `main_screen.dart:132-145` y `sync_service.dart`; `dryRun = true` por defecto en `gasto_repository.dart`. |
| **`E0-01`** | Arnés de pruebas SQLite real en memoria | **Completada ✅** | Mergeada en `main` (commit `de17323`). `sqflite_common_ffi` incorporado en `dev_dependencies` (**A-08**) y validado en CI. |
| **`E0-02`** | Dominio monetario, tupla y purga de caché A-07 | **Pendiente de validación 🧪** | Aceptada técnicamente en 8.ª reauditoría. D-05, M5-a, M-08, R-01, B-02, N-09 resueltos. CI Build 665 en verde (commit `b58965a`). 127 pruebas en verde. Pendiente de visto bueno explícito de César en dispositivo físico. |
| **`E0-03`** | Integración en lectores móviles y panel web | **Autorizado condicionalmente ⚠️ — Listo para iniciar** | CI de E0-02 confirmado en verde (**A-16**). Habilitado el inicio técnico de U3/U4 (D-01 a D-08, H-1, H-2). |
| **`E0-04`** | Atomismo `synced=0`, CAS, allowlist de metadatos | **Pendiente ⏳** | Pendiente; requiere E0-02 y E0-03 en verde. Incluye la semántica de limpieza nullable de `copyWith` en `GastoModel` (S3.2). |
| **`E0-05b`** | Diagnósticos read-only `Q01..Q20` sin PII | **Pendiente ⏳** | Pendiente; ejecución en paralelo o tras E0-03 (**A-14**). |
| **Fase 0B** | Guardado sin tasa con sincronización remota | **Bloqueada 🔴** | Bloqueada por diseño normativo (**A-12**, **D-03**, **D-04**). Prohibido habilitar mientras la nube no esté contenida. |
| **Doc RM-03** | Documentación central y persistente del proyecto | **Completada ✅** | Estructura en `docs/rm-03/` activa: `README.md`, `contrato-v1.2.md` (íntegro), `decisiones.md` (`A-01` a `A-16` y `D-01` a `D-08`), `estado-actual.md` e historial en `auditorias/`. |

---

## 2. Estado Técnico Detallado de E0-02

### 2.1 Situación actual frente a la compuerta de auditoría

La **sexta reauditoría adversarial independiente** (`auditorias/sexta-reauditoria-u1-u2-deepseek.md`) emitió **RECHAZADO ❌** identificando:
1. **R-01 (bloqueante):** La revalidación TOCTOU de `isValidMonetaryRate` se aplicaba indiscriminadamente a claves marcadas por motivos estructurales (fechas de calendario imposibles como `2026-02-30` o `tasas_historico_v1` de tipo int), suprimiendo su purga y fijando la marca sobre datos corruptos.
2. **B-02 (conteo inconsistente):** En las ramas de escaneo de `tasas_historico_v1`, `cleanedCount++` se ejecutaba en el escaneo y nuevamente al borrar (doble conteo). Faltaba prueba de eliminación de mapa completo con reintento.
3. **M-05:** Pruebas vacuas para TOCTOU y rescisión; `actualizarTasaAutomatica` no notificaba `onKeyWriteConfirmed` para claves secundarias.
4. **M-08:** `settings_provider_rate_cache_test.dart` dejaba un `actualizarTasaAutomatica` sin await en segundo plano durante `loadSettings()`; faltaba prueba de `finally` condicional con `identical == false`.
5. **NEW-3b:** `GastoProvider.cargarDatos` no implementaba la precedencia de tasa manual global sobre caché automática anterior.
6. **N-09:** Getters tipados en `SettingsProvider.loadSettings` vulnerables a `TypeError` ante tipos corruptos.

**Resolución en este parche:**
- **D-05 / NEW-3b:** En `SettingsProvider.actualizarTasaAutomatica` rama `esReferencia`, no se sobrescribe la tasa manual global (`prefTasaCambio`) con la caché automática anterior. Solo se sustituye ante tasa en vivo confirmada. En `setTasaCambio`, `pref_es_tasa_manual_usd` solo se persiste si la escritura en disco de la tasa confirmó (`ok == true`). Cubierto con prueba determinista en `settings_provider_rate_cache_test.dart`.
- **M-05 / M5-a:** En el bucle de replay de `_pendingPurgeOperations`, eliminada la rescisión basada en `prefs.get()` (memoria). Si una mutación falló en disco (`returnFalseOnSetDouble = true`), la operación pendiente permanece y no se fija la marca de purga.
- **M-08:** `activePurgeFuture` expuesto y probado con discriminación estricta de `identical(...)` mediante `Completer`. Prueba de generación con `returnFalseOnRemove = false` para verificar que el cambio de generación es la causa del `-1`.
- **R-01:** Revalidación selectiva en bucle de borrado restringida a tasas diarias activas; las claves estructuralmente corruptas nunca se omiten.
- **B-02:** Eliminado `cleanedCount++` del escaneo; incremento exclusivo ante confirmación física.
- **NEW-3b:** `GastoProvider.cargarDatos` unificado con la misma precedencia manual que `SettingsProvider`.
- **N-09:** Safe getters defensivos (`_safeGetBool`, `_safeGetString`, `_safeGetDouble`) implementados y probados.
- **Suite monetaria:** 127 pruebas verificadas por conteo estricto.

### 2.2 Delimitación de Fases y Clarificaciones Normativas

- **D-02 (Exactitud por fecha efectiva):** Diferida a E0-03 (U3/U4).
- **D-06 (Modelo de tres estados nominales por moneda):** Diferida a E0-03 (U3/U4). Durante E0-02, `_tasasSonReferencia = true` en fail-closed es una salvaguarda conservadora de la sesión mientras no haya tasa viva; las tasas numéricas en `0.0` señalan la ausencia de tasa conforme a D-03.
- **D-07 (Denominaciones visuales en UI):** Diferida a E0-03 (U3/U4).
- **H-1 Global (USDT -> USD en adquisición):** Diferida a E0-03.
- **H-2 Presentación (Getters y agregaciones):** Diferida a E0-03.
- **S3.2 (`copyWith` en GastoModel):** Diferida a E0-04.

---

## 3. Estado de Validación y Entorno Técnico

- **Entorno Local:** Sin SDK de Flutter ni Dart local. Cero pruebas ejecutadas en local.
- **`node scripts/check_syntax.js`:** Ejecutado localmente. Resultado: **ALL FILES BALANCED AND SYNTACTICALLY SOUND!** (7/7 archivos validados).
- **`powershell -File scripts/check_rules.ps1`:** Ejecutado localmente. Resultado: **PASO con advertencias**.
- **Validación de pruebas:** 127 pruebas en la suite monetaria inspeccionadas estáticamente, 0 ejecutadas localmente sin SDK.
- **Git:** Cero commits, cero push adicionales sobre el working tree de validación (`HEAD == origin/main == 676344b`).

---

## 4. Historial de Auditorías en `docs/rm-03/auditorias/`

1. [`primera-auditoria-adversarial-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/primera-auditoria-adversarial-deepseek.md): Informe original. Veredicto: RECHAZADO.
2. [`reauditoria-postparche-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/reauditoria-postparche-deepseek.md): Reauditoría postparche. Veredicto: RECHAZADO.
3. [`segunda-reauditoria-b1-n1-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/segunda-reauditoria-b1-n1-deepseek.md): Segunda reauditoría adversarial. Veredicto: RECHAZADO.
4. [`informe-consolidacion-documentacion-rm-03.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/informe-consolidacion-documentacion-rm-03.md): Consolidación documental de RM-03.
5. [`implementacion-b2-b3-b5.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/implementacion-b2-b3-b5.md): Parche de B2, B3, B5, O5, O2.
6. [`tercera-reauditoria-b2-b3-b5-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/tercera-reauditoria-b2-b3-b5-deepseek.md): Tercera reauditoría. Veredicto: **RECHAZADO ❌**.
7. [`implementacion-u1-u2.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/implementacion-u1-u2.md): Informe de implementación U1/U2.
8. [`cuarta-reauditoria-u1-u2-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/cuarta-reauditoria-u1-u2-deepseek.md): Cuarta reauditoría. Veredicto: **RECHAZADO ❌**.
9. [`correcciones-cuarta-reauditoria-u1-u2.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/correcciones-cuarta-reauditoria-u1-u2.md): Correcciones B-01..B-04 y M-01..M-08.
10. [`quinta-reauditoria-u1-u2-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/quinta-reauditoria-u1-u2-deepseek.md): Quinta reauditoría. Veredicto: **RECHAZADO ❌**.
11. [`sexta-reauditoria-u1-u2-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/sexta-reauditoria-u1-u2-deepseek.md): Sexta reauditoría. Bloqueante R-01, B-02 conteo doble, 122 pruebas. Veredicto: **RECHAZADO ❌**.
12. [`septima-reauditoria-u1-u2-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/septima-reauditoria-u1-u2-deepseek.md): Séptima reauditoría adversarial. Código de producción de D-05, M5-a y R-01 conforme. Bloqueante determinista en aserción de identidad `Future` externa en test de `finally` de M-08, higiene en test D-05 e inconsistencia documental. Veredicto: **RECHAZADO ❌**.
13. [`implementacion-u1-u4-e0-02.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md): Informe de implementación integral corregido (resolución de D-05, M5-a, M-08, R-01, B-02, B-05, NEW-3b, N-09, higiene en tests y 127 pruebas). Aceptado técnicamente en 8.ª reauditoría.
14. [`octava-reauditoria-u1-u2-deepseek.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/octava-reauditoria-u1-u2-deepseek.md): Octava reauditoría adversarial. Bloqueantes de M-08, D-05 y consistencia documental resueltos. 127 pruebas verificadas por inspección estática. Veredicto: **ACEPTADO CON OBSERVACIONES ⚠️**. Cierre técnico de E0-02 en working tree y autorización condicional de E0-03.
