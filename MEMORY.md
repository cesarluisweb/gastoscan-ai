# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y preparación de retorno a motor multimoneda (FIN-11).
- **Acción Reciente:** Build 500 verificado en producción (`version: 1.0.4+504`). Pruebas de tasas confirmadas exitosas por César. Documentación técnica auditada y actualizada.
- **Respaldo:** El código previo de FIN-11 está resguardado en el commit `0870133`.
- **Preservación:** Blindaje de R8 en `build_apk.yml` (`-dontobfuscate`, `-dontoptimize`, `-keepattributes`), scripts operativos y reglas intactos.

## Decisiones Técnicas y de Negocio Recientes
- La causa de las tasas en 40 Bs era ofuscación de `Continuation` por R8. Con `-dontobfuscate`, `-dontoptimize`, `-keepattributes` y `proguardFiles("proguard-rules.pro")`, la firma JNI queda 100% protegida.
- La sincronización manual en `MoreScreen` es silenciosa (sin `SnackBar` técnico invasivo); errores se registran en `debugPrint`.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Ejecución del plan de retorno a los avances multimoneda (`plan_retorno_avances_multimoneda.md`).
