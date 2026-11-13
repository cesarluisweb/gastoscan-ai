# Histórico de Desarrollo y Hitos Completados: Rinde Más

Este documento recopila el registro histórico y técnico de todas las fases, hitos y optimizaciones completadas en **Rinde Más**. Su propósito es servir de bitácora de ingeniería, consulta técnica para arquitectura y base documental para materiales de marketing y comunicación de producto.

Para consultar las tareas activas, en progreso y la visión futura, dirígete a [ROADMAP.md](ROADMAP.md).

---

## Índice Histórico de Fases Completadas
1. [Fase 1: Correcciones Críticas (MVP Inicial)](#fase-1-correcciones-críticas-mvp-inicial)
2. [Fase 2: Usabilidad, Diseño y Marca](#fase-2-usabilidad-diseño-y-marca)
3. [Fase 3: Infraestructura SaaS y Asistente IA Base](#fase-3-infraestructura-saas-y-asistente-ia-base)
4. [Fase 4: Asistente IA Proactivo y UX Avanzada](#fase-4-asistente-ia-proactivo-y-ux-avanzada)
5. [Fase 5: Infraestructura de Lanzamiento y Notificaciones](#fase-5-infraestructura-de-lanzamiento-y-notificaciones)
6. [Fase 6: Pulido, Navegación y Experiencia Recurrente](#fase-6-pulido-navegación-y-experiencia-recurrente)
7. [Fase 6.1: Hitos de Feedback de Comunidad y Resiliencia](#fase-61-hitos-de-feedback-de-comunidad-y-resiliencia)
8. [Fase 6.2: Consistencia Visual, Refinamiento UX y Herramientas](#fase-62-consistencia-visual-refinamiento-ux-y-herramientas)
9. [Fase 7.1: Auditoría Integral y Blindaje para Google Play](#fase-71-auditoría-integral-y-blindaje-para-google-play)
10. [Fase 7: Arquitectura de Producción, Confiabilidad y DevOps](#fase-7-arquitectura-de-producción-confiabilidad-y-devops)
11. [Fase 8.1: Modernización y Paridad del Panel Web](#fase-81-modernización-y-paridad-del-panel-web)
12. [Auditoría Argon y Calidad de Sincronización](#auditoría-argon-y-calidad-de-sincronización)

---

## Fase 1: Correcciones Críticas (MVP Inicial)
*Correcciones indispensables de bajo esfuerzo y alto impacto inicial:*
- **Edición de gastos guardados:** Capacidad de modificar comercios, fechas y categorías de gastos registrados previamente.
- **Exportación mensual:** Generación y descarga de resúmenes de gastos delimitados por mes.
- **Precio unitario editable:** Ajuste fino manual de precios unitarios por producto en facturas.

---

## Fase 2: Usabilidad, Diseño y Marca
*Transformación de identidad visual y retención de usuarios cotidianos:*
- **Rediseño a "Rinde Más":** Adopción de la identidad visual tipo billetera digital clara (amarillo `#F5C518` / blanco / carbón), Bottom Navigation Bar y botón central flotante (FAB) para agregar gastos mediante escaneo o registro manual.
- **Lista de Compras Inteligente:** Check-list interactivo de compras con auto-tachado automático al escanear facturas coincidentes.
- **Empty States y Confirmaciones:** Estados visuales informativos cuando no hay transacciones y diálogos de confirmación para acciones destructivas.

---

## Fase 3: Infraestructura SaaS y Asistente IA Base
*Pilares de retención, identidad de usuario y sincronización inicial:*
- **Registro de Usuarios y Autenticación:** Inicio de sesión silencioso automático como usuario Anónimo al abrir la app por primera vez, con opción de vinculación con cuenta de Google.
- **Sincronización en la Nube:** Respaldo y persistencia en Cloud Firestore.
- **Analista Financiero IA (Chatbot Básico):** Primera versión del chat conversacional para responder preguntas sobre el balance y gastos mensuales.

---

## Fase 4: Asistente IA Proactivo y UX Avanzada
*Capacidades offline y resiliencia de percepción:*
- **Cola Offline de Escaneo y UX Unificada:** Persistencia temprana en SQLite local, banner global reactivo único sin duplicidad visual, microcopy empático ("Guardada sin conexión" en lugar de errores técnicos), auto-reanudación transparente mediante `connectivity_plus` y observador del ciclo de vida (`AppLifecycleState.resumed`).

---

## Fase 5: Infraestructura de Lanzamiento y Notificaciones
- **Landing Page (`https://rindemas.cesarluis.com`):** Desarrollada con Astro + Tailwind CSS, alojada en Firebase Hosting, con diseño responsive, propuesta de valor, captura interactiva de smartphone y guía de instalación.
- **Canal Directo de Soporte:** Integración de tarjeta en la pestaña "Más" con acción directa para abrir chat oficial de asistencia técnica vía WhatsApp.
- **Playbook de Crecimiento Inicial (100 Usuarios):** Estrategia documentada en `marketing_plan.md` y `.agents/skills/growth-first-100-users/SKILL.md`.
- `REL-01` **Transición a Google Play y Silenciamiento de Actualizaciones Fantasma:** Silenciados popups automáticos en `DashboardScreen` y `MainScreen`. El botón de versión en `MoreScreen` abre la ficha de la tienda de Google Play. El APK directo en landing se mantiene hasta producción pública.
- `REL-02` **Compatibilidad Edge-to-Edge (Android 15+) y Adaptabilidad a Pantallas Grandes (Android 16):** Habilitado Edge-to-Edge nativo en `MainActivity.kt` (`WindowCompat.setDecorFitsSystemWindows`) y estilos transparentes en `styles.xml`. Invocado `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` en Flutter. Aplicado contenedor responsivo con ancho máximo centrado (`maxWidth: 600`) en pantallas y modales principales para evitar deformaciones en tablets y rotación horizontal (CI build 525).
- `NOTIF-01` **Sistema de Notificaciones Masivas (Broadcast FCM) y Recordatorios Quincenales:** Integración con Firebase Cloud Messaging (`firebase_messaging: ^15.1.3`) al topic `anuncios_generales` para envíos desde Firebase Console; recordatorio quincenal rotativo con 4 frases del Asistente IA sincronizable online desde Firestore (`config/recordatorios`); inactividad ajustada a 30 días sin insistencia en bucle; fila compacta en pantalla Más con modal de control de 3 canales; y manual operativo en `docs/GUIA_BROADCAST_FIREBASE.md` (CI build 609).

---

## Fase 6: Pulido, Navegación y Experiencia Recurrente
*Herramientas complementarias para usuarios activos:*
- **Subida Múltiple de Facturas (Batch Upload):** Procesamiento secuencial en cola de múltiples fotografías simultáneas.
- **Búsqueda en Tiempo Real:** Filtrado instantáneo por nombre de comercio o texto de productos en el historial.
- **Presupuestos Bimonetarios y por Categoría:** Asignación de límites mensuales en USD o VES con aislamiento por mes calendario y alertas visuales.
- **Recordatorios Locales y Notificaciones Push:** Recordatorios locales sobrios a 7 días de inactividad, deep-links a facturas listas tras escaneo, feedback háptico controlado y conmutador en Ajustes.
- **Navegación Fluida de 4 Destinos:** Transiciones sutiles (Inicio, Gastos, Análisis, Más) y barra flotante de escaneo accesible.
- **Asistente IA con Gestión de Compras:** Chat con Function Calling para agregar/tachar productos de la lista de compras, desambiguación obligatoria y 5 botones de consultas frecuentes.

---

## Fase 6.1: Hitos de Feedback de Comunidad y Resiliencia
*Optimizaciones derivadas de pruebas comunitarias y retroalimentación técnica:*
- **Estado de Facturas Pendientes en UI:** Eliminado el placeholder falso de "$ 0.00" mientras la factura está en cola de procesamiento; reemplazado por badge "Por revisar".
- **Detección de IVA y Alícuotas Fiscales en OCR:** Incorporación en prompts de extracción de la detección de marcadores fiscales venezolanos (`(E)` Exento, `(G)` Gravado, alícuota 16%) para desglosar impuestos con precisión.
- **Meta Mensual de Ahorro / Inversión y Proyección de Gastos:** Configuración de meta mensual de ahorro en el presupuesto, cálculo de límite para gastar (`Presupuesto - Meta`), validación de categorías, motor determinista `SavingsHealthCalculator`, estado semafórico (Protegida, En riesgo, Comprometida) y alertas inteligentes en Inicio y Chat.
- **Consistencia Matemática y Totales en Bolívares:** Montos en bolívares inmutables por fecha de compra sin distorsión por fluctuaciones de tasa diaria posterior. Sincronización exacta de Total Gastado del mes y Distribución por Categoría (incluyendo compras sin desglose de ítems), corrección de tasa en chat y auto-reparación transparente de tasas históricas.
- **Sistema Multimoneda y Selector de Tasas (BCV, Euro, USDT):** Soporte integral multimoneda (VES, USD, EUR, USDT) con conversión automática en vivo, chips de tasa rápida en revisión de gastos, tarjeta de 3 tasas con timestamp en "Más" e integración de APIs (DolarAPI oficial USD/EUR y Binance/Yadio USDT).
- **Monitoreo de Consumo de Tokens:** Captura y registro de metadata de tokens consumidos devuelta por Gemini para auditoría de costos de inferencia.
- **Robustez de Cola de Escaneo y Ciclo de Vida (Bloques 1 y 1b):** Protección contra carreras con guarda síncrona, confirmación modal para descartar/cancelar con descarte individual por ID, protección de fotos compartidas en escaneos por lote para evitar borrado huérfano, retención de fotos ante respuestas vacías con transición a error, reintentos controlados y recuperación de ítems atascados en `processing`.
- **Base de Datos y Asincronía (Bloque 2):** Eliminación de consultas N+1 mediante hidratación en lotes, índices en SQLite v15 (`items_gasto.gasto_id`, `scan_queue.status`, `gastos.synced`), borrado lógico en O(1), adopción de presupuestos en memoria sin escrituras fantasmas y mutadores asíncronos seguros.
- **Adjuntar y Gestionar Comprobantes en Registro Manual:** Adjuntar (cámara/galería), visualizar a pantalla completa, reemplazar y eliminar comprobantes desde el formulario manual y edición (`DOC_RESILIENCIA_IA_Y_COMPROBANTES.md`).
- **Resiliencia de IA y Recuperación en Cola:** Mensajes empáticos ante fallas de red/cuota, prevención de descarte accidental con reintento en el banner y respuestas limpias en Chat (`DOC_RESILIENCIA_IA_Y_COMPROBANTES.md`).
- **Estudio de Viabilidad de Cuota Individual de Gemini:** Documentado en `DOC_INFORME_VIABILIDAD_GEMINI.md`. Descartada delegación transparente por restricciones de Google; aprobada solución BYOK opcional.
- **Exploración de Respaldo y Privacidad:** Documentado en `DOC_INFORME_BACKUP_PRIVACIDAD.md`. Descartado Google Drive directo por permisos invasivos; adoptado esquema de exportación portable `.zip`.
- **Opción de API Key Propia para IA (BYOK Gemini):** Ajuste en pantalla Más para que usuarios avanzados ingresen su API Key de Google AI Studio con enrutamiento vía cabecera al Worker, almacenamiento seguro en Keystore (`FlutterSecureStorage`) y sincronización con Firestore (`DOC_BYOK_GEMINI.md`).
- **Autenticación Agnóstica de Correo (Addy.io / Alias):** Registro e inicio de sesión con cualquier correo o alias y contraseña en Firebase Auth, con vinculación transparente desde cuentas anónimas.
- **Múltiples Compras Independientes por Voz y en Chat:** Soporte para dictar compras en comercios distintos en una sola frase ("compré en la farmacia X y en el supermercado Y"). La IA desglosa cada compra como un gasto independiente con su propia moneda, categoría e ítems, encolándolos en `ScanQueueProvider` y habilitando revisión secuencial continua.

---

## Fase 6.2: Consistencia Visual, Refinamiento UX y Herramientas

### Bloque A: Consistencia Visual y Semántica (UI)
- `UI-01` **Unificación Canónica de Íconos de Categorías:** Centralizada la definición canónica en `AppConstants.getCategoryIcon(cat)` para que todas las vistas móviles y el panel web compartan exactamente los mismos íconos (manos con jabón para Higiene).
- `UI-03` **Semántica de Color Unificada en Progreso de Presupuesto:** Unificada la escala semafórica en toda la app: Verde (`AppColors.success` / `#10B981` para $<85\%$), Amarillo/Ámbar (`AppColors.warning` / `#F59E0B` para $\ge 85\%$) y Rojo (`AppColors.error` / `#EF4444` para $\ge 100\%$ o sobregiro), con paridad exacta en Inicio, Análisis y Web.
- `UI-04` **Rediseño de Ícono, Enlaces y Enfoque Directo en Presupuesto por Categoría:**
  1. Fila superior limpia con `maxLines: 1`, `overflow: ellipsis` y `FittedBox` generoso para montos gastado/presupuesto.
  2. Acción de edición integrada (`Key('edit_budget_$cat')`) en la fila inferior junto a la barra de progreso.
  3. Chip sutil de asignación con ícono `+` y texto «Asignar presupuesto» (`Key('assign_budget_prompt_$cat')`).
  4. Navegación directa con auto-scroll (`Scrollable.ensureVisible`) y foco instantáneo en el campo numérico al pulsar cualquier categoría (`BudgetBottomSheet.show(context, initialCategory: cat)`).
- `UI-05` **Ícono Superior de Asistente IA en Inicio:** Reemplazada la burbuja de interrogación `[?]` en el AppBar por destellos (`✨` / `Icons.auto_awesome`), coherente con la identidad visual de la IA.
- `UI-06` **Unificación del Orden Canónico de Monedas (`USD -> VES -> USDT -> EUR`):** Alineado el orden en `AnalysisScreen` (vía `CurrencyLensDropdown`), selector de "Moneda Principal de Reportes" en `MoreScreen` (`USD BCV`, `VES Bolívares`, `USDT P2P`, `EUR BCV`) y selectores del panel web (`panel.astro`) (CI build 566 y deploy web 8).
- `UI-07` **Anclaje Canónico de Hojas Desplegables (Bottom Sheets) y Diálogo de Autenticación Flotante:** Patrón canónico shrink-wrapped (`Material` + `SafeArea(top: false)` sin `Center` ni `Align` vertical) aplicado en `VoiceExpenseSheet`, `BudgetBottomSheet`, `ReviewExpenseScreen` y `MainScreen`. Migración del modal de autenticación a `AuthEmailDialog` (`Dialog` nativo centrado sobre scrim, con `PopScope`, `dispose()` y textos flexibles) (CI build 555).
- `UI-08` **Reorganización de ReviewExpenseScreen (Moneda & Monto Superior) e Idempotencia Monetaria:**
  1. Reordenamiento visual: Comercio y Fecha $\rightarrow$ Moneda del importe y forma de pago $\rightarrow$ Monto total y equivalencias $\rightarrow$ Desglose opcional de artículos $\rightarrow$ Guardar.
  2. Preservación estricta del valor nominal al alternar entre monedas (`USD`, `VES`, `USDT`, `EUR`) sin conversiones imprevistas.
  3. Re-tap idempotente: pulsar la moneda activa no modifica montos, tasas ni forma de pago.
  4. Preservación del método de liquidación entre divisas y de bolívares reales cobrados en gastos indexados.
  5. Bloqueo determinista de guardado ante tasas en bolívares inválidas (`<= 1.0`). (CI build 580).
- `UX-13` **Guardado de Gastos como Borrador y Flujo Seguro al Editar:**
  1. Opción "Guardar borrador" al retroceder con datos en gastos nuevos, botón directo en AppBar (`Icons.bookmark_border_rounded`), persistencia en `scan_queue` SQLite con estado `ready` y denominación "Comercio no especificado".
  2. En edición de gasto existente: título «Editar gasto» en AppBar, confirmación «¿Guardar modificaciones?» al retroceder y mensaje «Gasto actualizado con éxito». (CI build 620).
- `UI-14` **Autocategorización Semántica Local de Conceptos:** Catálogo estático 100% offline de más de 250 términos venezolanos (`CategoryClassifierService`), preservando elecciones manuales del usuario y sincronizando líneas de impuestos.
- `UI-15` **Modelo "Tanque que se Vacía" en Medidores de Presupuesto (V2):**
  1. Inversión visual (`100% → 0%`) en Inicio, Análisis, Categorías y Web.
  2. Marcador vertical de meta de ahorro a la izquierda y carril visible (`#E5E7EB` / `#374151`).
  3. Doble tono con muesca separadora: reserva de ahorro protegida en `#065F46` y saldo para gastar en `#16A34A` (Verde), `#D97706` (Ámbar $\le$ 15%) o `#DC2626` (Rojo).
  4. Al invadir el ahorro, leyenda dinámica «Ahorro comprometido · quedan $ X» en rojo sin romper la semántica de `enRiesgo`. Swap de etiquetas de cabecera en `SummaryCard`. (DOC_BARRA_TANQUE_PRESUPUESTO.md, CI Build 641 y commits `8b81c66`/`24e73e4`).

### Bloque B: Finanzas Bimonetarias y Lentes Multimoneda (Finanzas / UX)
- `FIN-09` **Equivalencias Multimoneda Inmutables (`USD`, `VES`, `USDT`, `EUR`) y Migración SQLite v18:**
  1. Migración SQLite v18 con columnas `total_eur` y `tasa_eur` en céntimos inmutables con soporte en `GastoModel` y Firestore.
  2. En `ReviewExpenseScreen`, visualización simultánea de 3 columnas de equivalencia en `VES` (`USD BCV`, `EUR BCV`, `USDT P2P`), con edición de tasas independientes y botón circular para restaurar tasa oficial.
  3. USDT directo con paridad 1:1 con USD y almacenamiento de tasas en segundo plano para lentes `Bs.` y `EUR`.
  4. Paridad matemática en el panel web (`panel.astro`). (DOC_TASAS_EQUIVALENCIAS_MULTIMONEDA.md).
- `UX-06` **Corrección de Etiqueta de Agrupación en Gráfico de Inicio:** Consolidación de categorías secundarias después del Top 4 bajo la etiqueta `+X categorías` para no colisionar con la categoría *Otros*.
- `UX-07` **Desglose Directo de Productos en Pestaña "Gastos":** Visualización directa de artículos con mini-ícono de categoría y subtotal, con expansor `Ver X artículos más ▾` para compras extensas y formato compacto de una línea para compras sin desglose.
- `UX-08` **Rediseño Definitivo de Tarjeta de Resumen (Modelo Mental V3 - Saldo Protagonista):** Saldo disponible en 32sp negrita verde, selector Binance en cabecera (`USD BCV ▾`), contexto horizontal (`Gastado` vs `Límite`), y pie con meta de ahorro.
- `UX-10` **Jerarquía y Claridad de la Acción "Eliminar Cuenta":** Separación visual de la acción en una sección sutil de "Zona de Peligro" al final de `MoreScreen` (solo con sesión en la nube activa) y modernización del botón "Cerrar sesión".
- `UX-11` **Feedback Visual e Indicador de Estado en Vinculación / Sincronización de Cuenta:** Spinner negro de alto contraste con textos dinámicos de estado (*"Conectando con Google..."*, *"Vinculando y sincronizando..."*) y bloqueo de interacción con `PopScope`.
- `SYNC-01` **Respaldo y Sincronización de Presupuestos en la Nube:** Despliegue de `firestore:rules` para presupuestos en CI/CD, adopción histórica del último presupuesto previo en SQLite y panel web, casteo seguro y aislamiento de dominios de sincronización en `SyncService`.
- `UX-12` **Rediseño y Enriquecimiento de la Pantalla de Análisis (Centro de Diagnóstico Exhaustivo):** Adopción de `CurrencyLensDropdown` dentro de la Tarjeta 1, ritmo y proyección diaria, curva acumulativa `LineChart`, desglose de monedas de origen y radiografía de compras por umbrales.

### Bloque C: Percepción con IA, Optimización y Seguridad
- `AI-02` **Detección Automática y Transparente de Pagos Digitales (Pago Móvil / Zelle / Binance / PayPal):** Corrección del parser de precios de centavos, capturando pagos digitales con montos exactos sin divisiones erróneas.
- `AI-03` **Resumen Semántico y Ventana Deslizante en Chat IA:** Resumen precalculado en SQLite (`totales_categoria`, `top_productos_mes`, `ultimas_compras`) y ventana de 5 mensajes en Gemini, recortando el consumo de tokens en >80%.
- `AI-04` **Persistencia de Conversación en Sesión y Exclusión Fiscal de IVA en Asistente IA:** `ChatProvider` en memoria para retener la charla durante la sesión activa, botón de reinicio en el AppBar con advertencia, y directiva de IVA como tributo legal ineludible.
- `SEC-13` **Blindaje de Cuota Diaria y Límite Anti-Abuso en Gateway:** Rate limiting en Cloudflare Worker con tope de 50 peticiones/día por UID en cuota compartida, bypass para BYOK y respuesta HTTP 429 empática.
- `AI-07` **Corrección de Escala de Decimales en OCR y Validación Matemática Cruzada:** Inversión corregida de ramas en `GeminiExtractionResult`, normalización defensiva de ítems descalzados, soporte multi-separador en `amount_parser.dart` y validación en céntimos enteros (DOC_CORRECCION_DECIMALES_OCR.md).
- `AI-08` **Tratamiento Defensivo de Decimales y Comas en OCR y Asistente IA:** Consenso de Decimales y Residual Match en `GeminiExtractionResult`, prompt ancla de total en Cloudflare Worker y normalización de expresiones coloquiales de voz ("11 con 56", "3 harinas en 4 dólares") (DOC_CORRECCION_DECIMALES_Y_VOZ.md).
- `AI-09` **Triple Escudo de Fechas en Facturas (DD/MM/YYYY) y Contraste de DatePicker:**
  1. Regla en Worker para exigir formato día/mes/año, función sanitizadora determinista `normalizeReceiptIsoDate()` en el Gateway, y parser tolerante `GeminiExtractionResult.parseExtractionDate()` en Flutter.
  2. DatePicker con número de día actual en negro (`Colors.black`), fondo amarillo suave (`AppColors.primaryLight`) inactivo y amarillo sólido (`AppColors.primary`) seleccionado (CI Build 640).

### Bloque D: Herramientas Financieras y Tasas
- `FIN-09` **Calculadora Cambiaria Rápida (Conversor Bs. / $):** Herramienta bidireccional en la pestaña Más con selección rápida de texto, chips de tasas BCV/Euro/USDT/Personalizada, comparativa simultánea de brecha cambiaria, acción rápida para copiar monto en bolívares y botón para registrar directamente como gasto.
- `FIN-10` **Paridad Directa 1:1 USD/USDT en Pagos en Divisa e Inmutabilidad:** Paridad 1:1 directa entre USD y USDT en pagos en divisas sin aplicar spread artificial ni fluctuaciones futuras.
- `FIN-11` **Motor Multimoneda "Dos Lentes", Pulido Integral y Soporte de IA:** Migración SQLite v17 con `total_usdt`, 3 opciones de liquidación (`BS_BCV`, `BS_USDT`, `DIVISA`), switch de 4 lentes (`USD BCV`, `USDT P2P`, `EUR BCV`, `Bs.`) y soporte en prompts de IA (DOC_MOTOR_MULTIMONEDA.md).
- `FIN-12` **Resiliencia de Tasas de Cambio Multifuente (BCV / Paralelo):** Integración multifuente (Cloudflare Gateway `/tasas`, DolarAPI, Yadio, jsDelivr), purga de semillas obsoletas (`<= 50.0`) y actualización silenciosa en segundo plano (DOC_RESILIENCIA_TASAS_CAMBIO.md).
- `FIN-13` **Límites de Fechas y Blindaje de Tasas Históricas (BCV / Paralelo):** Límite del selector a partir del 3 de enero de 2023 (`AppConstants.fechaMinimaHistoricoTasas`), fallback editable sin red en tasas históricas, sugerencia de tasa BCV para USDT antes de feb 2026, y ajuste visual en `DailyEvolutionCard` suprimiendo `d30` en meses de 31 días (CI build 524, DOC_LIMITES_FECHAS_TASAS_HISTORICAS.md).

---

## Fase 7.1: Auditoría Integral y Blindaje para Google Play
*Blindaje técnico de 10 puntos para publicación segura:*
- **Confirmación Humana en Chat IA (H-05, GP-05):** Eliminada la inserción silenciosa directa en base de datos; tarjeta estructurada con botón de confirmación humana en `ReviewExpenseScreen`.
- **Sincronización y Vinculación Segura (SEC-02):** Vaciado de datos locales secuencial tras confirmar éxito en Firestore.
- **Tasa Dinámica en Galería de Comprobantes (TEC-02):** Formateo determinista mediante `CurrencyFormatter.formatPreferido`.
- **Depuración de Permisos en Android (GP-04, GP-06):** Eliminado permiso `READ_MEDIA_IMAGES` (reemplazado por Photo Picker nativo) y notificaciones `inexactAllowWhileIdle`.
- **Canal Oficial de Actualizaciones (TEC-03):** Enrutamiento exclusivo a Google Play Store (`market://`).
- **Gráfico de Funciones para Play Store:** Actualizado con propuesta de valor (*Local-First y Privado*, *Tasas BCV en Vivo*, *Escaneo con IA*).
- **Integridad Multimoneda y Datos (FIN-04, FIN-05, FIN-06, TEC-06):** Soporte EUR/USDT en colas de escaneo e historial; persistencia de tasa Euro BCV; consolidación perezosa de presupuesto en SQLite; UUIDs criptográficamente seguros.
- **Blindaje de Sesión y Eliminación Segura (SEC-03, SEC-04, SEC-06):** Reautenticación por contraseña ante `requires-recent-login`; purga de llaves de API en `FlutterSecureStorage` al cerrar sesión.
- **Rendimiento y Accesibilidad UI (UX-01, UX-04, TEC-03, TEC-04):** Contraste dinámico en donas según luminancia; borde de foco visible en `AppColors.primaryDark`; verificación asíncrona de archivos sin jank.
- **Cumplimiento de Google Play (GP-07, GP-08):** Capturas anonimizadas y `targetSdk = 36` fijado en Gradle.

---

## Fase 7: Arquitectura de Producción, Confiabilidad y DevOps
- **Motor de Sincronización Real (Sync Engine):** UUIDs locales deterministas, marcas de tiempo (`created_at`, `updated_at`, `deleted_at`) y resolución de conflictos.
- **Precisión Financiera Determinística:** Almacenamiento de dinero en enteros (centavos / minor units). Separación estricta de Monto Original y Monto Convertido auditando fuente y fecha de tasa.
- **Seguridad y Separación de Capas:** Aislamiento de capas en `GastoRepository`, `SyncService` y gestores de estado desacoplados.
- **Sistema Híbrido de Percepción:** Google Document Scanner (auto-recorte) con fallback a cámara; ML Kit Text Recognition v2 Bundled con ordenamiento espacial local e interpretación semántica en Cloudflare Worker. Indexación en SQLite `gastos_fts` (FTS5).
- **UX en Lote y Privacidad:** Revisión secuencial de facturas listas, eliminación total de cuenta y datos locales, y políticas sobre fotos locales vs nube.
- **Gateway Serverless en Cloudflare Workers y Distribución Automática de APK:** Desacoplamiento de proxy de IA a Cloudflare Workers con verificación nativa de Firebase JWT, Rate Limiting y secretos cifrados.
- **Testing y CI Estricto:** Versionamiento estricto de `android/` en git, suite de tests unitarios y de sincronización requerida antes de despliegue.
- `OPS-02` **Desacoplamiento de Pipelines CI/CD Web y Móvil:** Separación formal de flujos en `.github/workflows/deploy_web.yml` (~45–60 s) con caché npm y preservación de `version.json`, excluyendo rutas web de `build_apk.yml` vía `paths-ignore`.
- `OPS-03` **Entorno Paralelo de Pruebas (Rinde Más Dev) y Aislamiento de Producción:** Compilación del artefacto privado `rindemas-dev-apk` (`com.cesarluis.rindemas.dev`) firmado con `rindemas.jks` para pruebas en dispositivo físico en simultáneo con la versión de Google Play sin afectar la prueba cerrada de 14 días.

---

## Fase 8.1: Modernización y Paridad del Panel Web
- **Fase 1, 2 y 3 (Web): Presupuestos, Semáforo y Multimoneda:** Paridad con la app móvil en `landing/src/pages/panel.astro` integrando modal de presupuesto general con meta de ahorro, cálculo del medidor de tanque, semáforo de batería y switch de 4 lentes en vivo (`USD BCV`, `VES Bolívares`, `USDT P2P`, `EUR BCV`).
- **Fase 4 (Web): Autenticación con Correo y Contraseña:** Inicio de sesión, creación de cuenta y restablecimiento de contraseña vía Firebase Auth en navegador (`signInWithEmailAndPassword`, `createUserWithEmailAndPassword`, `sendPasswordResetEmail`), permitiendo acceso completo al panel web (Web Build 8).

---

## Auditoría Argon y Calidad de Sincronización
*Detallado en `DOC_AUDITORIA_FASE_3.md` y `docs/auditoria_integral_argon.md`:*
- `FIN-07`: Cálculo exacto de días y proyección en meses históricos basándose en la fecha seleccionada.
- `FIN-08`: Validación de montos estrictamente positivos (`> 0`) en formularios y desglose de ítems.
- `UX-03`: Búsqueda global a lo largo de todo el historial financiero (cross-month).
- `UX-05`: Navegación unificada del Asistente IA (`Navigator.push`) manteniendo barra inferior visible.
- `SEC-12`: Versionado formal del Cloudflare Worker en la carpeta `workers/` del repositorio.
- `OCR-01`: Deduplicación SHA-256 nativa en cola de escaneo para evitar duplicar comprobantes.
- `AI-01`: 5 chips analíticos diferenciados sin acciones destructivas, inyección de `tasa_usdt` en contexto y saludo guiado.
- `LOTE-03` **Integridad de Sincronización Cloud/Offline, Privacidad Local y Resiliencia SQLite:** Serialización pura con `GastoFirestoreMapper`, reemplazo atómico en una sola transacción SQLite, cerrojo de conflicto "Borrado Gana", bloqueo durable en `SharedPreferences` con reintento guiado, token monótono de tasas en revisión y diálogo de borrado seguro de fotos en `MoreScreen`.
- `LOTE-04` **Resiliencia UI en Bolívares (360dp), Rendimiento en Historial y Escáner:** Protección en filas de montos con `FittedBox(fit: BoxFit.scaleDown)` contra desbordes de pantalla en cifras millonarias en bolívares, virtualización de lista en `ExpenseHistoryScreen`, integración de `DocumentScannerService` con recorte inteligente y unificación de evaluación OCR.
