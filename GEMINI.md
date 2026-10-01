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

## 4. Guía de Diseño UI (Colores y Formularios)
- **Prohibido textos amarillos:** NUNCA apliques los colores de acento amarillos (`AppColors.primary` o `AppColors.primaryDark`) a textos regulares, descripciones o etiquetas. Todos los textos deben usar `AppColors.textPrimary` (negro/oscuro) para garantizar su legibilidad.
- El color amarillo (`AppColors.primaryDark` preferiblemente) queda reservado de forma estricta y exclusiva para **iconos**, contenedores de fondo y símbolos gráficos de acción.
- **Banners y SnackBars:** Todo `SnackBar` o elemento flotante con fondo amarillo (`AppColors.primary` o `AppColors.primaryDark`) DEBE llevar su texto explícitamente en color negro (`style: TextStyle(color: Colors.black)`) para garantizar su legibilidad.
- **Botón Único en Listas Dinámicas:** En formularios con listas dinámicas desplazables de ítems (como el desglose de productos de un gasto), no duplicar botones de agregar arriba y abajo. Usar un único botón de ancho completo al final de la lista para respetar el flujo natural de scroll y carga secuencial. Iconos de acción en dicho botón deben usar `AppColors.primaryDark`.

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
- **Verificación de Miembros y Firmas en Utilidades:** Al invocar métodos de clases utilitarias compartidas (`DateFormatter`, `CurrencyFormatter`, etc.), es obligatorio revisar previamente su definición en el archivo fuente para usar el identificador exacto y evitar roturas de compilación en CI (ej. verificar `getMonthName` vs `obtenerNombreMes`).
- **Contenedores Material para ListTile (Flutter 3.24+):** NUNCA envuelvas `ListTile` o `SwitchListTile` directamente dentro de un `Container` con `BoxDecoration(color: ...)`. En su lugar, usa siempre un widget `Material` con `shape: RoundedRectangleBorder(...)` y `clipBehavior: Clip.antiAlias` para evitar aserciones de renderizado de tinta en Flutter 3.24+.
- **Widget Tests en Pantallas con Scroll:** En pruebas unitarias de pantallas con `ListView` o vistas desplazables, define siempre en `setUp()` el tamaño de viewport (`binding.window.physicalSizeTestValue = const Size(1080, 4000);`) y límpialo en `tearDown()`, o utiliza `skipOffstage: false` en los `find.text(...)` / `find.byKey(...)` de elementos inferiores para evitar falsos negativos por renderizado fuera de pantalla.
- **Resiliencia de Firebase en UI y Tests:** Todo widget que interactúe con `FirebaseAuth` o servicios nativos debe validar `Firebase.apps.isNotEmpty` antes de instanciar streams o métodos para garantizar que los widget tests se ejecuten limpiamente sin requerir un backend simulado.
- **Firmas Exactas en Mocks/Fakes de Test:** Al implementar clases simuladas para testing (`FakeGastoProvider`, `FakeSettingsProvider`), es obligatorio replicar exactamente la firma de los métodos de la clase real, verificando si los parámetros son posicionales o nombrados para evitar fallos de compilación en CI.

## 7. Gestión de Documentación del Proyecto
- **Archivos de Planificación:** Siempre que se genere, actualice o discuta un documento estratégico para el proyecto (como ROADMAP.md, PROJECT.md, planes de arquitectura, o guías de estilo), DEBE guardarse directamente en la raíz del repositorio.
- **Actualización Obligatoria del Roadmap:** Cada vez que se complete una tarea, funcionalidad, corrección o hito planificado, se DEBE actualizar inmediatamente `ROADMAP.md` marcando el ítem como completado (`(Completada ✅)`) o tachándolo, manteniendo el estado de avance siempre al día.
- **Bitácora de Marketing Obligatoria:** Cada vez que se ejecute una nueva acción, post, experimento, campaña o se recopilen aprendizajes de marketing y comunidad, se DEBE registrar y actualizar inmediatamente en `DOC_BITACORA_MARKETING.md` para acumular conocimiento reutilizable para este y futuros proyectos.
- **Artefactos Prohibidos:** Está estrictamente prohibido dejar estos documentos clave confinados únicamente a los artefactos internos del agente (carpeta .gemini/antigravity/brain/...).
- **Sincronización:** Tras cualquier actualización a estos documentos, se debe hacer un git commit y git push de inmediato para asegurar que el resto del equipo (humanos y otros agentes) tenga acceso a la fuente de verdad actualizada.

## 8. Extracción y Parsing de Facturas con IA (Gemini OCR)
- **Prompt de Decimales:** En los prompts de extracción OCR, NUNCA pidas "no usar comas" (ya que la IA tiende a eliminarlas dejando números inflados). En su lugar, ordena explícitamente: *"Si el precio usa coma (ej. 12,50), reemplázala por un punto (12.50)"*.
- **Moneda Unificada:** Para facturas venezolanas con ítems en Bolívares (VES) y total en USD ("Ref"), la IA DEBE extraer todos los montos en la moneda principal de los ítems (VES) para evitar descuadres en los cálculos de la app.
- **Red de Seguridad en Dart:** La aplicación debe mantener una validación matemática local que sume los ítems y los compare con el total de la factura, aplicando autocorrección si la IA omite un separador de decimales.

## 9. Lógica de Negocio: Presupuestos Mensuales
- **Aislamiento por Mes:** Los presupuestos (general y por categoría) se persisten por mes y año `(anio, mes)` en SQLite. Modificar el presupuesto de un mes nunca debe alterar los meses pasados ni futuros.
- **Copia Automática de Mes Previo:** Si un mes no tiene presupuestos registrados al consultarse, el sistema debe copiar automáticamente la configuración del mes inmediatamente anterior.
- **Validación de Asignación:** La suma total de los presupuestos asignados a categorías NO debe superar el presupuesto general mensual. Toda UI de presupuestos debe validar esta condición en tiempo real y bloquear el guardado si se excede.

## 10. Consistencia de Marca Global y Terminología
- **Identidad de Marca Unificada:** El nombre oficial y definitivo de la aplicación es **Rinde Más** (`AppConstants.appName`). Queda estrictamente prohibido utilizar nombres anteriores (como *GastoScan AI* o *GastosCan AI*) en pantallas, reportes exportados (Markdown, CSV), notificaciones, modales o cualquier texto expuesto al usuario.
- **Terminología Estricta ("Facturas" vs "Tickets"):** Queda estrictamente prohibido referirse a los comprobantes de compra como "tickets". Debe utilizarse siempre el término **"facturas"** (o "comprobantes" en contextos genéricos de escaneo) en toda redacción, mensajes a usuarios o comunidades, documentación y textos de la interfaz.

## 11. Filosofía de Producto y Simplicidad Operativa
- **Cero Fricción Contable (Sin Múltiples Cuentas):** Queda prohibido obligar al usuario a microgestionar de qué banco o cuenta proviene el dinero (Banesco, Zinli, etc.). El valor central de la app es un presupuesto mensual global claro y ver cuánto dinero le queda.
- **Diferenciador Clave frente a Competidores (vs. Rial y Apps Contables):** Aplicaciones como Rial agotan al usuario exigiendo contabilidad estricta (registrar ingresos, saldos por banco, transferencias entre cuentas y cambio en efectivo). Rinde Más se enfoca **exclusivamente en el presupuesto de salidas y control de gastos**. Cero fricción de cuadre bancario: el usuario solo define su límite del mes y registra lo que gasta (foto o voz). Este es el principal argumento de diferenciación ante comparativas.
- **Divisas Estrictas (VES y USD):** La aplicación opera exclusivamente con Bolívares (VES) y Dólares (USD) a tasa oficial BCV. No agregar monedas redundantes como USDT.
- **Estrategia Anti-Rial (Registro Básico Siempre Ilimitado):** El registro manual y el dictado por voz son y serán siempre 100% ilimitados y gratuitos. Queda estrictamente prohibido poner techos artificiales a la cantidad de gastos registrados.
- **Cuotas de IA y Subvención Cruzada:** El escaneo con cámara incluirá una cuota mensual gratuita generosa (15 a 20 facturas al mes). Con una conversión del 1% al plan Pro ($1,99/mes), el costo de API de 1.000 usuarios queda completamente cubierto.
- **Publicidad en Tiempos de Espera y Better Ads:** La monetización publicitaria debe priorizar espacios no obstructivos, como el tiempo de análisis de imágenes ("Analizando comprobante..."), sin interrumpir el flujo de registro. Los anuncios intersticiales deben mostrarse EXCLUSIVAMENTE en puntos de transición naturales (ej. tras guardar exitosamente una factura). Queda estrictamente prohibido disparar anuncios al abrir la app, durante la captura de fotos o interrumpiendo acciones en curso para cumplir con las normas de *Better Ads Standards*.
- **Cumplimiento Estricto de Pagos (Google Play):** Toda compra o suscripción digital dentro del APK distribuido en Google Play debe procesarse obligatoriamente mediante Google Play Billing para evitar sanciones o suspensión de cuenta. Pagos locales (Pago Móvil) solo podrán gestionarse externamente vía web.
- **Prohibición de IA Vitalicia Ilimitada:** Ningún paquete de pago único podrá prometer consumo de IA sin límites en el tiempo, protegiendo los costos recurrentes de API.

## 12. Asistente IA: Reglas de Intención y Gestión de Compras
- **Desambiguación Obligatoria (Gasto vs. Lista de Compras):** Si el usuario pide registrar o anotar productos sin monto y sin especificar claramente la intención (ej. *"anota una harina pan"*), el asistente NUNCA debe adivinar ni registrar a ciegas. Debe preguntar de forma directa:
  > *"¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?"*
- **Doble Capa de Protección:** La desambiguación no depende solo del prompt. En `chat_screen.dart`, cualquier ejecución de `registrar_gasto` con monto cero o sin números explícitos en el mensaje del usuario debe ser interceptada localmente para formular la pregunta obligatoria antes de guardar.
- **Herramientas de Lista de Compras:** Cuando el usuario indique explícitamente agregar, modificar, eliminar o tachar de la lista de compras, el asistente invocará las funciones correspondientes (`agregar_items_lista_compras`, `modificar_item_lista_compras`, `eliminar_items_lista_compras`, `marcar_items_lista_compras`) y confirmará la acción con naturalidad y brevedad en español.
- **Cotejo Universal con Lista de Compras:** Todo gasto guardado en la aplicación (formulario manual, dictado por voz, asistente chat o escáner OCR) DEBE cotejar los nombres de sus productos contra los pendientes en `getPendingShoppingItems()`, normalizando acentos y mayúsculas, y marcar automáticamente como comprados los ítems coincidentes.

## 13. Landing Page y Presencia Web (Astro + Firebase Hosting)
- **Despliegue Automatizado por CI/CD:** El pipeline de GitHub Actions (`build_apk.yml`) compila el APK firmado y lo despliega automáticamente junto con la landing page en Firebase Hosting (`rindemas.cesarluis.com/app-release.apk`) en cada actualización a `main`.
- **Flujo de Compilación y Despliegue Manual (Local):**
  1. Si se requiere desplegar desde local, compilar Astro con telemetría desactivada: en `landing/`, ejecutar `$env:ASTRO_TELEMETRY_DISABLED="1"; .\node_modules\.bin\astro.cmd build`.
  2. Desplegar a Firebase Hosting: desde la raíz del proyecto, ejecutar `firebase.cmd deploy --only hosting --non-interactive`. El parámetro `--non-interactive` es **estrictamente obligatorio** en Windows para evitar bloqueos indefinidos del proceso en PowerShell.
  3. Verificación en vivo: Comprobar el despliegue con `curl.exe -sI https://rindemas.cesarluis.com/app-release.apk` antes de confirmar al usuario.
- **Mockups de la Aplicación:** Todo mockup o representación gráfica de la aplicación en la web DEBE tener chasis y proporción de smartphone (teléfono móvil vertical ~20:9 con bordes redondeados y altavoz), quedando prohibido el formato tablet o de escritorio.
- **Paleta de Colores Web:** Usar estrictamente la paleta oficial de Rinde Más: amarillo (`#FACC15` / `#EAB308`) para acentos y botones, fondos limpios (`#F8FAFC` / `#FFFFFF`) y textos oscuros legibles (`#0F172A` / `#334155`). Prohibido el uso de colores naranjas.

## 14. Entrada por Voz, Escaneo y Cloud Functions
- **Estándar Unificado de Reconocimiento de Voz:** Toda pantalla o componente con entrada de voz (formulario, modal flotante o chat) debe utilizar una tolerancia de pausas de 10 segundos (`pauseFor: Duration(seconds: 10)`) y 60 segundos de escucha (`listenFor: Duration(seconds: 60)`). Al pausar y reanudar la grabación, el texto nuevo DEBE concatenarse al final del texto existente sin sobreescribirlo.
- **Avisos Neutros en Procesamiento de Imágenes:** Al enviar fotos a la cola de escaneo, los SnackBars y banners deben referirse a "imágenes" o "comprobantes" (ej. *"Analizando imagen con IA..."*), nunca asumir que una fotografía contiene estrictamente una sola factura.
- **Despliegue de Cloud Functions en Windows:** Al ejecutar `firebase deploy --only functions --non-interactive`, debe asignarse previamente `$env:FUNCTIONS_DISCOVERY_TIMEOUT="60"` (en segundos) para evitar fallos por timeout en el análisis estático local.

## 15. Privacidad, Almacenamiento Híbrido y Comunicación Externa
- **Arquitectura de Datos Real:** Rinde Más es una aplicación *Local-First* con sincronización en la nube (Cloud Firestore). Los datos se guardan localmente en SQLite y se respaldan de forma privada y cifrada en Firebase bajo el identificador único (`uid`) de la cuenta Google del usuario.
- **Modo Máxima Privacidad (Uso Anónimo 100% Local):** Si el usuario elige no vincular su cuenta de Google, `SyncService` no envía absolutamente ningún dato a Firestore (`user.isAnonymous`). El 100% de la información permanece confinado exclusivamente en la memoria local (SQLite) del teléfono.
- **Argumento Comercial de Privacidad (Web y Soporte):** Destacar explícitamente en la landing page y en respuestas comunitarias:
  > *"Si prefieres máxima privacidad, puedes usar la app sin iniciar sesión con Google y el 100% de tus datos se quedan únicamente en la memoria local de tu teléfono sin subir a ningún servidor."*
- **Regla de Comunicación de Privacidad:** En respuestas públicas, soporte o debates en comunidades:
  1. **NUNCA afirmar que es "exclusivamente local":** Debe explicarse con precisión que el almacenamiento es local-first con respaldo en la nube en su cuenta privada de Google.
  2. **Enfatizar la ausencia de riesgo bancario:** Aclarar siempre que la app **nunca** solicita claves bancarias, números de tarjeta, acceso a SMS ni credenciales financieras, y que no vende ni comparte datos con terceros.
  3. **Privacidad estricta por reglas:** Los datos en Firestore están blindados por reglas de seguridad donde cada usuario solo puede leer y escribir sus propios documentos (`request.auth.uid == userId`).

## 16. Comunicación con Comunidades y Usuarios (Voz de César)
Al redactar sugerencias de respuestas para foros (Reddit), redes, mensajes directos o soporte de la app:
- **Validación Empática Inmediata:** Desarmar cualquier escepticismo o crítica validando la postura del usuario con naturalidad (ej. *"Es totalmente comprensible"*, *"Jajaja, gracias por la honestidad"*). Nunca ponerse a la defensiva ni contradecir.
- **Cero Tono Corporativo:** Prohibidas las frases de community manager o vendedor ("¡Estimado usuario!", "¡Excelente aporte!", signos de admiración excesivos). Hablar de igual a igual como desarrollador independiente.
- **Llamado a la Acción Directo y Puntuación Casual:** Invitar a probar con preguntas de una sola línea sin rodeos y puntuación digital relajada, omitiendo el signo de apertura `¿` (ej. *"Genial, te gustaría probarla?"*, *"Si la pruebas, me dejas tu opinión sincera"*).
- **Claridad Técnica Serena:** Explicar el funcionamiento de forma transparente, directa y sin rodeos (ej. sin bancos, sin contraseñas, respaldo privado en su Google).
- **Cierre Constructivo:** Conectar el feedback con la mejora del producto (ej. *"me ayuda a seguir dándole prioridad a la privacidad"*).




