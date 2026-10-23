# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y Fase 6.2 (Finanzas y UX).
- **Acción Reciente (FIN-09 Equivalencias Multimoneda Inmutables):**
  1. Base de datos elevada a SQLite v18: columnas `total_eur` (INTEGER centavos) y `tasa_eur` (REAL) con backfill inmutable en `DatabaseHelper` y soporte en `GastoModel`.
  2. `ReviewExpenseScreen`: resuelto bug donde Euro BCV sobreescribía Dólar BCV en compras en `VES`. Implementadas 3 columnas fijas de equivalencia simultáneas (`USD BCV`, `EUR BCV`, `USDT P2P`), edición de tasa por chip y botón para restaurar tasa oficial histórica (`Icons.restart_alt`).
  3. Compras en `USDT`: flujo limpio sin pedir bolívares, con cintillo de equivalencias informativas y respaldo de tasas del día en segundo plano.
  4. Lentes financieros móviles (`DashboardScreen`, `SummaryCard`, `ExpenseCard`, `CurrencyFormatter`) y panel web (`landing/src/pages/panel.astro`) unificados con paridad al céntimo.
  5. Documentación de tarea crítica creada: `docs/DOC_TASAS_EQUIVALENCIAS_MULTIMONEDA.md`. Estado en `ROADMAP.md`: `Pendiente de validación 🧪`.
- **Acción Previa (Lote 1 Argon):** Sanitización XSS en panel web, protección de clave BYOK en `FlutterSecureStorage`, cabecera `x-goog-api-key` y anti-CSV Injection.

## Decisiones Técnicas y de Negocio Recientes
- La tasa Euro nunca debe sobrescribir la tasa Dólar en memoria (`_tasaEurCtrl` y `_tasaCambioCtrl` son independientes).
- En pagos directos en divisa (`USDT`), no se exige tasa en bolívares en la UI, pero se guardan las tasas de la fecha para los lentes `Bs.` y `EUR`.
- Inmutabilidad estricta: los montos históricos en bolívares y divisas nunca se recalculan con tasas futuras.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Iniciar Lote 3 de la Auditoría Integral Argon (`docs/auditoria_integral_argon.md`): Integridad de Sincronización offline, optimización SQLite y limpieza de datos en cierre de sesión (`clearLocalDataOnSignOut`).
