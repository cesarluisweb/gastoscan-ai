# RM-03 — Registro de Decisiones Adjudicadas (A-01 a A-16)

> **Documento normativo:** `contrato-v1.2.md` (`RM-03-fase-0-especificacion-adjudicada-v1.2.md`).  
> **Fuentes de origen:** `C:\Users\cesar\.opencode\plan\RM-03-fase-0-adenda.md` (§9), `.agents/rules/dinero-datos.md`, `DOC_MOTOR_MULTIMONEDA.md`.  
> **Regla de inmutabilidad:** Las decisiones registradas en este documento han sido aprobadas por César y son vinculantes. Prohibido alterarlas, reinterpretarlas silenciosamente o relajarlas sin autorización expresa previa.

---

## 1. Matriz de Decisiones A-01 a A-16

### A-01 — Política de contención en Fase 0A (Compuerta estricta)

- **Identificador:** `A-01`
- **Decisión aprobada:** Adopción de la **Opción A: Bloqueo estricto de guardado incompleto**. No se permite persistir ningún gasto que carezca de alguna tasa o equivalencia requerida en su tuple monetario. La opción B (guardado local sin sincronización remota) queda diferida como `0A.1` sujeta a SQLite v19, UX dedicada y pruebas de contención.
- **Alcance:** Creación y edición de gastos en la aplicación móvil (`ReviewExpenseScreen`) y en el panel web (`panel.astro`).
- **Restricciones:** Si falta cualquier tasa requerida para conformar el tuple completo, la aplicación debe bloquear el guardado y mostrar al usuario qué dato falta. Queda prohibido recurrir a fallbacks silenciosos (`?? 1.0`, `?? totalUsd`, `?? tasaCambio`, `|| 1.0`, o tasas de hoy para fechas pasadas).
- **Fase de aplicación:** Fase 0A (unidad de trabajo `E0-06`).

---

### A-02 — Manejo del riesgo residual de clientes antiguos en la nube

- **Identificador:** `A-02`
- **Decisión aprobada:** **Aceptar el riesgo residual con documentación explícita** durante la Fase 0A y diferir la solución durable a la Fase C.
- **Alcance:** Sincronización bidireccional con Cloud Firestore (`SyncService`, `FirestoreGastosRemoteDataSource`).
- **Restricciones:** La contención monetaria de Fase 0A se garantiza exclusivamente en clientes actualizados. Queda estrictamente prohibido afirmar o prometer a los usuarios o en la documentación que los datos en la nube están blindados contra corrupción mientras existan clientes antiguos sin versión mínima requerida que puedan escribir en Firestore.
- **Fase de aplicación:** Fase 0A (documentación de riesgo residual y límites) y Fase C (solución definitiva mediante `min_supported_app_version` o validación estricta en `firestore.rules`).

---

### A-03 — Alcance normativo de la paridad USD/USDT

- **Identificador:** `A-03`
- **Decisión aprobada:** La paridad 1:1 entre USD y USDT está autorizada **únicamente para pagos directos en divisa (`metodo_liquidacion == 'DIVISA'`) y para presupuestos mensuales** (`DOC_MOTOR_MULTIMONEDA.md:46`).
- **Alcance:** Conversiones monetarias, cálculo de equivalencias y agregaciones financieras en SQLite, Dart y JavaScript.
- **Restricciones:** Prohibido asumir o extender la paridad 1:1 a EUR, a gastos en Bolívares (VES) indexados o a gastos sin método de liquidación documentado. Prohibido encadenar conversiones como `EUR → USD → USDT`. En SQLite v18, los gastos legacy sin método explícito con importes idénticos se clasifican como `persistidoNoVerificado` / `Sospechosa`, nunca como verdad canónica indubitable.
- **Fase de aplicación:** Fase 0A (unidades `E0-02` y `E0-03`).

---

### A-04 — Tratamiento de gastos en EUR offline en Fase 0A

- **Identificador:** `A-04`
- **Decisión aprobada:** **Bloqueo estricto del registro offline de EUR en 0A** cuando no se disponga de las tasas requeridas (`tasa_eur` y `tasa_cambio`).
- **Alcance:** Formulario de registro de gastos (`ReviewExpenseScreen`), endpoint de importación y panel web.
- **Restricciones:** En Fase 0A no se permite guardar un gasto en EUR sin sus tasas de cruce exactas o válidas. Queda prohibido inventar tasas paritarias o ratios cableados (`usd / 1.08`). Queda terminantemente prohibida la combinación `EUR + BS_USDT` tanto en la interfaz como en el dominio (`buildNewExpenseTuple`).
- **Fase de aplicación:** Fase 0A (unidades `E0-02`, `E0-03` y `E0-06`).

---

### A-05 — Persistencia de `metodo_liquidacion` en SQLite

- **Identificador:** `A-05`
- **Decisión aprobada:** Incorporar formalmente la columna `metodo_liquidacion` (`'DIVISA'`, `'BS_BCV'`, `'BS_USDT'`) en el esquema SQLite en la futura **migración v19**.
- **Alcance:** Esquema local SQLite (`DatabaseHelper`) y serialización completa.
- **Restricciones:** Fase 0A NO modifica el esquema SQLite (`_dbVersion = 18` se mantiene inalterado). En v18 no se infiere ni se retroalimenta el método hacia atrás con conjeturas.
- **Fase de aplicación:** SQLite v19 (Fase posterior a Fase 0).

---

### A-06 — Modelo de durabilidad de estados mediante `equivalencia_estado`

- **Identificador:** `A-06`
- **Decisión aprobada:** Incorporar la columna o enum `equivalencia_estado` en el esquema SQLite en la **migración v19** para modelar durabilidad de estados monetarios (`Conocida`, `Derivable`, `Pendiente`, `Incoherente`, `Sospechosa`).
- **Alcance:** Modelo de datos `GastoModel` y persistencia SQLite/Firestore.
- **Restricciones:** No utilizar `null` o `0.0` como sustitutos silenciosos de estado persistido en SQLite v18. En Fase 0A se utiliza exclusivamente el módulo puro de resolución en memoria `resolvePersistedExpense` con `ResumenLenteMonetario`.
- **Fase de aplicación:** SQLite v19 (Fase posterior a Fase 0).

---

### A-07 — Política operativa de purga de caché histórica de tasas

- **Identificador:** `A-07`
- **Decisión aprobada:** **Limpieza selectiva de caché histórica**. Se purgan únicamente aquellas entradas históricas que carezcan de metadatos coherentes, entradas con valores no numéricos, no finitos (`NaN`, `Infinity`, `-Infinity`) o tasas `<= 1.0`. Se conservan intactas las tasas del día de hoy y las entradas históricas válidas.
- **Alcance:** `ExchangeRateService` (`tasas_historico_v1` y claves diarias `cached_rate_<MONEDA>_<ISO>`).
- **Restricciones:**
  1. Aislamiento estricto de lectura/decodificación vs escritura con `prefs.setString`: un fallo de persistencia en disco NO debe borrar el mapa histórico en memoria (B1 corregido).
  2. Cero consumo de tasas no finitas o `<= 1.0` en el punto de consumo (`getRateForDate` corregido en N1; B2 y B3 pendientes).
  3. Comportamiento fail-closed: si la purga falla o retorna `-1`, se bloquea el consumo de caché no verificada.
  4. La semilla `tasa_cambio_ves_usd` no debe persistirse como tasa exacta sin verificación (O5 pendiente).
- **Fase de aplicación:** Fase 0A (unidad de trabajo `E0-02`).

---

### A-08 — Arnés de pruebas con SQLite real en memoria (`sqflite_common_ffi`)

- **Identificador:** `A-08`
- **Decisión aprobada:** Incorporar la dependencia `sqflite_common_ffi: ^2.3.3` en la sección `dev_dependencies` de `pubspec.yaml` para ejecutar pruebas unitarias y de integración sobre SQLite real en memoria en el entorno CI.
- **Alcance:** Suite de pruebas en GitHub Actions CI (`test/`).
- **Restricciones:** Prohibido agregar `sqflite_common_ffi` en las dependencias de producción (`dependencies`).
- **Fase de aplicación:** Fase 0A (unidad `E0-01`). **Estado:** Implementada en commit `cf177ed`, probada en CI y cerrada en `de17323`.

---

### A-09 — Restricciones de escritura y allowlist de metadatos en el panel web

- **Identificador:** `A-09`
- **Decisión aprobada:** Implementar una **allowlist de metadatos** en `landing/src/pages/panel.astro` para aislar las ediciones de campos descriptivos (`comercio`, `categoria`, `notas`) de los campos monetarios.
- **Alcance:** Panel web Astro (`panel.astro`) y escrituras remotas vía `setDoc(..., { merge: true })`.
- **Restricciones:** Editar comercio o categoría en la web jamás debe recalcular `total_original`, `total_usd`, `total_eur`, `total_usdt` ni tasas con los valores en vivo (`liveRates`). Cualquier edición de importes requiere intención explícita y confirmación previa.
- **Fase de aplicación:** Fase 0A (unidades `E0-04` y `E0-08`).

---

### A-10 — Neutralización de la auto-reparación histórica 850 / 474

- **Identificador:** `A-10`
- **Decisión aprobada:** **Neutralizar inmediatamente la ejecución automática** de `repararTasasHistoricasIncompletas` (`repararGastosTasa474` y `repararGastosTasa850`) en el arranque de la app (`main_screen.dart:132-145`) y en los ciclos de sincronización (`sync_service.dart`).
- **Alcance:** Métodos de auto-reparación en `DatabaseHelper`, `GastoRepository`, `MainScreen` y `SyncService`.
- **Restricciones:** Conservar `dryRun = true` por defecto en las llamadas auxiliares. Prohibido que procesos en background reescriban silenciosamente tasas locales o remotas sin previa inspección visual y consentimiento del usuario.
- **Fase de aplicación:** Fase 0A (unidad `E0-05a`). **Estado:** Implementada en commit `489812b` y cerrada en `de17323`.

---

### A-11 — Reglas de seguridad de Firestore y exigencia de versión mínima

- **Identificador:** `A-11`
- **Decisión aprobada:** **Diferir a la Fase C** la implementación de validaciones estrictas de esquema en `firestore.rules` y la imposición de versión mínima de cliente (`min_supported_app_version`).
- **Alcance:** `firestore.rules` y configuración de versiones en Cloud Firestore.
- **Restricciones:** Prohibido modificar `firestore.rules` durante la Fase 0A. Documentar formalmente que la contención en la nube queda pendiente de esta fase posterior.
- **Fase de aplicación:** Fase C (posterior a Fase 0).

---

### A-12 — Habilitación de la Fase 0B (Guardado sin tasa con sincronización)

- **Identificador:** `A-12`
- **Decisión aprobada:** La **Fase 0B permanece estrictamente BLOQUEADA**.
- **Alcance:** Flujos de guardado offline y propagación remota de equivalencias pendientes.
- **Restricciones:** Prohibido habilitar Fase 0B mientras clientes antiguos puedan sincronizar y sobrescribir documentos incompletos. Su eventual desbloqueo exige cumplir todos los pasos de Fase 0A, diagnósticos `Q01..Q20`, arnés de pruebas de contención y autorización explícita de César.
- **Fase de aplicación:** Fase 0B (actualmente bloqueada).

---

### A-13 — Modelo de auditoría para mutaciones de importes

- **Identificador:** `A-13`
- **Decisión aprobada:** Incorporar campos de auditoría (`importe_actualizado_en`, `motivo_cambio`) en Cloud Firestore cuando se modifique un monto pagado; diferir la persistencia en SQLite a la migración v19.
- **Alcance:** Repositorio de datos, contratos de payload y sincronización.
- **Restricciones:** Distinguir a nivel de API la operación de actualización de metadatos de la operación de modificación de montos financieros.
- **Fase de aplicación:** Fase 0A (capa remota/Firestore); SQLite v19 (capa local).

---

### A-14 — Protocolo de diagnóstico de datos existentes de solo lectura

- **Identificador:** `A-14`
- **Decisión aprobada:** Aprobar el protocolo de consultas diagnósticas `Q01..Q20` bajo modalidad estrictamente de **solo lectura (`query_only`)**, ejecutado exclusivamente sobre copias de trabajo o fixtures de prueba.
- **Alcance:** Scripts de diagnóstico SQL sobre bases de datos locales.
- **Restricciones:** Prohibido ejecutar `UPDATE`, `DELETE`, `VACUUM` o diagnósticos sobre la base de datos real de producción de un usuario. Prohibido capturar o almacenar Información Personal Identificable (PII). Destruir las copias temporales al finalizar la ejecución.
- **Fase de aplicación:** Fase 0A (unidad `E0-05b`).

---

### A-15 — Interfaz de usuario con confirmación explícita de cambio de monto

- **Identificador:** `A-15`
- **Decisión aprobada:** Exigir confirmación obligatoria con motivo (`IntencionCambioImporte`) en las interfaces móvil y web cuando el usuario altere intencionalmente el monto pagado (`total_original`) o la moneda.
- **Alcance:** `ReviewExpenseScreen`, edición en historial y modal de edición del panel web.
- **Restricciones:** Las ediciones ordinarias de metadatos (comercio, notas, categoría) no deben presentar este diálogo ni alterar los importes persistidos.
- **Fase de aplicación:** Fase 0A (unidades `E0-04` y `E0-08`).

---

### A-16 — Corrección obligatoria de lectores actuales como prerrequisito

- **Identificador:** `A-16`
- **Decisión aprobada:** Es **prerrequisito no negociable** corregir todos los lectores actuales (`GastoModel`, `fromMap`, getters, agregaciones SQLite, métricas del panel) para que representen la ausencia de equivalencias sin inventar números (`?? 1.0`, `?? totalUsd`, `?? tasaCambio`, `|| 1.0`) antes de habilitar compuertas de guardado definitivas.
- **Alcance:** Todo el stack de lectura y agregación en Dart y JavaScript.
- **Restricciones:** Prohibido implementar o habilitar compuertas de guardado si los lectores continúan fabricando equivalencias en memoria al deserializar.
- **Fase de aplicación:** Fase 0A (unidades `E0-01`, `E0-02`, `E0-03`).

---

## 2. Registro de Discrepancias entre Documentos

Al contrastar la propuesta inicial de la adenda (`RM-03-fase-0-adenda.md` §9) con la especificación definitiva adjudicada (`contrato-v1.2.md` §6.1), se señalan las siguientes precisiones:

1. **Estado de Autorización:**
   - En `RM-03-fase-0-adenda.md` §9, las decisiones se plantearon como propuestas a la espera de confirmación de producto.
   - En `contrato-v1.2.md` §6.1, César adjudicó y formalizó el orden de ejecución: `E0-05a` (A-10) y `E0-01` (A-08) como autorizadas inmediatas (cerradas en commit `de17323`); `E0-02` (A-07) autorizada tras `E0-01` (actualmente en curso); `E0-03` (A-16, A-03, A-04) autorizada secuencialmente tras `E0-02` en verde; `E0-04` (A-09, A-15) tras `E0-03`; `E0-05b` (A-14) en paralelo o tras `E0-03`; y `Fase 0B` (A-12) bloqueada.
2. **Alcance de la Purga A-07:**
   - La adenda contemplaba purgar `tasas_historico_v1`. La primera y segunda auditoría adversarial revelaron que `tasas_historico_v1` no es consumida activamente por la app en producción, mientras que las claves diarias `cached_rate_<MONEDA>_<ISO>` y la semilla `tasa_cambio_ves_usd` sí alimentan flujos activos. La especificación adjudicada y los hallazgos B1/N1/O5 delimitan que la purga debe proteger la integridad de todas las claves de caché de `SharedPreferences` sin destruir datos históricos válidos.
3. **Persistencia SQLite v18 vs v19:**
   - Ninguna decisión autoriza alterar la versión de SQLite en Fase 0A (`_dbVersion = 18`). Toda persistencia de estados durables (`equivalencia_estado`, A-06) y método de liquidación (`metodo_liquidacion`, A-05) queda formalmente diferida a v19.

---

## 3. Decisiones de Política Monetaria y Comportamiento Offline (D-01 a D-08)

> **Estado:** Aprobadas por César (propietario del producto) mediante sesión de decisiones de producto y política monetaria.  
> **Relación normativa:** Estas decisiones complementan y precisan la implementación de `E0-02` y `E0-03` **sin alterar, relajar ni sustituir** las decisiones `A-01` a `A-16` ni el contrato normativo `contrato-v1.2.md`.

### Matriz Resumen (D-01 a D-08)

| ID | Decisión | Respuesta aprobada del propietario | Consecuencia técnica | Estado |
| :--- | :--- | :--- | :--- | :--- |
| **`D-01`** | **Eliminación de `850.0` y uso de la última tasa conocida sin Internet (`NEW-4`)** | Eliminar `850.0` (`AppConstants.defaultTasaCambio`) como tasa efectiva. Sin conexión, recuperar la última tasa válida registrada del mismo mercado y permitir pre-rellenar cálculos identificando su fecha efectiva y fuente real, exigiendo confirmación explícita del usuario al guardar cuando sea una referencia. | Ningún proveedor ni pantalla puede usar `850.0` como tasa activa o fallback de cálculo. Una tasa en caché se evalúa según su fecha efectiva respecto a la fecha del gasto (`exacta` vs. `referencia`) y nunca por el solo hecho de provenir de caché. | **APROBADA** |
| **`D-02`** | **Vigencia, exactitud y antigüedad de una tasa (`O3`)** | La clasificación depende de la fecha efectiva respecto a la fecha del gasto: `actualizada` (obtenida y validada en vivo), `exacta` (fecha efectiva igual a la fecha del gasto o último cierre hábil oficial inmediato verificado) y `referencia` (fecha efectiva anterior que no cumple cierre hábil inmediato). Las referencias no tienen caducidad destructiva, exigen confirmación al guardar y muestran alerta reforzada si superan 5 días. | `ExchangeRateService` debe preservar la `fechaEfectiva` real (`YYYY-MM-DD`) y la fuente (`RateSourceId`) de cada tasa sin sobrescribir la fecha efectiva con la fecha solicitada. Una tasa en caché cuya `fechaEfectiva` coincide con la fecha del gasto es `exacta`, no `referencia`. | **APROBADA** |
| **`D-03`** | **Ausencia total de una tasa válida (`NEW-4`, `A-01`)** | Si nunca se ha registrado una tasa válida para una moneda, mostrar `"Sin tasa disponible"` (`—`), permitir operaciones que no requieran conversión y, para guardar un gasto nuevo en Fase 0A (`SQLite v18`), exigir ingreso manual en `"Ajustar tasas"` o recuperar conexión. | Se mantiene íntegramente vigente `A-01` y `contrato-v1.2.md` §2.4: `D-03` **no** autoriza guardar equivalencias `null` ni tuples incompletos en gastos nuevos bajo el contrato actual. | **APROBADA** |
| **`D-04`** | **Tasas independientes por moneda: `USD BCV`, `EUR BCV`, `USDT P2P` (`H-1`, `A-01`, `A-03`, `A-04`)** | Independencia estricta entre `USD`, `EUR` y `USDT`. Prohibido sustituir una tasa faltante con la de otra moneda. En Fase 0A (`SQLite v18`), cada moneda busca exclusivamente la última tasa válida de su propio mercado o requiere ingreso manual / conexión. El modo *standby* para equivalencias pendientes queda diferido a `0A.1` / Fase 0B. | Eliminación de todo fallback cruzado (`cachedUsdt ?? _tasaCambioVesUsd`, `tasaEur > 0 ? tasaEur : tasaUsd`). Conservación íntegra de `A-01`, `A-03`, `A-04` y `contrato-v1.2.md` §2.4 en Fase 0A. | **APROBADA** |
| **`D-05`** | **Precedencia y persistencia de tasas manuales vs. automáticas (`NEW-3b`)** | Distinguir entre: (1) última tasa automática registrada, (2) tasa manual global configurada por el usuario, y (3) tasa manual de un gasto individual. La tasa manual global conserva su procedencia manual y persiste al reiniciar prevaleciendo sobre cachés automáticas anteriores mientras no haya red; cuando vuelve Internet se actualiza con la tasa en vivo validada. La tasa manual de un gasto individual jamás se sobrescribe. | Unificación de lectura/escritura en `SettingsProvider` y `GastoProvider`. Prohibido convertir automáticamente una tasa de procedencia manual en una tasa `BCV`, `EUR oficial` o `USDT P2P`. | **APROBADA** |
| **`D-06`** | **Fallos de purga, estado previo y 3 estados independientes por moneda (`NEW-2`, `NEW-5`, `B2`, `A-07`)** | Modelar 3 estados independientes para `USD`, `EUR` y `USDT`: `actualizada`, `referencia` y `sinTasa` (sin depender de un único booleano global). Si la purga falla (`-1`), no se consumen tasas no verificadas del disco; las tasas ya validadas en memoria durante la sesión se conservan como `referencia` cuando corresponda; las monedas sin tasa verificada quedan en `sinTasa`. El estado `sinTasa` nunca se etiqueta como `referencia`. | `SettingsProvider` y `GastoProvider` exponen estados por moneda. Una tasa nueva validada en vivo actualiza la memoria aunque falle su persistencia local. La marca de purga solo se fija tras confirmar la limpieza persistente en disco (`NEW-1`). | **APROBADA** |
| **`D-07`** | **Identificación visual de tasas offline, manuales y ausentes** | Utilizar las denominaciones canónicas: `"Última tasa registrada"` (acompañada siempre de fecha y fuente), `"Tasa manual"` (para procedencia manual) y `"Sin tasa disponible"` (utilizando `—`). Solicitar confirmación de tasas de referencia al guardar el gasto, sin banners intrusivos en la calculadora. | Ajuste de etiquetas en `MoreScreen`, `ReviewExpenseScreen` y `CurrencyCalculatorScreen` para reflejar el estado individual de cada moneda sin avisos engañosos. | **APROBADA** |
| **`D-08`** | **Criterio canónico de validez numérica (`NEW-3`)** | El criterio canónico de validez numérica es `val is num && val.isFinite && val > 1.0`, aplicado uniformemente a todas las rutas de validación monetaria. Se elimina el umbral divergente de `50.0` como criterio general de validez. | Unificación del predicado numérico en `ExchangeRateService`, `SettingsProvider`, `GastoProvider` y `ExchangeRatesData.fromJson`, sin que ello sustituya la validación de mercado, procedencia, fecha efectiva ni correspondencia entre monedas. | **APROBADA** |

---

### Detalle Normativo de las Decisiones D-01 a D-08

#### D-01 y D-02 — Eliminación de `850.0`, Clasificación por Fecha Efectiva y Antigüedad
- **Identificadores:** `D-01`, `D-02`
- **Política aprobada:**
  1. Queda eliminado el uso de `AppConstants.defaultTasaCambio = 850.0` como tasa efectiva o fallback de conversión en proveedores y pantallas.
  2. **Prohibido clasificar automáticamente toda tasa almacenada en caché como referencia.** La clasificación de una tasa depende estrictamente de su `fechaEfectiva` respecto a la fecha del gasto (`fechaSolicitada`):
     - **`actualizada`:** Tasa obtenida y validada en vivo durante la sesión.
     - **`exacta`:** Tasa cuya `fechaEfectiva` coincide con la fecha del gasto (`fechaEfectiva == fechaSolicitada`), o corresponde al último cierre hábil oficial inmediato debidamente verificado (ej. fin de semana o feriado bancario respecto al cierre hábil inmediato anterior). Una tasa descargada previamente y almacenada en caché **es `exacta`** para un gasto de esa misma fecha; la procedencia de caché no implica automáticamente que sea una tasa desactualizada.
     - **`referencia`:** Tasa cuya `fechaEfectiva` es anterior a la fecha solicitada y **no** cumple la condición de cierre hábil inmediato (por ejemplo, la última tasa conocida en caché usada mientras no hay conexión para una fecha posterior).
  3. Las tasas en estado `referencia` conservan siempre su `fechaEfectiva` y su fuente real (`BCV`, `DolarAPI`, `USDT P2P`, `Manual`), permiten pre-rellenar cálculos y **exigen confirmación explícita del usuario (`confirmadaPorUsuario: true`)** antes de guardar el gasto, mostrando una advertencia reforzada cuando su antigüedad supere los **5 días**.

#### D-03 y D-04 — Ausencia de Tasa Válida, Independencia por Moneda y Vigencia de A-01
- **Identificadores:** `D-03`, `D-04`
- **Política aprobada:**
  1. **Independencia estricta por moneda (`USD`, `EUR`, `USDT`):** Cada mercado (`RateMarket.usdOficial`, `RateMarket.eurOficial`, `RateMarket.usdtP2p`) es independiente. Queda terminantemente prohibido sustituir una tasa faltante con la tasa de otra moneda (`USD -> USDT`, `USD -> EUR` o viceversa). La existencia de una tasa o referencia para una moneda no autoriza utilizarla como sustituto de otra.
  2. **Vigencia íntegra de `A-01` y del `contrato-v1.2.md` en Fase 0A (`SQLite v18`):**
     - No se permite guardar gastos nuevos con tuples monetarios incompletos.
     - `D-03` **no autoriza** guardar equivalencias `null` en gastos nuevos bajo el contrato actual.
     - Si falta la tasa en vivo o exacta de `USD`, `EUR` o `USDT`, se busca exclusivamente la última tasa válida registrada **de ese mismo mercado**.
     - Si no existe ninguna tasa válida previa para ese mercado en el dispositivo, la interfaz muestra `"Sin tasa disponible"` (`—`), permite las operaciones de consulta que no requieran conversión y, para poder guardar un gasto nuevo, exige que el usuario ingrese manualmente la tasa faltante mediante `"Ajustar tasas"` o recupere la conexión a Internet.
     - El modo *"en espera (standby)"* para guardar gastos dejando equivalencias secundarias pendientes queda formalmente diferido a la etapa **`0A.1` / Fase 0B (`SQLite v19`)**, una vez completadas y validadas `E0-02`, `E0-03` y `E0-04`.

#### D-05 — Distinción y Precedencia entre Tasas Automáticas y Manuales
- **Identificador:** `D-05`
- **Política aprobada:**
  1. El sistema distingue explícitamente tres categorías de tasa:
     - **Última tasa automática registrada:** Obtenida de fuentes remotas autorizadas (`Gateway`, `DolarAPI`, `Yadio`, `jsDelivr`) con su mercado y fecha efectiva.
     - **Tasa manual global configurada por el usuario:** Establecida explícitamente por el usuario a nivel de aplicación (`setTasaCambio`).
     - **Tasa manual introducida en un gasto individual:** Ingresada por el usuario en el formulario de un gasto específico (`"Ajustar tasas"`).
  2. **Persistencia y precedencia de la tasa manual global:** Conserva su procedencia manual (`RateSourceId.manualUsuario` / `'Manual'`) y su persistencia en disco, teniendo prioridad al reiniciar la aplicación sobre cachés automáticas anteriores mientras no exista conexión a Internet.
  3. **Retorno de Internet:** Cuando vuelve la conexión y se obtiene y valida una cotización en vivo, la actualización automática actualiza la tasa global activa conforme a la política aprobada.
  4. **Inmutabilidad de la tasa manual por gasto:** La tasa manual introducida en un gasto individual **nunca** es sobrescrita por una actualización global o automática.
  5. **Integridad de procedencia:** Queda prohibido convertir o etiquetar automáticamente una tasa de procedencia manual como si fuera una tasa `BCV`, `EUR oficial` o `USDT P2P`.

#### D-06 — Estados Independientes por Moneda y Comportamiento ante Fallos de Purga
- **Identificador:** `D-06`
- **Política aprobada:**
  1. Se registran y gestionan los tres estados de disponibilidad de forma **independiente para cada moneda (`USD`, `EUR`, `USDT`)**:
     - `actualizada`
     - `referencia`
     - `sinTasa`
  2. Queda prohibido utilizar un único booleano global (`_tasasSonReferencia`) para describir estados monetarios que pueden diferir entre `USD`, `EUR` y `USDT`, o para colapsar `referencia` y `sinTasa`.
  3. **El estado `sinTasa` nunca debe etiquetarse como `referencia`.**
  4. **Reglas ante fallo de purga (`ensureCacheHistoricaPurgada == -1`) o fallo de `SharedPreferences`:**
     - Las tasas no verificadas almacenadas en disco **no se consumen** (cumplimiento estricto de `A-07`).
     - Las tasas que **ya habían sido previamente obtenidas y validadas en memoria durante la sesión activa** no se destruyen: se conservan en memoria como `referencia` cuando corresponda.
     - Las monedas que carezcan de tasa previamente validada en la sesión quedan en estado `sinTasa` (`0.0` / `null`).
     - Una tasa nueva obtenida y validada en vivo desde la red actualiza el estado en memoria a `actualizada` aunque falle su persistencia local en `SharedPreferences`.
     - La marca persistente de purga (`tasas_cache_historica_purgada_v1`) solo se fija después de confirmar que la limpieza persistente en disco se completó sin fallos (`NEW-1`).

#### D-07 — Denominaciones Visuales Canónicas en Interfaz
- **Identificador:** `D-07`
- **Política aprobada:**
  1. Se adoptan las siguientes denominaciones oficiales en la interfaz:
     - **`Última tasa registrada`**, acompañada siempre de su fecha efectiva y fuente (ej. `"Última tasa registrada · BCV 30/10/2026"`).
     - **`Tasa manual`**, cuando la tasa provenga de ingreso manual del usuario.
     - **`Sin tasa disponible`**, utilizando el símbolo **`—`** en lugar de `Bs. 0,00` cuando la moneda se encuentre en estado `sinTasa`.
  2. La confirmación del uso de una tasa de referencia ocurre al guardar el gasto, sin introducir banners intrusivos en la Calculadora Cambiaria.

#### D-08 — Criterio Canónico Único de Validez Numérica
- **Identificador:** `D-08`
- **Política aprobada:**
  1. El criterio canónico de validez numérica de una tasa de cambio es:
     `val is num && val.isFinite && val > 1.0`
  2. Este criterio se aplica uniformemente a todas las rutas de validación monetaria (`ExchangeRateService`, `SettingsProvider`, `GastoProvider`, `ExchangeRatesData.fromJson`, caché histórica, semillas y tasas manuales).
  3. Se elimina el umbral divergente `> 50.0` como criterio general de validez.
  4. **Restricción de suficiencia:** Superar la validación numérica (`val is num && val.isFinite && val > 1.0`) es condición necesaria pero **no suficiente**: no sustituye en ningún caso la validación de mercado (`RateMarket`), procedencia autorizada (`RateSourceId`), fecha efectiva (`fechaEfectiva`) ni correspondencia estricta entre monedas (`RateQuoteInput.validateFor`).

