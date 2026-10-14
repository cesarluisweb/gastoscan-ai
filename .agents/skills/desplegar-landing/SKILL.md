---
name: desplegar-landing
description: "Procedimiento oficial para compilar, verificar y desplegar la landing page y el panel web a producción vía CI/CD en GitHub Actions."
---

# Procedimiento de Publicación de la Landing Page y Panel Web

## 1. Regla de Oro del Canal Único
**GitHub Actions (`build_apk.yml`) es el único canal autorizado para desplegar la web a producción en Firebase Hosting.**
- **Sobrescritura por CI:** Cualquier despliegue ejecutado manualmente desde la máquina local será sobrescrito en el siguiente `git push` a `main`, ya que el pipeline de GitHub Actions compila y despliega automáticamente Firebase Hosting en el paso final.
- **Riesgo de Desincronización en Despliegues Locales:** Si se ejecuta un deploy local, el archivo `landing/public/version.json` contendrá valores estáticos locales sin el número de compilación dinámico oficial (`BASE_BUILD + github.run_number`) que genera el CI. Esto provoca desincronización entre la versión anunciada en la landing y el APK real distribuido en BanaHosting.
- **Consumo de Cuota de CI en Cambios Web:** De acuerdo con los filtros `paths-ignore` de `.github/workflows/build_apk.yml`, un `git push` que modifique archivos dentro de `landing/` disparará la compilación completa de Android (APK y AAB) consumiendo minutos de GitHub Actions. *(Mejora futura documentada: desacoplar los workflows de web y móvil).*

---

## 2. Flujo de Trabajo Rutinario (CI/CD)

### Paso 1: Verificación de Compilación Local (Sin Desplegar)
Antes de enviar cambios al repositorio, verificar que el proyecto Astro compila limpiamente sin errores de sintaxis ni de dependencias:

En PowerShell desde el directorio raíz:
```powershell
Set-Location landing
$env:ASTRO_TELEMETRY_DISABLED="1"
npm run build
Set-Location ..
```
*Criterio de Éxito:* La salida debe terminar con `✓ Completed in ...` y generar el directorio `landing/dist/`.

### Paso 2: Sincronización con el Repositorio
Hacer commit de los cambios y empujar a `main`:
```powershell
git add landing/
git commit -m "feat(web): descripcion del cambio en landing o panel"
git push origin main
```

### Paso 3: Monitoreo del Pipeline en GitHub Actions
Monitorear activamente el workflow hasta confirmar `conclusion: success` utilizando la API de GitHub:
```powershell
# Obtener el run_id del commit recién enviado
$run = gh run list --branch main --limit 1 --json databaseId,status,conclusion | ConvertFrom-Json
$runId = $run[0].databaseId
gh run watch $runId
```

### Paso 4: Verificación en Vivo en Producción
Una vez que el job finalice con éxito, validar mediante petición HTTP que el contenido nuevo esté disponible:
```powershell
# Verificar estado HTTP de la landing
curl.exe -sI https://rindemas.cesarluis.com/ | Select-String "HTTP/"

# Verificar redirección del APK
curl.exe -sI https://rindemas.cesarluis.com/rindemas.apk | Select-String "HTTP/"
```

---

## 3. Despliegue de Emergencia Local (Solo con Autorización de César)
Si la cuota de GitHub Actions está agotada o el CI presenta una caída global, y César ha dado **autorización explícita previa**, se puede ejecutar el despliegue manual:

```powershell
# 1. Compilar Astro
Set-Location landing
$env:ASTRO_TELEMETRY_DISABLED="1"
npm run build
Set-Location ..

# 2. Desplegar a Firebase Hosting (flag --non-interactive OBLIGATORIO en Windows)
firebase.cmd deploy --only hosting --non-interactive

# 3. Validar producción
curl.exe -sI https://rindemas.cesarluis.com/
```
