# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Corrección integral de sincronización y adopción de presupuestos (SYNC-01): inclusión de `firestore:rules` en CI/CD, método `getUltimoPresupuestoConfigurado` en SQLite para heredar presupuestos saltando meses vacíos, sanitización de tipos Map en `SyncService`, adopción en panel web y aislamiento de bloques de sincronización.
- **Estado de CI:** CI build 516 en verde (`success` en commit `1d9e05f`), pruebas unitarias aprobadas, reglas desplegadas y APK/AAB listos. `SYNC-01` en `Pendiente de validación 🧪`.

## Decisiones Técnicas y de Negocio Recientes
- Despliegue de `firestore:rules` integrado en GitHub Actions junto a `hosting` (`npx firebase-tools deploy --only hosting,firestore:rules`).
- La herencia de presupuesto ahora busca el último presupuesto configurado históricamente (`antesDeAnio`, `antesDeMes`), en lugar de restringirse ciegamente a `mes - 1`.
- Aislamiento de excepciones en `SyncService.syncBidirectional()`: fallos en presupuestos o Gemini no abortan la sincronización de gastos ni viceversa.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Validación en dispositivo físico por César según DOC_SINCRONIZACION_PRESUPUESTO.md para graduar `SYNC-01` a `Completada ✅`.
- Abordar `UI-06`: unificar orden canónico (USD -> VES -> USDT -> EUR) en vistas secundarias.
