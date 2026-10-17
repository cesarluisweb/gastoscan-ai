# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Compilación en verde del Build 505 (CI 501, commit `a3c7184`). Verificación forense en DEX confirmó que `Continuation` y `SharedPreferencesApiRegistrar` permanecen íntegros sin ofuscación. La landing y el panel web están desplegados en producción.
- **Preservación:** Blindaje de R8 en `build_apk.yml` intacto (`-dontobfuscate`, `-dontoptimize`, `-keepattributes`), scripts operativos y reglas intactos.

## Decisiones Técnicas y de Negocio Recientes
- La causa de las tasas en 40 Bs era ofuscación de `Continuation` por R8. Con `-dontobfuscate`, `-dontoptimize`, `-keepattributes` y `proguardFiles("proguard-rules.pro")`, la firma JNI queda 100% protegida.
- La sincronización manual en `MoreScreen` es silenciosa (sin `SnackBar` técnico invasivo); errores se registran en `debugPrint`.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Validación manual en dispositivo físico por César de los 4 lentes y las 3 pastillas de liquidación en el APK Build 505.

