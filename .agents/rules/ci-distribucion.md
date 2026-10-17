---
trigger: glob
globs: ".github/workflows/**, android/**"
description: "Pipeline de CI/CD en GitHub Actions, inyección programática en Android y distribución automatizada de APK."
---

# Integración Continua (CI/CD) y Distribución de Binarios

## 1. Plataforma Android e Inyección Nativa en CI
- **Regeneración de `android/` en GitHub Actions:** El workflow `build_apk.yml` ejecuta `flutter create .` al inicio, borrando y regenerando la carpeta `android/` en cada ejecución.
- **Prohibición de Edición Local en `android/`:** Queda terminantemente prohibido modificar archivos locales dentro de `android/` (como `build.gradle.kts`, `settings.gradle` o manifiestos), ya que cualquier cambio se pierde en el runner de CI.
- **Inyección Programática por Bash:** Toda configuración nativa requerida (reglas ProGuard, firmas, plugins de Firebase o Google Sign-In) DEBE inyectarse mediante scripts automatizados (`sed`, scripts Python inline) directamente dentro del archivo `.github/workflows/build_apk.yml` después del paso de regeneración.

## 2. Autenticación Nativa y Google Sign-In (Error 10)
- **Registro Doble de Huellas SHA-1:** Para prevenir el Error 10 de Google Sign-In en Android, deben registrarse obligatoriamente **dos** huellas SHA-1 en el proyecto Firebase (`com.cesarluis.rindemas`):
  1. La de la clave de subida de producción (`android_template/rindemas.jks`).
  2. La de la clave de firma de Google Play (obtenida en Play Console → Integridad de la app → Certificado de la clave de firma).
- **Client ID Web:** En código Dart, pasar explícitamente `serverClientId: AppConstants.googleWebClientId` al constructor de `GoogleSignIn()`.

## 3. Distribución Automatizada de APK (BanaHosting FTP)
- **Cero Binarios en Hosting o Releases Privados:** En repositorios privados, los assets de GitHub Releases devuelven HTTP 404 a visitantes no autenticados. La distribución oficial de APK se realiza vía FTP a BanaHosting.
- **Conexión Directa FTP:** El secreto de GitHub Actions `FTP_SERVER` DEBE contener la dirección IP directa del servidor de BanaHosting. Queda prohibido utilizar dominios que pasen por el proxy naranja de Cloudflare, ya que este bloquea el puerto 21 de FTP.
- **Directorio de Destino:** El destino de subida debe coincidir con la raíz pública del dominio en cPanel (`/home/user/cesarluis.com/rindemas/`).
- **Verificación Fail-Closed:** El pipeline verifica con reintentos HTTP (`curl`) que el tamaño del APK remoto coincida con el local antes de compilar la landing page y generar `version.json`.

## 4. Gestión de Cuota de GitHub Actions
- **Filtros de Exclusión (`paths-ignore`):** Todo workflow que compile código nativo debe incluir `paths-ignore` para cambios que involucren exclusivamente documentación o herramientas locales de mantenimiento (`'**.md'`, `'docs/**'`, `'.agents/**'`, `'scripts/**'`, `'LICENSE'`, `'.gitignore'`). Prohibido disparar compilaciones completas por actualizaciones de bitácoras, notas o ajustes a `scripts/` (solo hay utilidades de mantenimiento, ninguna afecta el build).
- **Desbloqueo de Emergencia por Cuota:** Si la cuota mensual de 2.000 minutos de GitHub Actions se agota, el repositorio solo podrá pasarse a Público temporalmente con **autorización explícita previa de César** y tras verificar que no existan credenciales o datos expuestos. Una vez concluido el release en verde, debe retornarse inmediatamente a Privado.
