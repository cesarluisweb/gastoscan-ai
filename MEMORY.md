# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y restauración a Build 470 (1.0.4).
- **Acción Reciente:** Identificada causa raíz del fallo en APK (NoSuchMethodError en SharedPreferences por optimización agresiva de R8). Corregidas reglas ProGuard en CI.
- **Respaldo:** El trabajo y diagnóstico previo de FIN-12 queda salvaguardado en la rama `backup/pre-regreso-build-470`.
- **Preservación:** Documentación técnica (`DOC_*.md`), scripts operativos (`scripts/wait_ci.ps1`) y reglas se mantienen intactos.

## Decisiones Técnicas y de Negocio Recientes
- La causa de las tasas fijas en 40 Bs era que `SharedPreferences.getInstance()` fallaba por R8/ProGuard en APK release, abortando antes de la llamada HTTP.
- Se configuró `-keep class io.flutter.plugins.**` y `-keep class dev.flutter.pigeon.**` y se cambió a `proguard-android.txt` en `build_apk.yml`.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Compilar en CI (Build 496+), probar en teléfono de César y confirmar que las tasas cargan en vivo.
