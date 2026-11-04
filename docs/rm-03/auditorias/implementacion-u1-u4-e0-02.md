# RM-03 — Informe Técnico de Implementación: Unidades U1 a U4 (Saneamiento de E0-02)

> **Documento:** Informe de implementación del parche de saneamiento sobre E0-02 (Fase 0A).  
> **Fecha:** Noviembre de 2026.  
> **Contrato normativo:** `docs/rm-03/contrato-v1.2.md` (`RM-03 Fase 0A v1.2`).  
> **Decisiones vinculantes:** `docs/rm-03/decisiones.md` (`A-01` a `A-16` y `D-01` a `D-08`).  
> **Auditoría previa:** Tercera reauditoría adversarial (`docs/rm-03/auditorias/tercera-reauditoria-b2-b3-b5-deepseek.md`) — **RECHAZADO ❌**.  
> **Veredicto de implementación:** **PARCHE IMPLEMENTADO, PENDIENTE DE 4.ª REAUDITORÍA ADVERSARIAL INDEPENDIENTE.**  
> **Estado de Git:** Cero commits, cero push. Modificaciones confinadas exclusivamente al working tree local.

---

## 1. Resumen de Hallazgos Resueltos en este Parche

| ID Hallazgo | Componente | Severidad Previa | Corrección Aplicada | Archivo Modificado |
| :--- | :--- | :---: | :--- | :--- |
| **NEW-1** | `ExchangeRateService.ensureCacheHistoricaPurgada` / `purgarCacheHistoricaInvalida` | Bloqueante | Rastreo en memoria de mutaciones físicas pendientes (`_pendingPurgeOperations` y `_purgeMarkPendingConfirmation`). En reintentos dentro del mismo proceso, si el disco no confirmó la escritura física, se reintenta forzadamente la persistencia aunque la caché en memoria parezca limpia. La marca persistente solo se fija tras confirmar el disco físico (`_pendingPurgeOperations.isEmpty`). | `lib/services/exchange_rate_service.dart` |
| **NEW-2** | `SettingsProvider._tasasSonReferencia` | Bloqueante | En la rama *fail-closed* (`purgeResult == -1`), se fija explícitamente `_tasasSonReferencia = true`. No se oculta el carácter de referencia ante purga fallida. | `lib/providers/settings_provider.dart` |
| **NEW-3** | Umbrales de dominio divergentes | Media / Bloqueante | Se eliminó el umbral divergente `> 50.0`. Se unificó en el predicado canónico puro `isValidMonetaryRate` (`val is num && val.isFinite && val > 1.0`, Decisión `D-08`). | `lib/domain/monetary/rate_market.dart`, `lib/services/exchange_rate_service.dart`, `lib/providers/settings_provider.dart`, `lib/providers/gasto_provider.dart` |
| **NEW-3b** | Tasa manual vs. caché automática | Bloqueante | `setTasaCambio` marca `pref_es_tasa_manual_usd = true`. Al reiniciar (`loadSettings`), si existe tasa manual configurada, prevalece sobre cachés automáticas anteriores mientras no haya red. Al volver conexión (`actualizarTasaAutomatica`), la tasa viva válida sustituye la tasa manual (`D-05`). | `lib/providers/settings_provider.dart` |
| **NEW-4** | `850.0` como tasa efectiva | Bloqueante | Eliminado el uso de `850.0` como tasa activa. En `SettingsProvider` y `GastoProvider`, valores iniciales y ramas *fail-closed* asignan `0.0` (sin tasa). `AppConstants.defaultTasaCambio` anotada con `@Deprecated` (`D-01`). | `lib/core/constants/app_constants.dart`, `lib/providers/settings_provider.dart`, `lib/providers/gasto_provider.dart` |
| **NEW-5** | Estado anterior retenido en `GastoProvider` | Bloqueante | Ante `purgeResult == -1` o excepción, `_tasaUsd` y `_tasaEur` se restablecen deterministamente a `0.0`. No conservan valores de sesiones anteriores. | `lib/providers/gasto_provider.dart` |
| **NEW-6** | Timestamp con tipo incorrecto | Media / Bloqueante | Comprobación segura `raw is String` antes de parsear `cached_exchange_rates_timestamp`. Se purga la clave si contiene tipos no `String` o fechas no parseables. | `lib/services/exchange_rate_service.dart`, `lib/providers/settings_provider.dart` |
| **B3-OBS** | Casts ciegos en `fromJson` | Bloqueante | `ExchangeRatesData.fromJson` descarta tipos no numéricos (`String`, `bool`, `Map`, `List`) degradando a `0.0` y `esReferencia = true` sin lanzar `TypeError`. | `lib/services/exchange_rate_service.dart` |
| **O2** | Fake `TestSharedPreferences` | Observación | `getString`, `getDouble`, `getBool` reproducen los lanzamientos de `TypeError` del plugin nativo. `remove` muta memoria antes del fallo de plataforma. Inyección de fallos en `setDouble`. | `test/services/exchange_rate_service_cache_purge_test.dart` |
| **B4** | Cobertura y observabilidad | Bloqueante | Accesores públicos `tasaUsd` y `tasaEur` en `GastoProvider`. Pruebas que observan directamente el reseteo de tasas a `0.0`. Pruebas remotas con `1e400`, `Infinity`, `null` y `String`. Reintentos de purga sin `reloadFromDisk()`. | `lib/providers/gasto_provider.dart`, `test/providers/gasto_provider_rate_cache_test.dart`, `test/providers/settings_provider_rate_cache_test.dart`, `test/services/exchange_rate_service_cache_purge_test.dart` |

---

## 2. Inventario de Archivos Modificados en el Working Tree

### Archivos de Producción:
- `lib/core/constants/app_constants.dart`: anotación `@Deprecated` y documentación restrictiva de `defaultTasaCambio` (`D-01`).
- `lib/domain/monetary/rate_market.dart`: predicado canónico puro `isValidMonetaryRate` (`D-08`).
- `lib/services/exchange_rate_service.dart`: NEW-1 (operaciones pendientes y marca física), NEW-6 (timestamp), B3-OBS (fromJson defensivo), NEW-3 (unificación con `isValidMonetaryRate`).
- `lib/providers/settings_provider.dart`: NEW-2 (`_tasasSonReferencia`), NEW-3b (prevalencia y persistencia de tasa manual D-05), NEW-4 (eliminación de 850.0 -> 0.0), NEW-6 (timestamp seguro).
- `lib/providers/gasto_provider.dart`: NEW-4 (inicialización a 0.0), NEW-5 (reseteo a 0.0 en fail-closed), B4 (getters `tasaUsd` y `tasaEur`).

### Archivos de Pruebas:
- `test/services/exchange_rate_service_cache_purge_test.dart`: O2 (fake fiel con `TypeError`), B3-OBS (fromJson con tipos corruptos), B4 (pruebas remotas `1e400`/overflow/String), reintentos sin `reloadFromDisk()`.
- `test/providers/settings_provider_rate_cache_test.dart`: D-01/NEW-4 (defaults en 0.0), NEW-2 (tasasSonReferencia en true), NEW-3b/D-05 (persistencia de tasa manual y actualización viva).
- `test/providers/gasto_provider_rate_cache_test.dart`: B4 (observabilidad real sobre `provider.tasaUsd` y `provider.tasaEur`), NEW-5 (reseteo sin retener estado previo).

### Documentación:
- `ROADMAP.md`: Incorporación formal de la Fase 0 (Iniciativa RM-03) y sus estados normativos.
- `MEMORY.md`: Actualización del estado operativo en 29 líneas.

---

## 3. Asuntos Formalmente Fuera de Alcance (Permanecen Abiertos para E0-03 y E0-04)

- **H-1 Global (Fallback USDT -> USD en adquisición):** Líneas 115, 150-154 y 522-536 de `ExchangeRateService`. Asignada a **E0-03**.
- **H-2 Presentación (Getters y agregaciones en UI):** Getters en `GastoModel`, `ChatScreen`, `CurrencyCalculatorScreen`, `ReviewExpenseScreen` y `AnalysisScreen`. Asignada a **E0-03**.
- **S3.2 (`copyWith` en `GastoModel`):** Limpieza de campos nulables. Asignada a **E0-04**.
- **E0-03 y E0-04:** Continúan **NO AUTORIZADAS** hasta que la 4.ª reauditoría apruebe E0-02 y CI confirme en verde.
- **Fase 0B y SQLite v19:** Permanecen **BLOQUEADAS** normativamente (`A-01`, `A-12`).

---

## 4. Estado de Validación

- **Entorno local:** Sin SDK de Flutter ni Dart (`Get-Command flutter, dart` retornó 1). Cero pruebas ejecutadas en local.
- **`scripts/check_rules.ps1`:** Ejecutado localmente. Resultado: **PASO con advertencias**.
- **Git:** Cero commits, cero push. Working tree local listo para revisión.
