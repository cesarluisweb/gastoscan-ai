---
name: diagnosticar-ci
description: "Procedimiento para monitorear GitHub Actions, diagnosticar errores de compilación y pruebas, y leer test_results.txt de forma remota sin modificar el working tree local."
---

# Diagnóstico de Integración Continua (GitHub Actions)

## 1. Monitoreo del Workflow mediante Proceso Dormido Único

El SDK de Flutter no está instalado en la máquina local. Toda compilación y suite de pruebas se ejecuta exclusivamente en el runner de GitHub Actions (`build_apk.yml`).

**Regla de oro:** el agente NUNCA consulta el estado del CI turno tras turno. Lanza una sola invocación dormida y espera su notificación.

### Paso 1: Lanzar el Proceso Dormido (Única Invocación)
`gh` CLI NO está instalado en esta máquina. Ejecutar `scripts/wait_ci.ps1` **una sola vez en segundo plano sin pasarle argumentos** (el script no acepta parámetros como `-HeadSha`; detecta `git rev-parse HEAD` automáticamente):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/wait_ci.ps1
```

El script localiza el run del commit actual, espera internamente (bucle `Start-Sleep` de 180 s, tope 25 min) y solo al terminar imprime el resumen:

```
CI 39032330731 | success | build 487 | ecc3760
```

*Si el script reporta `SIN RUN` significa que el push no disparó CI (típicamente por `paths-ignore` en cambios de solo documentación). No es un fallo.*

### Paso 2: Reporte de Fallo (Solo si `conclusion != success`)
`wait_ci.ps1` ya imprime automáticamente los steps fallidos y la cola de `test_results.txt`. Recurrir a la API solo si se necesita más detalle, con **una única** llamada a `/actions/runs/{id}/jobs`:

```powershell
$runId = 39032330731
$jobs = Invoke-RestMethod "https://api.github.com/repos/cesarluisweb/gastoscan-ai/actions/runs/$runId/jobs"
$jobs.jobs.steps | Where-Object { $_.conclusion -eq 'failure' } | Select-Object number, name
```

**Prohibido** solicitar `/actions/runs/{id}/logs`: devuelve HTTP 403 en este repositorio privado y su tamaño es enorme. **Prohibido** usar `gh run watch` (streaming bloqueante que vuelca la salida completa línea por línea).

### Visibilidad del Repositorio y Cuota de API
Mientras el repositorio esté **Público** (etapa de desarrollo) la API REST responde sin credenciales. Si vuelve a **Privado**, exportar `GITHUB_TOKEN` en el entorno; `wait_ci.ps1` lo toma de la variable y aborta de inmediato ante un `401`/`404` en lugar de esperar los 25 minutos.

**Cuota de API:** sin token el límite es de **60 peticiones por hora** por IP, margen muy corto para un intervalo agresivo (agotarla deja el monitoreo ciego hasta la reposición). Con `GITHUB_TOKEN` el límite sube a 5.000/hora. Ante un `403` el script calcula el momento de reposición y espera en lugar de fallar en silencio. Nunca escribir ese token en un archivo versionado.

---

## 2. Diagnóstico de Errores y Artefactos de CI (Canal Principal)

Los workflows de GitHub Actions **NUNCA** realizan commits en `main` para reportar fallos. Todos los registros se publican exclusivamente como artefactos descargables de CI.

### Prioridad de Artefactos de Error:
1. `aab-build-failure-log`: Fallos en la compilación del paquete AAB de producción (`aab_build_log.txt`).
2. `apk-build-failure-log`: Fallos en la compilación, alineación o firma de Rinde Más Dev (`apk_dev_build_log.txt`).
3. `test-results`: Fallos en pruebas unitarias (`flutter test`) o análisis estático (`flutter analyze`).

### Diagnóstico Automatizado con `scripts/wait_ci.ps1`:
Al finalizar la ejecución, si se detecta un fallo, `wait_ci.ps1` extrae automáticamente los pasos fallidos y descarga/muestra la cola del artefacto prioritario:
- Si `gh` CLI está disponible, usa `gh run download`.
- Si `GITHUB_TOKEN` está configurado en el entorno, lo descarga vía API REST y lo extrae con `Expand-Archive`.
- Si no hay credenciales, informa el nombre del artefacto y el enlace directo al run en GitHub para su inspección manual.

### Consulta Manual de Steps Fallidos vía API:
```powershell
$runId = <id_del_run>
$jobs = Invoke-RestMethod "https://api.github.com/repos/cesarluisweb/gastoscan-ai/actions/runs/$runId/jobs"
$jobs.jobs.steps | Where-Object { $_.conclusion -eq 'failure' } | Select-Object number, name
```

---

## 3. Inspección Forense de Binarios (DEX / APK ante Fallos Nativos)

Si una versión release falla en el dispositivo con `NoSuchMethodError`, `ClassNotFoundException` o `PlatformException(channel-error, ...)` que no ocurre en desarrollo:

1. **Descargar el APK de producción a `scratch/`:**
   ```powershell
   powershell -Command "Invoke-WebRequest -Uri 'https://rindemas.cesarluis.com/rindemas.apk?b=<build>' -OutFile 'scratch/test_apk.apk'"
   ```
2. **Inspeccionar los métodos y tipos en `classes.dex` mediante script Python:**
   Extraer y parsear la tabla de tipos y métodos del archivo DEX sin necesidad de decompiladores pesados:
   ```python
   import zipfile, struct
   with zipfile.ZipFile("scratch/test_apk.apk") as z:
       dex = z.read("classes.dex")
       # Verificar si los nombres de clases nativas o interfaces JNI fueron renombrados por R8
   ```
3. **Señal de alarma:** Si una firma de método que espera `kotlin.coroutines.Continuation` contiene tipos ofuscados de una o dos letras (ej. `Ljj;`), R8 ofuscó los tipos de Kotlin. La solución inmediata es asegurar `-dontobfuscate`, `-dontoptimize`, `-keepattributes` y `-keep class kotlin.Metadata` en ProGuard.
