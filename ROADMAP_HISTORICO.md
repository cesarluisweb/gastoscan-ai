# Histórico de Desarrollo y Hitos Completados: Rinde Más

Este documento recopila el registro histórico y técnico de todas las fases, hitos y optimizaciones completadas en **Rinde Más**. Su propósito es servir de bitácora de ingeniería, consulta técnica para arquitectura y base documental para materiales de marketing y comunicación de producto.

Para consultar las tareas activas, en progreso y la visión futura, dirígete a [ROADMAP.md](ROADMAP.md).

---

## Índice Histórico de Fases Completadas
1. [Fase 1: Correcciones Críticas (MVP Inicial)](#fase-1-correcciones-críticas-mvp-inicial)
2. [Fase 2: Usabilidad, Diseño y Marca](#fase-2-usabilidad-diseño-y-marca)
3. [Fase 3: Infraestructura SaaS y Asistente IA Base](#fase-3-infraestructura-saas-y-asistente-ia-base)
4. [Fase 4: Asistente IA Proactivo y UX Avanzada](#fase-4-asistente-ia-proactivo-y-ux-avanzada)
5. [Fase 6: Pulido, Navegación y Experiencia Recurrente](#fase-6-pulido-navegación-y-experiencia-recurrente)
6. [Fase 6.1: Hitos de Feedback de Comunidad y Resiliencia](#fase-61-hitos-de-feedback-de-comunidad-y-resiliencia)
7. [Fase 7.1: Auditoría Integral y Blindaje para Google Play](#fase-71-auditoría-integral-y-blindaje-para-google-play)
8. [Fase 7 (Completados): Arquitectura de Producción y Confiabilidad](#fase-7-completados-arquitectura-de-producción-y-confiabilidad)
9. [Fase 5 (Completados): Infraestructura de Lanzamiento](#fase-5-completados-infraestructura-de-lanzamiento)

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

## Fase 5 (Completados): Infraestructura de Lanzamiento
- **Landing Page (`https://rindemas.cesarluis.com`):** Desarrollada con Astro + Tailwind CSS, alojada en Firebase Hosting, con diseño responsive, propuesta de valor, captura interactiva de smartphone y guía de instalación.
- **Canal Directo de Soporte:** Integración de tarjeta en la pestaña "Más" con acción directa para abrir chat oficial de asistencia técnica vía WhatsApp.
- **Playbook de Crecimiento Inicial (100 Usuarios):** Estrategia documentada en `marketing_plan.md` y `.agents/skills/growth-first-100-users/SKILL.md`.

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

## Fase 7.1: Auditoría Integral y Blindaje para Google Play
*Blindaje técnico de 10 puntos para publicación segura:*
- **Confirmación Humana en Chat IA (H-05, GP-05):** Eliminada la inserción silenciosa directa en base de datos. Los gastos dictados se presentan como tarjeta estructurada con botón que abre `ReviewExpenseScreen` para validación humana. Incorporado diálogo de reporte de respuestas erróneas.
- **Sincronización y Vinculación Segura (SEC-02):** El vaciado de datos locales en vinculación de cuentas se ejecuta de forma estrictamente secuencial tras confirmar éxito en Firestore, eliminando riesgo de pérdida de datos.
- **Tasa Dinámica en Galería de Comprobantes (TEC-02):** Eliminado el cálculo con tasa fija cableada (`/ 1.08`). Formateo determinista mediante `CurrencyFormatter.formatPreferido`.
- **Depuración de Permisos en Android (GP-04, GP-06):** Eliminado permiso `READ_MEDIA_IMAGES` de `AndroidManifest.xml` (reemplazado por Google Photo Picker y cámara del sistema) y convertidas notificaciones a `inexactAllowWhileIdle` eliminando necesidad de `SCHEDULE_EXACT_ALARM`.
- **Canal Oficial de Actualizaciones (TEC-03):** Eliminada la redirección directa a APKs externos desde el diálogo de nueva versión; enruta exclusivamente a Google Play Store (`market://`).
- **Gráfico de Funciones para Play Store:** Actualizado con propuesta de valor (*Local-First y Privado*, *Tasas BCV en Vivo*, *Escaneo con IA*), eliminando botones falsos de descarga.
- **Integridad Multimoneda y Datos (FIN-04, FIN-05, FIN-06, TEC-06):** Soporte nativo para EUR/USDT en colas de escaneo e historial; persistencia de tasa Euro BCV en `ReviewExpenseScreen`; consolidación perezosa de presupuesto adoptado en SQLite; UUIDs criptográficamente seguros (`Random.secure()`).
- **Blindaje de Sesión y Eliminación Segura (SEC-03, SEC-04, SEC-06):** Reautenticación por contraseña ante `requires-recent-login` en eliminación de cuenta; purga de llaves de API en `FlutterSecureStorage` al cerrar sesión; eliminación de tokens en línea de comandos de CI.
- **Rendimiento y Accesibilidad UI (UX-01, UX-04, TEC-03, TEC-04):** Contraste dinámico en gráfico de dona según luminancia; borde de foco visible en `AppColors.primaryDark`; verificación asíncrona de archivos sin jank; guardas `mounted` tras asincronía.
- **Cumplimiento de Google Play (GP-07, GP-08):** Capturas anonimizadas y `targetSdk = 36` fijado en Gradle cumpliendo requisitos de Play Store.

---

## Fase 7 (Completados): Arquitectura de Producción y Confiabilidad
- **Motor de Sincronización Real (Sync Engine):** UUIDs locales deterministas, marcas de tiempo (`created_at`, `updated_at`, `deleted_at` para borrado lógico/tombstones) y resolución de conflictos.
- **Precisión Financiera Determinística:** Almacenamiento de dinero en enteros (centavos / minor units). Separación estricta de Monto Original y Monto Convertido auditando fuente y fecha de tasa.
- **Seguridad y Separación de Capas:** Aislamiento de capas en `GastoRepository`, `SyncService` y gestores de estado desacoplados.
- **Sistema Híbrido de Percepción:** Google Document Scanner (auto-recorte) con fallback a cámara; ML Kit Text Recognition v2 Bundled con ordenamiento espacial local e interpretación semántica en Cloudflare Worker. Indexación en SQLite `gastos_fts` (FTS5) con fallback a `LIKE`.
- **UX en Lote y Privacidad:** Revisión secuencial de facturas listas, eliminación total de cuenta y datos locales, y políticas transparentes sobre fotos locales vs nube.
- **Gateway Serverless en Cloudflare Workers y Distribución Automática de APK:** Desacoplamiento de proxy de IA a Cloudflare Workers con verificación nativa de Firebase JWT, Rate Limiting y secretos cifrados. Distribución automatizada de APK a BanaHosting vía FTP en CI.
- **Testing y CI Estricto:** Versionamiento estricto de `android/` en git (sin `flutter create .`), suite de tests unitarios y de sincronización requerida antes de despliegue.
