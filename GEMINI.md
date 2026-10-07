# Reglas Técnicas del Proyecto (Control de Gastos VE)

## 0. Autonomía Ejecutiva y Protocolo de Memoria

### Semáforo de Límites
- 🟢 **Siempre (Incondicional):**
  - Monitorear el CI en GitHub Actions vía API (`curl`) tras cada `git push` hasta confirmar `success` antes de notificar al usuario.
  - Mantener textos de interfaz y respuestas en español neutro/venezolano.
  - Respetar la paleta oficial (textos oscuros legibles, amarillo reservado para iconos y acentos).
  - Consultar `MEMORY.md` al iniciar una tarea y actualizarlo al finalizarla.
  - Guardar scripts y modificaciones en PowerShell con codificación UTF-8 explícita.
  - Romper el análisis e iterar hacia la acción (editar/probar) en un máximo de 2 lecturas por bloque de código.
- ⚠️ **Pregunta antes (Consultar a César):**
  - Añadir o actualizar dependencias en `pubspec.yaml` o `package.json`.
  - Modificar esquemas de datos (tablas SQLite, entidades Firestore) o flujos de sincronización.
  - Cambiar la arquitectura de navegación principal o flujos de autenticación.
  - Eliminar archivos existentes de código o documentación.
- 🚫 **Nunca (Prohibiciones estrictas):**
  - Modificar archivos en `android/` de forma manual o local (CI los regenera).
  - Usar el operador `>` en PowerShell (provoca corrupción a UTF-16 LE).
  - Cantar victoria o decir que la app "está lista" tras un commit sin verificar CI.
  - Introducir conceptos de conciliación bancaria o cuentas múltiples (anti-filosofía Rinde Más).
  - Prometer planes de IA ilimitada de por vida.
  - Ejecutar bucles de relectura redundante (`view_file` más de 2 veces sobre el mismo rango de archivo sin cambios intermedios). Tras identificar la causa, proceder inmediatamente a editar o consultar.
  - Alojar archivos `.apk` directamente en `landing/public/` o `landing/dist/` (Firebase Hosting bloquea ejecutables en plan Spark con error HTTP 400).
  - Usar dominios con proxy naranja de Cloudflare como `FTP_SERVER` en CI/CD (el proxy bloquea el puerto 21 de FTP).

### Protocolo de Memoria Dinámica
1. **Al iniciar:** Leer `MEMORY.md` para situarse en el estado inmediato del trabajo.
2. **Al finalizar:** Actualizar `MEMORY.md` con el estado final, decisiones tomadas y errores a evitar.
3. **Brevedad:** Mantener `MEMORY.md` en máximo ~50 líneas, depurando lo que ya no aporte.
4. **Graduación:** Si un patrón o lección se vuelve permanente, moverlo a `GEMINI.md` y eliminarlo de `MEMORY.md`.

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
- **No Exclusión en Estados Asíncronos Concurrentes (Banners):** En componentes que notifican estados de colas o tareas en segundo plano (ej. procesamiento OCR, ítems pendientes de revisión, estados sin conexión), NUNCA estructurar la presentación como `if / else if` excluyente si los estados pueden coexistir. Deben acumularse y apilarse verticalmente (ej. en un `Column` con espaciado compacto) para que una tarea terminada no oculte el progreso o estado de otra en curso.
- **Flexibilidad en Etiquetas con Iconos (Evitar RenderFlex Overflow):** En filas (`Row`) dentro de tarjetas, modales o formularios que contengan iconos descriptivos junto a textos de etiquetas o subtítulos, envolver SIEMPRE el widget `Text` en un `Expanded` (o `Flexible`). Esto previene desbordamientos horizontales (`RenderFlex overflow`) ante textos largos, sufijos dinámicos de moneda o pantallas estrechas.

## 5. Verificación de CI y Promesas al Usuario
- **NUNCA** le digas al usuario que la aplicación "ya está lista para descargar" inmediatamente después de hacer un git push.
- DEBES utilizar la API de GitHub (usando curl a https://api.github.com/repos/cesarluisweb/gastoscan-ai/actions/runs) para monitorear activamente el estado del workflow.
- Solo puedes notificar éxito cuando el workflow correspondiente al último commit haya finalizado con un estado de success. Si falla, debes intentar leer los logs para autocorregir el error sin que el usuario te lo tenga que pedir.
- **Lectura de Logs de Error:** La API de GitHub para descargar logs de jobs (`/jobs/{id}/logs`) devuelve `403` en este repositorio. En su lugar, el workflow ya guarda los resultados de pruebas en `test_results.txt` y hace commit automáticamente al fallar. Para leer los errores de CI, haz `git pull --rebase` y luego lee `test_results.txt`.
- **Diagnóstico de Fallos en CI:** Para inspeccionar rápidamente el fallo en GitHub Actions sin depender exclusivamente de `test_results.txt`, consultar los pasos del job mediante la API de GitHub (`GET /repos/:owner/:repo/actions/runs/:run_id/jobs`). Si un paso falla, se pueden extraer las líneas de error consultando el log del job específico (`GET /actions/jobs/:job_id/logs`) con PowerShell filtrando por patrones (`FAIL`, `Error:`, `Exception`).
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
- **Mocks de Dependencias Externas con Firmas Complejas (`noSuchMethod`):** Al simular plugins o paquetes externos de terceros (`speech_to_text`, clientes HTTP o hardware) cuyos métodos posean listas extensas o cambiantes de parámetros nombrados entre versiones de CI, NO replicar manualmente firmas completas ni intentar usar parámetros `dynamic` en el override. Extender en su lugar `Fake implements InterfazExterna` y manejar las llamadas mediante `noSuchMethod(Invocation invocation)` interceptando `invocation.memberName == #metodo` para devolver los valores simulados o incrementar contadores de prueba.
- **Determinismo Temporal en Widgets y Tests:** Todo widget o servicio cuya lógica dependa del día del mes o de umbrales temporales (ej. mensajes de "Nuevo mes" en los primeros 5 días, alertas de cierre de ciclo) DEBE admitir un parámetro opcional de fecha (ej. `DateTime? currentDate`) con fallback a `DateTime.now()`. En los tests unitarios o de widgets queda estrictamente prohibido evaluar comportamientos temporales sin fijar una fecha determinista.
- **Aserciones Robustas de Moneda en Tests:** En los widget tests, evitar evaluar cadenas literales completas que combinen texto y montos formateados (ej. evitar `find.textContaining('de $100.00 está')`). En su lugar, validar por separado las frases clave o usar `contains` independientes (ej. `find.textContaining('Tu meta de ahorro')` y `find.textContaining('comprometida')`), para evitar falsos negativos ocasionados por separadores decimales (`.` vs `,`) o espacios de `NumberFormat`.
- **Lanzamiento Robusto de URLs Externas (`url_launcher` en Android):** NUNCA condicionar la apertura de URLs web (`https://`) a la evaluación previa de `canLaunchUrl(uri)`. En Android 11+ (API 30+), `canLaunchUrl` devuelve `false` si no existen declaraciones `<queries>` en el manifiesto. Invocar directamente `await launchUrl(uri, mode: LaunchMode.externalApplication)` con fallback a `LaunchMode.platformDefault` protegido en un bloque `try/catch`.
- **Ajustes de Usuario en Firestore bajo Reglas Existentes:** Al persistir configuraciones o credenciales del usuario (como la API Key de Gemini BYOK) en Firestore sin alterar `firestore.rules`, utilizar el documento `/users/{userId}/presupuestos/user_settings`. La lógica de lectura de presupuestos debe ignorar explícitamente este documento (`if (anio == 0 || mes == 0) continue`).

## 7. Gestión de Documentación del Proyecto
- **Archivos de Planificación:** Siempre que se genere, actualice o discuta un documento estratégico para el proyecto (como ROADMAP.md, PROJECT.md, planes de arquitectura, o guías de estilo), DEBE guardarse directamente en la raíz del repositorio.
- **Actualización Obligatoria del Roadmap:** Cada vez que se complete una tarea, funcionalidad, corrección o hito planificado, se DEBE actualizar inmediatamente `ROADMAP.md` marcando el ítem como completado (`(Completada ✅)`) o tachándolo, manteniendo el estado de avance siempre al día.
- **Bitácora de Marketing Obligatoria:** Cada vez que se ejecute una nueva acción, post, experimento, campaña o se recopilen aprendizajes de marketing y comunidad, se DEBE registrar y actualizar inmediatamente en `DOC_BITACORA_MARKETING.md` para acumular conocimiento reutilizable para este y futuros proyectos.
- **Protocolo para Cambios Importantes o Numerosos:** Para cambios estructurales, refactorizaciones o funcionalidades con múltiples componentes:
  1. Registrar los cambios en detalle en un documento técnico dedicado en la raíz del repositorio (`DOC_*.md`) y mantenerlo referenciado.
  2. Proveer al usuario una guía de pruebas paso a paso para que realice la verificación manual en su dispositivo o entorno.
  3. Queda prohibido dar por finalizada la tarea o marcar hitos como completados en `ROADMAP.md` antes de recibir el visto bueno explícito del usuario tras sus pruebas.
  4. Solo tras la aprobación del usuario, asentar los apuntes finales y actualizar el estado en `ROADMAP.md`.
- **Sincronización:** Tras cualquier actualización a estos documentos, se debe hacer un git commit y git push de inmediato para asegurar que el resto del equipo (humanos y otros agentes) tenga acceso a la fuente de verdad actualizada.

## 8. Extracción y Parsing de Facturas con IA (Gemini OCR)
- **Prompt de Decimales:** En los prompts de extracción OCR, NUNCA pidas "no usar comas" (ya que la IA tiende a eliminarlas dejando números inflados). En su lugar, ordena explícitamente: *"Si el precio usa coma (ej. 12,50), reemplázala por un punto (12.50)"*.
- **Moneda Unificada:** Para facturas venezolanas con ítems en Bolívares (VES) y total en USD ("Ref"), la IA DEBE extraer todos los montos en la moneda principal de los ítems (VES) para evitar descuadres en los cálculos de la app.
- **Red de Seguridad en Dart:** La aplicación debe mantener una validación matemática local que sume los ítems y los compare con el total de la factura, aplicando autocorrección si la IA omite un separador de decimales.
- **Arquitectura de Gateway y Cuotas de Gemini API:**
  1. *Alcance por Proyecto:* Las cuotas (RPM, RPD y límites de facturación por ventana de 10 min) son evaluadas por proyecto en Google AI Studio, nunca por API Key. Ante un bloqueo general de proyecto, crear nuevas claves en el mismo proyecto no restablece el servicio; requiere nuevo proyecto, reinicio diario (medianoche PST) o habilitar facturación.
  2. *Exclusividad Flash-Lite:* El Cloudflare Gateway (`rindemas-gateway`) debe limitar estrictamente su cadena de fallback a versiones explícitas de Flash-Lite (`gemini-3.1-flash-lite` y `gemini-3.5-flash-lite`). Prohibido incluir modelos pesados (3.8 Flash, Pro) o alias `latest` en la cadena para evitar bloqueos por cuotas mínimas y proteger el límite de gasto de Tier 1 ($10 / 10 min).
  3. *Autenticación con Claves `AQ.` (Encabezado Estricto):* Las peticiones a `generativelanguage.googleapis.com` deben autenticarse mediante el encabezado HTTP `x-goog-api-key: <KEY>`. Prohibido enviar la clave en cabeceras `Authorization: Bearer` para evitar el error `401 UNAUTHENTICATED` (`ACCESS_TOKEN_TYPE_UNSUPPORTED`).
  4. *Sanitización en Cloudflare Workers:* Toda credencial leída de `env` o cabeceras personalizadas debe ser sanitizada con `.trim().replace(/[\r\n\t ]+/g, "")` antes de despacharse a Google.
  5. *Observabilidad Declarativa en Cloudflare:* `wrangler.toml` DEBE incluir siempre `[observability] enabled = true` (con `head_sampling_rate = 1`) para garantizar que la retención de eventos, métricas de tokens y logs de fallback queden activos automáticamente tras cualquier despliegue sin depender de configuraciones manuales en el dashboard web.

## 9. Lógica de Negocio: Presupuestos Mensuales
- **Aislamiento por Mes:** Los presupuestos (general y por categoría) se persisten por mes y año `(anio, mes)` en SQLite. Modificar el presupuesto de un mes nunca debe alterar los meses pasados ni futuros.
- **Copia Automática de Mes Previo:** Si un mes no tiene presupuestos registrados al consultarse, el sistema debe copiar automáticamente la configuración del mes inmediatamente anterior.
- **Validación de Asignación:** La suma total de los presupuestos asignados a categorías NO debe superar el presupuesto general mensual. Toda UI de presupuestos debe validar esta condición en tiempo real y bloquear el guardado si se excede.

## 10. Consistencia de Marca Global y Terminología
- **Identidad de Marca Unificada:** El nombre oficial y definitivo de la aplicación es **Rinde Más** (`AppConstants.appName`). Queda estrictamente prohibido utilizar nombres anteriores (como *GastoScan AI* o *GastosCan AI*) en pantallas, reportes exportados (Markdown, CSV), notificaciones, modales o cualquier texto expuesto al usuario.
- **Terminología Estricta ("Facturas" vs "Tickets"):** Queda estrictamente prohibido referirse a los comprobantes de compra como "tickets". Debe utilizarse siempre el término **"facturas"** (o "comprobantes" en contextos genéricos de escaneo) en toda redacción, mensajes a usuarios o comunidades, documentación y textos de la interfaz.

## 11. Filosofía de Producto y Simplicidad Operativa
- **Cero Fricción Contable (Sin Múltiples Cuentas):** Queda prohibido obligar al usuario a microgestionar de qué banco o cuenta proviene el dinero (Banesco, Zinli, etc.). El valor central de la app es un presupuesto mensual global claro y ver cuánto dinero le queda.
- **Divisas de Referencia (VES, USD, EUR, USDT):** La aplicación opera con Bolívares (VES), Dólares (USD), Euros (EUR) a tasa oficial BCV y USDT a promedio de mercado Binance P2P. Todas las monedas se convierten y expresan de forma determinista sin requerir cuentas bancarias ni balances de billeteras.
- **Estrategia Anti-Rial (Registro Básico Siempre Ilimitado):** El registro manual y el dictado por voz son y serán siempre 100% ilimitados y gratuitos. Queda estrictamente prohibido poner techos artificiales a la cantidad de gastos registrados.
- **Cuotas de IA y Subvención Cruzada:** El escaneo con cámara incluirá una cuota mensual gratuita generosa (15 a 20 facturas al mes). Con una conversión del 1% al plan Pro ($1,99/mes), el costo de API de 1.000 usuarios queda completamente cubierto.
- **Publicidad en Tiempos de Espera y Better Ads:** La monetización publicitaria debe priorizar espacios no obstructivos, como el tiempo de análisis de imágenes ("Analizando comprobante..."), sin interrumpir el flujo de registro. Los anuncios intersticiales deben mostrarse EXCLUSIVAMENTE en puntos de transición naturales (ej. tras guardar exitosamente una factura). Queda estrictamente prohibido disparar anuncios al abrir la app, durante la captura de fotos o interrumpiendo acciones en curso para cumplir con las normas de *Better Ads Standards*.
- **Cumplimiento Estricto de Pagos (Google Play):** Toda compra o suscripción digital dentro del APK distribuido en Google Play debe procesarse obligatoriamente mediante Google Play Billing para evitar sanciones o suspensión de cuenta. Pagos locales (Pago Móvil) solo podrán gestionarse externamente vía web.
- **Prohibición de IA Vitalicia Ilimitada:** Ningún paquete de pago único podrá prometer consumo de IA sin límites en el tiempo, protegiendo los costos recurrentes de API.
- **Inmutabilidad y Consistencia en Bolívares (VES):**
  1. Los gastos cuyo pago se realiza en Bolívares (VES) guardan su monto original inmutable (`total_original`). Los totales y distribuciones por categoría en VES reflejan la suma exacta en Bolívares sin recalcularse por fluctuaciones futuras de la tasa diaria.
  2. Los gastos pagados en divisas (USD, EUR, USDT) se convierten a Bolívares utilizando de forma determinista la tasa de cambio vigente en la fecha exacta del registro.
  3. Toda vista de resumen en Bolívares debe garantizar exactitud matemática al céntimo entre el Total Gastado y la Distribución de Gastos.
- **Sincronización Histórica de Tasas en UI y Neutralidad de Etiquetas:**
  1. En todo formulario o modal con selectores rápidos de divisas (chips de USD, EUR, USDT), las tasas mostradas y aplicables DEBEN sincronizarse de forma asíncrona con la fecha del gasto (`_selectedFecha`), aplicando automáticamente el retroceso al último día hábil anterior si la fecha corresponde a fines de semana o feriados sin cotización oficial.
  2. Los campos de entrada de tasa de cambio deben usar etiquetas neutras (ej. `"Tasa de Cambio"`) sin fijar pares específicos como `(VES / USD)` en el título, delegando la indicación de la moneda, fuente y fecha al texto de ayuda (`helperText`).

## 12. Asistente IA: Reglas de Intención y Gestión de Compras
- **Desambiguación Obligatoria (Gasto vs. Lista de Compras):** Si el usuario pide registrar o anotar productos sin monto y sin especificar claramente la intención (ej. *"anota una harina pan"*), el asistente NUNCA debe adivinar ni registrar a ciegas. Debe preguntar de forma directa:
  > *"¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?"*
- **Doble Capa de Protección:** La desambiguación no depende solo del prompt. En `chat_screen.dart`, cualquier ejecución de `registrar_gasto` con monto cero o sin números explícitos en el mensaje del usuario debe ser interceptada localmente para formular la pregunta obligatoria antes de guardar.
- **Herramientas de Lista de Compras:** Cuando el usuario indique explícitamente agregar, modificar, eliminar o tachar de la lista de compras, el asistente invocará las funciones correspondientes (`agregar_items_lista_compras`, `modificar_item_lista_compras`, `eliminar_items_lista_compras`, `marcar_items_lista_compras`) y confirmará la acción con naturalidad y brevedad en español.
- **Cotejo Universal con Lista de Compras:** Todo gasto guardado en la aplicación (formulario manual, dictado por voz, asistente chat o escáner OCR) DEBE cotejar los nombres de sus productos contra los pendientes en `getPendingShoppingItems()`, normalizando acentos y mayúsculas, y marcar automáticamente como comprados los ítems coincidentes.

## 13. Landing Page, Distribución y Presencia Web (Astro + Firebase Hosting + BanaHosting)
- **Despliegue Automatizado por CI/CD:** El pipeline de GitHub Actions (`build_apk.yml`) compila el APK firmado y lo despliega automáticamente junto con la landing page en Firebase Hosting en cada actualización a `main`.
- **Prohibición de Ejecutables en Firebase Spark:** En el plan gratuito Spark, Firebase Hosting prohíbe estrictamente archivos ejecutables (`.apk`). Está prohibido copiar o compilar el APK dentro de `landing/public/` o `landing/dist/`.
- **Redirección de Descarga (BanaHosting):** En `firebase.json`, las rutas `/rindemas.apk` y `/app-release.apk` deben configurarse como redirección 302 hacia el almacenamiento en BanaHosting (`https://cesarluis.com/rindemas/rindemas.apk`).
- **Distribución Automática por FTP (BanaHosting):** 
  1. El workflow de CI/CD debe subir `rindemas.apk` (y copia `app-release.apk`) vía FTP (`SamKirkland/FTP-Deploy-Action`).
  2. El secreto `FTP_SERVER` DEBE configurarse con la dirección IP directa del servidor de BanaHosting (evitando dominios detrás del proxy naranja de Cloudflare que bloquean el puerto 21).
  3. El directorio de destino debe coincidir con la raíz pública del dominio en cPanel (`/home/user/cesarluis.com/rindemas/`), verificando siempre el *Document Root* del dominio adicional en lugar de asumir ciegamente `public_html/`.
- **Incompatibilidad de Releases Privados:** En repositorios privados de GitHub, los assets de GitHub Releases devuelven HTTP 404 para visitantes públicos. No utilizar enlaces de GitHub Releases para la descarga pública ni para `version.json`.
- **Flujo de Compilación y Despliegue Manual (Local):**
  1. Si se requiere desplegar desde local, compilar Astro con telemetría desactivada: en `landing/`, ejecutar `$env:ASTRO_TELEMETRY_DISABLED="1"; .\node_modules\.bin\astro.cmd build`.
  2. Desplegar a Firebase Hosting: desde la raíz del proyecto, ejecutar `firebase.cmd deploy --only hosting --non-interactive`. El parámetro `--non-interactive` es **estrictamente obligatorio** en Windows para evitar bloqueos indefinidos del proceso en PowerShell.
  3. Verificación en vivo: Comprobar el despliegue con `curl.exe -sI https://rindemas.cesarluis.com/rindemas.apk` antes de confirmar al usuario.
- **Enrutamiento Multi-Página en Firebase Hosting (Astro):** Queda estrictamente prohibido usar la reescritura SPA comodín (`"rewrites": [{"source": "**", "destination": "/index.html"}]`) en `firebase.json` para el sitio web. Para que subrutas como `/panel` resuelvan limpiamente sus archivos estáticos (`dist/panel/index.html`), `firebase.json` DEBE configurarse con `"cleanUrls": true` y `"trailingSlash": false`.
- **Mockups de la Aplicación y Panel Web:** Las representaciones visuales de la app móvil DEBEN tener chasis y proporción de smartphone (teléfono móvil vertical ~20:9 con bordes redondeados y altavoz). Las secciones dedicadas al panel web se representan con marco de ventana de navegador de escritorio.
- **Paleta de Colores Web:** Usar estrictamente la paleta oficial de Rinde Más: amarillo (`#FACC15` / `#EAB308`) para acentos y botones, fondos limpios (`#F8FAFC` / `#FFFFFF`) y textos oscuros legibles (`#0F172A` / `#334155`). Prohibido el uso de colores naranjas.

## 14. Gateway Serverless de IA (Cloudflare Workers) y Entrada por Voz
- **Arquitectura Serverless Desacoplada:** Para mantener Firebase en el plan Spark (100% gratuito sin tarjetas bancarias ni facturación en Google Cloud), el proxy de IA hacia Gemini opera exclusivamente en **Cloudflare Workers** (`rindemas-gateway`).
- **Seguridad Obligatoria del Worker:**
  1. **Validación de Token Firebase (JWT):** Todo endpoint (`/analyze-receipt`, `/chat-analyst`) debe validar la firma criptográfica del ID Token de Firebase Auth usando Web Crypto nativo (`crypto.subtle`) y las claves públicas JWKS de Google (`https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com`).
  2. **Rate Limiting por Usuario:** Limitar las peticiones a un máximo de 30 por minuto por `uid` para prevenir saturación y abuso.
  3. **Secretos Seguros:** La clave `GEMINI_API_KEY` reside exclusivamente en los secretos de Cloudflare (`wrangler secret put`), nunca en código cliente ni variables de repositorio.
- **Estándar Unificado de Reconocimiento de Voz:** Toda pantalla o componente con entrada de voz (formulario, modal flotante o chat) debe utilizar una tolerancia de pausas de 10 segundos (`pauseFor: Duration(seconds: 10)`) y 60 segundos de escucha (`listenFor: Duration(seconds: 60)`). Al pausar y reanudar la grabación, el texto nuevo DEBE concatenarse al final del texto existente sin sobreescribirlo.
- **Detención Automática y Silenciosa del Micrófono ante Interacción:** Si el reconocimiento de voz está activo y el usuario interactúa manualmente con la pantalla (enfoca o toca el `TextField` para escribir, se desplaza por listas, pulsa botones de navegación o acción, o la aplicación pasa a segundo plano `didChangeAppLifecycleState`), el componente DEBE detener la escucha inmediatamente de forma silenciosa. El icono debe volver a su estado neutro y todo el texto reconocido hasta el momento debe preservarse intacto en el campo de texto para su edición o envío sin pérdidas.
- **Avisos Neutros en Procesamiento de Imágenes:** Al enviar fotos a la cola de escaneo, los SnackBars y banners deben referirse a "imágenes" o "comprobantes" (ej. *"Analizando imagen con IA..."*), nunca asumir que una fotografía contiene estrictamente una sola factura.

## 15. Privacidad, Almacenamiento Híbrido y Comunicación Externa
- **Arquitectura de Datos Real:** Rinde Más es una aplicación *Local-First* con sincronización en la nube (Cloud Firestore). Los datos se guardan localmente en SQLite y se respaldan de forma privada y cifrada en Firebase bajo el identificador único (`uid`) de la cuenta Google del usuario.
- **Modo Máxima Privacidad (Uso Anónimo 100% Local):** Si el usuario elige no vincular su cuenta de Google, `SyncService` no envía absolutamente ningún dato a Firestore (`user.isAnonymous`). El 100% de la información permanece confinado exclusivamente en la memoria local (SQLite) del teléfono.
- **Argumento Comercial de Privacidad (Web y Soporte):** Destacar explícitamente en la landing page y en respuestas comunitarias:
  > *"Si prefieres máxima privacidad, puedes usar la app sin iniciar sesión con Google y el 100% de tus datos se quedan únicamente en la memoria local de tu teléfono sin subir a ningún servidor."*
- **Regla de Comunicación de Privacidad:** En respuestas públicas, soporte o debates en comunidades:
  1. **NUNCA afirmar que es "exclusivamente local":** Debe explicarse con precisión que el almacenamiento es local-first con respaldo en la nube en su cuenta privada de Google.
  2. **Enfatizar la ausencia de riesgo bancario:** Aclarar siempre que la app **nunca** solicita claves bancarias, números de tarjeta, acceso a SMS ni credenciales financieras, y que no vende ni comparte datos con terceros.
  3. **Privacidad estricta por reglas:** Los datos en Firestore están blindados por reglas de seguridad donde cada usuario solo puede leer y escribir sus propios documentos (`request.auth.uid == userId`).
- **Microcopy Obligatorio al Vincular Google:** En todo diálogo, modal o pantalla de la app móvil que invite al usuario a iniciar sesión o vincular su cuenta de Google, se DEBE incluir el texto explícito de tranquilidad: *"Solo usamos tu cuenta de Google para respaldar tus facturas en tu propio espacio privado. Sin bancos ni contraseñas."*

## 16. Comunicación con Comunidades y Usuarios (Voz de César)
Al redactar sugerencias de respuestas para foros (Reddit), redes, mensajes directos o soporte de la app:
- **Validación Empática Inmediata:** Desarmar cualquier escepticismo o crítica validando la postura del usuario con naturalidad (ej. *"Es totalmente comprensible"*, *"Jajaja, gracias por la honestidad"*). Nunca ponerse a la defensiva ni contradecir.
- **Cero Tono Corporativo:** Prohibidas las frases de community manager o vendedor ("¡Estimado usuario!", "¡Excelente aporte!", signos de admiración excesivos). Hablar de igual a igual como desarrollador independiente.
- **Llamado a la Acción Directo y Puntuación Casual:** Invitar a probar con preguntas de una sola línea sin rodeos y puntuación digital relajada, omitiendo el signo de apertura `¿` (ej. *"Genial, te gustaría probarla?"*, *"Si la pruebas, me dejas tu opinión sincera"*).
- **Claridad Técnica Serena:** Explicar el funcionamiento de forma transparente, directa y sin rodeos (ej. sin bancos, sin contraseñas, respaldo privado en su Google).
- **Cierre Constructivo:** Conectar el feedback con la mejora del producto (ej. *"me ayuda a seguir dándole prioridad a la privacidad"*).




