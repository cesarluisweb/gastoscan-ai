# DOC E0-05b — Protocolo de Diagnóstico Read-Only (`Q01..Q20`)

## 1. Propósito y Alcance (`A-14`)

Implementa el protocolo de diagnóstico de solo lectura (`Q1..Q19` de la adenda §7.4 + `Q20` de `docs/rm-03/contrato-v1.2.md:579`) para inspeccionar copias de bases de datos SQLite sin modificar datos ni exponer Información Personal Identificable (PII).

- **Catálogo normativo:** [`docs/rm-03/diagnostico-q01-q20.md`](file:///c:/Development/Control%20de%20gastos%20VE/docs/rm-03/diagnostico-q01-q20.md)
- **Implementación:**
  - [`lib/domain/diagnostics/rm03_copy_strategy.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/domain/diagnostics/rm03_copy_strategy.dart)
  - [`lib/domain/diagnostics/rm03_diagnostic_protocol.dart`](file:///c:/Development/Control%20de%20gastos%20VE/lib/domain/diagnostics/rm03_diagnostic_protocol.dart)
  - [`tool/diagnose_sqlite.dart`](file:///c:/Development/Control%20de%20gastos%20VE/tool/diagnose_sqlite.dart)

## 2. Garantías de Seguridad y Aislamiento

1. **Sin contaminación del singleton:** `Rm03DiagnosticProtocol.runOnFile(String sourceDbPath)` solo recibe una ruta de archivo, nunca una `Database` abierta.
2. **Copia temporal con soporte WAL:** `FileRm03CopyStrategy` copia `.db`, `-wal` y `-shm` (si existen) a un directorio temporal único y los elimina en `finally`, incluso ante excepciones. (Recomendación operativa: cerrar la app antes de extraer el archivo origen).
3. **Solo lectura verificada (fail-closed):** Abre con `readOnly: true`, ejecuta `PRAGMA query_only = ON;` y verifica `PRAGMA query_only;` == `1` antes de consultar.
4. **Validación de esquema:** Lee `PRAGMA user_version;` y verifica con `PRAGMA table_info(gastos);` que existan todas las columnas requeridas antes de ejecutar `Q01..Q20`.
5. **Guard SQL:** `assertReadOnlySql` rechaza cualquier consulta que no comience por `SELECT` o `WITH`, o que contenga palabras clave mutantes (`UPDATE`, `DELETE`, `INSERT`, `DROP`, `ALTER`, `CREATE`, `VACUUM`, `ANALYZE`, `ATTACH`, `DETACH`, `REPLACE`).
6. **Cero PII:** El reporte excluye `comercio`, `ocr_text`, `descripcion`, `ruta_foto_local`, rutas de archivo y `uuid` en claro. Las muestras (`sample_hashes`, máx. 20) usan SHA-256 con sal efímera por ejecución.

## 3. Interpretación de `Q18` y `Q20`

- **`Q18`:** Ejecuta el SQL normativo intacto y clasifica en `breakdown` tres buckets derivados: `ISO_DISTINTA`, `ETIQUETA_NO_ISO` (`'Hoy'`, `'Guardada'`, etc. del panel web) y `VACIA`.
- **`Q20`:** Cuenta ocurrencias de `{36.5, 40.0, 474.0, 850.0}` en `tasa_cambio`, `tasa_usdt` y `tasa_eur` como **indicio estadístico** (`clase: 'indicio'`), nunca como prueba automática de corrupción.

## 4. Guía de Pruebas

- **Suite en CI:** [`test/diagnostics/rm03_diagnostic_protocol_test.dart`](file:///c:/Development/Control%20de%20gastos%20VE/test/diagnostics/rm03_diagnostic_protocol_test.dart) (`T1..T10` + validación de columnas faltantes).
- **Ejecución CLI sobre copia local:**
  ```powershell
  dart run tool/diagnose_sqlite.dart --db ruta\a\copia_gastoscan.db --out reporte.json
  ```
