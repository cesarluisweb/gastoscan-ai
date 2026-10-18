# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Rediseño y desacoplamiento de las 3 pastillas de liquidación en `ReviewExpenseScreen` y `panel.astro`: pastillas independientes con bordes activos claros, espaciado de 6dp, textos limpios ('En Bs. a tasa BCV', 'En Bs. a tasa P2P', 'En divisa directa') y etiqueta de contexto superior.
- **Preservación:** Blindaje de R8 en `build_apk.yml` intacto (`-dontobfuscate`, `-dontoptimize`, `-keepattributes`), scripts operativos y reglas intactos.

## Decisiones Técnicas y de Negocio Recientes
- La causa de las tasas en 40 Bs era ofuscación de `Continuation` por R8. Con `-dontobfuscate`, `-dontoptimize`, `-keepattributes` y `proguardFiles("proguard-rules.pro")`, la firma JNI queda 100% protegida.
- La sincronización manual en `MoreScreen` es silenciosa (sin `SnackBar` técnico invasivo); errores se registran en `debugPrint`.
- Las 3 pastillas de liquidación se muestran como botones independientes con feedback táctil y borde de acento activo (`AppColors.primary`).

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Monitorear CI tras push y verificar que el nuevo build mantenga las pastillas refinadas y las firmas DEX íntegras.


