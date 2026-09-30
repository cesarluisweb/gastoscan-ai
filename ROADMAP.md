# Roadmap y Fases de Desarrollo: Rinde Más

Este documento centraliza las ideas y mejoras pendientes, ordenadas estratégicamente por prioridad, impacto de valor (especialmente B2C) y viabilidad técnica.

## Fase 1: Correcciones Críticas (Completada ✅)
*Estas tareas eran de bajo esfuerzo pero indispensables.*
- Edición de gastos guardados.
- Exportar por mes.
- Precio unitario editable.

## Fase 2: Usabilidad y Diseño (Completada ✅)
*Mejoras para retener al usuario común.*
- **Rediseño a "Rinde Más":** Tema claro estilo billetera digital (amarillo/blanco), Bottom Navigation Bar y botón central flotante (FAB) para agregar gastos (Escáner o Manual).
- **Lista de Compras Inteligente:** Check-list que se tacha automáticamente al escanear facturas.
- **Empty state y confirmaciones.**

## Fase 3: Infraestructura SaaS y Asistente IA (Completada ✅)
*Las funciones clave para retener usuarios.*
- **Registro de Usuarios y Autenticación:** Inicio de sesión silencioso (Anónimo) al abrir, y opción de vinculación con cuenta de Google.
- **Sincronización en la Nube:** Base de datos respaldada en Firestore.
- **Analista Financiero IA (Chatbot Básico):** Chat que analiza tus gastos mensuales.

## Fase 4: Asistente IA Proactivo y UX Avanzada (Completada ✅)
*Darle superpoderes a la app.*
- **Ingreso de gastos conversacional (Function Calling):** Gemini puede interpretar un texto o audio y ejecutar comandos en la base de datos para guardar gastos manualmente.
- **Cola Offline de Escaneo:** Si no hay internet, la factura se guarda en cola y se procesa sola cuando vuelve la conexión, notificando al usuario.

## Fase 5: Marketing y Lanzamiento (En Progreso 🔄)
*El paso para empezar a captar usuarios reales en Venezuela.*
- ~~**Landing Page (rindemas.cesarluis.com):** (Completada ✅)~~ Creada en Astro + Tailwind y desplegada en Firebase Hosting con mockup de smartphone, propuesta de valor y guía de instalación directa de APK.
- **Plan de Crecimiento Inicial (100 Usuarios):** (Documentado ✅) Playbook táctico definido en `marketing_plan.md` y `.agents/skills/growth-first-100-users/SKILL.md`.
- **Subida de APK / Google Play Console:** (En preparación 🔄) Pago de cuenta de desarrollador ($25), configuración de Keystore y reclutamiento de 20 testers por 14 días.
- **Correo de bienvenida automatizado:** Disparar un correo de bienvenida y primeros pasos cuando el usuario vincule su cuenta de Google (mediante Cloud Functions / trigger de autenticación o Firestore).
- **Canal directo de soporte y contacto en "Más":** Agregar sección inferior en la pantalla *Más* con botón de "Escribir a soporte" para contactar directamente por correo electrónico o WhatsApp.

## Fase 6: Pulido, Navegación y UX Avanzada (Completada ✅)
*Funciones complementarias para usuarios recurrentes.*
- **Subida múltiple de facturas (Batch Upload):** Seleccionar varias fotos a la vez y procesarlas en cola.
- **Búsqueda de gastos:** Filtrar en tiempo real por comercio o producto.
- **Presupuestos bimonetarios y por categoría:** Límites mensuales en USD o VES con aislamiento por mes y alerta semáforo.
- **Recordatorios locales:** Notificaciones push programadas por inactividad.
- **Navegación fluida de 4 destinos:** Transiciones sutiles (Inicio, Gastos, Análisis, Más) y barra flotante global de escaneo.
- **Asistente IA con Gestión de Compras y Frases:** Chat con Function Calling para modificar lista de compras, desambiguación obligatoria y 5 botones de consultas frecuentes.

## Fase 7: Arquitectura de Producción y Confiabilidad (En Progreso 🔄)
*Transformar el excelente MVP actual en un producto de grado financiero ("Bank-grade").*
- ~~**Motor de Sincronización Real (Sync Engine):** (Completada ✅)~~ Abandonar `synced = 0/1`. Implementar UUIDs locales, marcas de tiempo (`created_at`, `updated_at`, `deleted_at` para borrado lógico/tombstones) y control de versiones para resolver conflictos entre dispositivos.
- ~~**Precisión Financiera Determinística:** (Completada ✅)~~ Cambiar almacenamiento de dinero de coma flotante (`double`) a números enteros (centavos/minor units). Separar estrictamente el "Monto Original" del "Monto Convertido" auditando la fuente y fecha de la tasa de cambio. **Regla de oro: La IA interpreta, el código calcula.**
- ~~**Seguridad y Separación de Capas (Repository / SyncService):** (Completada ✅)~~ Blindar las Cloud Functions con Firebase App Check. Separar el mastodóntico `GastoProvider` en `Repository`, `SyncService` y gestores de estado más limpios (arquitectura por features).
- **Evaluación de Firebase AI Logic (`firebase_vertexai`):** Evaluar migración de llamadas REST directas al SDK de Firebase Vertex AI en Flutter (`firebase_vertexai`), integrando Firebase App Check (protección de cuotas) y Remote Config (actualización dinámica de prompts y modelos sin publicar APK).
- **Procesamiento Background Nativo:** Migrar la cola local en Dart a un Background Worker real del sistema operativo (Firebase Cloud Tasks / WorkManager) para asegurar subidas e IA incluso con la app cerrada.
- **Extracción Asistida por Confianza (Confidence Scores):** Gemini debe devolver qué tan seguro está de un dato extraído. La UI alertará "⚠️ Revisar" si la confianza es baja. Implementar un "Diccionario Personal" local para que la app aprenda de las correcciones del usuario sin reentrenar IA.
- ~~**UX en Lote y Privacidad:** (Completada ✅)~~ Pantalla de "3 facturas listas para revisar" en vez de forzar revisión individual inmediata. Incorporar eliminación total de cuenta/datos y políticas claras sobre fotos locales vs nube.
- ~~**Testing y CI Estricto:** Eliminar la regeneración de la carpeta `android` (`flutter create .`) del pipeline CI/CD en favor de versionamiento estricto. Requisito de Unit Tests y Sync Tests antes de nuevas integraciones.~~

## Fase 8: Ecosistema Web y Red Colaborativa (Visión a Largo Plazo)
*El salto de app personal a plataforma comunitaria.*
- **Versión Web (Dashboard de Escritorio):** Compilar el proyecto Flutter a web para ver estadísticas globales y subir facturas cómodamente.
- **Crowdsourcing de Precios (El Waze de las compras):** Base de datos global alimentada anónimamente por los escaneos de los usuarios.
- **Comparativa por Unidad de Medida:** Comparar precios de forma inteligente (ej. Arroz $2.00/kg vs $1.60/kg) en lugar del precio total bruto.
- **Buscador de Ofertas Locales:** Ver en qué comercio cercano se escaneó más barato un producto específico en las últimas 48 horas.
- **Historial de Tasas BCV:** Gráfico interactivo para ver la evolución de la tasa de cambio a lo largo del tiempo.

## Fase 9: Modelo de Monetización y Suscripción Premium (Rinde Más Pro)
*Monetización combinada (Freemium + suscripción o pago único) sin bloquear el registro básico de gastos.*
- **Categorías Personalizadas Ilimitadas:** Posibilidad de crear, editar y archivar categorías propias con selección de icono y color representativo (el plan gratuito mantiene las 10 categorías base).
- **Experiencia Cero Publicidad (Zero Ads):** Supresión total de anuncios promocionales en toda la interfaz.
- **Exportación Contable Avanzada:**
  - Generación de reportes mensuales en PDF con diseño limpio, gráficos de distribución y balance listos para imprimir o compartir.
  - Exportación en formato Excel/CSV detallado con el desglose ítem por ítem para contabilidad personal o pequeños negocios.
- **Cuotas de IA y OCR Extendidas:**
  - Procesamiento ilimitado de comprobantes mediante OCR con Gemini (el plan base conservará un cupo mensual suficiente para uso personal regular).
  - Consultas profundas al Analista Financiero IA con comparativas de meses previos y proyecciones de gasto.
- **Alertas Proactivas de Inflación y Desvío:** Notificaciones inteligentes cuando un producto frecuente incremente su precio por encima del promedio o cuando el ritmo de gasto proyecte superar el presupuesto antes de fin de mes.
