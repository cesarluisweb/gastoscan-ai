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

*Tareas integradas en `main` que permanecen pendientes de verificación o cierre administrativo:*

1. `UX-14` **Estado Vacío Contextual Inteligente y Sincronización Temporal de Sesión:** `Implementada 🔧`
   - Detección automática del último mes con compras (`obtenerUltimoMesConGastos()`), incentivo sin botón cuando el mes actual está vacío, flecha izquierda hacia atrás al consultar meses futuros y `[Volver al mes actual]` en períodos históricos.
   - Restablecimiento automático al mes en curso tras inactividad mayor a 30 minutos al reanudar la app (`WidgetsBindingObserver`).
2. **Seguridad Crítica de Firma (Keystore):** `Pendiente de validación 🧪`
   - `rindemas.jks` retirado de Git y firma inyectada desde GitHub Secrets con guardas SHA-1/SHA-256 en CI (Builds 664/671).
   - *Pendiente posterior:* Rotación de la upload key tras aprobación de Producción en Google Play.
3. **Subida a Google Play Store (Solicitud de Producción):** `Pendiente de validación 🧪`
   - Prueba cerrada de 14 días completada con 12 evaluadores (cero crashes / cero ANR). Solicitud de producción enviada el 04/11/2026 (en revisión). Doc en [`docs/DOC_CUESTIONARIO_PRODUCCION.md`](docs/DOC_CUESTIONARIO_PRODUCCION.md).

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
- `E0-05b` **Protocolo de diagnóstico de datos existentes (Q01..Q20):** `Pendiente` Consultas de solo lectura sobre fixtures de prueba sin PII (A-14).

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
- `UX-17` **Botón y Flujo de Referidos Simple ("Compartir Rinde Más por WhatsApp"):** `Pendiente` Botón en `MoreScreen` con `Share.share` y enlace directo a Google Play.
- `UX-18` **Evolución Mensual en Gráfica Única (Pantalla Análisis):** `Pendiente` Gráfica consolidada de los últimos 6 a 12 meses en una sola vista.

### Bloque C: Percepción con IA
- `AI-06` **Imputación de IVA en Precios de Anaquel y Algoritmo del Centavo Residual:** `Pendiente` Imputar 16% de IVA a productos gravados `(G)` preservando exentos `(E)`, ajustando $\pm 0,01$ en el ítem de mayor valor y mostrando base fiscal en `ReviewExpenseScreen`.
- `AI-07` **Refinamiento de UX en Chat del Asistente (Sugerencias Verticales y Botón Dinámico):** `Pendiente` Sugerencias apiladas verticalmente (2 a 3 opciones) y botón dinámico micrófono/enviar estilo WhatsApp.

### Bloque D: Nuevas Herramientas Financieras
- `FIN-14` **Flexibilidad y Opciones de Liquidación en Gastos Registrados en USDT:** `Pendiente` Habilitar `BS_BCV`, `BS_USDT` y `DIVISA` al registrar en `USDT`, almacenando contravalor con `tasaUsdt` de la fecha.
- `FIN-15` **Soporte Nativo para Cashea y Compras en Cuotas:** `Pendiente` Selector `[ Contado | ⚡ Cashea / Cuotas ]`, cuotas cada 14 días como compromisos `'PENDIENTE'`, liquidación en 1 toque, notificaciones y paridad IA/Web. Ver [`docs/DOC_PLAN_CASHEA.md`](docs/DOC_PLAN_CASHEA.md).

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
| **Endurecimiento de reglas de Firestore (`B1`)** | P0 | `Pendiente` | Plan completo en `docs/DOC_REGLAS_FIRESTORE_B1.md`; requiere sesión dedicada con emulador. |
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
