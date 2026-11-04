# RM-03 — Estado Actual del Proyecto

> **Fecha de corte de inspección:** Noviembre de 2026.  
> **Rama activa:** `main` (Working Tree local con las correcciones completas de R-01, B-02, B-05, M-05, M-08, NEW-3b en GastoProvider y N-09; listo para 7.ª reauditoría; sin commit ni push).  
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md` (íntegro, sin modificaciones).  
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (`A-01` a `A-16` y `D-01` a `D-08` aprobadas, sin modificaciones).  
> **Último informe de implementación:** `docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md` → resolución integral de R-01, B-02, B-05, M-05, M-08, NEW-3b, N-09 y suite de 126 pruebas.  
> **Última auditoría previa:** Sexta reauditoría adversarial independiente (`auditorias/sexta-reauditoria-u1-u2-deepseek.md`) → **RECHAZADA ❌** (por bloqueante R-01 y residuales de conteo).  
> **Próximo hito:** Someter el working tree a la **Séptima Reauditoría Adversarial Independiente** de DeepSeek.

---

## 1. Estado General de las Etapas (Fase 0)

| Etapa | Descripción | Estado Oficial | Detalle y Referencia |
| :--- | :--- | :--- | :--- |
| **`E0-05a`** | Neutralización de auto-reparación 850/474 | **Completada ✅** | Mergeada en `main` (commit `de17323`). `repararTasasHistoricasIncompletas` neutralizada en `main_screen.dart:132-145` y `sync_service.dart`; `dryRun = true` por defecto en `gasto_repository.dart`. |
| **`E0-01`** | Arnés de pruebas SQLite real en memoria | **Completada ✅** | Mergeada en `main` (commit `de17323`). `sqflite_common_ffi` incorporado en `dev_dependencies` (**A-08**) y validado en CI. |
| **`E0-02`** | Dominio monetario, tupla y purga de caché A-07 | **Parche corregido 🔧 — Pendiente de 7.ª reauditoría** | R-01 resuelto (revalidación selectiva sin blindar corrupción estructural). B-02 resuelto sin doble conteo y con test de mapa completo. M-05 con pruebas reales y notificación exhaustiva. M-08 con token y `finally` condicional probado. NEW-3b implementado en `GastoProvider`. N-09 resuelto con safe getters. 126 pruebas monetarias documentadas. Ver §2.1 y §2.2. |
| **`E0-03`** | Integración en lectores móviles y panel web | **No autorizada ⏸️** | Continúa **NO AUTORIZADA** hasta que E0-02 sea aceptada por auditoría adversarial independiente y validada en CI en verde (**A-16**). Incluye H-1 global y H-2 en presentación, regidas por **D-01 a D-08**. |
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
- **R-01:** Revalidación selectiva en bucle de borrado y replay: restringida a `cached_exchange_rate`, `prefTasaCambio` y `cached_rate_usd/eur/usdt`. Si una clave tiene fecha imposible (`!_isValidCalendarDate`) o es un mapa histórico corrupto, **nunca se omite del borrado**.
- **B-02:** Eliminado `cleanedCount++` del escaneo. Se incrementa solo ante remoción física confirmada. Añadida prueba dedicada para eliminación de mapa completo corrupto.
- **M-05:** Callback `onKeyRemoved` para prueba de concurrencia real TOCTOU; prueba de rescisión con `returnFalseOnRemove = true` durante llamada remota; notificación exhaustiva en `actualizarTasaAutomatica`.
- **M-08:** `TestableSettingsProvider` con `disableAutoSyncOnLoad` erradica futuros en background; prueba dedicada de `finally` condicional.
- **NEW-3b:** `GastoProvider.cargarDatos` unificado con la misma precedencia manual que `SettingsProvider` y cubierto con prueba.
- **N-09:** Safe getters defensivos (`_safeGetBool`, `_safeGetString`, `_safeGetDouble`) implementados y probados.
- **Suite monetaria:** 126 pruebas verificadas por conteo estricto.

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
- **Validación de pruebas:** 126 pruebas en la suite monetaria inspeccionadas estáticamente, 0 ejecutadas localmente sin SDK.
- **Git:** Cero commits, cero push adicionales sobre el working tree de validación.

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
12. [`implementacion-u1-u4-e0-02.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/auditorias/implementacion-u1-u4-e0-02.md): Informe de implementación integral corregido (resolución de R-01, B-02, M-05, M-08, NEW-3b, N-09 y 126 pruebas). Estado: **LISTO PARA 7.ª REAUDITORÍA ADVERSARIAL**.
