# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y restauración a estado funcional probado.
- **Acción Crítica Reciente:** Restauración de `main` al estado funcional exacto de Build 470 (`54f8432`) para garantizar tasas en vivo BCV (~880 Bs). El desarrollo de `FIN-11` queda 100% respaldado en `feature/fin-11-motor-multimoneda-backup` y etiqueta `backup-pre-revert-build-494`.
- **Documentación Técnica:** [ROADMAP.md](ROADMAP.md) y [DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md) preservados.

## Decisiones Técnicas y de Negocio Recientes
- **Restauración a Build 470 (Opción A):**
  1. Rama de respaldo permanente `feature/fin-11-motor-multimoneda-backup` y tag `backup-pre-revert-build-494` creados en origin.
  2. Árbol de código restaurado a `54f8432` donde las tasas cargaban de forma inmediata sin quedarse en valores semilla (40/850).
  3. Preservadas las herramientas de CI (`scripts/wait_ci.ps1`), workflows y documentación técnica.

## Errores y Fricciones a Evitar
- No romper la trazabilidad de builds en GitHub Actions; mantener numeración incremental (+4).
- Al reintroducir componentes de FIN-11 desde la rama de respaldo, hacerlo de forma modular y validando las tasas paso a paso.

## Próximo Paso Inmediato
- Monitorear el CI del nuevo build (Build 495), verificar APK publicado y validar en teléfono de César que las tasas cargan en vivo.
