---
name: diagnosticar-ci
description: "Procedimiento para monitorear GitHub Actions, diagnosticar errores de compilación y pruebas, y leer test_results.txt de forma remota sin modificar el working tree local."
---

# Diagnóstico de Integración Continua (GitHub Actions)

## 1. Monitoreo del Workflow y Detección de Errores

### Paso 1: Consultar Estado del Run Activo
El SDK de Flutter no está instalado en la máquina local. Toda compilación y suite de pruebas se ejecuta exclusivamente en el runner de GitHub Actions (`build_apk.yml`).

Monitorear el último run en `main`:
```powershell
gh run list --branch main --limit 1 --json databaseId,status,conclusion,headSha
```

### Paso 2: Identificar el Paso Fallido
El endpoint `/jobs/{id}/logs` devuelve HTTP 403 en este repositorio privado. En su lugar, consultar los steps del job mediante la API estructurada:
```powershell
$runId = (gh run list --branch main --limit 1 --json databaseId | ConvertFrom-Json)[0].databaseId
gh api "repos/:owner/:repo/actions/runs/$runId/jobs" --jq '.jobs[0].steps[] | select(.conclusion == "failure") | {name: .name, number: .number}'
```

---

## 2. Lectura Remota Segura de `test_results.txt` (Canal Principal)

Cuando los tests unitarios (`flutter test`) o el análisis estático (`flutter analyze`) fallan en CI, el workflow ejecuta el paso *"Guardar Logs de Error"*, commiteando automáticamente el archivo `test_results.txt` directamente en la rama remota (`origin/main`).

**Procedimiento de Lectura Remota (Sin tocar el working tree local):**
```powershell
# 1. Traer los metadatos remotos más recientes sin mezclar
git fetch origin main

# 2. Leer directamente el reporte de fallos desde el commit remoto
git show origin/main:test_results.txt
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
