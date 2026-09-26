# Reglas Técnicas del Proyecto (Control de Gastos VE)

## 1. Entorno de Desarrollo y Ejecución
**IMPORTANTE:** El repositorio oficial de este proyecto ha sido migrado permanentemente a `C:\Development\Control de gastos VE` para evitar conflictos con Google Drive.
- Los agentes tienen luz verde para ejecutar comandos nativos (como builds, instalación de dependencias, scripts de modificación masiva) directamente en este directorio.
- Ya no aplican restricciones de sincronización ni bloqueos de archivos ("Folder In Use"). Toda operación debe hacerse en esta ruta, ignorando cualquier metadato antiguo que referencie al Disco H.

## 2. Codificación en PowerShell y Scripts
- Al modificar archivos de texto usando `Set-Content` en PowerShell, **SIEMPRE** debes usar el parámetro `-Encoding UTF8`. Si lo omites, Windows romperá todos los acentos y caracteres especiales en español.
- **Prohibición de Redirección:** NUNCA uses el operador de redirección `>` para crear archivos o scripts desde PowerShell (ej. `echo "..." > script.py`), ya que esto guarda en UTF-16 LE y corrompe el código. Siempre usa tuberías: `... | Out-File script.py -Encoding utf8`.

## 3. Integración Continua (CI) y Plugins Nativos (Firebase)
La compilación en GitHub Actions (`build_apk.yml`) ejecuta `flutter create`, lo que borra y regenera la carpeta `android/` desde cero en cada ejecución.
- **Prohibición de Edición Local:** Queda **estrictamente prohibido** modificar manualmente archivos como `android/app/build.gradle` o `android/settings.gradle` para instalar dependencias nativas, ya que estos cambios se perderán en la nube.
- **Inyección por Bash:** Toda configuración nativa requerida DEBE inyectarse programáticamente usando scripts automatizados (ej. `sed`) directamente dentro del archivo `.github/workflows/build_apk.yml` en el paso posterior a la regeneración de la plataforma.
- **Auth Bypass:** Para evitar el Error 10 de Google Sign-In por la ausencia del archivo `google-services.json` generado nativamente, debes pasar explícitamente el `serverClientId` (Web Client ID) como parámetro en el constructor de `GoogleSignIn()` en Dart.

## 4. Guía de Diseño UI (Colores)
- **Prohibido textos amarillos:** NUNCA apliques los colores de acento amarillos (`AppColors.primary` o `AppColors.primaryDark`) a textos regulares, descripciones o etiquetas. Todos los textos deben usar `AppColors.textPrimary` (negro/oscuro) para garantizar su legibilidad.
- El color amarillo (`AppColors.primaryDark` preferiblemente) queda reservado de forma estricta y exclusiva para **iconos**, contenedores de fondo y símbolos gráficos de acción.
- **Banners y SnackBars:** Todo `SnackBar` o elemento flotante con fondo amarillo (`AppColors.primary` o `AppColors.primaryDark`) DEBE llevar su texto explícitamente en color negro (`style: TextStyle(color: Colors.black)`) para garantizar su legibilidad.

## 5. Verificación de CI y Promesas al Usuario
- **NUNCA** le digas al usuario que la aplicación "ya está lista para descargar" inmediatamente después de hacer un git push.
- DEBES utilizar la API de GitHub (usando curl a https://api.github.com/repos/cesarluisweb/gastoscan-ai/actions/runs) para monitorear activamente el estado del workflow.
- Solo puedes notificar éxito cuando el workflow correspondiente al último commit haya finalizado con un estado de success. Si falla, debes intentar leer los logs para autocorregir el error sin que el usuario te lo tenga que pedir.
- **Lectura de Logs de Error:** La API de GitHub para descargar logs de jobs (`/jobs/{id}/logs`) devuelve `403` en este repositorio. En su lugar, el workflow ya guarda los resultados de pruebas en `test_results.txt` y hace commit automáticamente al fallar. Para leer los errores de CI, haz `git pull --rebase` y luego lee `test_results.txt`.
- **Sin Flutter Local:** El SDK de Flutter NO está instalado en la máquina del usuario. No intentes ejecutar `flutter test` ni `flutter build` localmente. Todo testing y compilación se ejecuta exclusivamente a través de GitHub Actions CI.

## 6. Control de Calidad en Dart (Importaciones y Sintaxis)
- El entorno de CI de Flutter detendrá la compilación instantáneamente si falta una importación.
- Cada vez que utilices una clase, modelo o servicio en un archivo, es **obligatorio** rastrear el origen de esa clase e inyectar el import correspondiente en la cabecera. No asumas que la inyección de código lo incluye automáticamente.
- **Identificadores ASCII:** Queda strictly prohibido utilizar caracteres no-ASCII (tildes, acentos, 'ñ') en nombres de variables, métodos o nombres de test en Dart (ej. usar `gastoAlimentacion` en lugar de `gastoAlimentación`).
- **Acceso a Propiedades de Widget:** Al convertir o refactorizar un widget a `StatefulWidget`, asegúrate de acceder a los callbacks y parámetros del constructor usando la referencia `widget.` (ej. `widget.onSetBudget`).
- **Keys de Widget Globalmente Únicos:** Cuando se creen widgets que coexistan en el árbol visual (Bottom Sheets, Dialogs, Overlays), sus `Key(...)` DEBEN ser globalmente únicos. Si un widget existente ya usa `Key('edit_budget_$cat')`, un nuevo widget que se renderice *encima* NO puede reutilizar esa misma Key. Usa un prefijo diferenciador (ej. `Key('edit_budget_bottom_$cat')`).

## 7. Gestión de Documentación del Proyecto
- **Archivos de Planificación:** Siempre que se genere, actualice o discuta un documento estratégico para el proyecto (como ROADMAP.md, PROJECT.md, planes de arquitectura, o guías de estilo), DEBE guardarse directamente en la raíz del repositorio.
- **Artefactos Prohibidos:** Está estrictamente prohibido dejar estos documentos clave confinados únicamente a los artefactos internos del agente (carpeta .gemini/antigravity/brain/...).
- **Sincronización:** Tras cualquier actualización a estos documentos, se debe hacer un git commit y git push de inmediato para asegurar que el resto del equipo (humanos y otros agentes) tenga acceso a la fuente de verdad actualizada.

## 8. Extracción y Parsing de Facturas con IA (Gemini OCR)
- **Prompt de Decimales:** En los prompts de extracción OCR, NUNCA pidas "no usar comas" (ya que la IA tiende a eliminarlas dejando números inflados). En su lugar, ordena explícitamente: *"Si el precio usa coma (ej. 12,50), reemplázala por un punto (12.50)"*.
- **Moneda Unificada:** Para facturas venezolanas con ítems en Bolívares (VES) y total en USD ("Ref"), la IA DEBE extraer todos los montos en la moneda principal de los ítems (VES) para evitar descuadres en los cálculos de la app.
- **Red de Seguridad en Dart:** La aplicación debe mantener una validación matemática local que sume los ítems y los compare con el total de la factura, aplicando autocorrección si la IA omite un separador de decimales.
