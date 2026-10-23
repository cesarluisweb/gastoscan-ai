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

## 2. Lectura Remota Segura de `test_results.txt` (Canal Principal)

Cuando los tests unitarios (`flutter test`) o el análisis estático (`flutter analyze`) fallan en CI, el workflow ejecuta el paso *"Guardar Logs de Error"*, commiteando automáticamente el archivo `test_results.txt` directamente en la rama remota (`origin/main`).

**Procedimiento de Lectura Remota (Sin tocar el working tree local):**
```powershell
# 1. Traer los metadatos remotos más recientes sin mezclar
git fetch origin main

# 2. Leer directamente el reporte de fallos desde el commit remoto
#    Limitado a las ultimas 60 lineas para no volcar el reporte completo
git show origin/main:test_results.txt | Select-Object -Last 60

# 3. Si falló el step "Analisis Estatico de Codigo" (flutter analyze), filtrar solo errores y warnings:
git show origin/main:test_results.txt | Select-String -Pattern "error|warning"
```
*Ventajas:*
- No genera conflictos de git.
- No requiere `git stash` ni `git pull --rebase`.
- Protege intactos todos los archivos sin seguimiento o modificaciones locales en curso.

### Alternativa vía API de Contenidos de GitHub
Si no se dispone de conexión git directa:
```powershell
gh api repos/:owner/:repo/contents/test_results.txt --jq '.content' | [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($input))
```

---

## 3. Actualización Local Opcional (Manejo Seguro de Cambios)
Si por alguna razón se requiere sincronizar el commit de logs en la copia de trabajo local:

1. **Verificar estado limpio:**
   ```powershell
   git status --porcelain
   ```
2. **Si existen cambios locales pendientes (incluyendo archivos sin seguimiento):**
   ```powershell
   git stash -u -m "wip_antes_de_pull"
   git pull --rebase origin main
   git stash pop
   ```
3. Si ocurren conflictos durante el `stash pop`, resolver manualmente o descartar el commit de logs remoto con `git reset --soft HEAD~1`.

---

## 4. Inspección Forense de Binarios (DEX / APK ante Fallos Nativos)

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
