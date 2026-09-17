# Reglas Técnicas del Proyecto (Control de Gastos VE)

## 1. Google Drive Sync vs. Ejecución de Comandos
**IMPORTANTE:** Este proyecto se encuentra dentro de un directorio sincronizado por Google Drive.
- NUNCA ejecutes comandos pesados como `npm install` o `npm run build` directamente dentro de este directorio, ya que el cliente de Google Drive bloqueará los archivos, provocando errores.
- **Conflicto de Edición IA:** Si modificas código y notas que tus cambios desaparecen o se revierten misteriosamente, es Google Drive pisándolos. En ese caso, **DEBES** copiar los archivos afectados a una carpeta temporal (ej. `C:\Users\cesar\Desktop\temp_fix`), editarlos allí, devolverlos al proyecto usando comandos seguros y hacer `git commit` de inmediato.

## 2. Codificación en PowerShell y Scripts
- Al modificar archivos de texto usando `Set-Content` en PowerShell, **SIEMPRE** debes usar el parámetro `-Encoding UTF8`. Si lo omites, Windows romperá todos los acentos y caracteres especiales en español.
- **Prohibición de Redirección:** NUNCA uses el operador de redirección `>` para crear archivos o scripts desde PowerShell (ej. `echo "..." > script.py`), ya que esto guarda en UTF-16 LE y corrompe el código. Siempre usa tuberías: `... | Out-File script.py -Encoding utf8`.

## 3. Integración Continua (CI) y Plugins Nativos (Firebase)
La compilación en GitHub Actions (`build_apk.yml`) ejecuta `flutter create`, lo que borra y regenera la carpeta `android/` desde cero en cada ejecución.
- **Prohibición de Edición Local:** Queda **estrictamente prohibido** modificar manualmente archivos como `android/app/build.gradle` o `android/settings.gradle` para instalar dependencias nativas (como Crashlytics o Analytics), ya que estos cambios se perderán en la nube.
- **Inyección por Bash:** Toda configuración nativa requerida DEBE inyectarse programáticamente usando scripts automatizados (ej. `sed`) directamente dentro del archivo `.github/workflows/build_apk.yml` en el paso posterior a la regeneración de la plataforma.
- **Auth Bypass:** Para evitar el Error 10 de Google Sign-In por la ausencia del archivo `google-services.json` generado nativamente, debes pasar explícitamente el `serverClientId` (Web Client ID) como parámetro en el constructor de `GoogleSignIn()` en Dart.

## 4. Guía de Diseño UI (Colores)
- **Prohibido textos amarillos:** NUNCA apliques los colores de acento amarillos (`AppColors.primary` o `AppColors.primaryDark`) a textos regulares, descripciones o etiquetas. Todos los textos deben usar `AppColors.textPrimary` (negro/oscuro) para garantizar su legibilidad.
- El color amarillo (`AppColors.primaryDark` preferiblemente) queda reservado de forma estricta y exclusiva para **iconos**, contenedores de fondo y símbolos gráficos de acción.
