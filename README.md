# Rinde Más 📱🧾

Aplicación móvil Android (*Local-First*) desarrollada en Flutter para el control de gastos personales y familiares en Venezuela. Digitaliza facturas físicas y comprobantes digitales (Pago Móvil, transferencias) con IA multimodal, gestiona presupuestos multimoneda (VES, USD, EUR, USDT) con tasas oficiales BCV en vivo, compara precios históricos y ofrece un asistente financiero conversacional.

Sitio oficial y panel web: [rindemas.cesarluis.com](https://rindemas.cesarluis.com)

---

## ✨ Características Principales

- **Escaneo Inteligente de Facturas con IA:** Extrae comercio, fecha, artículos, cantidades, IVA y totales desde fotos de tickets físicos o capturas de bancos nacionales, con cola de procesamiento en segundo plano y respaldo en álbum local.
- **Gestión Multimoneda (VES, USD, EUR, USDT):** Consulta en vivo las tasas oficiales BCV y USDT, con calculadora cambiaria integrada y cálculos deterministas en dominio monetario (`lib/domain/monetary/`).
- **Presupuestos Mensuales y Metas de Ahorro:** Límites generales y por categoría aislados por mes, proyección de salud de ahorro y alertas visuales tipo semáforo.
- **Comparador de Precios Histórico:** Detecta automáticamente si un producto subió o bajó de precio respecto a compras previas en los últimos 60 días.
- **Asistente Financiero Conversacional (IA):** Chat y dictado continuo por voz para registrar gastos, consultar balances, gestionar la lista de compras y recibir consejos dinámicos en Inicio.
- **Privacidad Local-First y Sincronización Opcional:** Base de datos local SQLite (`sqflite`) 100% funcional sin internet, con respaldo opcional en Firebase Firestore mediante Google Sign-In.
- **Panel Web Integrado:** Acceso desde escritorio en [rindemas.cesarluis.com/panel](https://rindemas.cesarluis.com/panel) con paridad de registro, calculadora cambiaria y asistente IA.
- **Exportación de Datos:** Reportes detallados en `.csv` y `.md`.

---

## 🛠️ Stack Tecnológico

- **App Móvil:** Flutter `3.47.9` (Dart) + `provider` + Material 3.
- **Base de Datos Local:** SQLite (`sqflite`) con pruebas en memoria (`sqflite_common_ffi`).
- **Autenticación y Nube:** Firebase Authentication (Google Sign-In / Anónimo) y Cloud Firestore (plan Spark, reglas endurecidas en `firestore.rules`).
- **Gateway de IA y Cuotas:** Cloudflare Workers (`workers/`, `rindemas-gateway`) + Cloudflare D1 (control de cuota diaria) + Google Gemini API.
- **OCR y Captura:** `google_mlkit_document_scanner`, `google_mlkit_text_recognition`, `image_picker`, `flutter_image_compress` y `speech_to_text`.
- **Web (Landing y Panel):** Astro + Tailwind CSS en `landing/`, desplegado en Firebase Hosting vía CI/CD.

---

## 📁 Estructura del Proyecto

> Para el inventario completo y actualizado de archivos, símbolos y pruebas, consulta [`docs/CODE_MAP.md`](docs/CODE_MAP.md) y [`docs/INDEX.md`](docs/INDEX.md).

```text
lib/
├── core/          # Constantes, paleta (AppColors), tema M3, formateadores y hash de imágenes
├── data/          # SQLite (DatabaseHelper), Firestore, GeminiService, modelos y repositorios
├── domain/        # Lógica pura: dominio monetario (RM-03), salud de ahorro y diagnósticos Q01..Q20
├── providers/     # ChatProvider, GastoProvider, ScanQueueProvider, SettingsProvider
├── services/      # Tasas BCV/USDT, OCR local, sincronización, notificaciones, exportación e imágenes
├── ui/
│   ├── screens/   # Dashboard, Historial, Análisis, Más, Revisión de factura, Chat, Calculadora, Galería, Lista
│   └── widgets/   # Tarjetas, gráficos (fl_chart), selector de mes, hoja de presupuesto y barra de escaneo
└── main.dart      # Arranque Local-First desacoplado

landing/           # Landing page y panel web (Astro + Tailwind CSS)
workers/           # Cloudflare Worker gateway de IA (rindemas-gateway)
docs/              # Documentación técnica vigente, mapa de código e índice
test/              # Pruebas unitarias, de widgets y de reglas Firestore
```

---

## 🚀 Despliegue e Integración Continua (CI/CD)

Toda compilación, análisis estático, pruebas y publicación se ejecutan en **GitHub Actions**:

- **App Android (`.github/workflows/build_apk.yml`):** Ejecuta `flutter analyze`, pruebas unitarias/widgets y compila el APK/AAB firmado con secretos de CI.
- **Landing y Panel Web (`.github/workflows/deploy_web.yml`):** Ejecuta pruebas unitarias web, compila Astro y despliega a Firebase Hosting al hacer push a `main`.
- **Reglas de Firestore (`.github/workflows/deploy_rules.yml` y `audit_firestore.yml`):** Validación en emulador (`RT-01..RT-24`) y despliegue controlado de `firestore.rules`.
