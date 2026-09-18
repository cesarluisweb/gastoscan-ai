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

## Fase 5: Marketing y Lanzamiento (Pausada ⏸️)
*El paso para empezar a captar usuarios reales.*
- **Subida de APK/Play Store:** Configurar las llaves criptográficas (Keystore) de Android permanentemente en GitHub Actions.
- **Landing Page (rindemas.app):** Crear una página web sencilla orientada a la propuesta de valor y captación.

## Fase 6: Pulido y Control Avanzado (Completada ✅)
*Funciones complementarias para usuarios recurrentes.*
- **Subida múltiple de facturas (Batch Upload):** Seleccionar varias fotos a la vez y procesarlas en cola.
- **Búsqueda de gastos:** Filtrar por comercio, categoría o fecha.
- **Presupuestos por categoría:** Límite máximo en áreas específicas.
- **Recordatorios locales:** Notificaciones push si no se registran gastos.

## Fase 7: Arquitectura de Producción y Confiabilidad (En Progreso 🔄)
*Transformar el excelente MVP actual en un producto de grado financiero ("Bank-grade").*
- **Motor de Sincronización Real (Sync Engine):** Abandonar `synced = 0/1`. Implementar UUIDs locales, marcas de tiempo (`created_at`, `updated_at`, `deleted_at` para borrado lógico/tombstones) y control de versiones para resolver conflictos entre dispositivos.
- **Precisión Financiera Determinística:** Cambiar almacenamiento de dinero de coma flotante (`double`) a números enteros (centavos/minor units). Separar estrictamente el "Monto Original" del "Monto Convertido" auditando la fuente y fecha de la tasa de cambio. **Regla de oro: La IA interpreta, el código calcula.**
- **Seguridad y Separación de Capas:** Blindar las Cloud Functions con Firebase App Check. Separar el mastodóntico `GastoProvider` en `Repository`, `SyncService` y gestores de estado más limpios (arquitectura por features).
- **Procesamiento Background Nativo:** Migrar la cola local en Dart a un Background Worker real del sistema operativo (Firebase Cloud Tasks / WorkManager) para asegurar subidas e IA incluso con la app cerrada.
- **Extracción Asistida por Confianza (Confidence Scores):** Gemini debe devolver qué tan seguro está de un dato extraído. La UI alertará "⚠️ Revisar" si la confianza es baja. Implementar un "Diccionario Personal" local para que la app aprenda de las correcciones del usuario sin reentrenar IA.
- **UX en Lote y Privacidad:** Pantalla de "3 facturas listas para revisar" en vez de forzar revisión individual inmediata. Incorporar eliminación total de cuenta/datos y políticas claras sobre fotos locales vs nube.
- ~~**Testing y CI Estricto:** Eliminar la regeneración de la carpeta `android` (`flutter create .`) del pipeline CI/CD en favor de versionamiento estricto. Requisito de Unit Tests y Sync Tests antes de nuevas integraciones.~~

## Fase 8: Ecosistema Web y Red Colaborativa (Visión a Largo Plazo)
*El salto de app personal a plataforma comunitaria.*
- **Versión Web (Dashboard de Escritorio):** Compilar el proyecto Flutter a web para ver estadísticas globales y subir facturas cómodamente.
- **Crowdsourcing de Precios (El Waze de las compras):** Base de datos global alimentada anónimamente por los escaneos de los usuarios.
- **Comparativa por Unidad de Medida:** Comparar precios de forma inteligente (ej. Arroz $2.00/kg vs $1.60/kg) en lugar del precio total bruto.
- **Buscador de Ofertas Locales:** Ver en qué comercio cercano se escaneó más barato un producto específico en las últimas 48 horas.
- **Historial de Tasas BCV:** Gráfico interactivo para ver la evolución de la tasa de cambio a lo largo del tiempo.
