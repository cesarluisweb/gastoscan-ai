# Roadmap de Desarrollo: Rinde Más

Este documento centraliza las iniciativas y mejoras activas de **Rinde Más**, ordenadas por prioridad, impacto de valor para el usuario venezolano y viabilidad técnica.

> 📜 **Histórico de Hitos Completados:** Para consultar el detalle técnico y la bitácora de todas las fases y tareas finalizadas, consulta [ROADMAP_HISTORICO.md](docs/archive/2026-Q4/ROADMAP_HISTORICO.md).

---

## Principios de Ejecución y Entrega de Valor
1. **Impacto de Negocio sobre Complejidad:** Priorizar funciones con alto impacto cotidiano y retención sobre desarrollos complejos de bajo uso.
2. **Filosofía Local-First y Anti-Microgestión:** Cero conciliaciones bancarias complejas ni gestión de múltiples cuentas; enfoque en presupuestos bimonetarios (VES/USD) y tasas oficiales en vivo.
3. **Los Datos son el Producto:** Captura precisa, normalización y cálculo exacto de compras (precios, productos, IVA, tasa BCV) como base del sistema.
4. **Monetización como Producto Independiente:** La monetización requiere su propio embudo de conversión y propuesta de valor, sin degradar la experiencia base gratuita.
5. **Regla de Oro de IA:** La inteligencia artificial interpreta; el código determinista calcula.

---

## Estados Oficiales de Tareas
- `Pendiente`: Tarea planificada no iniciada.
- `Implementada 🔧`: Código commiteado en `main` y CI en curso o pendiente de verificación.
- `Pendiente de validación 🧪`: CI en verde (`conclusion: success`); pendiente de validación en dispositivo físico por César.
- `Completada ✅`: Verificada y aprobada (las tareas críticas requieren aprobación explícita de César).

---

## Tareas en Validación Activa por César (`Pendiente de validación 🧪` / `Implementada 🔧`)

*Tareas integradas en `main` que permanecen pendientes de cierre administrativo:*

1. **Seguridad Crítica de Firma (Keystore):** `Pendiente de validación 🧪`
   - `rindemas.jks` retirado de Git y firma inyectada desde GitHub Secrets con guardas SHA-1/SHA-256 en CI (Builds 664/671).
   - *Pendiente posterior:* Rotación de la upload key tras aprobación de Producción en Google Play.
2. **Subida a Google Play Store (Solicitud de Producción):** `Pendiente de validación 🧪`
   - Prueba cerrada de 14 días completada con 12 evaluadores (cero crashes / cero ANR). Solicitud de producción enviada el 04/11/2026 (en revisión). Doc en [`docs/DOC_CUESTIONARIO_PRODUCCION.md`](docs/DOC_CUESTIONARIO_PRODUCCION.md).
3. **Herramientas Web Bloque 1 (Calculadora Cambiaria + Asistente IA en Panel Web):** `Completada ✅`
   - Módulos puros (`expense-money.js`, `currency-calculator.js`, `ai-assistant.js`), componentes Astro (`CalculatorModal.astro`, `AiChatDrawer.astro`), 29 pruebas unitarias en CI (`deploy_web.yml`, build 32, run `44784979988`, `3df3104`) y cola de compras múltiples. Desplegado, verificado HTTP 200 en `https://rindemas.cesarluis.com/panel` y aprobado por César (20/11/2026). Doc en [`docs/DOC_HERRAMIENTAS_PANEL_WEB.md`](docs/DOC_HERRAMIENTAS_PANEL_WEB.md).

---

## Decisiones Estratégicas y Restricciones Vigentes

> **Documento canónico de análisis:** [`consejo_arquitectura_rinde_mas.md`](file:///c:/Users/cesar/.gemini/antigravity/brain/76540cb9-a8d1-4d3f-8230-6bc5cb272025/consejo_arquitectura_rinde_mas.md)

### 🔴 Acción Diferida (Tras Aprobación de Producción)
- **Rotación de la clave de subida (upload key):** Ejecutar después de la aprobación de Producción vía CI (`keytool`), registrar la nueva SHA-1 para `com.cesarluis.rindemas.dev` y actualizar los 3 secretos en GitHub.

### 🟢 Qué NO Implementar (Condicionado a métricas)
- **Búsqueda FTS5:** No conectar a ciegas; migrar a SQL indexado únicamente si las métricas en dispositivo superan 300 ms.
- **Prohibido refactorizar o dividir `DatabaseHelper` o `ReviewExpenseScreen`** durante la evaluación de Google Play.

---

## Fase 0: Integridad Financiera y Multimoneda (Iniciativa RM-03 — Cierre)
*Hitos `E0-01` a `E0-05a` completados; ver [ROADMAP_HISTORICO.md](docs/archive/2026-Q4/ROADMAP_HISTORICO.md).*
- `E0-05b` **Protocolo de diagnóstico de datos existentes (Q01..Q20):** `Completada ✅` Consultas de solo lectura (`PRAGMA query_only = ON`, copia temporal con soporte WAL, sin PII) en `lib/domain/diagnostics/` y CLI `tool/diagnose_sqlite.dart`. Doc en [`docs/DOC_E0_05B_DIAGNOSTICO_Q01_Q20.md`](docs/DOC_E0_05B_DIAGNOSTICO_Q01_Q20.md). CI en verde (build 707, `4dafbf9`) y validada por César (13/11/2026).

---

## Fase 5: Marketing, Lanzamiento y Tracción (En Progreso 🔄)
- **Código QR de Descarga en Landing (Desktop):** `Pendiente` Incorporar tarjeta con código QR dinámico en `rindemas.cesarluis.com` para escanear e instalar desde PC.
- **Correo de Bienvenida Automatizado:** `Pendiente` Disparar correo de bienvenida y guía de primeros pasos al vincular cuenta de Google.
- **Ejecución del Plan de Crecimiento (Primeros 100 Usuarios):** `Pendiente` Según `docs/DOC_BITACORA_MARKETING.md` y `.agents/skills/growth-first-100-users/SKILL.md`:
  - *Post de Victoria en Reddit:* Lanzamiento en `r/vzla` y `r/AskVenezuela` con el enlace oficial de Google Play.
  - *Outreach a Micro-Creadores:* Acercamiento directo a creadores de comparativas de supermercado y gestión del hogar.
  - *Videos Formato F (Dilema del Bolívar):* Capitalizar búsquedas orgánicas de TikTok (*"cómo ahorrar si uno gana en bolívares"*).

---

## Fase 6.1 (Remanente): Catálogo de Categorías
- **Revisión y Expansión de Categorías por Defecto:** `Pendiente` Evaluar nuevas categorías predeterminadas (ej. 'Vestimenta' / 'Ropa') coordinando UI, `AppConstants.normalizarCategoria`, Cloudflare Worker y panel web.

---

## Fase 6.2: Refinamiento UX y Nuevas Herramientas Financieras (Planificada 📋)

### Bloque B: Finanzas Bimonetarias y Flujos de Captura
- `UX-15` **Selector y Autocompletado de Comercios Frecuentes:** `Pendiente` Desplegar chips o sugerencias rápidas de comercios frecuentes al enfocar `¿Dónde compraste?`.
- `UX-16` **Sistema Ligero de Etiquetas (Tags) para Gastos:** `Pendiente` Etiquetas opcionales (`#tags`) en captura y filtro de historial sin alterar las categorías canónicas.
- `UX-17` **Botón y Flujo de Referidos Simple ("Compartir Rinde Más por WhatsApp"):** `Pendiente` *(Diferida hasta tener el enlace público de Google Play Store)*. Planificado para App (`MoreScreen`), Panel Web y Landing + meta tags Open Graph. Ver [`docs/DOC_PLAN_UX17_COMPARTIR_WHATSAPP.md`](docs/DOC_PLAN_UX17_COMPARTIR_WHATSAPP.md).
- `UX-18` **Evolución Mensual en Gráfica Única (Pantalla Análisis):** `Pendiente` Gráfica consolidada de los últimos 6 a 12 meses en una sola vista.
- `UX-19` **(Idea en evaluación) Simplificación del Registro Manual:** `Pendiente` Evaluar agilización de gastos sueltos sin lista de ítems detallados, preservando el método de liquidación (`MetodoLiquidacion`) y chips frecuentes (`UX-15`).
- `UX-20` **Rediseño de Ítems en Revisión de Factura:** `Completada ✅` Iteración 2 validada en dispositivo (build 712, `18ae858`): fondo gris por ítem, etiqueta "Concepto" en negrita, categoría en caja alineada, total más grande y deshacer al eliminar. Ver [`docs/DOC_REDISENO_ITEMS_FACTURA.md`](docs/DOC_REDISENO_ITEMS_FACTURA.md).

### Bloque C: Percepción con IA
- `AI-06` **Imputación de IVA en Precios de Anaquel y Reparto por Mayor Resto:** `Implementada 🔧` Reparto determinista por Mayor Resto del IVA documental (16% `G` / 8% `R`, preservando exentos `E`), nombres limpios, `IvaModo` en `SemanticValidator` y `scan_queue` (`schema_v: 2`), nota `Base impresa` en `ReviewExpenseScreen`, comparador simétrico móvil+web (`DatabaseHelper` + `price-comparator.js`) y soporte `'R'` en Worker. Ver [`docs/DOC_PRECIOS_ANAQUEL_IVA.md`](docs/DOC_PRECIOS_ANAQUEL_IVA.md).
- `AI-07` **Refinamiento de UX en Chat del Asistente (Sugerencias Verticales y Botón Dinámico):** `Pendiente` Sugerencias apiladas verticalmente (2 a 3 opciones) y botón dinámico micrófono/enviar estilo WhatsApp.
- `AI-08` **Consejos Dinámicos en Tarjeta Asistente IA (Inicio):** `Implementada 🔧` Consejo único combinado con el cálculo de ritmo diario, heurísticas locales, banco de valor real y generación periódica con Gemini en segundo plano (`modo: "insight_inicio"` sin `tools`, máx. 1 vez cada 24h con $\ge 3$ gastos); al pulsar `Consultar ->` abre el chat con la versión ampliada y detallada del consejo para seguir interactuando.
- `AI-09` **Detección Preventiva de Fotos y Facturas Duplicadas:** `Pendiente` Control en dos capas para evitar duplicados en la cola de escaneo (por hash SHA-256) y alertas semánticas en revisión/guardado (mismo comercio, fecha y monto) con opción de descarte inmediato. Ver [`docs/DOC_PLAN_DETECCION_DUPLICADOS.md`](docs/DOC_PLAN_DETECCION_DUPLICADOS.md).

### Bloque D: Nuevas Herramientas Financieras
- `FIN-14` **Flexibilidad y Opciones de Liquidación en Gastos Registrados en USDT:** `Pendiente` Habilitar `BS_BCV`, `BS_USDT` y `DIVISA` al registrar en `USDT`, almacenando contravalor con `tasaUsdt` de la fecha.
- `FIN-15` **Soporte Nativo para Cashea y Compras en Cuotas:** `Pendiente` Selector `[ Contado | ⚡ Cashea / Cuotas ]`, cuotas cada 14 días como compromisos `'PENDIENTE'`, liquidación en 1 toque, notificaciones y paridad IA/Web. Ver [`docs/DOC_PLAN_CASHEA.md`](docs/DOC_PLAN_CASHEA.md).
- `FIN-16` **Gastos Fijos / Recurrentes Mensuales:** `Pendiente` Plantillas o recordatorios de pagos fijos mensuales (alquiler, internet, servicios) para registrarlos con un toque sin llenarlos desde cero cada mes.

### Bloque E: Inteligencia de Precios y Antiinflación (Post-Play)
- `RADAR-01` **Radar de Precios e Historial de Variación:** `Pendiente` Pantalla dedicada de consulta sobre el historial de compras recientes (últimos 30–60 días) comparando precios unitarios en USD para reportar variaciones porcentuales y el mejor comercio registrado.

### Bloque E: Respaldo y Soberanía de Datos (Local-First Backup)
- `BACKUP-01` **Exportación e Importación Completa con Comprobantes (.zip):** `Pendiente` Empaquetado de SQLite y `recibo_*.jpg` con restauración transaccional sin colisiones.
- `BACKUP-02` **Importación Masiva y Migración desde Otras Apps (MyMoney Pro / CSV / Excel):** `Pendiente` Plantilla oficial, detector de MyMoney Pro, cálculo histórico de tasas BCV desde 2023 y vista previa por lotes.

### Bloque F: Retención, Hábitos y Gamificación
- `RET-01` **Sistema de Hábitos Financieros, Rachas Protegidas y Puntos Rinde:** `Pendiente` Puntos por registro/consulta (tope 5/día), botón *"Hoy no gasté nada 👍"*, *Streak Freeze*, puesta al día semanal y canje por días Pro o tokens de escaneo.

---

## Fase 7: Arquitectura de Producción, Confiabilidad y Deuda Técnica

### Bloque A: Seguridad y Deuda Técnica Pendiente

| Ítem / Área | Prioridad | Estado | Detalle |
| :--- | :---: | :---: | :--- |
| **Endurecimiento de reglas de Firestore (`B1`)** | P0 | `Completada ✅` | Reglas endurecidas con `diff()` en `firestore.rules`, suite `RT-01..RT-24` en verde (`43499032804`), auditoría read-only (`audit_firestore.yml`) y pruebas en producción aprobadas por César (13/11/2026). |
| **Búsqueda histórica eficiente (tabla normalizada)** | P2 | `Pendiente` | Condicionado a métricas en dispositivo > 300 ms. |
| **Crear `ShoppingListProvider` / Repository** | P2 | `Pendiente` | Desacoplar pantallas y chat de llamadas directas a `DatabaseHelper.instance`. |
| **Actualizar `README.md` a la realidad** | P2 | `Pendiente` | Sigue listando Cloud Functions y archivos inexistentes del proyecto inicial. |
| **Eliminar binarios locales y `fix.py`** | P3 | `Pendiente` | `app-release.apk` (57 MB), `scratch/*.apk` (~300 MB) y `fix.py` en disco. |

### Bloque B: Infraestructura y Capacidades de Producción (Bank-Grade)
- **Evaluación de Firebase AI Logic (`firebase_vertexai`):** `Pendiente` Evaluar migración e integración con App Check y Remote Config.
- **Despliegue Dinámico y Configuración Remota (Firebase Remote Config):** `Pendiente` Cuotas, textos y parámetros desde servidor sin nuevo APK.
- **Manejo de Casos Borde en Facturas Locales:** `Pendiente` Facturas térmicas dobladas, comprobantes mixtos Bs/USD y marcadores de IVA.
- **Procesamiento Background Nativo:** `Pendiente` Migrar cola local a WorkManager / Cloud Tasks.
- **Extracción Asistida por Confianza (Confidence Scores):** `Pendiente` Nivel de confianza por dato con alerta "⚠️ Revisar" y diccionario personal.
- **Cifrado de Extremo a Extremo en Nube (E2EE / Zero-Knowledge Sync):** `Pendiente` Cifrado AES-256 local antes de persistir en Firestore.

---

## Fase 8: Ecosistema Web y Red Colaborativa (Largo Plazo 🔭)
- **Dashboard Web de Escritorio en Flutter Web:** Estadísticas avanzadas y subida masiva de facturas desde PC.
- **Crowdsourcing de Precios (El Waze de las compras):** Base de datos anónima de precios recopilada colaborativamente en Venezuela.
- **Comparativa por Unidad de Medida:** Comparación inteligente de precios normalizados (ej. Arroz \$2.00/kg vs \$1.60/kg).
- **Buscador de Ofertas Locales:** Consulta de comercios cercanos con mejores precios en las últimas 48 horas.
- **Historial Interactivo de Tasas BCV:** Gráfico histórico de tasas oficiales y brecha cambiaria.
- **Cross-Selling de Ecosistema:** Reutilización de módulos para nuevas herramientas financieras.

---

## Fase 9: Modelo de Monetización y Suscripción Premium (Rinde Más Pro)
- **Cuota Gratuita Base y Prevención del Anti-patrón Rial:** Escaneo abierto protegido por límite anti-abuso de 50 peticiones/día por UID en Cloudflare Gateway (`SEC-13`). Registro manual y por voz 100% ilimitados y gratuitos.
- **Publicidad en Transiciones Naturales:** Anuncios discretos tras guardar gastos cumpliendo Better Ads Standards.
- **Rinde Más Pro (\$1,99/mes o \$19,99/año):**
  - Cero Publicidad, categorías personalizadas ilimitadas, exportación contable avanzada (PDF/Excel), respaldo de fotos en la nube, consultas analíticas profundas al Asistente IA, Modo Contable/Fiscal y soporte BYOK (*Bring Your Own Key*).
- **Optimización del Embudo de Conversión (Funnel):** Eventos en Firebase Analytics y paywalls contextuales no invasivos.
- **Métrica de Validación Financiera:** Meta de primeros \$50 USD en 30–60 días con 500–1.000 usuarios activos.
- **Alertas Proactivas de Inflación y Desvío:** Notificaciones cuando productos frecuentes suban de precio o el ritmo de gasto comprometa el mes.
