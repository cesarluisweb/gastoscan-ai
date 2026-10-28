# Roadmap de Desarrollo: Rinde Más

Este documento centraliza las iniciativas y mejoras activas de **Rinde Más**, ordenadas estratégicamente por prioridad, impacto de valor para el usuario venezolano y viabilidad técnica.

> 📜 **Histórico de Hitos Completados:** Para consultar el detalle técnico y la bitácora de todas las fases y tareas ya finalizadas, consulta [ROADMAP_HISTORICO.md](ROADMAP_HISTORICO.md).

---

## Principios de Ejecución y Entrega de Valor
1. **Impacto de Negocio sobre Complejidad:** Priorizar funciones con alto impacto cotidiano y retención sobre desarrollos complejos de bajo uso.
2. **Filosofía Local-First y Anti-Microgestión:** Cero conciliaciones bancarias complejas ni gestión de múltiples cuentas; enfoque en presupuestos bimonetarios (VES/USD) y tasas oficiales en vivo.
3. **Los Datos son el Producto:** Captura precisa, normalización y cálculo exacto de compras (precios, productos, IVA, tasa BCV) como base del sistema.
4. **Monetización como Producto Independiente:** La monetización requiere su propio embudo de conversión y propuesta de valor, sin degradar la experiencia base gratuita.
5. **Regla de Oro de IA:** La inteligencia artificial interpreta; el código determinista calcula.

---

## Estados Oficiales de Tareas
- `Pendiente`: Tarea planificada no iniciada.
- `Implementada 🔧`: Código commiteado en `main` y CI en curso o pendiente de verificación.
- `Pendiente de validación 🧪`: CI en verde (`conclusion: success`); pendiente de validación en dispositivo físico por César.
- `Completada ✅`: Verificada y aprobada (las tareas críticas requieren aprobación explícita de César).

---

## Fase 3: Mejoras de Calidad de Auditoría (Completada ✅)
*Verificada y aprobada en dispositivo físico por César (Detallado en `DOC_AUDITORIA_FASE_3.md`):*
- `FIN-07`: Cálculo exacto de días y proyección en meses históricos basándose en la fecha seleccionada.
- `FIN-08`: Validación de montos estrictamente positivos (`> 0`) en formularios y desglose de ítems.
- `UX-03`: Búsqueda global a lo largo de todo el historial financiero (cross-month).
- `UX-05`: Navegación unificada del Asistente IA (`Navigator.push`) manteniendo barra inferior visible.
- `SEC-12`: Versionado formal del Cloudflare Worker en la carpeta `workers/` del repositorio.
- `OCR-01`: Deduplicación SHA-256 nativa en cola de escaneo para evitar duplicar comprobantes.
- `AI-01`: 5 chips analíticos diferenciados sin acciones destructivas, inyección de `tasa_usdt` en contexto y saludo guiado.
- `LOTE-03` **Integridad de Sincronización Cloud/Offline, Privacidad Local y Resiliencia SQLite (Auditoría Argon):** `Completada ✅`
  - *Problema:* Pérdida de ítems de compra en Firestore por falta de mapper, reemplazo no atómico y desalineación de esquema SQLite v18 (`presupuestos_categorias_mensuales`, `gastos_fts`), resurrección de gastos borrados en web, fuga de datos al vincular con error de descarga, y condiciones de carrera en tasas históricas.
  - *Solución:* Serialización pura con `GastoFirestoreMapper`, reemplazo atómico en una sola `db.transaction` con `PresupuestoRemotoModel`, política "Borrado Gana" en `sync_conflict_resolver.dart`, bloqueo durable en `SharedPreferences` (`sync_pending_replace_<uid>`) con guard completo en `SyncService`, método `retryPendingReplace()` con cerrojo de concurrencia y banner ámbar en Dashboard, bloqueo en botón `+` de MainScreen, desbloqueo automático en fusiones (`descartarDatosLocales == false`), token monótono `_tasaRequestId` en `ReviewExpenseScreen`, pre-check offline con `ConnectivityService.instance.isConnected()` y diálogo con switch opcional para eliminación física de fotos en `MoreScreen`. Detallado en `docs/DOC_SINCRONIZACION_OFFLINE.md`.
- `LOTE-04` **Resiliencia UI en Bolívares (360dp), Rendimiento en Historial y Escáner (Auditoría Argon):** `Completada ✅`
  - *Problema:* Desbordes de `RenderFlex` con cifras millonarias en bolívares en tarjetas de resumen y análisis en pantallas estrechas (`360dp`), doble `jsonDecode` dentro del método build en `ExpenseHistoryScreen` con `ListView` sin virtualización, omisión de `DocumentScannerService` desde el botón `+`, evaluación heurística OCR fragmentada, y directorio duplicado `cloudflare_worker/`.
  - *Solución:* Protección en todas las filas de montos con `Flexible`, `Expanded` y `FittedBox(fit: BoxFit.scaleDown)`; virtualización del historial con `ListView.builder` y parseo único en `ExpenseHistoryScreen`; integración transparente de `DocumentScannerService` con recorte inteligente de bordes y fallback a cámara estándar; unificación de la evaluación de calidad OCR con `LocalOcrService.evaluateRawText`; y eliminación del directorio redundante `cloudflare_worker/` preservando `workers/`. Detallado en `docs/auditoria_integral_argon.md`.

---

## Fase 5: Marketing, Lanzamiento y Tracción (En Progreso 🔄)
*Hitos para validar el producto con usuarios reales en Venezuela:*
- **Subida a Google Play Store (Closed Testing):** (En progreso 🔄) Ficha técnica y capturas preparadas (`DOC_FICHA_PLAY_STORE.md`). Adaptación de políticas de información gubernamental completada: descargos de no representación y enlaces funcionales a `https://www.bcv.org.ve/` integrados en la ficha de tienda, Calculadora de divisas y pantalla Más. AAB v1.0.4 compilado y listo para reenvío conjunto con la ficha. Prueba cerrada activa en Play Console; período de 14 días en curso con evaluadores activos y recopilación de evidencias.
- `REL-01` **Transición a Google Play y Silenciamiento de Actualizaciones Fantasma:** `Completada ✅`
  - *Problema:* Discrepancia entre builds continuos de CI (`version.json` 470) y Google Play (466) causaba alertas falsas de actualización y bucle con "Abrir" en la tienda.
  - *Solución:* Silenciados popups automáticos en `DashboardScreen` y `MainScreen`. El botón de versión en `MoreScreen` ahora dice *"Google Play"* y abre directamente la ficha de la tienda para que el usuario actualice cuando Google apruebe el build. El APK directo en la landing se mantiene hasta el pase a Producción pública.
- `REL-02` **Compatibilidad Edge-to-Edge (Android 15+) y Adaptabilidad a Pantallas Grandes (Android 16):** `Pendiente de validación 🧪`
  - *Problema:* Google Play Console alertó en la versión 516 sobre la obligatoriedad de Edge-to-Edge al apuntar a SDK 35+ y el descarte de restricciones de orientación en tablets y plegables en Android 16.
  - *Solución:* Habilitado Edge-to-Edge nativo en `MainActivity.kt` (`WindowCompat.setDecorFitsSystemWindows`) y estilos transparentes en `styles.xml`. Invocado `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` en Flutter. Aplicado contenedor responsivo con ancho máximo centrado (`maxWidth: 600`) en pantallas y modales principales para evitar deformación o desbordes en modo horizontal y tablets. (Verificado en CI build 525, commit `6a9e804`).
- **Código QR de Descarga en Landing (Desktop):** (Pendiente) Incorporar tarjeta con código QR dinámico en `rindemas.cesarluis.com` para escanear e instalar directamente desde una PC.
- **Correo de Bienvenida Automatizado:** (Pendiente) Disparar correo de bienvenida y guía de primeros pasos cuando el usuario vincule su cuenta de Google (vía trigger de Cloud Functions o Firestore).
- **Ejecución del Plan de Crecimiento (Primeros 100 Usuarios):** (Pendiente) Despliegue de tácticas comunitarias y orgánicas en grupos venezolanos según `marketing_plan.md` y `.agents/skills/growth-first-100-users/SKILL.md`.

---

## Fase 6.2: Consistencia Visual, Refinamiento UX y Nuevas Herramientas (Planificada 📋)
*Mejoras derivadas de auditoría de interfaz, legibilidad y optimización de flujos:*

### Bloque A: Consistencia Visual y Semántica (UI)
- `UI-01` **Unificación Canónica de Íconos de Categorías:** `Completada ✅`
  - *Problema:* Discrepancia entre Inicio/Análisis y Gastos (Higiene: jabón vs escoba; Salud: corazón vs botiquín; Servicios: rayo vs recibo; Alimentación: cubiertos vs carrito).
  - *Solución:* Centralizar la definición canónica en `AppConstants.getCategoryIcon(cat)` para que todas las vistas móviles y el panel web compartan exactamente los mismos íconos (adoptando manos con jabón para Higiene).
- `UI-02` **Contraste de Íconos y Controles en Pestaña "Más":**
  - *Problema:* Íconos y toggles amarillos sobre fondo blanco pierden definición visual.
  - *Solución:* Aplicar el patrón del modal `+` con contenedores circulares en tono suave (`AppColors.primaryContainer`) y trazos en carbón/negro (`AppColors.textPrimary`), o elevar el contraste hacia tonos ámbar/mostaza.
- `UI-03` **Semántica de Color Unificada en Progreso de Presupuesto:** `Completada ✅`
  - *Problema:* El mismo porcentaje (ej. 29%) se muestra verde en Inicio pero amarillo en Análisis.
  - *Solución:* Unificar la escala semafórica en toda la app: Verde (`AppColors.success` / `#10B981` para $<85\%$), Amarillo/Ámbar (`AppColors.warning` / `#F59E0B` para $\ge 85\%$) y Rojo (`AppColors.error` / `#EF4444` para $\ge 100\%$ o sobregiro), con paridad exacta en Inicio, Análisis y Web.
- `UI-04` **Rediseño de Enlaces en Presupuesto por Categoría:**
  - *Problema:* El texto `+ Asignar presupuesto mensual` con subrayado web clásico desentona con el diseño móvil.
  - *Solución:* Transformar la acción en botón tipo *pill* sutil o hacer la tarjeta completa pulsable con indicador de acento.
- `UI-05` **Ícono Superior de Asistente IA en Inicio:** `Completada ✅`
  - *Problema:* La burbuja con interrogación `[?]` en el AppBar de Inicio se confunde universalmente con "Soporte / Ayuda".
  - *Solución:* Reemplazar por ícono de destellos (`✨` / `Icons.auto_awesome`), coherente con las tarjetas del Asistente IA.
- `UI-06` **Unificación del Orden Canónico de Monedas (USD -> VES -> USDT -> EUR) en Vistas Restantes:** `Pendiente de validación 🧪`
  - *Contexto:* Tras unificar `AppConstants.monedas`, `SummaryCard`, `ReviewExpenseScreen`, `BudgetBottomSheet` y los selectores principales del panel web, se alinearon las vistas secundarias pendientes (Verificado en CI build 566 y deploy web 8, commit `0bd3500`):
    1. `lib/ui/screens/analysis_screen.dart`: Alineado vía `CurrencyLensDropdown` compartido.
    2. `lib/ui/screens/more_screen.dart`: Selector desplegable de "Moneda Principal de Reportes" reordenado a `USD -> VES -> USDT -> EUR` con etiquetas unificadas limpias (`USD BCV`, `VES Bolívares`, `USDT P2P`, `EUR BCV`).
    3. `landing/src/pages/panel.astro`: Selector de moneda en el modal de Presupuesto General y barra de lentes alineados al estándar limpio (`USD BCV`, `VES Bolívares`, `USDT P2P`, `EUR BCV`). En modal de gasto compacto se usan códigos directos (`USD`, `VES`, `USDT`, `EUR`).
- `UI-07` **Anclaje Canónico de Hojas Desplegables (Bottom Sheets) y Diálogo de Autenticación Flotante:** `Pendiente de validación 🧪`
  - *Problema:* Las hojas modales (`VoiceExpenseSheet`, `BudgetBottomSheet`) flotaban en el centro vertical de la pantalla en lugar de anclarse abajo; la hoja de presupuesto mostraba un espacio en blanco excesivo bajo "Guardar Presupuestos"; la modal de vinculación con correo cubría la pantalla de blanco en pantallas estrechas con `Center` y carecía de `dispose()` en controladores.
  - *Solución:* Patrón canónico shrink-wrapped (`Material` + `SafeArea(top: false)` sin `Center` ni `Align` vertical) aplicado en `VoiceExpenseSheet`, `BudgetBottomSheet`, `ReviewExpenseScreen` y `MainScreen`. Migración del modal de autenticación a `AuthEmailDialog` (`Dialog` nativo centrado sobre scrim, con `PopScope`, `dispose()`, textos flexibles sin desborde y sanitización de errores). Pruebas de geometría y ciclo de vida unitarias implementadas (`sheet_geometry_test.dart` y `auth_dialog_test.dart`). (Verificado en CI build 555, commit `7fbbe3d`).
- `UI-08` **Reorganización de ReviewExpenseScreen (Moneda & Monto Superior) e Idempotencia Monetaria:** `Pendiente de validación 🧪`
  - *Problema:* El formulario de registro y edición de gastos colocaba la selección de moneda y el monto al final de la pantalla, forzando al usuario a deslizarse verticalmente tras los artículos para definir la moneda. Cambiar de moneda podía alterar importes nominales o descalzar los bolívares reales cobrados en compras indexadas.
  - *Solución:*
    1. Reordenamiento visual del formulario: Comercio y Fecha $\rightarrow$ Moneda del importe y forma de pago $\rightarrow$ Monto total y equivalencias $\rightarrow$ Desglose opcional de artículos $\rightarrow$ Botón inferior de guardar.
    2. Preservación estricta del valor nominal al alternar entre monedas (`USD`, `VES`, `USDT`, `EUR`) sin conversiones imprevistas ni alteración de números introducidos.
    3. Re-tap idempotente: pulsar la moneda activa no modifica montos, tasas ni forma de pago.
    4. Preservación del método de liquidación entre divisas (`USD` $\leftrightarrow$ `EUR`).
    5. Protección de gastos indexados existentes: preservación de bolívares cobrados y montos de referencia.
    6. Bloqueo determinista de guardado si la tasa en bolívares no es válida (`<= 1.0`), eliminando fallbacks silenciosos a 1.0.
    7. Suite de pruebas exhaustiva: 12 casos en `review_expense_screen_layout_test.dart` y suite completa de 403 pruebas en verde. (Verificado en CI build 580, commit `15a0af4`).

### Bloque B: Finanzas Bimonetarias y Lentes Multimoneda (Finanzas / UX)
- `FIN-09` **Equivalencias Multimoneda Inmutables (`USD`, `VES`, `USDT`, `EUR`) y Migración SQLite v18:** `Pendiente de validación 🧪`
  - *Problema:* Al registrar un gasto en `VES` y pulsar el chip `Euro BCV`, la app actualizaba la tasa al euro oficial pero abajo seguía diciendo `Equiv. USD (BCV)` con símbolo `$`. Asimismo, la base de datos carecía de `total_eur` y `tasa_eur`, obligando al lente `EUR` a recalcular compras pasadas con la tasa del día actual.
  - *Solución:* 
    1. Migración SQLite v18 con columnas `total_eur` (en centavos) y `tasa_eur` con backfill inmutable, sincronización en Firestore y soporte en `GastoModel`.
    2. En registro de gastos (`ReviewExpenseScreen`), visualización simultánea de 3 columnas de equivalencia en `VES` (`USD BCV`, `EUR BCV`, `USDT P2P`), con chips independientes para editar cada tasa y botón circular (`Icons.restart_alt`) para restaurar la tasa oficial de la fecha.
    3. En `USDT` directo: interfaz limpia sin pedir bolívares, con cintillo de paridad 1:1 USD y contravalores informativos, guardando tasas en segundo plano para los lentes `Bs.` y `EUR`.
    4. En `USD` y `EUR`: 3 formas de liquidación alineadas y cálculo de 4 lentes deterministas.
    5. Paridad matemática al céntimo en el panel web (`landing/src/pages/panel.astro`).
  - *Documentación:* Ver [DOC_TASAS_EQUIVALENCIAS_MULTIMONEDA.md](docs/DOC_TASAS_EQUIVALENCIAS_MULTIMONEDA.md). Tarea crítica: validada y aprobada por César en *Rinde Más Dev*.


- `UX-06` **Corrección de Etiqueta de Agrupación en Gráfico de Inicio:** `Completada ✅`
  - *Comportamiento:* Se mantiene la lógica de consolidar las categorías secundarias después del Top 4 para no saturar el espacio vertical de la tarjeta.
  - *Ajuste:* Cambiar únicamente el texto de esa fila consolidada (reemplazar la palabra "Otros" por `+X categorías` o `Resto de categorías`) para que no se confunda con la categoría individual canónica *Otros*.
- `UX-07` **Desglose Directo de Productos en Pestaña "Gastos":** `Completada ✅`
  - *Problema:* Tanto Inicio como Gastos muestran tarjetas cerradas que obligan a tocar cada compra para saber qué se compró, repitiendo fechas redundantemente.
  - *Solución:* 
    - En **Inicio**: mantener tarjetas compactas con resumen limpio (`14 Oct • 4 artículos`).
    - En **Gastos**: mostrar directamente los productos con mini-ícono de categoría y subtotal. Para facturas largas, limitar a los primeros 4 ítems con botón expansor `Ver X artículos más ▾`. Mantener formato limpio de una línea para compras sin desglose.
- `UX-08` **Rediseño Definitivo de Tarjeta de Resumen (Modelo Mental V3 - Saldo Protagonista):** `Completada ✅`
  - *Problema:* El porcentaje abstracto obligaba a cálculos mentales y apilar dos números grandes competía visualmente creando un efecto de factura sobrecargada.
  - *Solución Definitiva (Estructura de 3 Niveles):*
    - **Nivel 1 (Héroe Disponible):** `Disponible para gastar` (o `Te sobraron` en meses pasados) en la cabecera junto al selector compacto Binance (`USD BCV ▾`), con el saldo disponible en 32sp negrita verde (`Color(0xFF16A34A)`) y su equivalente secundario debajo (`≈ Bs. 302.737,82`). En estado excedido muestra pastilla roja compacta `Excedido del límite` con cifra en rojo negativo (`- $ 62,40`). Sin presupuesto muestra `Total gastado` y botón full-width amarillo `+ Definir presupuesto del mes`.
    - **Nivel 2 (Contexto Horizontal sobre la Barra):** Fila equilibrada con `Gastado: $ 205,31` a la izquierda y `Límite: $ 550,00 ✏️` tocable a la derecha que abre `BudgetBottomSheet`.
    - **Nivel 3 (Barra con Asignación y Pie de Meta):** Barra lineal de 10dp con marcador vertical gris oscuro (`#4B5563`, sobresale 3dp) delimitando el ahorro. Divisor de 1dp y pie con alcancía + `Meta de ahorro: $ 50,00 · Protegida` (o `· En riesgo`).
    - **Pedagogía en Asistente IA:** El ritmo diario (`puedes gastar hasta $ 26,51/día durante los 13 días restantes...`) y sugerencias de pausa de gastos se integraron de forma dinámica en `AiInsightCard`.
- `UX-09` **Rediseño del Filtro de Comprobantes en "Gastos":**
  - *Solución:* Incorporar un distintivo de recibo/clip (`🧾`) en las tarjetas que tienen fotografía adjunta y reemplazar el botón confuso de galería por un chip activo `[🧾 Con comprobante]` o ícono de filtro con estado evidente.
- `UX-10` **Jerarquía y Claridad de la Acción "Eliminar Cuenta":** `Completada ✅`
  - *Solución:* Separar visualmente la acción de eliminar cuenta de la tarjeta "Respaldo en la Nube", ubicándola en una sección independiente y sutil de "Zona de Peligro" al final de la pantalla (solo visible con sesión en la nube activa) y modernizando el botón "Cerrar sesión" en la tarjeta de cuenta.
- `UX-11` **Feedback Visual e Indicador de Estado en Vinculación / Sincronización de Cuenta:** `Completada ✅`
  - *Problema:* Al pulsar "Vincular con Google" o autenticar con correo, la app carecía de indicadores durante la comunicación con Google Play Services y la sincronización con Firestore, generando sensación de bloqueo y permitiendo toques concurrentes.
  - *Solución:* Spinner negro de alto contraste con texto de estado (*"Conectando con Google..."*, *"Vinculando y sincronizando..."*), leyenda informativa, bloqueo de interacción cruzada y protección con `PopScope` en modales y diálogos.
- `SYNC-01` **Respaldo y Sincronización de Presupuestos en la Nube:** `Completada ✅`
  - *Problema:* Al vincular con cuenta de Google o reinstalar, los gastos se descargaban pero el presupuesto mensual aparecía en $0, debido a que las reglas de Firestore para presupuestos no se desplegaban en CI/CD, la adopción se limitaba estrictamente a `mes - 1`, y existía riesgo de error de tipo en mapas de Firestore.
  - *Solución:* Despliegue de `firestore:rules` en CI/CD, adopción histórica del último presupuesto previo en SQLite y panel web, casteo seguro y aislamiento de dominios de sincronización en `SyncService`.
- `UX-12` **Rediseño y Enriquecimiento de la Pantalla de Análisis (Centro de Diagnóstico Exhaustivo):** `Completada ✅`
  - *Problema:* Las 4 pestañas de moneda segmentadas fuera de las tarjetas fragmentaban la visión analítica y los gráficos se encontraban dispersos o limitados sin una vista de diagnóstico completa en scroll continuo.
  - *Solución:* 
    - Eliminación de la barra de 4 pestañas de moneda bajo el selector de mes y adopción del selector desplegable compacto compartido `CurrencyLensDropdown` (`[ USD BCV ▾ ]`) dentro de la Tarjeta 1 (compartido con Inicio).
    - **Tarjeta 1:** Título `Total gastado en [Mes]`, monto gastado y límite en la misma fila con línea base (`FittedBox`), equivalente secundario, barra de 10dp con divisor de meta de ahorro y recuadro inferior analítico con 3 filas (Presupuesto total, Promedio gastado por día y Proyección/Gasto final).
    - **Tarjeta 2:** Curva de `Evolución Diaria` con `LineChart` acumulativo del mes (ritmo ideal vs real con punto final destacado y etiqueta).
    - **Tarjetas 3 y 4:** Dona de categorías y Control de presupuestos por categoría desacoplados en tarjetas independientes continuas.
    - **Tarjeta 5:** `¿En qué moneda se va tu dinero?` con barra horizontal apilada multi-segmento y desglose ordenado de monedas de origen convertidas a la moneda activa.
    - **Tarjeta 6:** `Radiografía de Compras` con clasificación por umbrales (hormiga <$5, medias $5-$25, fuertes >$25) y pie con mayor gasto del mes.
    - **Padding inferior seguro:** $\ge 100\,\text{dp}$ para evitar solapamientos con la barra de navegación o el botón flotante.
- `UX-13` **Sistema Ligero de Etiquetas (Tags) para Gastos:** `Pendiente`
  - *Problema:* Los usuarios solicitan clasificar gastos en conceptos específicos no cubiertos por las 8 categorías canónicas (como Entretenimiento, Comisiones bancarias, Mascotas o Ocio). Crear categorías libres rompería el catálogo canónico de `AppConstants.categorias`, la clasificación determinista de Gemini y la paridad con el panel web.
  - *Solución:* Permitir agregar una o más etiquetas opcionales (`#tags`) en `ReviewExpenseScreen` y formularios manuales, persistirlas en SQLite/Firestore y habilitar filtro por etiquetas en el historial sin alterar las 8 categorías fijas en presupuestos y radiografías.

### Bloque C: Percepción con IA, Optimización y Seguridad
- `AI-02` **Detección Automática y Transparente de Pagos Digitales (Pago Móvil / Zelle / Binance / PayPal):** `Completada ✅`
  - *Premisa:* Funcionalidad integrada por defecto en el pipeline unificado de escaneo OCR. Resuelta la anomalía de lectura donde montos enteros (ej. $25 en PayPal o 50 Bs en Pago Móvil) se convertían a 0.25 o 0.50 debido al flag de precio de centavos en el parser.
- `AI-03` **Resumen Semántico y Ventana Deslizante en Chat IA:** `Completada ✅`
  - *Problema:* Volcado completo de la base de datos de gastos crudos (`toMap()`) y todo el historial de conversación disparaba picos de hasta >60.000 tokens en pocas consultas.
  - *Solución:* Construcción local en SQLite de un resumen semántico precalculado (`totales_categoria`, `top_productos_mes`, `ultimas_compras`, presupuesto y ritmo de ahorro) y ventana deslizante que envía solo los últimos 5 mensajes a Gemini, reduciendo el consumo de tokens en >80% preservando la capacidad analítica para preguntas frecuentes de productos.
- `AI-04` **Persistencia de Conversación en Sesión y Exclusión Fiscal de IVA en Asistente IA:** `Completada ✅`
  - *Problema:* El Asistente IA señalaba al IVA como un gasto pequeño a recortar al analizar gastos hormiga (debido a renglones fiscales `Impuesto IVA` no filtrados en `top_productos_mes`). Además, al salir del chat hacia cualquier otra pantalla de la app, toda la conversación se destruía.
  - *Solución:* Creación de `ChatProvider` en memoria (`MultiProvider`) que preserva la conversación durante toda la sesión activa de la app, botón de reinicio en el `AppBar` (`Icons.restart_alt`) con diálogo de confirmación que advierte la pérdida del historial previo, filtro estricto con `DatabaseHelper.isTaxItem` en `_buildSemanticChatContext` y regla de negocio en Cloudflare Worker instruyendo al modelo que el IVA es un tributo obligatorio legal no prescindible.
- `SEC-13` **Blindaje de Cuota Diaria y Límite Anti-Abuso en Gateway:** `Completada ✅`
  - *Problema:* Riesgo de agotamiento de saldo en Google AI Studio por bucles, ataques o scripts de scraping automatizados.
  - *Solución:* Implementación de rate limiting en Cloudflare Worker con límite de seguridad invisible de 50 peticiones/día por UID en cuota compartida, bypass automático para usuarios con API Key propia (BYOK) y respuesta amigable HTTP 429 invitando a apoyar el proyecto en `Más > Apoyar el proyecto ☕`.
- `AI-06` **Imputación de IVA en Precios de Anaquel y Algoritmo del Centavo Residual:** `Pendiente`
  - *Problema:* Las facturas fiscales del SENIAT imprimen bases imponibles (sin IVA) para productos gravados `(G)`. Al extraer el ticket, la app crea un renglón artificial "Impuesto IVA" en categoría 'Otros', distorsionando los presupuestos por categoría y descalzando el comparador histórico de precios con las entradas manuales y por voz.
  - *Solución:* Imputar el 16% de IVA directamente en los productos gravados para reflejar el precio de anaquel que el usuario pagó en caja, preservar intactos los alimentos exentos `(E)`, resolver la discrepancia de $\pm 0,01$ mediante ajuste determinista en el producto gravado de mayor valor y mostrar la base fiscal como microcopy informativo en `ReviewExpenseScreen`.
- `AI-07` **Corrección de Escala de Decimales en OCR y Validación Matemática Cruzada:** `Completada ✅`
  - *Problema:* Discrepancias donde los montos perdían decimales (ej. $56.12 aparecía como $5.612,00 o viceversa). La validación matemática cruzada en `GeminiExtractionResult` tenía las ramas de ratio invertidas, multiplicando por 100 en lugar de dividir cuando el total o los ítems omitían el punto decimal en el OCR.
  - *Solución:* Inversión corregida de ramas en `GeminiExtractionResult`, corrección defensiva de ítems individuales cuyo subtotal supera el total general por falta de coma/punto, soporte de múltiples separadores de miles en `amount_parser.dart`, suma en céntimos enteros en `review_expense_screen.dart` para evitar residuos IEEE 754 y refuerzo estricto de la regla decimal en los prompts del Cloudflare Worker.
  - *Documentación:* Ver [DOC_CORRECCION_DECIMALES_OCR.md](DOC_CORRECCION_DECIMALES_OCR.md). Tarea crítica: validada y aprobada por César en dispositivo físico.
- `AI-08` **Tratamiento Defensivo de Decimales y Comas en OCR y Asistente IA:** `Completada ✅`
  - *Problema:* Tras desactivar `isPrice: true` para preservar enteros devueltos por IA, los recibos térmicos fiscales donde los puntos o comas se imprimen tenues o borrosos (ej. `11,56` leído como `1156`) se interpretan como enteros de cuatro dígitos (`1156.00`), inflando los montos x100 cuando el total general de la factura es mayor que el ítem o cuando la IA sobreescribe el total sumando el error. Asimismo, en el Asistente y Dictado por Voz, expresiones coloquiales ("11 con 56", "3 harinas en 4 dólares") causaban confusión entre subtotales y precios unitarios.
  - *Solución:*
    1. **Consenso de Decimales y Residual Match en `GeminiExtractionResult`:** Si un ítem omitió la coma (ej. `1156` en vez de `11.56`), el motor comprueba si al dividirlo entre 100 calza con el `total_original` impreso (Residual Match) o si la mayoría de los productos tienen decimales y el ítem es un outlier de escala (Consenso de Decimales), normalizándolo a `11.56` y desinflando el total si fue alterado por la IA.
    2. **Ancla de Verdad en Worker:** El prompt de Gemini instruye leer el `total_original` estrictamente del pie de la factura como ancla inmutable y no inventarlo sumando ítems a ciegas.
    3. **Sanitización de Comas Térmicas y Expresiones de Voz:** `LocalOcrService.sanitizeOcrLine` une comas partidas (`11 . 56` -> `11.56`) y `GeminiService.normalizeVoiceText` convierte "11 con 56" y "12 y medio", desarmando además la trampa del subtotal vs precio unitario en dictado múltiple.
    4. **Corrección de IVA en `SemanticValidator`:** Eliminada la doble suma de IVA cuando la lista de ítems ya incluye el renglón impositivo.
  - *Documentación:* Ver [DOC_CORRECCION_DECIMALES_Y_VOZ.md](DOC_CORRECCION_DECIMALES_Y_VOZ.md). Tarea crítica: CI Build 538 aprobado en verde y validada exitosamente en dispositivo físico por César.


### Bloque D: Nueva Herramienta Financiera
- `FIN-09` **Calculadora Cambiaria Rápida (Conversor Bs. / $):** `Completada ✅`
  - *Ubicación:* Exclusivamente en la pestaña **Más** (el botón central `+` se preserva intacto y 100% exclusivo para ingresar gastos).
  - *Propósito:* Resolver el cálculo instantáneo antes de pagar en caja o emitir un Pago Móvil, reteniendo usuarios en la app varias veces al día.
  - *Características Clave:*
    1. **Doble campo bidireccional en tiempo real con selección y borrado rápido:** Escribir en divisa calcula bolívares al instante y viceversa; al pulsar o enfocar el campo se selecciona todo el texto para sobreescribir sin borrar manualmente, e incluye botón rápido `X` para vaciar el campo.
    2. **Chips de tasa en un toque:** Selector directo entre `[Dólar BCV]`, `[Euro BCV]`, `[USDT]` y `[Personalizada ✏️]` usando las tasas ya cacheadas en la app.
    3. **Comparativa simultánea y brecha cambiaria:** Cuadro comparativo mostrando equivalencias en las otras tasas de referencia.
    4. **Acción rápida `📋 Copiar monto en Bs.`:** Copia el número limpio al portapapeles para pegarlo directamente en la app del banco.
    5. **Acción rápida `➕ Registrar como gasto`:** Pre-llena el formulario de nuevo gasto con el monto, moneda y tasa recién calculados.

- `FIN-10` **Paridad Directa 1:1 USD/USDT en Pagos en Divisa e Inmutabilidad:** `Completada ✅`
  - *Problema:* Al mostrar valores en USDT, la app triangulaba USD -> VES -> USDT aplicando la brecha cambiaria (spread oficial BCV vs Binance P2P) a dos monedas que cotizan en dólares ($19.99 USD se transformaban en 17.66 USDT), y recalculaba el total mensual con la tasa USDT en vivo de cada día, provocando que los totales históricos fluctuaran y disminuyeran día a día.
  - *Solución:* Establecimiento de paridad determinista 1:1 directa entre USD y USDT en pagos en divisas sin aplicar tasas futuras.

- `FIN-11` **Motor Multimoneda "Dos Lentes", Pulido Integral (10 Puntos) y Soporte de IA:** `Completada ✅`
  - *Problema:* La paridad 1:1 global de FIN-10 impedía distinguir gastos cancelados en bolívares de gastos en divisas duras, borrando el ahorro real obtenido al vender USDT en Binance P2P para compras locales (ej. gasolina pagada en Bs a tasa BCV).
  - *Solución:*
    1. **Migración SQLite v17:** Columnas `total_usdt INTEGER` (céntimos inmutables) y `tasa_usdt REAL` con backfill determinista.
    2. **3 Opciones de Liquidación USD/EUR:** Pastillas `[ Pagado en Bs. (a BCV) ]`, `[ Pagado en Bs. (a USDT P2P) ]` y `[ Pagado en $ (Divisa directa) ]` en `ReviewExpenseScreen` y `panel.astro`.
    3. **Switch de 4 Lentes:** Selector `[USD BCV | USDT P2P | EUR BCV | Bs.]` en `SummaryCard`, `AnalysisScreen` y `panel.astro`, con eliminación visual de la insignia de brecha capturada para mantener limpia la UI.
    4. **Moneda Principal Dedicada:** Tarjeta independiente en `MoreScreen` con nomenclatura unificada.
    5. **Presupuestos sin Deriva (Drift):** Memoria de monto base original y paridad 1:1 estricta entre USD y USDT en `BudgetBottomSheet` y `panel.astro`.
    6. **Fallbacks Amigables y Tasas Históricas:** Fallback automático a `Compra general` y `Producto 1`, `Producto 2`, con actualización incondicional de tasas históricas al cambiar fecha.
    7. **Calculadora Cambiaria Limpia:** Estado inicial limpio sin borrado prematuro y remoción de badge duplicado.
    8. **Soporte de IA Integral:** Detección de `metodo_liquidacion` (`BS_BCV`, `BS_USDT`, `DIVISA`) en `GeminiService` y Workers Cloudflare, preselección automática en revisión y preservación de los 4 lentes en el contexto de `ChatScreen`.
  - *Documentación:* Ver [DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md). Tarea crítica: validada y aprobada por César en dispositivo físico.

- `FIN-12` **Resiliencia de Tasas de Cambio Multifuente (BCV / Paralelo):** `Completada ✅`
  - *Estado:* Resuelta la causa raíz en R8 (`NoSuchMethodError` en JNI) en el Build 500. Se integra la arquitectura de tasas multifuente (Cloudflare Gateway `/tasas`, DolarAPI, Yadio, jsDelivr), la purga automática de semillas `<= 50.0` y la actualización silenciosa sin alertas técnicas invasivas.
  - *Documentación:* Ver [DOC_RESILIENCIA_TASAS_CAMBIO.md](DOC_RESILIENCIA_TASAS_CAMBIO.md). Tarea crítica: validada y aprobada por César en dispositivo físico.

- `FIN-13` **Límites de Fechas y Blindaje de Tasas Históricas (BCV / Paralelo):** `Pendiente de validación 🧪`
  - *Problema:* Al registrar gastos en fechas anteriores a 2023 (ej. 2021), la app asignaba la tasa de hoy (881.88) debido a un fallback ciego en `ExchangeRateService`. Adicionalmente, el gráfico de Evolución Diaria solapaba las etiquetas `d30d31` en meses de 31 días y la fila de proyección en Análisis carecía de flexibilidad de espaciado.
  - *Solución:* Límite del selector a partir del 3 de enero de 2023 (`AppConstants.fechaMinimaHistoricoTasas`) hasta la fecha actual; enfoque pragmático local-first para tasas históricas (aviso de referencia y sin conexión si no hay red, permitiendo cálculo editable sin bloquear en cero); sugerencia de tasa BCV como referencia para USDT antes de feb 2026; límites en `MonthSelectorBar`; supresión de `d30` en meses de 31 días en `DailyEvolutionCard`; y ajuste con `Expanded` en la proyección de `AnalysisScreen`.
  - *Documentación:* Ver [DOC_LIMITES_FECHAS_TASAS_HISTORICAS.md](DOC_LIMITES_FECHAS_TASAS_HISTORICAS.md). Tarea crítica: Build 524 confirmado en verde (`conclusion: success`), pendiente de prueba en dispositivo por César.

- `FIN-14` **Flexibilidad y Opciones de Liquidación en Gastos Registrados en USDT:** `Pendiente`
  - *Problema:* Al seleccionar `USDT` como moneda de un gasto en `ReviewExpenseScreen`, la app aplica paridad 1:1 plana con el dólar (`helperText: 'Paridad 1:1 con USD'`) sin habilitar los métodos de liquidación (`BS_BCV`, `BS_USDT`, `DIVISA`) ni calcular el contravalor real en bolívares a tasa Binance P2P. Esto impide registrar compras cotizadas o pagadas en USDT que tienen impacto en bolívares o reflejar la brecha cambiaria frente al BCV.
  - *Solución:*
    1. Permitir opciones de liquidación para gastos ingresados en `USDT` (ej. liquidado en Bolívares a tasa Binance P2P o pagado en USDT directo vía Binance Pay/cripto).
    2. Almacenar el contravalor en Bolívares y USD calculándolo con `tasaUsdt` de la fecha seleccionada.
    3. Mantener la consistencia matemática en el switch de los 4 lentes (`USD BCV`, `USDT P2P`, `EUR BCV`, `Bs.`) sin alterar la inmutabilidad histórica.

- `FIN-15` **Soporte Nativo para Cashea y Compras en Cuotas (Flujo de Caja + Cuotas Programadas):** `Pendiente`
  - *Problema:* Registrar una compra con Cashea como 100% pagada el día 0 distorsiona el "Disponible para gastar" del mes actual y congela las cuotas futuras a una tasa BCV/USDT obsoleta (en Venezuela cada cuota cada 14 días se liquida en Bolívares a la tasa BCV vigente el día en que se paga la cuota). Por otro lado, un módulo contable de "Cuentas por Pagar / Pasivos" rompería la filosofía anti-microgestión de Rinde Más.
  - *Solución:*
    1. **Selector `[ Contado | ⚡ Cashea / Cuotas ]` en captura:** Permite elegir el nivel de inicial (`60%`, `50%`, `40%`, `20%` o monto manual) y la cantidad de cuotas (`3`, `6`, `9` o `12` cada 14 días), aplicando el algoritmo determinista del centavo residual.
    2. **Criterio de Caja + Compromisos Visibles:** Hoy impacta el presupuesto únicamente la **Inicial** pagada; las cuotas futuras se generan automáticamente en `USD` con `estado_pago = 'PENDIENTE'` en sus fechas de vencimiento (+14, +28, +42 días), mostrándose en un banner preventivo (*"⚡ Cuotas por pagar este mes"*) sin inflar el gasto ejecutado hasta que se paguen.
    3. **Liquidación en 1 toque y notificaciones locales:** Aviso 24h antes y el día de vencimiento; al pulsar `[ ✓ Pagar cuota ]` (incluso por adelantado), precarga la tasa BCV oficial de ese día, permite adjuntar el capture del Pago Móvil y pasa a `'PAGADO'`.
    4. **Soporte en IA (Voz, OCR y Chat) y Paridad Web:** Detección por voz/OCR de compras con Cashea e inyección de `cuotas_pendientes` en el contexto del Asistente IA.
  - *Documentación y Plan Técnico:* Ver [DOC_PLAN_CASHEA.md](DOC_PLAN_CASHEA.md).

### Bloque E: Respaldo y Soberanía de Datos (Local-First Backup)
- `BACKUP-01` **Exportación e Importación Completa con Comprobantes (.zip):** `Pendiente`
  - *Problema:* Al desinstalar y reinstalar la app (común en evaluadores de Play Store y cambios de dispositivo), los gastos se recuperan desde Firestore pero las fotos de los comprobantes (`recibo_*.jpg`) se pierden definitivamente, ya que por política de privacidad y costo cero residen exclusivamente en el sandbox local del teléfono y no en la nube.
  - *Solución:*
    1. Crear en la pestaña Más la opción **"Exportar copia de seguridad completa (.zip)"** que comprima la base de datos SQLite y la carpeta de imágenes de comprobantes.
    2. Implementar la acción inversa **"Restaurar copia de seguridad (.zip)"** mediante selector de archivos (`file_picker`), extrayendo las imágenes al directorio local y reinsertando/fusionando los registros en SQLite sin colisiones de IDs.
    3. Permitir guardar o compartir el archivo `.zip` en Google Drive personal, almacenamiento interno o mensajería, ofreciendo total soberanía y respaldo offline sin depender de servidores en la nube.
- `BACKUP-02` **Importación Masiva y Migración desde Otras Apps (MyMoney Pro / CSV / Plantilla Excel):** `Pendiente`
  - *Problema:* Usuarios que llevan meses o años registrando gastos en otras aplicaciones (como MyMoney Pro, Gestor de Gastos, 1Money o hojas de Excel) enfrentan una alta barrera de salida al no poder traer su historial a Rinde Más sin transcribir compra por compra.
  - *Solución:*
    1. **Plantilla Oficial Descargable (`.csv` / `.xlsx`) y Parser Directo:** Proveer una plantilla limpia desde la app y el panel web (`panel.astro`) con columnas claras (`Fecha`, `Comercio/Concepto`, `Monto`, `Moneda`, `Categoría`, `Tasa opcional`, `Notas`), además de un detector automático del formato CSV nativo exportado por MyMoney Pro (`Time`, `Type`, `Category`, `Amount`, `Account`, `Notes`).
    2. **Normalización y Cruce Histórico Automático de Tasas:** Para registros desde el 3 de enero de 2023 sin tasa especificada, cruzar automáticamente la fecha del gasto con el historial local/remoto de `ExchangeRateService` (`getRateForDate`) para calcular e inmutabilizar los contravalores (`total_ves`, `total_usd`, `total_usdt`, `tasa_bcv`) en céntimos.
    3. **Mapeo Inteligente a las 8 Categorías Canónicas:** Traducir las categorías libres de la app de origen hacia las 8 categorías oficiales mediante `AppConstants.normalizarCategoria` y conservar el nombre de la categoría o cuenta original como `#etiqueta` o en el concepto para no perder contexto ni alterar la filosofía sin múltiples cuentas bancarias.
    4. **Vista Previa y Deduplicación en Lote:** Mostrar resumen previo a la inserción (`X gastos listos para importar, Y omitidos por ingresos/transferencias`) y ejecutar inserción transaccional por lotes (`batch`) en SQLite y Firestore.

---

## Fase 6.1 (Remanente): Catálogo de Categorías
- **Revisión y Expansión de Categorías por Defecto:** (Pendiente) Evaluar la incorporación de nuevas categorías predeterminadas de uso habitual (ej. 'Vestimenta' / 'Ropa' o afines) para evitar la sobreutilización de 'Otros'. Requiere coordinar: asignación de color e icono en UI, ampliación de sinónimos en `AppConstants.normalizarCategoria`, actualización de prompts de categorización en IA (Cloudflare Worker), y paridad matemática/visual en el panel web.

---

## Fase 7: Arquitectura de Producción y Confiabilidad (Pendientes Técnicos)
*Evolución hacia grado de confiabilidad bancaria ("Bank-grade"):*
- `OPS-02` **Desacoplamiento de Pipelines CI/CD Web y Móvil:** `Completada ✅`
  - *Problema:* El pipeline monolítico `build_apk.yml` compilaba Android (APK + AAB, 12–14 min) ante cualquier cambio estético o de texto en `landing/`, `firebase.json` o `firestore.rules`.
  - *Solución:* Creación de `.github/workflows/deploy_web.yml` (~45–60 s) con caché de npm, control de concurrencia y preservación automática del `version.json` activo de producción antes de compilar Astro; exclusión de rutas web en `paths-ignore` de `build_apk.yml`; corrección de `set -e -o pipefail` en compilación de binarios y soporte multi-workflow e intervalo adaptativo en `scripts/wait_ci.ps1`. (Verificado en CI `deploy_web.yml` run `39876106103`, commit `af85856`).
- `OPS-03` **Entorno Paralelo de Pruebas (Rinde Más Dev) y Aislamiento de Producción:** `Pendiente de validación 🧪`
  - *Problema:* Necesidad de validar cambios en dispositivo físico sin desinstalar ni alterar la app oficial de Google Play (`com.cesarluis.rindemas`) en el teléfono de César (para no reiniciar ni poner en riesgo los 14 días consecutivos de la Prueba Cerrada). Asimismo, la landing page ofrecía descargas de APK directos con advertencias de fuentes desconocidas en Android y obligaba a subidas FTP a BanaHosting en cada push.
  - *Solución:*
    1. **App Paralela Dev:** `build_apk.yml` compila el artefacto privado `rindemas-dev-apk` (`com.cesarluis.rindemas.dev` / *"Rinde Más Dev"*) firmado con `rindemas.jks`, coexistiendo en el mismo teléfono sin pisar la versión de la tienda.
    2. **AAB de Producción Intacto:** En la misma corrida se genera el artefacto `app-release-aab` (`com.cesarluis.rindemas`) para Play Store.
    3. **Landing Centrada en Lanzamiento:** Eliminada la descarga de APK en la web y la subida FTP a BanaHosting. Todo el tráfico web se canaliza a la lista de espera oficial en el Canal de WhatsApp y la insignia de Google Play.
    4. **Soporte Oficial en Firebase:** Sincronizado `google-services.json` con el cliente registrado `com.cesarluis.rindemas.dev`.
  - *Documentación:* Ver [ci-distribucion.md](.agents/rules/ci-distribucion.md) y [AGENTS.md](AGENTS.md). CI en verde (run `39966116419`).
- **Evaluación de Firebase AI Logic (`firebase_vertexai`):** Evaluar migración de llamadas REST al SDK de Firebase Vertex AI en Flutter, integrando Firebase App Check y Remote Config.
- **Despliegue Dinámico y Configuración Remota (Firebase Remote Config):** Configurar cuotas mensuales de IA, textos y parámetros de modelos desde el servidor sin requerir nuevo APK.
- **Manejo de Casos Borde en Facturas Locales (Corner Cases):** Refinamiento para facturas térmicas dobladas, comprobantes mixtos con ítems en Bs y total en USD/"Ref", y marcadores de IVA exento/gravado.
- **Procesamiento Background Nativo:** Migrar la cola local en Dart a un Background Worker real del sistema operativo (Firebase Cloud Tasks / WorkManager) para asegurar subidas e IA incluso con la app cerrada.
- **Extracción Asistida por Confianza (Confidence Scores):** Retorno de nivel de confianza por dato extraído con alerta "⚠️ Revisar" y diccionario personal local de aprendizaje.
- **Cifrado de Extremo a Extremo en Nube (E2EE / Zero-Knowledge Sync):** Cifrado local con AES-256 de gastos y comprobantes antes de persistir en Firestore utilizando clave derivada de la contraseña del usuario.
- **Copia de Seguridad y Restauración Portable (.zip):** Especificada y priorizada en Fase 6.2 Bloque E (`BACKUP-01`).

---

## Fase 8.1: Modernización y Paridad del Panel Web (En Progreso 🔄)
*Actualización progresiva del panel web (`landing/src/pages/panel.astro`) con paridad respecto a la app móvil:*
- **Fase 1 (Web): Presupuesto y Meta de Ahorro en Modal y Firestore:** (En verificación 🔄)
- **Fase 2 (Web): Semáforo de Salud de Ahorro y Ritmo Diario:** (En verificación 🔄)
- **Fase 3 (Web): Soporte Multimoneda (USD, VES, EUR, USDT) y Tasas en Vivo:** (En verificación 🔄)
- **Fase 4 (Web): Autenticación con Correo y Contraseña:** (Pendiente de validación 🧪) Soporte en `panel.astro` para inicio de sesión, registro y recuperación de clave vía Firebase Auth (`signInWithEmailAndPassword`, `createUserWithEmailAndPassword`, `sendPasswordResetEmail`). Desplegado a producción en web build 8 (commit `0bd3500`).
- **Fase 5 (Web): Edición y Detalle Ampliado de Facturas:** (Pendiente de validación 🧪) Edición completa de compras, desglose dinámico de ítems, cálculo proporcional y sincronización directa con Firestore desde el navegador. Desplegado a producción en web build 8 (commit `0bd3500`).

---

## Fase 8: Ecosistema Web y Red Colaborativa (Largo Plazo 🔭)
- **Dashboard Web de Escritorio en Flutter Web:** Estadísticas avanzadas y subida masiva de facturas desde PC.
- **Crowdsourcing de Precios (El Waze de las compras):** Base de datos anónima de precios recopilada colaborativamente en Venezuela.
- **Comparativa por Unidad de Medida:** Comparación inteligente de precios normalizados (ej. Arroz $2.00/kg vs $1.60/kg).
- **Buscador de Ofertas Locales:** Consulta de comercios cercanos con mejores precios en las últimas 48 horas.
- **Historial Interactivo de Tasas BCV:** Gráfico histórico de la evolución de tasas oficiales y brecha cambiaria.
- **Cross-Selling de Ecosistema:** Reutilización de módulos (Auth, Sync, SQLite, IA OCR) para nuevas herramientas financieras.

---

## Fase 9: Modelo de Monetización y Suscripción Premium (Rinde Más Pro)
*Diseño de experiencia de pago, embudo de conversión y monetización:*
- **Cuota Gratuita Base:** 15 a 20 facturas escaneadas por cámara al mes (registro manual y voz siempre ilimitados).
- **Publicidad en Transiciones Naturales:** Anuncios discretos tras guardar gastos para cubrir el costo de tokens de usuarios gratuitos, cumpliendo Better Ads Standards.
- **Rinde Más Pro ($1,99/mes o $19,99/año):**
  - Cuotas de IA y OCR ilimitadas.
  - Experiencia Cero Publicidad (Zero Ads).
  - Categorías personalizadas ilimitadas (icono y color propio).
  - Exportación contable avanzada (PDF mensual con balance y diseño limpio; Excel/CSV con desglose completo ítem por ítem).
  - Sincronización y respaldo de fotos de comprobantes en la nube (Cloudflare R2 / Storage / Plan Pro: en la versión gratuita las fotos se mantienen 100% locales en el dispositivo por privacidad y contención de costos).
  - Consultas analíticas profundas al Asistente IA con comparativa de meses previos.
  - Modo Contable y Desglose Tributario Formal: Selector en Más para alternar entre Modo Anaquel (con IVA) y Modo Fiscal (base imponible desglosada), con exportación de libro fiscal de compras en Excel/PDF.
- **Optimización del Embudo de Conversión (Funnel):** Medición de fugas con Firebase Analytics (Impresión → Descarga → Onboarding → Activación → Retención → Pago) y Paywalls contextuales.
- **Métrica de Validación Financiera:** Meta de generar los primeros $50 USD en 30-60 días con 500-1.000 usuarios activos.
- **Alertas Proactivas de Inflación y Desvío:** Notificaciones inteligentes cuando productos frecuentes suban de precio o el ritmo de gasto comprometa el mes.
