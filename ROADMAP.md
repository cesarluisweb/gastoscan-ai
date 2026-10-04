# Roadmap y Fases de Desarrollo: Rinde Más

Este documento centraliza las ideas y mejoras pendientes, ordenadas estratégicamente por prioridad, impacto de valor (especialmente B2C) y viabilidad técnica.

## Principios de Ejecución y Entrega de Valor (Metodología de Validación Rápida)
1. **Impacto de Negocio sobre Complejidad Técnica:** Priorizar funciones con alto impacto comercial y retención sobre desarrollos técnicamente complejos pero poco valorados por el usuario.
2. **MVP Estricto:** Descartar funcionalidades que no resuelvan la necesidad central validada de los usuarios (cero conciliaciones complejas ni múltiples cuentas bancarias).
3. **Los Datos son el Producto:** La captura precisa, normalización y cálculo exacto de datos de compras (precios, productos, IVA, tasa BCV) es la pieza más crítica del sistema.
4. **Monetizar es un Producto Independiente:** La monetización requiere su propio diseño de experiencia, embudo de conversión y optimización continua; no se reduce a poner un botón de pago.
5. **Fracasa Rápido, Ajusta Barato:** Validar hipótesis rápido, medir con analíticas y descartar o pivotar sin apego emocional.
6. **Infraestructura como Activo Reutilizable:** Diseñar módulos desacoplados para que sirvan de base para futuras aplicaciones del mismo ecosistema financiero.


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
- ~~**Cola Offline de Escaneo y UX Unificada:** (Completada ✅)~~ Persistencia temprana local (SQLite), banner global reactivo único sin duplicidad visual, mensajes empáticos ("Guardada sin conexión" en lugar de errores falsos de servidor), auto-reanudación transparente mediante `connectivity_plus` y observador del ciclo de vida de la app (`AppLifecycleState.resumed`).

## Fase 5: Marketing y Lanzamiento (En Progreso 🔄)
*El paso para empezar a captar usuarios reales en Venezuela.*
- ~~**Landing Page (rindemas.cesarluis.com):** (Completada ✅)~~ Creada en Astro + Tailwind y desplegada en Firebase Hosting con mockup de smartphone, propuesta de valor y guía de instalación directa de APK.
- **Plan de Crecimiento Inicial (100 Usuarios):** (Documentado ✅) Playbook táctico definido en `marketing_plan.md` y `.agents/skills/growth-first-100-users/SKILL.md`.
- **Subida de APK / Google Play Console:** (En preparación 🔄) Pago de cuenta de desarrollador ($25), configuración de Keystore y reclutamiento de 20 testers por 14 días.
- **Correo de bienvenida automatizado:** Disparar un correo de bienvenida y primeros pasos cuando el usuario vincule su cuenta de Google (mediante Cloud Functions / trigger de autenticación o Firestore).
- ~~**Canal directo de soporte y contacto en "Más":** (Completada ✅)~~ Tarjeta con acción "Escribir a soporte" para abrir chat directo por WhatsApp al número de soporte oficial.
  - *Nota futura:* Evaluar la transición del canal de soporte a una dirección de correo electrónico dedicada en lugar de WhatsApp a medida que crezca el volumen de usuarios o para mayor formalidad.

## Fase 6: Pulido, Navegación y UX Avanzada (Completada ✅)
*Funciones complementarias para usuarios recurrentes.*
- **Subida múltiple de facturas (Batch Upload):** Seleccionar varias fotos a la vez y procesarlas en cola.
- **Búsqueda de gastos:** Filtrar en tiempo real por comercio o producto.
- **Presupuestos bimonetarios y por categoría:** Límites mensuales en USD o VES con aislamiento por mes y alerta semáforo.
- ~~**Recordatorios locales y auditoría de notificaciones:** (Completada ✅)~~ Notificaciones push sobrias a 7 días, soporte cold start/deep-link a facturas listas, feedback háptico sin solapamiento con AppBar y control en Ajustes.
- **Navegación fluida de 4 destinos:** Transiciones sutiles (Inicio, Gastos, Análisis, Más) y barra flotante global de escaneo.
- **Asistente IA con Gestión de Compras y Frases:** Chat con Function Calling para modificar lista de compras, desambiguación obligatoria y 5 botones de consultas frecuentes.

## Fase 6.1: Mejoras Derivadas de Feedback de Comunidad (En Progreso 🔄)
*Optimizaciones directas sugeridas por los primeros evaluadores y desarrolladores:*
- ~~**Estado de Facturas Pendientes en UI:** (Completada ✅)~~ Ocultar el monto o mostrar badge "Por revisar" en vez de "$ 0.00" mientras la factura está en cola o en proceso de escaneo.
- ~~**Detección de IVA y Alícuotas Fiscales en OCR:** (Completada ✅)~~ Incorporar en el prompt de extracción de Cloud Functions la detección de marcadores fiscales venezolanos (`(E)` Exento, `(G)` Gravado, alícuota 16%) para desglosar el impuesto con precisión legal por ítem.
- ~~**Meta Mensual de Ahorro / Inversión y Proyección de Gastos:** (Completada ✅)~~ Configuración de meta mensual de ahorro/inversión en el presupuesto, cálculo de límite para gastar (`Presupuesto - Meta`), validación de categorías, motor de proyección determinista (`SavingsHealthCalculator`), estado semafórico (Protegida, En riesgo, Comprometida) y alertas inteligentes en Inicio y Chat.
- **Tasa y Moneda Personalizada / Paralela:** Permitir ingresar una tasa de cambio manual o consultar USDT (Binance P2P) para usuarios que operan fuera de la tasa oficial del Banco Central.
  - *Recurso útil para histórico de precios USDT:* [usdt.com.ve/historico](https://www.usdt.com.ve/historico) (referencia para consulta/histórico de tasas).
- ~~**Monitoreo de Consumo de Tokens:** (Completada ✅)~~ Capturar la metadata de tokens consumidos devuelta por Gemini en Cloud Functions y registrar métricas de costo por escaneo.

## Fase 7: Arquitectura de Producción y Confiabilidad (En Progreso 🔄)
*Transformar el excelente MVP actual en un producto de grado financiero ("Bank-grade").*
- ~~**Motor de Sincronización Real (Sync Engine):** (Completada ✅)~~ Abandonar `synced = 0/1`. Implementar UUIDs locales, marcas de tiempo (`created_at`, `updated_at`, `deleted_at` para borrado lógico/tombstones) y control de versiones para resolver conflictos entre dispositivos.
- ~~**Precisión Financiera Determinística:** (Completada ✅)~~ Cambiar almacenamiento de dinero de coma flotante (`double`) a números enteros (centavos/minor units). Separar estrictamente el "Monto Original" del "Monto Convertido" auditando la fuente y fecha de la tasa de cambio. **Regla de oro: La IA interpreta, el código calcula.**
- ~~**Seguridad y Separación de Capas (Repository / SyncService):** (Completada ✅)~~ Blindar las Cloud Functions con Firebase App Check. Separar el mastodóntico `GastoProvider` en `Repository`, `SyncService` y gestores de estado más limpios (arquitectura por features).
- ~~**Sistema Híbrido de Document Scanner, OCR Local y Búsqueda FTS5:** (Completada ✅)~~ Separación de percepción determinista local (Google Document Scanner con auto-recorte y fallback a cámara estándar, ML Kit Text Recognition v2 Bundled con ordenamiento espacial) e interpretación semántica en la nube (Gemini Texto con fallback a Gemini Visión ante baja calidad o discrepancia). Persistencia temprana de imagen y texto en SQLite (`scan_queue`) e indexación no intrusiva en `gastos_fts` (FTS5) con fallback a `LIKE`.
- **Evaluación de Firebase AI Logic (`firebase_vertexai`):** Evaluar migración de llamadas REST directas al SDK de Firebase Vertex AI en Flutter (`firebase_vertexai`), integrando Firebase App Check (protección de cuotas) y Remote Config (actualización dinámica de prompts y modelos sin publicar APK).
- **Despliegue Dinámico y Configuración Remota (Firebase Remote Config):** Configurar dinámicamente desde el servidor las cuotas mensuales de IA, textos del paywall, precios y parámetros de modelos sin requerir nueva compilación ni aprobación en Google Play.
- **Manejo de Casos Borde en Facturas Locales (Corner Cases):** El 90% del esfuerzo de refinamiento en IA se enfoca en resolver excepciones venezolanas (facturas térmicas dobladas o borrosas, comprobantes mixtos con ítems en Bs y total en USD/"Ref", y marcadores de IVA exento/gravado).
- **Procesamiento Background Nativo:** Migrar la cola local en Dart a un Background Worker real del sistema operativo (Firebase Cloud Tasks / WorkManager) para asegurar subidas e IA incluso con la app cerrada.
- **Extracción Asistida por Confianza (Confidence Scores):** Gemini debe devolver qué tan seguro está de un dato extraído. La UI alertará "⚠️ Revisar" si la confianza es baja. Implementar un "Diccionario Personal" local para que la app aprenda de las correcciones del usuario sin reentrenar IA.
- ~~**UX en Lote y Privacidad:** (Completada ✅)~~ Pantalla de "3 facturas listas para revisar" en vez de forzar revisión individual inmediata. Incorporar eliminación total de cuenta/datos y políticas claras sobre fotos locales vs nube.
- ~~**Gateway Serverless en Cloudflare Workers y Distribución Automática de APK:** (Completada ✅)~~ Desacoplamiento del proxy de IA a Cloudflare Workers con validación nativa de Firebase JWT, Rate Limiting y secretos cifrados. Distribución automatizada de APK a BanaHosting vía FTP para descargas directas sin 404 ni restricciones de cuota Spark.
- ~~**Testing y CI Estricto:** Eliminar la regeneración de la carpeta `android` (`flutter create .`) del pipeline CI/CD en favor de versionamiento estricto. Requisito de Unit Tests y Sync Tests antes de nuevas integraciones.~~

## Fase 8: Ecosistema Web y Red Colaborativa (Visión a Largo Plazo)
*El salto de app personal a plataforma comunitaria y reutilización de infraestructura.*
- **Versión Web (Dashboard de Escritorio):** Compilar el proyecto Flutter a web para ver estadísticas globales y subir facturas cómodamente.
- **Crowdsourcing de Precios (El Waze de las compras):** Base de datos global alimentada anónimamente por los escaneos de los usuarios.
- **Comparativa por Unidad de Medida:** Comparar precios de forma inteligente (ej. Arroz $2.00/kg vs $1.60/kg) en lugar del precio total bruto.
- **Buscador de Ofertas Locales:** Ver en qué comercio cercano se escaneó más barato un producto específico en las últimas 48 horas.
- **Historial de Tasas BCV:** Gráfico interactivo para ver la evolución de la tasa de cambio a lo largo del tiempo.
- **Cross-Selling de Ecosistema:** Reutilizar la infraestructura base (Auth, Sync, SQLite, IA OCR y Facturación) para lanzar rápidamente productos complementarios sin empezar de cero.

## Fase 9: Modelo de Monetización y Suscripción Premium (Rinde Más Pro)
*Monetizar es un producto independiente: experiencia de pago, embudo de conversión y subvención cruzada.*
- **Cuota Gratuita Base:** 15 a 20 facturas escaneadas por cámara al mes (registro manual y dictado por voz siempre 100% ilimitado).
- **Publicidad en Transiciones Naturales:** Anuncios discretos tras guardar gastos para cubrir el costo de tokens de Gemini de los usuarios gratuitos, respetando Better Ads Standards.
- **Rinde Más Pro ($1,99/mes o $19,99/año):**
  - **Cuotas de IA y OCR Ilimitadas:** Procesamiento ilimitado de comprobantes físicos para uso intensivo o pequeños negocios.
  - **Experiencia Cero Publicidad (Zero Ads):** Supresión total de anuncios promocionales en toda la interfaz.
  - **Categorías Personalizadas Ilimitadas:** Posibilidad de crear, editar y archivar categorías propias con selección de icono y color representativo (el plan gratuito mantiene las 10 categorías base).
  - **Exportación Contable Avanzada:**
    - Generación de reportes mensuales en PDF con diseño limpio, gráficos de distribución y balance listos para imprimir o compartir.
    - Exportación en formato Excel/CSV detallado con el desglose ítem por ítem para contabilidad personal o negocios.
  - **Consultas Profundas al Asistente IA:** Análisis financiero con comparativas de meses previos y proyecciones de gasto.
- **Optimización del Embudo de Conversión (Funnel):**
  - Medición de fugas en cada paso con Firebase Analytics: Impresión → Ficha → Descarga → Onboarding → Activación (primer escaneo) → Retención → Pago.
  - Paywalls contextuales activados en momentos de alto valor percibido (límite de cuota alcanzado, exportación avanzada).
  - A/B testing de ofertas y pruebas gratuitas (trials).
- **Métrica de Validación Financiera:** Meta de generar los primeros $50 USD en 30-60 días con 500-1.000 usuarios activos (validando la disposición de pago en subperfiles clave).
- **Alertas Proactivas de Inflación y Desvío:** Notificaciones inteligentes cuando un producto frecuente incremente su precio por encima del promedio o cuando el ritmo de gasto proyecte superar el presupuesto antes de fin de mes.

