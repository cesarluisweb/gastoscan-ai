# Roadmap de Desarrollo: Rinde Más

Este documento centraliza las iniciativas y mejoras activas de **Rinde Más**, ordenadas estratégicamente por prioridad, impacto de valor para el usuario venezolano y viabilidad técnica.

> 📜 **Histórico de Hitos Completados:** Para consultar el detalle técnico y la bitácora de todas las fases y tareas ya finalizadas, consulta [ROADMAP_HISTORICO.md](ROADMAP_HISTORICO.md).

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

## Fase 3: Mejoras de Calidad de Auditoría (Completada ✅)
*Verificada y aprobada en dispositivo físico por César (Detallado en `DOC_AUDITORIA_FASE_3.md`):*
- `FIN-07`: Cálculo exacto de días y proyección en meses históricos basándose en la fecha seleccionada.
- `FIN-08`: Validación de montos estrictamente positivos (`> 0`) en formularios y desglose de ítems.
- `UX-03`: Búsqueda global a lo largo de todo el historial financiero (cross-month).
- `UX-05`: Navegación unificada del Asistente IA (`Navigator.push`) manteniendo barra inferior visible.
- `SEC-12`: Versionado formal del Cloudflare Worker en la carpeta `workers/` del repositorio.
- `OCR-01`: Deduplicación SHA-256 nativa en cola de escaneo para evitar duplicar comprobantes.
- `AI-01`: 5 chips analíticos diferenciados sin acciones destructivas, inyección de `tasa_usdt` en contexto y saludo guiado.

---

## Fase 5: Marketing, Lanzamiento y Tracción (En Progreso 🔄)
*Hitos para validar el producto con usuarios reales en Venezuela:*
- **Subida a Google Play Store (Closed Testing):** (En progreso 🔄) Ficha técnica y capturas preparadas (`DOC_FICHA_PLAY_STORE.md`). Adaptación de políticas de información gubernamental completada: descargos de no representación y enlaces funcionales a `https://www.bcv.org.ve/` integrados en la ficha de tienda, Calculadora de divisas y pantalla Más. AAB v1.0.4 compilado y listo para reenvío conjunto con la ficha. Prueba cerrada activa en Play Console; coordinando los 12 evaluadores requeridos durante el período de prueba.
- `REL-01` **Transición a Google Play y Silenciamiento de Actualizaciones Fantasma:** `Implementada 🔧`
  - *Problema:* Discrepancia entre builds continuos de CI (`version.json` 470) y Google Play (466) causaba alertas falsas de actualización y bucle con "Abrir" en la tienda.
  - *Solución:* Silenciados popups automáticos en `DashboardScreen` y `MainScreen`. El botón de versión en `MoreScreen` ahora dice *"Google Play"* y abre directamente la ficha de la tienda para que el usuario actualice cuando Google apruebe el build. El APK directo en la landing se mantiene hasta el pase a Producción pública.
- **Código QR de Descarga en Landing (Desktop):** (Pendiente) Incorporar tarjeta con código QR dinámico en `rindemas.cesarluis.com` para escanear e instalar directamente desde una PC.
- **Correo de Bienvenida Automatizado:** (Pendiente) Disparar correo de bienvenida y guía de primeros pasos cuando el usuario vincule su cuenta de Google (vía trigger de Cloud Functions o Firestore).
- **Ejecución del Plan de Crecimiento (Primeros 100 Usuarios):** (Pendiente) Despliegue de tácticas comunitarias y orgánicas en grupos venezolanos según `marketing_plan.md` y `.agents/skills/growth-first-100-users/SKILL.md`.

---

## Fase 6.2: Consistencia Visual, Refinamiento UX y Nuevas Herramientas (Planificada 📋)
*Mejoras derivadas de auditoría de interfaz, legibilidad y optimización de flujos:*

### Bloque A: Consistencia Visual y Semántica (UI)
- `UI-01` **Unificación Canónica de Íconos de Categorías:** `Completada ✅`
  - *Problema:* Discrepancia entre Inicio/Análisis y Gastos (Higiene: jabón vs escoba; Salud: corazón vs botiquín; Servicios: rayo vs recibo; Alimentación: cubiertos vs carrito).
  - *Solución:* Centralizar la definición canónica en `AppConstants.getCategoryIcon(cat)` para que todas las vistas móviles y el panel web compartan exactamente los mismos íconos (adoptando manos con jabón para Higiene).
- `UI-02` **Contraste de Íconos y Controles en Pestaña "Más":**
  - *Problema:* Íconos y toggles amarillos sobre fondo blanco pierden definición visual.
  - *Solución:* Aplicar el patrón del modal `+` con contenedores circulares en tono suave (`AppColors.primaryContainer`) y trazos en carbón/negro (`AppColors.textPrimary`), o elevar el contraste hacia tonos ámbar/mostaza.
- `UI-03` **Semántica de Color Unificada en Progreso de Presupuesto:** `Implementada 🔧`
  - *Problema:* El mismo porcentaje (ej. 29%) se muestra verde en Inicio pero amarillo en Análisis.
  - *Solución:* Unificar la escala semafórica en toda la app: Verde (`AppColors.success` / `#10B981` para $<85\%$), Amarillo/Ámbar (`AppColors.warning` / `#F59E0B` para $\ge 85\%$) y Rojo (`AppColors.error` / `#EF4444` para $\ge 100\%$ o sobregiro), con paridad exacta en Inicio, Análisis y Web.
- `UI-04` **Rediseño de Enlaces en Presupuesto por Categoría:**
  - *Problema:* El texto `+ Asignar presupuesto mensual` con subrayado web clásico desentona con el diseño móvil.
  - *Solución:* Transformar la acción en botón tipo *pill* sutil o hacer la tarjeta completa pulsable con indicador de acento.
- `UI-05` **Ícono Superior de Asistente IA en Inicio:** `Completada ✅`
  - *Problema:* La burbuja con interrogación `[?]` en el AppBar de Inicio se confunde universalmente con "Soporte / Ayuda".
  - *Solución:* Reemplazar por ícono de destellos (`✨` / `Icons.auto_awesome`), coherente con las tarjetas del Asistente IA.

### Bloque B: Claridad de Datos y Vistas Principales (UX)
- `UX-06` **Corrección de Etiqueta de Agrupación en Gráfico de Inicio:** `Completada ✅`
  - *Comportamiento:* Se mantiene la lógica de consolidar las categorías secundarias después del Top 4 para no saturar el espacio vertical de la tarjeta.
  - *Ajuste:* Cambiar únicamente el texto de esa fila consolidada (reemplazar la palabra "Otros" por `+X categorías` o `Resto de categorías`) para que no se confunda con la categoría individual canónica *Otros*.
- `UX-07` **Desglose Directo de Productos en Pestaña "Gastos":** `Completada ✅`
  - *Problema:* Tanto Inicio como Gastos muestran tarjetas cerradas que obligan a tocar cada compra para saber qué se compró, repitiendo fechas redundantemente.
  - *Solución:* 
    - En **Inicio**: mantener tarjetas compactas con resumen limpio (`14 Oct • 4 artículos`).
    - En **Gastos**: mostrar directamente los productos con mini-ícono de categoría y subtotal. Para facturas largas, limitar a los primeros 4 ítems con botón expansor `Ver X artículos más ▾`. Mantener formato limpio de una línea para compras sin desglose.
- `UX-08` **Visibilidad de Tasa Cambiaria y Conmutador Rápido de Moneda:**
  - *Solución:* Mostrar la etiqueta de tasa de la transacción en el historial (`Bs. 4.389,50 • BCV` o `• USDT`) y permitir alternar o seleccionar la moneda de visualización tocando el monto total en la tarjeta de Inicio.
- `UX-09` **Rediseño del Filtro de Comprobantes en "Gastos":**
  - *Solución:* Incorporar un distintivo de recibo/clip (`🧾`) en las tarjetas que tienen fotografía adjunta y reemplazar el botón confuso de galería por un chip activo `[🧾 Con comprobante]` o ícono de filtro con estado evidente.
- `UX-10` **Jerarquía y Claridad de la Acción "Eliminar Cuenta":** `Implementada 🔧`
  - *Solución:* Separar visualmente la acción de eliminar cuenta de la tarjeta "Respaldo en la Nube", ubicándola en una sección independiente y sutil de "Zona de Peligro" al final de la pantalla (solo visible con sesión en la nube activa) y modernizando el botón "Cerrar sesión" en la tarjeta de cuenta.
- `UX-11` **Feedback Visual e Indicador de Estado en Vinculación / Sincronización de Cuenta:** `Completada ✅`
  - *Problema:* Al pulsar "Vincular con Google" o autenticar con correo, la app carecía de indicadores durante la comunicación con Google Play Services y la sincronización con Firestore, generando sensación de bloqueo y permitiendo toques concurrentes.
  - *Solución:* Spinner negro de alto contraste con texto de estado (*"Conectando con Google..."*, *"Vinculando y sincronizando..."*), leyenda informativa, bloqueo de interacción cruzada y protección con `PopScope` en modales y diálogos.

### Bloque C: Percepción con IA, Optimización y Seguridad
- `AI-02` **Detección Automática y Transparente de Pagos Digitales (Pago Móvil / Zelle / Binance / PayPal):** `Completada ✅`
  - *Premisa:* Funcionalidad integrada por defecto en el pipeline unificado de escaneo OCR. Resuelta la anomalía de lectura donde montos enteros (ej. $25 en PayPal o 50 Bs en Pago Móvil) se convertían a 0.25 o 0.50 debido al flag de precio de centavos en el parser.
- `AI-03` **Resumen Semántico y Ventana Deslizante en Chat IA:** `Completada ✅`
  - *Problema:* Volcado completo de la base de datos de gastos crudos (`toMap()`) y todo el historial de conversación disparaba picos de hasta >60.000 tokens en pocas consultas.
  - *Solución:* Construcción local en SQLite de un resumen semántico precalculado (`totales_categoria`, `top_productos_mes`, `ultimas_compras`, presupuesto y ritmo de ahorro) y ventana deslizante que envía solo los últimos 5 mensajes a Gemini, reduciendo el consumo de tokens en >80% preservando la capacidad analítica para preguntas frecuentes de productos.
- `AI-04` **Persistencia de Conversación en Sesión y Exclusión Fiscal de IVA en Asistente IA:** `Completada ✅`
  - *Problema:* El Asistente IA señalaba al IVA como un gasto pequeño a recortar al analizar gastos hormiga (debido a renglones fiscales `Impuesto IVA` no filtrados en `top_productos_mes`). Además, al salir del chat hacia cualquier otra pantalla de la app, toda la conversación se destruía.
  - *Solución:* Creación de `ChatProvider` en memoria (`MultiProvider`) que preserva la conversación durante toda la sesión activa de la app, botón de reinicio en el `AppBar` (`Icons.restart_alt`) con diálogo de confirmación que advierte la pérdida del historial previo, filtro estricto con `DatabaseHelper.isTaxItem` en `_buildSemanticChatContext` y regla de negocio en Cloudflare Worker instruyendo al modelo que el IVA es un tributo obligatorio legal no prescindible.
- `SEC-13` **Blindaje de Cuota Diaria y Límite Anti-Abuso en Gateway:** `Completada ✅`
  - *Problema:* Riesgo de agotamiento de saldo en Google AI Studio por bucles, ataques o scripts de scraping automatizados.
  - *Solución:* Implementación de rate limiting en Cloudflare Worker con límite de seguridad invisible de 50 peticiones/día por UID en cuota compartida, bypass automático para usuarios con API Key propia (BYOK) y respuesta amigable HTTP 429 invitando a apoyar el proyecto en `Más > Apoyar el proyecto ☕`.
- `AI-06` **Imputación de IVA en Precios de Anaquel y Algoritmo del Centavo Residual:** `Pendiente`
  - *Problema:* Las facturas fiscales del SENIAT imprimen bases imponibles (sin IVA) para productos gravados `(G)`. Al extraer el ticket, la app crea un renglón artificial "Impuesto IVA" en categoría 'Otros', distorsionando los presupuestos por categoría y descalzando el comparador histórico de precios con las entradas manuales y por voz.
  - *Solución:* Imputar el 16% de IVA directamente en los productos gravados para reflejar el precio de anaquel que el usuario pagó en caja, preservar intactos los alimentos exentos `(E)`, resolver la discrepancia de $\pm 0,01$ mediante ajuste determinista en el producto gravado de mayor valor y mostrar la base fiscal como microcopy informativo en `ReviewExpenseScreen`.
  - *Especificación técnica completa:* Ver [DOC_PRECIOS_ANAQUEL_IVA.md](DOC_PRECIOS_ANAQUEL_IVA.md).

### Bloque D: Nueva Herramienta Financiera
- `FIN-09` **Calculadora Cambiaria Rápida (Conversor Bs. / $):** `Pendiente de validación 🧪`
  - *Ubicación:* Exclusivamente en la pestaña **Más** (el botón central `+` se preserva intacto y 100% exclusivo para ingresar gastos).
  - *Propósito:* Resolver el cálculo instantáneo antes de pagar en caja o emitir un Pago Móvil, reteniendo usuarios en la app varias veces al día.
  - *Características Clave:*
    1. **Doble campo bidireccional en tiempo real con selección y borrado rápido:** Escribir en divisa calcula bolívares al instante y viceversa; al pulsar o enfocar el campo se selecciona todo el texto para sobreescribir sin borrar manualmente, e incluye botón rápido `X` para vaciar el campo.
    2. **Chips de tasa en un toque:** Selector directo entre `[Dólar BCV]`, `[Euro BCV]`, `[USDT]` y `[Personalizada ✏️]` usando las tasas ya cacheadas en la app.
    3. **Comparativa simultánea y brecha cambiaria:** Cuadro comparativo mostrando equivalencias en las otras tasas de referencia.
    4. **Acción rápida `📋 Copiar monto en Bs.`:** Copia el número limpio al portapapeles para pegarlo directamente en la app del banco.
    5. **Acción rápida `➕ Registrar como gasto`:** Pre-llena el formulario de nuevo gasto con el monto, moneda y tasa recién calculados.

- `FIN-10` **Paridad Directa 1:1 USD/USDT en Pagos en Divisa e Inmutabilidad:** `Completada ✅`
  - *Problema:* Al mostrar valores en USDT, la app triangulaba USD -> VES -> USDT aplicando la brecha cambiaria (spread oficial BCV vs Binance P2P) a dos monedas que cotizan en dólares ($19.99 USD se transformaban en 17.66 USDT), y recalculaba el total mensual con la tasa USDT en vivo de cada día, provocando que los totales históricos fluctuaran y disminuyeran día a día.
  - *Solución:* Establecimiento de paridad determinista 1:1 directa entre USD y USDT en pagos en divisas sin aplicar tasas futuras.

- `FIN-11` **Motor Multimoneda "Dos Lentes" (USD BCV vs. USDT P2P) y Migración SQLite v17:** `Implementada 🔧`
  - *Problema:* La paridad 1:1 global de FIN-10 impedía distinguir gastos cancelados en bolívares de gastos en divisas duras, borrando el ahorro real obtenido al vender USDT en Binance P2P para compras locales (ej. gasolina pagada en Bs a tasa BCV).
  - *Solución:*
    1. **Migración SQLite v17:** Nuevas columnas `total_usdt INTEGER` (en céntimos inmutables) y `tasa_usdt REAL` con backfill determinista.
    2. **Verdad física del pago:** Gastos en `VES` sellan ambas tasas (`tasa_bcv` y `tasa_usdt`). Gastos en `USD`/`USDT` mantienen paridad 1:1 directa.
    3. **UX de Captura:** Vista previa dual en `ReviewExpenseScreen` (`= $X,XX BCV • Y,YY USDT`) y selector `[ Pagado en Bs. a tasa BCV ]` vs `[ Pagado en Divisa ]` que convierte y persiste la verdad física para usuarios que piensan en dólares pero pagan en bolívares.
    4. **Switch de Lente Rápido:** Selector `[USD BCV | USDT P2P | Bs.]` en `SummaryCard` y `AnalysisScreen`, junto con la insignia de *"Brecha capturada (+$$ vs BCV)"*.
    5. **Paridad Total:** Sincronizado en `GastoProvider`, `CurrencyFormatter`, contexto semántico de IA en `ChatScreen`, y `panel.astro` (eliminando multiplicador prohibido `* 1.08`).
  - *Documentación:* Ver [DOC_MOTOR_MULTIMONEDA.md](DOC_MOTOR_MULTIMONEDA.md). Tarea crítica: pendiente de visto bueno de César.

---

## Fase 6.1 (Remanente): Catálogo de Categorías
- **Revisión y Expansión de Categorías por Defecto:** (Pendiente) Evaluar la incorporación de nuevas categorías predeterminadas de uso habitual (ej. 'Vestimenta' / 'Ropa' o afines) para evitar la sobreutilización de 'Otros'. Requiere coordinar: asignación de color e icono en UI, ampliación de sinónimos en `AppConstants.normalizarCategoria`, actualización de prompts de categorización en IA (Cloudflare Worker), y paridad matemática/visual en el panel web.

---

## Fase 7: Arquitectura de Producción y Confiabilidad (Pendientes Técnicos)
*Evolución hacia grado de confiabilidad bancaria ("Bank-grade"):*
- **Evaluación de Firebase AI Logic (`firebase_vertexai`):** Evaluar migración de llamadas REST al SDK de Firebase Vertex AI en Flutter, integrando Firebase App Check y Remote Config.
- **Despliegue Dinámico y Configuración Remota (Firebase Remote Config):** Configurar cuotas mensuales de IA, textos y parámetros de modelos desde el servidor sin requerir nuevo APK.
- **Manejo de Casos Borde en Facturas Locales (Corner Cases):** Refinamiento para facturas térmicas dobladas, comprobantes mixtos con ítems en Bs y total en USD/"Ref", y marcadores de IVA exento/gravado.
- **Procesamiento Background Nativo:** Migrar la cola local en Dart a un Background Worker real del sistema operativo (Firebase Cloud Tasks / WorkManager) para asegurar subidas e IA incluso con la app cerrada.
- **Extracción Asistida por Confianza (Confidence Scores):** Retorno de nivel de confianza por dato extraído con alerta "⚠️ Revisar" y diccionario personal local de aprendizaje.
- **Cifrado de Extremo a Extremo en Nube (E2EE / Zero-Knowledge Sync):** Cifrado local con AES-256 de gastos y comprobantes antes de persistir en Firestore utilizando clave derivada de la contraseña del usuario.
- **Copia de Seguridad y Restauración Portable (.zip):** Generación de archivo comprimido con SQLite e imágenes para resguardo bajo demanda en Google Drive personal o almacenamiento local.

---

## Fase 8.1: Modernización y Paridad del Panel Web (En Progreso 🔄)
*Actualización progresiva del panel web (`landing/src/pages/panel.astro`) con paridad respecto a la app móvil:*
- **Fase 1 (Web): Presupuesto y Meta de Ahorro en Modal y Firestore:** (En verificación 🔄)
- **Fase 2 (Web): Semáforo de Salud de Ahorro y Ritmo Diario:** (En verificación 🔄)
- **Fase 3 (Web): Soporte Multimoneda (USD, VES, EUR, USDT) y Tasas en Vivo:** (En verificación 🔄)
- **Fase 4 (Web): Autenticación con Correo y Contraseña:** (Pendiente) Soporte para usuarios registrados con alias (Addy.io) o credenciales directas.
- **Fase 5 (Web): Edición y Detalle Ampliado de Facturas:** (Pendiente) Edición completa de compras y comprobantes desde el navegador.

---

## Fase 8: Ecosistema Web y Red Colaborativa (Largo Plazo 🔭)
- **Dashboard Web de Escritorio en Flutter Web:** Estadísticas avanzadas y subida masiva de facturas desde PC.
- **Crowdsourcing de Precios (El Waze de las compras):** Base de datos anónima de precios recopilada colaborativamente en Venezuela.
- **Comparativa por Unidad de Medida:** Comparación inteligente de precios normalizados (ej. Arroz $2.00/kg vs $1.60/kg).
- **Buscador de Ofertas Locales:** Consulta de comercios cercanos con mejores precios en las últimas 48 horas.
- **Historial Interactivo de Tasas BCV:** Gráfico histórico de la evolución de tasas oficiales y brecha cambiaria.
- **Cross-Selling de Ecosistema:** Reutilización de módulos (Auth, Sync, SQLite, IA OCR) para nuevas herramientas financieras.

---

## Fase 9: Modelo de Monetización y Suscripción Premium (Rinde Más Pro)
*Diseño de experiencia de pago, embudo de conversión y monetización:*
- **Cuota Gratuita Base:** 15 a 20 facturas escaneadas por cámara al mes (registro manual y voz siempre ilimitados).
- **Publicidad en Transiciones Naturales:** Anuncios discretos tras guardar gastos para cubrir el costo de tokens de usuarios gratuitos, cumpliendo Better Ads Standards.
- **Rinde Más Pro ($1,99/mes o $19,99/año):**
  - Cuotas de IA y OCR ilimitadas.
  - Experiencia Cero Publicidad (Zero Ads).
  - Categorías personalizadas ilimitadas (icono y color propio).
  - Exportación contable avanzada (PDF mensual con balance y diseño limpio; Excel/CSV con desglose completo ítem por ítem).
  - Sincronización de comprobantes en la nube (Cloud Storage).
  - Consultas analíticas profundas al Asistente IA con comparativa de meses previos.
  - Modo Contable y Desglose Tributario Formal: Selector en Más para alternar entre Modo Anaquel (con IVA) y Modo Fiscal (base imponible desglosada), con exportación de libro fiscal de compras en Excel/PDF.
- **Optimización del Embudo de Conversión (Funnel):** Medición de fugas con Firebase Analytics (Impresión → Descarga → Onboarding → Activación → Retención → Pago) y Paywalls contextuales.
- **Métrica de Validación Financiera:** Meta de generar los primeros $50 USD en 30-60 días con 500-1.000 usuarios activos.
- **Alertas Proactivas de Inflación y Desvío:** Notificaciones inteligentes cuando productos frecuentes suban de precio o el ritmo de gasto comprometa el mes.
