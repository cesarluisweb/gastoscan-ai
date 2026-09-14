# GastoScan AI 📱🧾

Aplicación móvil Android desarrollada en Flutter para la digitalización instantánea de facturas, recibos y comprobantes de pago (físicos o capturas digitales de Pago Móvil y transferencias) mediante Inteligencia Artificial multimodal (Google Gemini 1.5 Flash API) y almacenamiento SQLite 100% local.

---

## 🛠️ Stack Tecnológico

- **Framework:** Flutter (Dart)
- **Base de Datos:** SQLite local con `sqflite` (relaciones atómicas en cascada entre facturas e ítems)
- **Motor de IA Multimodal:** Google Gemini 1.5 Flash (API REST optimizada con prompt estructurado JSON)
- **Gestión de Estado:** `provider` (reactivo y desacoplado)
- **Captura y Optimización:** `image_picker` + compresión JPEG con `flutter_image_compress`
- **Exportación:** Exportador nativo a formatos `.csv` y `.md` (Markdown) mediante `share_plus`
- **Interfaz:** Material 3 con modo oscuro profundo (Dark Mode) por defecto

---

## 📁 Estructura del Proyecto

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart        # Paleta de colores dark mode y tags
│   │   └── app_constants.dart     # Categorías, monedas y claves
│   ├── theme/
│   │   └── app_theme.dart         # Tema oscuro Material 3
│   └── utils/
│       ├── currency_formatter.dart# Formateo Bs., USD y EUR
│       └── date_formatter.dart    # Formateo de fechas y meses
├── data/
│   ├── datasources/
│   │   ├── local/
│   │   │   └── database_helper.dart # SQLite CRUD y transacciones
│   │   └── remote/
│   │       └── gemini_service.dart  # Conexión con Gemini 1.5 Flash
│   ├── models/
│   │   ├── gasto_model.dart         # Modelo cabecera de gasto
│   │   ├── item_gasto_model.dart    # Modelo líneas de detalle
│   │   └── gemini_extraction_result.dart # Parser seguro JSON
│   └── repositories/
│       └── gasto_repository.dart    # Abstracción de datos
├── providers/
│   ├── gasto_provider.dart          # Estado de gastos y métricas
│   └── settings_provider.dart       # API Key, tasa y almacenamiento
├── services/
│   ├── export_service.dart          # Generador CSV y Markdown
│   └── image_service.dart           # Compresión y guardado opcional
├── ui/
│   ├── screens/
│   │   ├── dashboard_screen.dart    # Totales del mes, gráfico y lista
│   │   ├── scan_screen.dart         # Captura cámara/galería y preview
│   │   ├── review_expense_screen.dart # Edición de datos e ítems
│   │   └── settings_screen.dart     # Configuración de clave y tasa
│   └── widgets/
│       ├── category_chart.dart      # Gráfico de dona (fl_chart)
│       ├── expense_card.dart        # Tarjeta de gasto expandible
│       └── summary_card.dart        # Resumen consolidado mensual
└── main.dart                        # Entrada principal de la aplicación
```

---

## 🚀 Pasos para Ejecutar la Aplicación

### 1. Requisitos Previos
- **Flutter SDK:** versión `>= 3.0.0` instalada y configurada en el PATH.
- **Android SDK / Android Studio** con emulador o dispositivo físico con depuración USB activada.

### 2. Instalar Dependencias
Abre una terminal en esta carpeta y ejecuta:
```bash
flutter pub get
```

### 3. Configurar API Key de Gemini
1. Obtén una clave gratuita en [Google AI Studio](https://aistudio.google.com/).
2. Inicia la aplicación en tu teléfono o emulador:
   ```bash
   flutter run
   ```
3. En la pantalla principal, presiona el icono de **Ajustes** (arriba a la derecha).
4. Pega tu API Key y guarda los cambios.

---

## 🔒 Privacidad y Almacenamiento
En **Ajustes**, dispones del interruptor:
- **`Guardar copia de fotos en el dispositivo`** (desactivado por defecto).
- Si permanece desactivado, la foto capturada se procesa en memoria temporal, se extraen los datos a texto en SQLite y el archivo se elimina de inmediato para evitar saturar el almacenamiento del teléfono.
