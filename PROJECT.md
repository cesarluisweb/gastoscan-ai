# Project: Control de Gastos VE ("Rinde Más")

## Arquitectura General
- **Framework:** Flutter (Dart) con soporte para Android (compilación en GitHub Actions).
- **Gestión de Estado:** Patrón Provider reactivo dividido por dominios (`GastoProvider`, `BudgetProvider`, `ScanQueueProvider`, `ShoppingListProvider`, `AuthProvider`, `SettingsProvider`).
- **Persistencia Local:** SQLite (`sqflite`) para funcionamiento offline prioritario con esquemas relacionales e integridad transaccional.
- **Backend & Cloud:** Firebase Authentication (anónimo y Google Sign-In), Cloud Firestore (sincronización y backup), Cloud Functions (orquestación segura de Gemini con Function Calling).
- **Inteligencia Artificial:** Google Gemini API multimodal para extracción OCR de facturas y razonamiento financiero conversacional.
- **Presencia Web:** Landing page en Astro + Tailwind CSS alojada en Firebase Hosting (`rindemas.cesarluis.com`).

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
