# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y restauración a Build 470 (1.0.4).
- **Acción Reciente:** Inspección forense de DEX reveló que R8 ofuscaba `kotlin.coroutines.Continuation` a `jj`, rompiendo la llamada JNI de Pigeon. Se aplicó `-dontobfuscate`, `-dontoptimize` y keep de Kotlin.
- **Respaldo:** El trabajo y diagnóstico previo de FIN-12 queda salvaguardado en la rama `backup/pre-regreso-build-470`.
- **Preservación:** Documentación técnica (`DOC_*.md`), scripts operativos (`scripts/wait_ci.ps1`) y reglas se mantienen intactos.

## Decisiones Técnicas y de Negocio Recientes
- La causa de las tasas fijas en 40 Bs era que Dart busca por JNI `getAll(String, List, Continuation)` y R8 renombraba `Continuation` a `jj`.
- Se configuró `-dontobfuscate`, `-dontoptimize` y `-keep class kotlin.**` en `build_apk.yml` garantizando firmas nativas intactas.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Compilar en CI (Build 498+), probar en teléfono de César y confirmar que las tasas cargan en vivo.
