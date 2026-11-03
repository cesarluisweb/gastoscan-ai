---
trigger: glob
globs: ".github/workflows/**, android/**"
description: "Pipeline de CI/CD en GitHub Actions, inyección programática en Android y distribución de artefactos móviles."
---

# Integración Continua (CI/CD) y Distribución de Binarios

## 1. Plataforma Android e Inyección Nativa en CI
- **Regeneración de `android/` en GitHub Actions:** El workflow `build_apk.yml` ejecuta `flutter create .` al inicio, borrando y regenerando la carpeta `android/` en cada ejecución.
- **Prohibición de Edición Local en `android/`:** Queda terminantemente prohibido modificar archivos locales dentro de `android/` (como `build.gradle.kts`, `settings.gradle` o manifiestos), ya que cualquier cambio se pierde en el runner de CI.
- **Inyección Programática por Bash:** Toda configuración nativa requerida (reglas ProGuard, firmas, plugins de Firebase o Google Sign-In) DEBE inyectarse mediante scripts automatizados (`sed`, scripts Python inline) directamente dentro del archivo `.github/workflows/build_apk.yml` después del paso de regeneración.
- **Integridad de Firmas JNI y Metadatos de Reflexión:** El código Dart ya se compila a binario nativo ARM64 (`libapp.so`). Prohibido ofuscar o aplicar optimizaciones destructivas en la capa Java/Kotlin. El archivo `proguard-rules.pro` inyectado en CI DEBE incluir siempre:
  - `-dontobfuscate` y `-dontoptimize` (usar únicamente `proguardFiles("proguard-rules.pro")`, sin la plantilla agresiva `proguard-android-optimize.txt`).
  - `-ignorewarnings`, `-dontwarn kotlin.**` y `-dontwarn kotlinx.**`.
  - `-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod`.
  - `-keep class kotlin.Metadata { *; }`.
  - Preservación explícita de `io.flutter.**`, `dev.flutter.**`, `kotlin.**` y `kotlinx.**`.
  Omitir estas directivas provoca que R8 renombre tipos como `kotlin.coroutines.Continuation` (ej. a `jj`) o mutile anotaciones de Pigeon y plugins federados, rompiendo las llamadas directas de JNI con `NoSuchMethodError`.
- **Reproducibilidad Determinista (`pubspec.lock` Obligatorio):** El archivo `pubspec.lock` DEBE estar versionado en git en todo momento. Prohibido añadirlo a `.gitignore`. Esto asegura que `flutter pub get` en GitHub Actions descargue con exactitud las dependencias nativas probadas, previniendo discrepancias entre entornos.

## 2. Autenticación Nativa y Google Sign-In (Error 10)
- **Registro Doble de Huellas SHA-1:** Para prevenir el Error 10 de Google Sign-In en Android, deben registrarse obligatoriamente **dos** huellas SHA-1 en el proyecto Firebase (`com.cesarluis.rindemas`):
  1. La de la clave de subida de producción (`android_template/rindemas.jks`).
  2. La de la clave de firma de Google Play (obtenida en Play Console → Integridad de la app → Certificado de la clave de firma).
- **Client ID Web:** En código Dart, pasar explícitamente `serverClientId: AppConstants.googleWebClientId` al constructor de `GoogleSignIn()`.

## 3. Estrategia de Lanzamiento Web y Eliminación de APK Directo
- **Canal Único de Adquisición Web (Lista de Espera WhatsApp):** La landing page (`rindemas.cesarluis.com`) no distribuye archivos APK directos para evitar advertencias de seguridad en Android y maximizar la conversión hacia el lanzamiento en la tienda. El tráfico web se canaliza exclusivamente hacia el Canal Oficial de WhatsApp (`channel/0029VbEPwHLDJ6H678QLlN1H`) y la insignia de *Próximamente en Google Play*.
- **Cierre del Canal de APK Directo y Redirecciones:** Queda descontinuada la distribución de APKs vía FTP o descargas directas. Las rutas `/rindemas.apk` y `/app-release.apk` en `firebase.json` redirigen (HTTP 302) a la landing oficial (`https://rindemas.cesarluis.com`). El archivo `version.json` en `landing/public/` se fija con versión `1.0.0` y `buildNumber: 1` para neutralizar el actualizador automático en instalaciones legadas (G1–G4) durante la Prueba Cerrada sin generar modales falsos ni enlaces rotos.
- **Transición Post-Prueba Cerrada:** Una vez concluido el período de 14 días y aprobada la app para producción abierta, el botón principal de la landing page enlazará directamente a la ficha oficial en Google Play Store (`https://play.google.com/store/apps/details?id=com.cesarluis.rindemas`).
- **Numeración de Build vs. `run_number`:** El número de compilación interno (`buildNumber`) es **`BASE_BUILD + github.run_number`**, donde `BASE_BUILD` se extrae de `version: x.y.z+N` en `pubspec.yaml`.
- **Incremento Obligatorio de Versión Semántica (pubspec.yaml):** Al cerrar una tarea o conjunto de cambios en Flutter, el agente DEBE evaluar si corresponde incrementar la versión semántica antes del commit y push:
  - **Parche (+0.0.1):** Ante correcciones de errores (bugs), ajustes de diseño, textos o rendimiento.
  - **Menor (+0.1.0, reiniciando parche a 0):** Ante nuevas pantallas, nuevos flujos, integración de APIs o capacidades funcionales.
  - **Mayor (+1.0.0):** Ante rediseños completos o cambios incompatibles.
  César no debe tener que recordarlo; es responsabilidad proactiva del agente proponer o aplicar el salto correspondiente.

## 4. Gestión de Cuota y Desacoplamiento de Pipelines en GitHub Actions
- **Pipelines Desacoplados (`build_apk.yml` vs `deploy_web.yml`):**
  - `deploy_web.yml` (~50 s) se activa exclusivamente ante cambios en `landing/**`, `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `.firebaserc` o el propio workflow web, desplegando el `version.json` controlado desde el repositorio.
  - `build_apk.yml` (~8–10 min) compila exclusivamente los artefactos móviles (`app-release-aab` y `rindemas-dev-apk`), excluyendo en `paths-ignore` documentación, scripts y rutas exclusivas de la web.
- **Desbloqueo de Emergencia por Cuota:** Si la cuota mensual de 2.000 minutos de GitHub Actions se agota, el repositorio solo podrá pasarse a Público temporalmente con **autorización explícita previa de César** y tras verificar que no existan credenciales o datos expuestos. Una vez concluido el release en verde, debe retornarse inmediatamente a Privado.
- **Ejecución de `wait_ci.ps1` con Bypass de Sandbox:** Al requerir conexión HTTPS saliente hacia `https://api.github.com`, la invocación de `scripts/wait_ci.ps1` DEBE realizarse siempre con `BypassSandbox: true`. En sandbox estándar falla silenciosamente por falta de red arrojando falsos positivos de "CI: SIN RUN" tras cumplirse los 5 minutos de descubrimiento.

## 5. Entorno Paralelo de Pruebas (Rinde Más Dev) y Ciclo de Promoción a Producción
- **Coexistencia en Dispositivo:** César mantiene instalada permanentemente la app oficial de Google Play (`com.cesarluis.rindemas`, nombre visible *"Rinde Más"*) para cumplir estrictamente el requisito de 14 días continuos de la Prueba Cerrada (y preservar su entorno estable). Queda terminantemente prohibido desinstalar o pisar esa app en su teléfono.
- **App Paralela para Pruebas:** Para validar cambios de código, César descarga e instala en su teléfono el artefacto **`rindemas-dev-apk`** (`com.cesarluis.rindemas.dev`, nombre visible *"Rinde Más Dev"*). Ambas apps conviven de forma independiente en el mismo dispositivo sin colisión de firmas ni de bases de datos locales SQLite.
- **Credenciales y Firebase en Dev:** El archivo `android/app/google-services.json` tiene registrado oficialmente el cliente `com.cesarluis.rindemas.dev`. Soporta autenticación anónima, Firestore, Gateway de IA (Cloudflare Worker) y Google Sign-In nativo con la huella SHA-1 de `android_template/rindemas.jks`.
- **Ciclo de Promoción (Dev → Visto Bueno → Play Store):**
  1. Cada push de código a `main` compila en paralelo el paquete oficial para la tienda (`app-release-aab`) y el paquete de pruebas (`rindemas-dev-apk`). La tarea en `ROADMAP.md` se coloca en `Pendiente de validación 🧪`.
  2. César instala/actualiza **`Rinde Más Dev`** desde el run de GitHub Actions y prueba los cambios en su teléfono.
  3. Tras el visto bueno explícito de César, la tarea se marca como `Completada ✅`. Para publicar la versión aprobada en Google Play Console (Prueba Cerrada hoy o Producción abierta mañana), **no se vuelve a compilar nada**: se descarga el artefacto **`app-release-aab`** generado en esa misma corrida de GitHub Actions y se sube a Play Console.

## 6. Política de Cero Commits de CI y Gestión de Artefactos de Diagnóstico
- **Prohibición de Commits Automáticos:** Queda terminantemente prohibido que cualquier paso de GitHub Actions ejecute `git add`, `git commit` o `git push` para almacenar reportes, logs o resultados de pruebas en ramas del repositorio.
- **Artefactos Desacoplados y Rutas Propias:** Cada etapa debe generar su propio log sin sobreescribir ni depender de `test_results.txt`:
  - Pruebas y análisis estático -> `test-results` (`test_results.txt`).
  - Compilación AAB -> `aab-build-failure-log` (`aab_build_log.txt`).
  - Compilación APK Dev -> `apk-build-failure-log` (`apk_dev_build_log.txt`).
- **Condiciones Estrictas de Publicación:**
  - Los reportes de pruebas solo deben publicarse si el paso de pruebas efectivamente se ejecutó (`steps.run_unit_tests.outcome == 'success' || steps.run_unit_tests.outcome == 'failure'`), previniendo publicar reportes viejos del checkout ante abortos tempranos.
  - Los artefactos de fallo de compilación solo deben subirse si el paso correspondiente falló (`steps.<id>.outcome == 'failure'`).
  - Todo paso `actions/upload-artifact@v4` debe incluir `if-no-files-found: ignore` para evitar fallos artificiales.
- **Tuberías Bash Seguras con `pipefail`:**
  - Cuando un paso de compilación ejecuta múltiples comandos (ej. Python, Flutter, zipalign, apksigner) canalizados a `tee`, debe encapsularse en una función con `set -e -o pipefail` (ej. `run_apk_dev_build 2>&1 | tee apk_dev_build_log.txt`). Esto garantiza que cualquier fallo intermedio aborte inmediatamente la ejecución y propague el código de salida fallido a GitHub Actions sin ocultar errores.
