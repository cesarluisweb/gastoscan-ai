# RM-03 — Catálogo Normativo de Diagnóstico Read-Only (`Q1..Q19` + `Q20`)

> **Fuente normativa:** `RM-03-fase-0-adenda.md` §7.4 (líneas 1211–1561) y `docs/rm-03/contrato-v1.2.md:579` (`Q20`).
> **Regla de entorno (`A-14`):** Ejecutar exclusivamente sobre una copia temporal del archivo SQLite (incluyendo `-wal` y `-shm` si existen), abriendo en solo lectura con `PRAGMA query_only = ON;` verificado antes de la primera consulta. Prohibido `UPDATE`, `DELETE`, `VACUUM`, `ANALYZE`, `CREATE INDEX` o exponer PII (`comercio`, `ocr_text`, `descripcion`, `ruta_foto_local`, `uuid` completo).

## Clases de diagnóstico
- **D (Demostrable):** Contradicción aritmética o violación de dominio indiscutible.
- **S (Sospechoso):** Patrón anómalo o indicio que requiere revisión, nunca condena automática.
- **V (Potencialmente válido):** Dato incompleto o heredado que puede ser legítimo.
- **N (No diagnosticable):** Sin procedencia suficiente para afirmar validez o invalidez.

---

### Q1 — Valores negativos o fuera de dominio (D)
```sql
SELECT id, uuid, moneda, total_original, total_usd, total_usdt, total_eur,
       tasa_cambio, tasa_usdt, tasa_eur
FROM gastos
WHERE eliminado_en IS NULL
  AND (total_original < 0 OR total_usd < 0 OR total_usdt < 0 OR total_eur < 0
       OR tasa_cambio < 0 OR tasa_usdt < 0 OR tasa_eur < 0);
```

### Q2 — Identidad de la moneda de origen (D)
```sql
SELECT id, uuid, moneda, total_original, total_usd, total_usdt, total_eur
FROM gastos
WHERE eliminado_en IS NULL
  AND (
       (moneda = 'USD'  AND ABS(total_usd  - total_original) > 1)
    OR (moneda = 'USDT' AND total_usdt IS NOT NULL AND ABS(total_usdt - total_original) > 1)
    OR (moneda = 'EUR'  AND total_eur  IS NOT NULL AND ABS(total_eur  - total_original) > 1)
  );
```

### Q3 — Importe original cero con equivalencias no cero (D)
```sql
SELECT id, uuid, moneda, total_original, total_usd, total_usdt, total_eur
FROM gastos
WHERE eliminado_en IS NULL
  AND total_original = 0
  AND (total_usd <> 0 OR total_usdt <> 0 OR total_eur <> 0);
```

### Q4 — `tasa_cambio = 1.0` (D, violación de dominio)
```sql
SELECT id, uuid, moneda, total_original, total_usd, tasa_cambio,
       fuente_tasa_cambio, fecha_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND tasa_cambio = 1.0;
```

### Q5 — `tasa_cambio = 0` o `NULL` (V/S, no D)
```sql
SELECT id, uuid, moneda, total_original, total_usd, total_usdt, total_eur,
       CASE WHEN tasa_cambio IS NULL THEN 'NULL' ELSE 'CERO' END AS estado_tasa,
       fuente_tasa_cambio, fecha_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND (tasa_cambio IS NULL OR tasa_cambio = 0);
```

### Q6 — VES con `total_usd > 0` y tasa `NULL`/0 (V)
```sql
SELECT id, uuid, moneda, total_original, total_usd,
       CASE WHEN tasa_cambio IS NULL THEN 'NULL' ELSE 'CERO' END AS estado_tasa,
       fuente_tasa_cambio, fecha_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'VES'
  AND total_usd > 0
  AND (tasa_cambio IS NULL OR tasa_cambio = 0);
```

### Q7 — Tasa implícita vs almacenada en VES (S)
```sql
SELECT id, uuid, moneda, total_original, total_usd, tasa_cambio,
       ROUND(total_original * 1.0 / total_usd, 4) AS tasa_implicita,
       ROUND(ABS((total_original * 1.0 / total_usd) - tasa_cambio) / tasa_cambio * 100, 2) AS diferencia_pct,
       fuente_tasa_cambio, fecha_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'VES'
  AND total_usd > 0
  AND tasa_cambio > 1
  AND ABS((total_original * 1.0 / total_usd) - tasa_cambio) / tasa_cambio > 0.05;
```

### Q8 — EUR con `total_usd = 0` (V)
```sql
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'EUR'
  AND total_usd = 0
  AND total_original > 0;
```

### Q9 — EUR con `total_eur = total_usd` (S)
```sql
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'EUR'
  AND total_eur IS NOT NULL
  AND total_usd > 0
  AND ABS(total_eur - total_usd) <= 1;
```

### Q10 — `tasa_eur = tasa_cambio` en EUR (Q10a: S; Q10b: D si el cruce falla)
```sql
-- Q10a: igualdad de tasas (S)
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'EUR'
  AND tasa_eur IS NOT NULL
  AND tasa_cambio IS NOT NULL
  AND ABS(tasa_eur - tasa_cambio) < 0.000001;

-- Q10b: igualdad + identidad del cruce rota (D)
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur,
       ROUND(total_eur * tasa_eur, 2) AS ves_desde_eur,
       ROUND(total_usd * tasa_cambio, 2) AS ves_desde_usd
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'EUR'
  AND tasa_eur IS NOT NULL
  AND tasa_cambio IS NOT NULL
  AND ABS(tasa_eur - tasa_cambio) < 0.000001
  AND total_original > 0
  AND total_usd > 0
  AND ABS((total_original * tasa_eur) - (total_usd * tasa_cambio)) > 100;
```

### Q11 — `tasa_usdt = tasa_cambio` en VES/EUR (S)
```sql
SELECT id, uuid, moneda, total_original, total_usd, total_usdt,
       tasa_cambio, tasa_usdt, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda IN ('VES', 'EUR')
  AND tasa_usdt IS NOT NULL
  AND tasa_cambio IS NOT NULL
  AND ABS(tasa_usdt - tasa_cambio) < 0.000001;
```

### Q12 — VES con `total_usdt = total_usd` (V/S)
```sql
SELECT id, uuid, moneda, total_original, total_usd, total_usdt,
       tasa_cambio, tasa_usdt, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'VES'
  AND total_usdt IS NOT NULL
  AND total_usd > 0
  AND ABS(total_usdt - total_usd) <= 1;
```

### Q13 — EUR/USDT con `total_eur = total_usd` (S)
```sql
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur, tasa_usdt, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda IN ('EUR', 'USDT')
  AND total_eur IS NOT NULL
  AND total_usd > 0
  AND ABS(total_eur - total_usd) <= 1;
```

### Q14 — VES: `total_original` vs `total_usd × tasa_cambio` (S)
```sql
SELECT id, uuid, moneda, total_original, total_usd, tasa_cambio,
       ROUND(total_usd * tasa_cambio, 2) AS ves_implicito,
       ROUND(total_original - (total_usd * tasa_cambio), 2) AS diferencia,
       fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'VES'
  AND total_usd > 0
  AND tasa_cambio > 1
  AND ABS(total_original - (total_usd * tasa_cambio)) > 100;
```

### Q15 — Identidad del cruce EUR (S)
```sql
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur,
       ROUND(total_eur * tasa_eur, 2) AS ves_desde_eur,
       ROUND(total_usd * tasa_cambio, 2) AS ves_desde_usd,
       ROUND((total_eur * tasa_eur) - (total_usd * tasa_cambio), 2) AS diferencia
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'EUR'
  AND total_eur > 0
  AND total_usd > 0
  AND tasa_eur > 1
  AND tasa_cambio > 1
  AND ABS((total_eur * tasa_eur) - (total_usd * tasa_cambio)) > 100;
```

### Q16 — USDT: lente VES P2P vs BCV (V para el dato)
```sql
SELECT id, uuid, moneda, total_original, total_usd, total_usdt,
       tasa_cambio, tasa_usdt,
       ROUND(total_usdt * tasa_usdt, 2) AS ves_p2p,
       ROUND(total_usd * tasa_cambio, 2) AS ves_bcv,
       ROUND((total_usdt * tasa_usdt) - (total_usd * tasa_cambio), 2) AS diferencia
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'USDT'
  AND total_usdt > 0
  AND tasa_usdt > 1
  AND tasa_cambio > 1
  AND ABS((total_usdt * tasa_usdt) - (total_usd * tasa_cambio)) > 100;
```

### Q17 — UUID duplicado (D para sync)
```sql
SELECT uuid, COUNT(*) AS n
FROM gastos
WHERE eliminado_en IS NULL
GROUP BY uuid
HAVING COUNT(*) > 1;
```

### Q18 — Fecha de tasa distinta de la fecha del gasto (S)
```sql
SELECT id, uuid, fecha, fecha_tasa_cambio, fuente_tasa_cambio, tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND tasa_cambio > 1
  AND (
       fecha_tasa_cambio IS NULL
    OR TRIM(fecha_tasa_cambio) = ''
    OR substr(fecha_tasa_cambio, 1, 10) <> substr(fecha, 1, 10)
  );
```
> Nota de interpretabilidad: se agregan buckets derivados en el reporte (`ISO_DISTINTA`, `ETIQUETA_NO_ISO`, `VACIA`) sin alterar la consulta normativa.

### Q19 — Procedencia ausente (S/N)
```sql
SELECT id, uuid, moneda, tasa_cambio, fuente_tasa_cambio, fecha_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND tasa_cambio > 1
  AND (fuente_tasa_cambio IS NULL OR TRIM(fuente_tasa_cambio) = '');
```

### Q20 — Indicios estadísticos `{36.5, 40.0, 474.0, 850.0}` (`contrato-v1.2.md:579`)
```sql
SELECT 'tasa_cambio' AS campo, '36.5' AS valor, COUNT(*) AS n
  FROM gastos WHERE eliminado_en IS NULL AND tasa_cambio = 36.5
UNION ALL SELECT 'tasa_cambio', '40.0',  COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_cambio = 40.0
UNION ALL SELECT 'tasa_cambio', '474.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_cambio = 474.0
UNION ALL SELECT 'tasa_cambio', '850.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_cambio = 850.0
UNION ALL SELECT 'tasa_usdt',   '36.5',  COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_usdt   = 36.5
UNION ALL SELECT 'tasa_usdt',   '40.0',  COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_usdt   = 40.0
UNION ALL SELECT 'tasa_usdt',   '474.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_usdt   = 474.0
UNION ALL SELECT 'tasa_usdt',   '850.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_usdt   = 850.0
UNION ALL SELECT 'tasa_eur',    '36.5',  COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_eur    = 36.5
UNION ALL SELECT 'tasa_eur',    '40.0',  COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_eur    = 40.0
UNION ALL SELECT 'tasa_eur',    '474.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_eur    = 474.0
UNION ALL SELECT 'tasa_eur',    '850.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_eur    = 850.0;
```
