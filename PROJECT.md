# Project: Control de Gastos VE ("Rinde Más")

## Arquitectura General
- **Framework:** Flutter (Dart) con soporte para Android (compilación en GitHub Actions).
- **Gestión de Estado:** Patrón Provider reactivo dividido por dominios (`GastoProvider`, `BudgetProvider`, `ScanQueueProvider`, `ShoppingListProvider`, `AuthProvider`, `SettingsProvider`).
- **Persistencia Local:** SQLite (`sqflite`) para funcionamiento offline prioritario con esquemas relacionales e integridad transaccional.
- **Backend & Cloud:** Firebase Authentication (anónimo y Google Sign-In), Cloud Firestore (sincronización y backup), Cloud Functions (orquestación segura de Gemini con Function Calling).
- **Inteligencia Artificial:** Google Gemini API multimodal para extracción OCR de facturas y razonamiento financiero conversacional. Opera bajo Tier 1 (Pay-as-you-go Prepago en Google AI Studio, 4.000 RPM / 150.000 RPD) orquestado vía Cloudflare Gateway con exclusividad en modelos ligeros Flash-Lite (`gemini-3.1-flash-lite` y `gemini-3.5-flash-lite`).
- **Presencia Web:** Landing page en Astro + Tailwind CSS alojada en Firebase Hosting (`rindemas.cesarluis.com`).
- **Repositorio y CI/CD:** Repositorio privado en GitHub (`cesarluisweb/gastoscan-ai`). Flujo de integración continua para compilación de Android (`.aab` y `.apk`), pruebas unitarias/widgets y despliegue del panel web en Firebase Hosting.

---

## Módulos y Funcionalidades Principales

| Módulo | Descripción | Estado |
|---|---|---|
| **Digitalización OCR** | Escaneo desde cámara o galería de facturas y comprobantes digitales (Pago Móvil, transferencias). Cola en segundo plano individual o múltiple con barra flotante global de progreso. | ✅ Activo |
| **Bimoneda & Tasa BCV** | Consulta en vivo de la tasa oficial del BCV. Conversión y visualización simultánea en USD y Bolívares sin descalces contables. | ✅ Activo |
| **Presupuestos Mensuales** | Presupuesto general y por categorías con aislamiento mensual por año/mes, semáforo visual de consumo (verde, ámbar, rojo) y copia automática de meses previos. | ✅ Activo |
| **Asistente Financiero IA** | Chat integrado con acceso a balances y gastos. Soporta *Function Calling* para modificar la lista de compras, registrar transacciones y responder con 5 preguntas predeterminadas rápidas. | ✅ Activo |
| **Lista de Compras** | Checklist interactivo con sincronización local y capacidad de ser gestionado manualmente o mediante comandos de voz/texto con la IA. | ✅ Activo |
| **Historial y Búsqueda** | Listado cronológico agrupado por fechas ("Hoy", "Ayer", etc.) con buscador en tiempo real por comercio o nombre de producto. | ✅ Activo |
| **Sincronización y Respaldo** | Vinculación opcional con cuenta de Google y respaldo en Cloud Firestore sin perder la operatividad local. | ✅ Activo |
| **Exportación** | Exportador de reportes mensuales en formatos CSV y Markdown para análisis externo. | ✅ Activo |

---

## Navegación de la Aplicación

La navegación principal (`MainScreen`) se basa en un patrón ergonómico de 4 pestañas y un botón de acción principal central:

1. **Inicio (`HomeScreen`):** Hero card de gasto mensual, saldo del presupuesto, botón de consulta con IA, pie chart resumido y últimos 5 gastos.
2. **Gastos (`ExpensesScreen`):** Historial completo agrupado cronológicamente con buscador en vivo por comercio/producto.
3. **[+] (Botón Flotante Central):** Menú rápido para escanear con cámara, subir desde galería (lote), dictar por voz o registrar manualmente.
4. **Análisis (`AnalysisScreen`):** Control detallado de presupuestos por categoría, gráfico interactivo de distribución y límites de gasto.
5. **Más (`MoreScreen`):** Acceso a Lista de Compras, Asistente IA, configuración de tasa BCV, respaldo con Google, exportación y preferencias.

---

## Estructura de Directorios

- `lib/core/`: Constantes de diseño (`AppColors`), constantes del sistema (`AppConstants`), tema y formateadores.
- `lib/data/datasources/`: SQLite local (`DatabaseHelper`), servicios remotos (BCV, Firebase, Gemini).
- `lib/data/models/`: Modelos de dominio (`GastoModel`, `ItemGastoModel`, `BudgetModel`, `ShoppingItemModel`).
- `lib/data/repositories/`: Capa de abstracción de datos para gastos y presupuestos.
- `lib/providers/`: Gestores de estado reactivo (`Provider`).
- `lib/services/`: Exportación, notificaciones locales y compresión de imágenes.
- `lib/ui/screens/`: Pantallas de la aplicación.
- `lib/ui/widgets/`: Componentes reutilizables (tarjetas, gráficos, banners).
- `landing/`: Proyecto web estático en Astro.
- `.github/workflows/`: Pipeline de CI/CD para compilación de APK y suite de pruebas.
- `test/`: Pruebas unitarias, de widgets y fakes de arquitectura.

---

## Directrices Estratégicas y Filosofía de Producto

1. **Impacto de Negocio sobre Complejidad Técnica:** Cada funcionalidad implementada debe tener un retorno directo en retención o conversión. Descartar cualquier sobre-ingeniería que no resuelva un dolor validado por los usuarios (principio de simplicidad operativa).
2. **Los Datos son el Producto:** El activo central del sistema es la precisión y calidad de la información extraída de los comprobantes (precios normalizados, productos, alícuotas de IVA y conversión cambiaria determinista).
3. **Casos Borde (Edge Cases):** La ventaja competitiva real reside en resolver las anomalías complejas de las facturas locales (impresión térmica tenue, monedas cruzadas VES/USD, comercios sin formato estándar).
4. **Despliegue Dinámico (Remote Config):** Arquitectura preparada para modificar cuotas, textos de paywall y parámetros de IA desde la nube sin depender de revisiones demoradas en tiendas de aplicaciones.
5. **Infraestructura como Activo Permanente:** Los módulos centrales (autenticación anónima/Google, base de datos SQLite con migraciones, cola offline resiliente, orquestación de Gemini y sincronización en Firestore) se diseñan como piezas desacopladas y reutilizables para futuros productos del mismo ecosistema financiero.

## Monetización y Políticas de Plataforma
- **Cuotas de IA, Subvención Cruzada y Prevención del Anti-patrón Rial:** Prohibido estrangular el escaneo con cuotas mensuales artificialmente bajas (ej. 10 a 15 facturas al mes) en la etapa de lanzamiento. La experiencia local de competidores (caso Rial) demostró que bloquear o limitar tempranamente el escaneo básico genera rechazo y abandono masivo. El escaneo con cámara opera de forma abierta y generosa para el uso cotidiano, protegido exclusivamente por el cerrojo de seguridad anti-abuso de 50 peticiones/día por UID en Cloudflare Gateway (`SEC-13`). El registro manual y el dictado por voz son siempre 100% ilimitados y gratuitos. Con una conversión estimada del 1% al plan Pro ($1,99/mes), el costo de API de 1.000 usuarios queda cubierto.
- **Publicidad en Tiempos de Espera (Better Ads Standards):** Los anuncios se muestran exclusivamente en puntos de transición naturales (ej. tras guardar exitosamente una factura o durante la pantalla de análisis). Prohibido disparar anuncios al abrir la app o interrumpiendo la captura de fotos.
- **Cumplimiento de Google Play Billing:** Toda compra digital o suscripción ofrecida dentro de la app Android distribuida en Play Store debe procesarse obligatoriamente mediante Google Play Billing para evitar sanciones o suspensión de cuenta.

## Mejoras de Infraestructura Futuras
- **Desacoplamiento de Workflows en GitHub Actions:** Separar el pipeline de compilación de Android (`build_apk.yml`) del despliegue de la web (`landing/`), de modo que cambios exclusivos en la web no disparen la compilación de APK ni consuman cuota de CI móvil.
  *Advertencia crítica:* El archivo `version.json` con el número de compilación dinámico lo genera el flujo del APK y se publica en Firebase Hosting. Un flujo web independiente no debe subir el `landing/public/version.json` estático del repositorio (que tiene números de compilación desactualizados), sino descargar o preservar el `version.json` activo en producción antes de compilar y desplegar la landing para no alterar el aviso de actualización de la app móvil.

---

## 📌 Documentación Externa en Obsidian
Existe una ficha técnica extendida y mapa de componentes en la bóveda de Obsidian en:
`H:\My Drive\Documentos\Notas\Trabajo\Rinde Más - Control de Gastos.md`
*(Nota: Sirve como documento de referencia y consulta conceptual; no requiere actualización continua obligatoria en cada tarea).*


