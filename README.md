# Rinde Más 📱🧾

Aplicación móvil Android desarrollada en Flutter para el control de gastos personales y familiares en Venezuela. Permite la digitalización instantánea de facturas físicas y comprobantes digitales (Pago Móvil, transferencias) mediante Inteligencia Artificial multimodal (Google Gemini API), gestión bimonetaria (USD y Bolívares a tasa oficial BCV), presupuestos mensuales aislados, asistente financiero con IA y almacenamiento local SQLite con sincronización opcional en la nube.

Sitio oficial y descarga: [rindemas.cesarluis.com](https://rindemas.cesarluis.com)

---

## ✨ Características Principales

- **Escaneo Inteligente de Facturas con IA:** Extracción de comercio, fecha, ítems, cantidades, precios unitarios y totales desde fotos de tickets físicos o capturas de pantalla de bancos nacionales (Banesco, Mercantil, BDV, etc.).
- **Gestión Bimonetaria (USD y VES):** Actualización automática de la tasa oficial del Banco Central de Venezuela (BCV), permitiendo registrar y presupuestar en dólares o bolívares sin distorsión cambiaria.
- **Presupuestos Mensuales y por Categoría:** Asignación de límites mensuales generales y desglosados con aislamiento por mes, copia automática del mes previo y alertas visuales tipo semáforo (verde, ámbar y rojo).
- **Asistente Financiero Conversacional (IA):** Chat inteligente con herramientas (*Function Calling*) capaz de registrar gastos por voz/texto, consultar balances, analizar consumos por categoría y gestionar la lista de compras con desambiguación automática.
- **Lista de Compras Integrada:** Checklist interactivo que se puede alimentar manualmente o dictar al asistente IA.
- **Cola de Procesamiento en Segundo Plano:** Subida individual o en lote (múltiples fotos) que procesa comprobantes en segundo plano con barra global de estado y acceso inmediato a revisión.
- **Privacidad y Sincronización Flexible:** Base de datos local SQLite con funcionamiento 100% offline. Opción de respaldo en la nube con Google Sign-In y Firebase Firestore.
- **Exportación de Datos:** Generación de reportes detallados en formatos `.csv` y `.md` (Markdown).

---

## 🛠️ Stack Tecnológico

- **Framework:** Flutter (Dart)
- **Base de Datos Local:** SQLite con `sqflite` (relaciones relacionales entre gastos, ítems, compras y presupuestos)
- **Backend y Nube:** Firebase (Authentication, Cloud Firestore, Cloud Functions para Gemini)
- **Motor de IA Multimodal:** Google Gemini API (vía Cloud Functions y API directa)
- **Gestión de Estado:** `provider` (arquitectura reactiva por features)
- **Captura y Compresión:** `image_picker` + `flutter_image_compress`
- **Tasa Cambiaria:** Consumo en vivo de API de tasas oficiales BCV
- **Exportación:** `share_plus`
- **Web / Landing:** Astro + Tailwind CSS alojado en Firebase Hosting

---

## 📁 Estructura del Proyecto

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart          # Paleta oficial (amarillo acento, superficies limpias, textos oscuros)
│   │   └── app_constants.dart       # Categorías, claves y constantes del sistema
│   ├── theme/
│   │   └── app_theme.dart           # Tema Material 3
│   └── utils/
│       ├── currency_formatter.dart  # Formateo USD y Bs.
│       └── date_formatter.dart      # Formateo de fechas y meses
├── data/
│   ├── datasources/
│   │   ├── local/
│   │   │   └── database_helper.dart # SQLite schema, migraciones y CRUD
│   │   └── remote/
│   │       ├── bcv_service.dart     # Servicio de tasa oficial BCV
│   │       ├── firebase_service.dart# Sincronización Firestore y Auth
│   │       └── gemini_service.dart  # Extracción OCR y llamadas a Gemini
│   ├── models/
│   │   ├── budget_model.dart        # Presupuestos generales y por categoría
│   │   ├── gasto_model.dart         # Encabezado de transacciones
│   │   ├── item_gasto_model.dart    # Detalle de líneas de gasto
│   │   └── shopping_item_model.dart # Elementos de la lista de compras
│   └── repositories/
│       ├── budget_repository.dart   # Repositorio de presupuestos
│       └── gasto_repository.dart    # Repositorio de gastos
├── providers/
│   ├── auth_provider.dart           # Estado de sesión y vinculación Google
│   ├── budget_provider.dart         # Gestión reactiva de presupuestos
│   ├── gasto_provider.dart          # Estado de gastos y métricas mensuales
│   ├── scan_queue_provider.dart     # Cola de procesamiento en segundo plano
│   ├── settings_provider.dart       # Tasas, claves y configuración
│   └── shopping_list_provider.dart  # Estado reactivo de lista de compras
├── services/
│   ├── export_service.dart          # Exportación a CSV y Markdown
│   ├── image_service.dart           # Almacenamiento y compresión de fotos
│   └── notification_service.dart   # Recordatorios locales de inactividad
├── ui/
│   ├── screens/
│   │   ├── analysis_screen.dart     # Gráficos de distribución y límites por categoría
│   │   ├── chat_screen.dart         # Asistente IA conversacional con frases rápidas
│   │   ├── expenses_screen.dart     # Historial cronológico con buscador
│   │   ├── home_screen.dart         # Dashboard principal, hero card y métricas
│   │   ├── main_screen.dart         # Navegación principal (4 pestañas + FAB) y barra de escaneo
│   │   ├── more_screen.dart         # Ajustes, perfil, sincronización y herramientas
│   │   ├── review_expense_screen.dart # Carga y confirmación de factura
│   │   └── shopping_list_screen.dart # Gestión de lista de compras
│   └── widgets/
│       ├── ai_insight_card.dart     # Consejo financiero inteligente
│       ├── category_chart.dart      # Gráfica de dona (fl_chart)
│       ├── expense_card.dart        # Tarjeta de gasto expandible
│       └── summary_card.dart        # Hero card de consumo mensual
└── main.dart                        # Punto de entrada de la aplicación
```

---

## 🚀 Despliegue e Integración Continua (CI)

La compilación y testing de la aplicación están automatizados en GitHub Actions (`.github/workflows/build_apk.yml`).

- Los tests unitarios y de widgets se ejecutan en cada push.
- Se compila el archivo APK de release con soporte arquitectónico ARM64/V7.
- La landing page estática en `landing/` se despliega en Firebase Hosting mediante:
  ```powershell
  # En landing/
  $env:ASTRO_TELEMETRY_DISABLED="1"; .\node_modules\.bin\astro.cmd build
  # En la raíz
  firebase.cmd deploy --only hosting --non-interactive
  ```
