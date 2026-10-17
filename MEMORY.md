# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y restauración a Build 470 (1.0.4).
- **Acción Reciente:** Restaurado el código fuente de la app (`lib/` y `test/`) al estado exacto de Build 470 (`54f8432`) a solicitud de César.
- **Respaldo:** El trabajo y diagnóstico previo de FIN-12 queda salvaguardado en la rama `backup/pre-regreso-build-470`.
- **Preservación:** Documentación técnica (`DOC_*.md`), scripts operativos (`scripts/wait_ci.ps1`) y reglas se mantienen intactos.

## Decisiones Técnicas y de Negocio Recientes
- La restauración del código a Build 470 devuelve la consulta de tasas a su implementación base previa (DolarAPI + Yadio simple).
- Se preserva el historial mediante commit hacia adelante en `main` para permitir despliegue continuo de CI sin romper versiones instalables en Android.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Monitorear ejecución de CI para compilar el nuevo APK con código de Build 470 y confirmar entrega en verde.
