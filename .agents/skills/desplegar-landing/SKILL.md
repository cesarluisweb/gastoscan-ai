---
name: desplegar-landing
description: "Procedimiento oficial para compilar, verificar y desplegar la landing page y el panel web a producción vía CI/CD en GitHub Actions."
---

# Procedimiento de Publicación de la Landing Page y Panel Web

## 1. Regla de Oro del Canal Único
**GitHub Actions (`deploy_web.yml` para cambios web y `build_apk.yml` tras releases móviles) es el único canal autorizado para desplegar la web a producción en Firebase Hosting.**
- **Pipeline Web Independiente (~50 s):** Todo cambio en `landing/**`, `firebase.json` o `firestore.rules` dispara exclusivamente `.github/workflows/deploy_web.yml` sin ejecutar la compilación de Android (`build_apk.yml` los ignora mediante `paths-ignore`).
- **Fuente Única de `version.json` en Repositorio:** El archivo `landing/public/version.json` versionado en el repositorio Git es la única fuente del JSON publicado por Astro. Con el cierre del canal de APK directo, `version.json` se mantiene con `version: 1.0.0` y `buildNumber: 1` durante la Prueba Cerrada para neutralizar comprobaciones automáticas en clientes legados (G1–G4) sin sobreescrituras en caliente desde producción.
- **Sobrescritura por CI:** Cualquier despliegue ejecutado manualmente desde la máquina local carecerá del pipeline de CI y será sobrescrito en el siguiente `git push` a `main`.

---

## 2. Flujo de Trabajo Rutinario (CI/CD)

### Paso 1: Verificación de Compilación Local (Sin Desplegar)
Antes de enviar cambios al repositorio, verificar que el proyecto Astro compila limpiamente sin errores de sintaxis ni de dependencias:

En PowerShell desde el directorio raíz:
```powershell
Set-Location landing; $env:ASTRO_TELEMETRY_DISABLED="1"; npm run build; Set-Location ..
```
*Criterio de Éxito:* La salida debe terminar con `✓ Completed in ...` y generar el directorio `landing/dist/`.

### Paso 2: Sincronización con el Repositorio
Hacer commit de los cambios y empujar a `main`:
```powershell
git add landing/
git commit -m "feat(web): descripcion del cambio en landing o panel"
git push origin main
```

### Paso 3: Monitoreo del Pipeline en GitHub Actions (Proceso Dormido Único)
Lanzar una sola vez `scripts/wait_ci.ps1` en segundo plano hasta confirmar `conclusion: success` (detecta automáticamente `deploy_web.yml` y usa intervalo corto de 30 s):
```powershell
powershell -ExecutionPolicy Bypass -File scripts/wait_ci.ps1
```
**Prohibido** usar `gh run watch` o consultar la API turno tras turno.

### Paso 4: Verificación en Vivo en Producción
Una vez que el job finalice con éxito, validar mediante petición HTTP que el contenido nuevo esté disponible y que `version.json` conserve el build activo:
```powershell
# Verificar estado HTTP de la landing
curl.exe -sI https://rindemas.cesarluis.com/ | Select-String "HTTP/"

# Verificar redirección de rutas de APK hacia la landing
curl.exe -sI https://rindemas.cesarluis.com/rindemas.apk | Select-String "HTTP/"

# Verificar integridad de version.json en producción
curl.exe -s https://rindemas.cesarluis.com/version.json
```

---

## 3. Despliegue de Emergencia Local (Solo con Autorización de César)
Si la cuota de GitHub Actions está agotada o el CI presenta una caída global, y César ha dado **autorización explícita previa**, se puede ejecutar el despliegue manual utilizando los archivos controlados por el repositorio:

```powershell
# 1. Compilar Astro (genera landing/dist/ preservando el version.json del repositorio)
Set-Location landing; $env:ASTRO_TELEMETRY_DISABLED="1"; npm run build; Set-Location ..

# 2. Desplegar a Firebase Hosting (flag --non-interactive OBLIGATORIO en Windows)
firebase.cmd deploy --only hosting --non-interactive

# 3. Validar producción
curl.exe -sI https://rindemas.cesarluis.com/
```
