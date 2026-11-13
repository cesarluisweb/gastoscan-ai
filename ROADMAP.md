# Roadmap de Desarrollo: Rinde Más

Este documento centraliza las iniciativas y mejoras activas de **Rinde Más**, ordenadas estratégicamente por prioridad, impacto de valor para el usuario venezolano y viabilidad técnica.

> 📜 **Histórico de Hitos Completados:** Para consultar el detalle técnico y la bitácora de todas las fases y tareas ya finalizadas, consulta [ROADMAP_HISTORICO.md](docs/archive/2026-Q4/ROADMAP_HISTORICO.md).

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

*Tareas integradas en `main` que permanecen en prueba técnica o en dispositivo físico:*

1. `UX-14` **Estado Vacío Contextual Inteligente y Sincronización Temporal de Sesión:** `Implementada 🔧`
   - Detección automática del último mes con compras en base de datos (`obtenerUltimoMesConGastos()`).
   - Botón directo al último período con registros en estados vacíos y `[Volver al mes actual]` en años históricos.
   - Deduplicación: un solo botón principal cuando el último mes con compras coincide con el mes actual. Flecha a la derecha del texto y botón secundario `OutlinedButton` con borde gris (commit `5ac3684`).
   - Restablecimiento automático al mes en curso tras inactividad mayor a 30 minutos al reanudar la app (`WidgetsBindingObserver`).
2. **Selector de Mes Responsivo en AppBar (Inicio, Gastos, Análisis, Más):** `Pendiente de validación 🧪`
   - Reubicación del selector de mes desde el cuerpo de las pantallas hacia el AppBar en las 4 pestañas principales.
   - Componente `AppBarMonthSelector` responsivo con 3 modos automáticos según ancho disponible (`Completo`, `Compacto`, `Mínimo`), protegido contra desbordes con `FittedBox`.
   - *Verificación:* CI Build 649 en verde (commit `0eb455a`), 22 pruebas unitarias y de widgets dedicadas.
3. **Fase 5 (Web): Sincronización del Registro y Edición de Gastos con App Móvil:** `Pendiente de validación 🧪`
   - Reorganización en 4 tarjetas idénticas a la app móvil (General, ¿En qué gastaste?, Monto total, ¿Cómo pagaste?).
   - Módulos puros `expense-money.js` y `category-classifier.js` con 11 pruebas unitarias (Node 24) validando paridad al céntimo (C1 a C6) y autoclasificación inteligente.
   - Eliminación de P2P en EUR, cálculo bidireccional de Bolívares/tasa cobrada en caja y protección de total dictado.
   - *Verificación:* CI Build 20 en verde (commit `14003f7`), validado en producción en `https://rindemas.cesarluis.com/panel`. Documentación técnica en `docs/DOC_SINCRONIZACION_PANEL_WEB.md`.
4. **Comparador de Precios v2 (Historial, Normalización de Comercios, Ventana Temporal y Paridad Web):** `Pendiente de validación 🧪`
   - Esquema SQLite v19 con columna `descripcion_norm`, backfill por lotes de 500 filas e índice dedicado `idx_items_gasto_desc_norm`.
   - Consulta única por lote `findPriceHistory` (límite 600, ventana máxima 60 días) y normalización de comercios (`normalizeCommerce` / `formatCommerceDisplay`).
   - Priorización de avisos en pantalla: Prioridad 1 mismo comercio (0 a 30 días), Prioridad 2 mejor precio del mercado (0 a 30 días), Prioridad 3 referencia neutra gris (31 a 60 días sin %). Silencio bajo 5%.
   - Mapeo por `clientKey` para eliminar desfasajes de lista al borrar artículos intermedios.
   - Paridad completa en panel web Astro (`price-comparator.js`, 14 tests nativos `node --test` y reactividad con debounce en `panel.astro`).
   - *Verificación:* CI Build 700 en verde (commit `02233c6`), pruebas unitarias y de widgets en `test/datasources/database_helper_migration_v19_test.dart`, `test/datasources/database_helper_price_history_test.dart` y `test/screens/review_expense_price_history_test.dart`. Documentación técnica en `docs/DOC_COMPARADOR_PRECIOS.md`.

---

## ⚠️ Decisión y Revisión Estratégica Obligatoria (Pendiente por César)

> **Documento canónico de análisis:** [`c:\Users\cesar\.gemini\antigravity\brain\76540cb9-a8d1-4d3f-8230-6bc5cb272025\consejo_arquitectura_rinde_mas.md`](file:///c:/Users/cesar/.gemini/antigravity/brain/76540cb9-a8d1-4d3f-8230-6bc5cb272025/consejo_arquitectura_rinde_mas.md)  
> *Auditoría cruzada y conciliación arquitectónica entre reportes de Gemini Flash, Gemini Argon y Claude Opus.*

### Estado de Implementación al 04/11/2026:

#### ✅ Ya Implementado en `main`:
1. **Arnés de pruebas SQLite real en memoria (`E0-01`):** Dependencia `sqflite_common_ffi` incorporada en `dev_dependencies` y validada en CI (commit `de17323`).
2. **Neutralización de tasas cableadas 850 / 474 (`E0-05a`):** Neutralizada la auto-reparación en segundo plano en `main_screen.dart` y `sync_service.dart` con `dryRun = true` (commit `de17323`).
3. **Logs desacoplados en CI:** Se eliminaron los auto-commits de error a `main`; `build_apk.yml` ahora sube `test_results.txt` como artefacto descargable de GitHub Actions (Build 641).
4. **Arquitectura de Arranque y Datos Local-First (`Prioridad 2`):** `Pendiente de validación 🧪`
   - Desacoplamiento de cold start en `main.dart` con `runApp()` inmediato y tareas diferidas post-frame.
   - Creación de `SyncCoordinator` con cerrojo de concurrencia, re-run secuencial, debounce de 2s en escrituras y throttle de 5 min en arranques rutinarios.
   - Bandeja de intenciones (`PendingLaunchAction`) en `NotificationService` sincronizada con `ScanQueueProvider.ready` para eliminar carreras de tiempo en recordatorios.
   - Documentación técnica y guía de validación en [`docs/DOC_ARRANQUE_LOCAL_FIRST.md`](docs/DOC_ARRANQUE_LOCAL_FIRST.md) (13 pruebas automatizadas dedicadas).
5. **Seguridad Crítica de Firma (Keystore) — `Pendiente de validación 🧪`:** `android_template/rindemas.jks` retirado de Git (respaldo cifrado fuera del repositorio) y firma inyectada desde GitHub Secrets (`ANDROID_KEYSTORE_*`). CI aborta si el SHA-1 restaurado no es `D3:85:0D:…` o si el AAB no queda firmado con SHA-256 `B2:06:E4:7B:…`. Rotación de la upload key diferida hasta la aprobación de Producción (ver nota de decisiones).
6. **Reproducibilidad y Congelación de CI/CD — `Completada ✅`:** Flutter fijado en `3.47.9`, `pubspec.lock` versionado (verificado idéntico al generado por el runner 3.47.9) con guarda anti-drift en CI y `cloud_functions` eliminado. Build 664 en verde (638 pruebas, commit `5219134`).

7. **Seguridad de IA, Cuotas, Galería e Integridad (A1a, B2, C1, C2):** `Completada ✅`
   - Estado: `Completada ✅` — Verificado y validado en dispositivo físico por César en *Rinde Más Dev* (Build 672, commit `87c8da0`).
   - A1a (Worker): Cuota compartida persistente con Cloudflare D1 (50/dia por UID, 20.000 global), fail-closed, corte VET (UTC-4). DESPLEGADO y verificado en produccion el 2026-11-10 (/health responde HTTP 200).
   - B2 (App): Copia de comprobantes en álbum "Rinde Más" de la galería del sistema activada por defecto, persistente fuera de la app. Aviso único verificado en primer guardado con foto y ausente en gastos manuales.
   - C1/C2 (IA/App): Saneamiento estricto de montos en `GeminiExtractionResult`, topes de cordura y validación semántica con tolerancia 0.50 en visión.
   - Pendiente adicional (B1): reglas de Firestore sin endurecer. Plan completo en docs/DOC_REGLAS_FIRESTORE_B1.md; requiere sesion dedicada con el emulador. El despliegue automatico de reglas ya fue cortado.

#### 🔴 Prioridades Inmediatas (Requieren decisión y acción de César):
1. **Rotación de la clave de subida (upload key):**
   - *Acción:* Ejecutar **después** de la aprobación de Producción. Requiere `keytool` (no hay JDK local: hacerlo vía CI), registrar la nueva SHA-1 para `com.cesarluis.rindemas.dev` y actualizar los 3 secretos. La app signing key de Google no cambia y las instalaciones existentes no se ven afectadas.

#### 🟡 Prioridades Medias / Mantenimiento:
- **Centralizar `_convertBudgetToLens`:** Diferida para ejecutarse dentro del hito `E0-03` (Integración en lectores móviles y pantallas) de la Fase 0 RM-03, evitando duplicar esfuerzo con fórmulas cambiarias que serán sustituidas por `ResumenLenteMonetario`.
- **Limpieza de Repositorio:** `Completada ✅` Purgados los 2.115 archivos de `firebase_functions/node_modules/` y desvinculado `test_results.txt` del árbol de Git e incorporado a `.gitignore`.
- **Decisión sobre Stash pendiente (`stash@{0}: wip-lote-4-ui`):** `Completada ✅` Descartado (`git stash drop`) tras comprobar con `git diff` que el 100% de los cambios en `lib/` fueron integrados en el commit `59c1b64` (Lote 4).

#### 🟢 Qué NO Implementar (Condicionado a métricas):
- **Búsqueda FTS5:** No conectar a ciegas. Utilizar tabla normalizada con consultas SQL `LIKE` indexadas únicamente si las métricas en dispositivo demuestran lentitud (> 300 ms).
- **Prohibido refactorizar o dividir `DatabaseHelper` o `ReviewExpenseScreen`** en pleno período de evaluación de Google Play.

---

## Fase 0: Integridad Financiera y Multimoneda (Iniciativa RM-03 — En Progreso 🔄)
*Contrato normativo [`docs/rm-03/contrato-v1.2.md`](docs/rm-03/contrato-v1.2.md), decisiones vinculantes `A-01` a `A-16` y `D-01` a `D-09`:*

- `E0-05a` **Neutralización de auto-reparaciones automáticas 850 / 474:** `Completada ✅` Neutralizada la ejecución en segundo plano en `main_screen.dart` y `sync_service.dart`; `dryRun = true` por defecto (commit `de17323`).
- `E0-01` **Arnés de pruebas SQLite real en memoria:** `Completada ✅` Dependencia `sqflite_common_ffi` incorporada en `dev_dependencies` y validada en CI (commit `de17323`).
- `E0-02` **Dominio monetario, tuplas inmutables y saneamiento de caché de tasas (A-07):** `Completada ✅` Aceptada técnicamente en 8.ª reauditoría adversarial ([`docs/rm-03/auditorias/octava-reauditoria-u1-u2-deepseek.md`](docs/rm-03/auditorias/octava-reauditoria-u1-u2-deepseek.md)). R-01, B-02, B-05, M-05, M-08, NEW-3b, N-09 y D-05 resueltos con 127 pruebas monetarias. CI Build 665 en verde (commit `b58965a`, run 42734265430). Visto bueno explícito de César otorgado en *Rinde Más Dev*.
- `E0-03` **Integración en lectores móviles, pantallas y panel web:** `Completada ✅` (A-16). Independencia estricta por moneda (D-04 / H-1), denominaciones visuales canónicas (D-07), bloqueo de `EUR + BS_USDT` en UI (A-04) y lectura sin invención de equivalencias (`resolvePersistedExpense` y `ResumenLenteMonetario`, A-16 / H-2). Validado en dispositivo físico por César en *Rinde Más Dev* (Build 678). Documentación completa en [`docs/DOC_E0_03_LECTORES_MULTIMONEDA.md`](docs/DOC_E0_03_LECTORES_MULTIMONEDA.md).
- `E0-04` **Sincronización atómica `synced = 0`, tombstones remotos y CAS:** `Completada ✅` (A-09, A-15, S3.2). CAS optimista con `marcarGastoSincronizadoCondicional`, defensa de tombstones `ConflictoTombstoneRemoto`, idempotencia post-crash `sonContenidoNegocioIdentico` con normalización canónica de categorías, allowlist estricta de metadatos en panel web y diálogo de confirmación de cambio de importe. Validado en dispositivo físico por César en *Rinde Más Dev* (Build 678). Documentación completa en [`docs/DOC_E0_04_SYNC_CAS_TOMBSTONES.md`](docs/DOC_E0_04_SYNC_CAS_TOMBSTONES.md).
- `E0-05b` **Protocolo de diagnóstico de datos existentes (Q01..Q20):** `Pendiente` Consultas de solo lectura sobre fixtures de prueba sin PII (A-14).

---

## Fase 5: Marketing, Lanzamiento y Tracción (En Progreso 🔄)
*Hitos para validar el producto con usuarios reales en Venezuela:*
- **Subida a Google Play Store (Closed Testing & Solicitud de Producción):** `Pendiente de validación 🧪` 14 días ininterrumpidos completados con 12 evaluadores activos (20/10/2026 - 03/11/2026). Cero bloqueos (crashes) y cero ANR reportados. Cuestionario de evaluación respondido y solicitud de acceso a producción enviada formalmente el 04/11/2026 (en revisión por Google Play). Documentación completa en [`docs/DOC_CUESTIONARIO_PRODUCCION.md`](docs/DOC_CUESTIONARIO_PRODUCCION.md).
  - **Estado verificado en Play Console al 05/11/2026:** la sección **Producción** aparece como **Inactivo** y el panel muestra *"Hemos recibido tu solicitud de acceso a producción. Estamos revisando tu formulario de solicitud. Enviaremos un correo al propietario de la cuenta con las novedades. Este proceso suele tardar 7 días o menos, pero en ocasiones puede llevar más tiempo."* (solicitud enviada el miércoles 04/11/2026 a las 07:42).
  - **Implicación operativa:** mientras Producción siga `Inactivo` no se puede crear un release de producción. El AAB `1.5.0 (669)` se sube a **prueba cerrada** y se promociona el mismo artefacto cuando Google apruebe.
- **Código QR de Descarga en Landing (Desktop):** `Pendiente` Incorporar tarjeta con código QR dinámico en `rindemas.cesarluis.com` para escanear e instalar directamente desde una PC.
- **Correo de Bienvenida Automatizado:** `Pendiente` Disparar correo de bienvenida y guía de primeros pasos cuando el usuario vincule su cuenta de Google (vía trigger de Cloud Functions o Firestore).
- **Ejecución del Plan de Crecimiento (Primeros 100 Usuarios):** `Pendiente` Despliegue de tácticas comunitarias y orgánicas en grupos venezolanos según `docs/DOC_BITACORA_MARKETING.md` y `.agents/skills/growth-first-100-users/SKILL.md`:
  - *Post de Victoria en Reddit:* Lanzamiento en `r/vzla` y `r/AskVenezuela` agradeciendo el apoyo de los evaluadores y compartiendo el enlace oficial de Google Play.
  - *Outreach a Micro-Creadores:* Acercamiento directo (cero comercial) a creadores de comparativas de supermercado (Forum, Farmatodo, Makro) y creadoras de gestión del hogar / compras familiares (25-54 años).
  - *Videos Formato F (Dilema del Bolívar):* Capitalizar búsquedas orgánicas de TikTok (*"cómo ahorrar si uno gana en bolívares"*).

---

## Fase 6.2: Refinamiento UX y Nuevas Herramientas Financieras (Planificada 📋)
*Mejoras derivadas de auditoría de interfaz, legibilidad y optimización de flujos:*

### Bloque A: Consistencia Visual y Semántica (UI)
- `UI-02` **Rediseño Modular de la Pestaña "Más":** `Pendiente de validación 🧪`
  - *Problema:* 11 tarjetas apiladas (~2.066 líneas monolíticas) con accesos dispersos y problemas de contraste en toggles/íconos.
  - *Solución:* Arquitectura modular (~1.5 alturas de pantalla) en `MoreScreen`, `MoreRatesCard` (3 mini-tarjetas internas, estado sin borde y botón refrescar a la derecha), `MoreToolsGrid` y `BcvLegalDisclaimerCard`. Rejilla Bento 2x2 unificada en blanco, tarjeta compacta de cuenta (con diálogo "ELIMINAR" en zona de peligro), 3 filas de ajustes (`Preferencias y datos` con `Moneda de reportes`, `Soporte y comunidad` y `Sobre Rinde Más` con `Ver en Google Play`) y pie compartido de aviso BCV + versión pasiva. Verificada en CI con build 693 (`fb7cecb`) y documentada en `docs/DOC_MAS_REDISENO.md`.

### Bloque B: Finanzas Bimonetarias y Flujos de Captura
- `UX-09` **Rediseño del Filtro de Comprobantes en "Gastos":** `Pendiente`
  - *Solución:* Incorporar un distintivo de recibo/clip (`🧾`) en las tarjetas que tienen fotografía adjunta y reemplazar el botón confuso de galería por un chip activo `[🧾 Con comprobante]` o ícono de filtro con estado evidente.
- `UX-15` **Selector y Autocompletado de Comercios Frecuentes:** `Pendiente`
  - *Problema:* El usuario debe teclear repetidamente los mismos nombres de comercios habituales (ej. Farmatodo, Automercado Plaza's, Central Madeirense, panadería local).
  - *Solución:* Al pulsar o enfocar el campo `¿Dónde compraste?`, desplegar una lista o chips de sugerencias rápidas con los comercios más frecuentes previamente registrados por el usuario una vez que acumule compras recurrentes, permitiendo seleccionarlo con un toque sin tener que escribirlo completo.
- `UX-16` **Sistema Ligero de Etiquetas (Tags) para Gastos:** `Pendiente`
  - *Problema:* Los usuarios solicitan clasificar gastos en conceptos específicos no cubiertos por las 8 categorías canónicas (como Entretenimiento, Comisiones bancarias, Mascotas u Ocio). Crear categorías libres rompería el catálogo canónico de `AppConstants.categorias`, la clasificación determinista de Gemini y la paridad con el panel web.
  - *Solución:* Permitir agregar una o más etiquetas opcionales (`#tags`) en `ReviewExpenseScreen` y formularios manuales, persistirlas en SQLite/Firestore y habilitar filtro por etiquetas en el historial sin alterar las 8 categorías fijas en presupuestos y radiografías.
- `UX-17` **Botón y Flujo de Referidos Simple ("Compartir Rinde Más con un familiar por WhatsApp"):** `Pendiente`
  - *Ubicación:* En `MoreScreen` (pantalla Más).
  - *Propósito:* Capitalizar la recomendación familiar boca a boca (hijos que le instalan la app a sus familiares).
  - *Acción:* Botón accesible que abre el diálogo nativo de compartir (`Share.share`) con texto predeterminado sin rodeos y enlace directo a la ficha de Google Play.
- `UX-18` **Evolución Mensual en Gráfica Única (Pantalla Análisis):** `Pendiente`
  - *Problema:* El usuario debe conmutar de mes a mes manualmente para comparar su gasto histórico o identificar tendencias de ahorro.
  - *Solución:* Incorporar en la pantalla Análisis una gráfica consolidada (barras o línea) que muestre el gasto total de los últimos meses (ej. 6 a 12 meses) en una sola vista, facilitando detectar picos de consumo y estacionalidad.

### Bloque C: Percepción con IA
- `AI-05` **Dictado Continuo por Voz, Blindaje Determinístico de Fechas y Alineación de Período:** `Completada ✅`
  - *Problema:* El motor nativo de voz borraba texto previo tras pausas cortas, Gemini alucinaba fechas desfasadas por falta de ancla temporal y el gasto guardado quedaba oculto visualmente por desfase del filtro mensual.
  - *Solución:*
    1. **Buffer de Voz Acumulativo:** Integración de `joinSpeechParts` y `shouldCommitPreviousSpeechSegment` para acumular segmentos confirmados entre pausas sin sobrescritura en `VoiceExpenseSheet` y `ChatScreen`.
    2. **Anclaje Temporal Determinista:** Inyección de `fecha_hoy` en cliente y Cloudflare Worker (`fechaReferenciaHoy`), con resolución determinista en `GeminiService.resolveSpokenExpenseDate` para calcular fechas relativas (*hoy*, *ayer*, *antier*, *hace X días*) e impedir alucinaciones del LLM.
    3. **Alineación de Filtro en Guardado:** `GastoProvider.agregarGasto` sincroniza automáticamente `_selectedYear` y `_selectedMonth` con la fecha del gasto antes de recargar datos en SQLite.
  - *Verificación:* CI Build 692 en verde (commit `1fdd815`), Worker desplegado (`6709639`), pruebas automatizadas en `voice_expense_sheet_test.dart` y validación física confirmada por César en *Rinde Más Dev*. Documentado en `docs/DOC_DICTADO_VOZ_CONTINUO.md`.
- `AI-06` **Imputación de IVA en Precios de Anaquel y Algoritmo del Centavo Residual:** `Pendiente`
  - *Problema:* Las facturas fiscales del SENIAT imprimen bases imponibles (sin IVA) para productos gravados `(G)`. Al extraer el ticket, la app crea un renglón artificial "Impuesto IVA" en categoría 'Otros', distorsionando los presupuestos por categoría y descalzando el comparador histórico de precios con las entradas manuales y por voz.
  - *Solución:* Imputar el 16% de IVA directamente en los productos gravados para reflejar el precio de anaquel que el usuario pagó en caja, preservar intactos los alimentos exentos `(E)`, resolver la discrepancia de $\pm 0,01$ mediante ajuste determinista en el producto gravado de mayor valor y mostrar la base fiscal como microcopy informativo en `ReviewExpenseScreen`.
- `AI-07` **Refinamiento de UX en Chat del Asistente (Sugerencias Verticales y Botón Dinámico):** `Pendiente`
  - *Problema:* Las sugerencias ocupan espacio disperso y la barra inferior mantiene dos botones simultáneos (micrófono y enviar), restando espacio al campo de texto.
  - *Solución:*
    1. **Sugerencias verticales y ergonómicas:** Disponer las sugerencias apiladas verticalmente (una debajo de la otra), alineadas a la derecha o al centro, con redacción corta, pocas opciones (2 a 3) y ubicadas en la zona de fácil alcance para el pulgar.
    2. **Botón dinámico estilo mensajería (WhatsApp):** Mostrar por defecto únicamente el icono de grabar audio. Al detectar texto en el campo de entrada (`onChanged`), conmutar fluidamente el icono a enviar, liberando espacio horizontal y previniendo pulsaciones accidentales.

### Bloque D: Nuevas Herramientas Financieras
- `FIN-14` **Flexibilidad y Opciones de Liquidación en Gastos Registrados en USDT:** `Pendiente`
  - *Problema:* Al seleccionar `USDT` como moneda de un gasto en `ReviewExpenseScreen`, la app aplica paridad 1:1 plana con el dólar (`helperText: 'Paridad 1:1 con USD'`) sin habilitar los métodos de liquidación (`BS_BCV`, `BS_USDT`, `DIVISA`) ni calcular el contravalor real en bolívares a tasa Binance P2P.
  - *Solución:* Permitir opciones de liquidación para gastos ingresados en `USDT` (ej. liquidado en Bolívares a tasa Binance P2P o pagado en USDT directo vía Binance Pay/cripto), almacenar el contravalor en Bolívares y USD con `tasaUsdt` de la fecha y mantener la consistencia en el switch de los 4 lentes sin alterar la inmutabilidad histórica.
- `FIN-15` **Soporte Nativo para Cashea y Compras en Cuotas (Flujo de Caja + Cuotas Programadas):** `Pendiente`
  - *Problema:* Registrar una compra con Cashea como 100% pagada el día 0 distorsiona el "Disponible para gastar" del mes actual y congela las cuotas futuras a una tasa BCV/USDT obsoleta (en Venezuela cada cuota cada 14 días se liquida en Bolívares a la tasa BCV vigente el día en que se paga la cuota).
  - *Solución:*
    1. **Selector `[ Contado | ⚡ Cashea / Cuotas ]` en captura:** Permite elegir inicial (`60%`, `50%`, `40%`, `20%` o manual) y número de cuotas (`3`, `6`, `9`, `12` cada 14 días) con algoritmo del centavo residual.
    2. **Criterio de Caja + Compromisos Visibles:** Solo la inicial pagada impacta el disponible actual; las cuotas futuras se generan como compromisos en USD con `estado_pago = 'PENDIENTE'` en sus fechas de vencimiento (+14, +28, +42 días), visibles en banner preventivo (*"⚡ Cuotas por pagar este mes"*).
    3. **Liquidación en 1 toque y notificaciones locales:** Avisos locales previos y botón `[ ✓ Pagar cuota ]` que precarga la tasa BCV del día, permite adjuntar captura de Pago Móvil y pasa a `'PAGADO'`.
    4. **Soporte en IA y Paridad Web:** Detección en voz/OCR e inyección en el Asistente IA. Ver [`docs/DOC_PLAN_CASHEA.md`](docs/DOC_PLAN_CASHEA.md).

### Bloque E: Respaldo y Soberanía de Datos (Local-First Backup)
- `BACKUP-01` **Exportación e Importación Completa con Comprobantes (.zip):** `Pendiente`
  - *Problema:* Al desinstalar y reinstalar la app, las fotos de comprobantes (`recibo_*.jpg`) se pierden ya que residen exclusivamente en el sandbox local del dispositivo.
  - *Solución:* Opción en Más para "Exportar copia de seguridad completa (.zip)" que empaqueta SQLite y comprobantes, y "Restaurar copia de seguridad (.zip)" vía `file_picker` con fusión transaccional sin colisiones.
- `BACKUP-02` **Importación Masiva y Migración desde Otras Apps (MyMoney Pro / CSV / Plantilla Excel):** `Pendiente`
  - *Problema:* Usuarios con historial extenso en otras apps (MyMoney Pro, 1Money, Gestor de Gastos, Excel) enfrentan alta fricción de migración.
  - *Solución:* Plantilla descargable oficial (`.csv`/`.xlsx`), detector automático de MyMoney Pro, cálculo histórico automático de tasas BCV para registros desde 2023, mapeo a las 8 categorías oficiales y guardado por lotes con vista previa.

### Bloque F: Retención, Hábitos y Gamificación (Sistema de Rachas y Recompensas Rinde)
- `RET-01` **Sistema de Hábitos Financieros, Rachas Protegidas y Puntos de Lealtad ("Puntos Rinde"):** `Pendiente`
  - *Problema:* Fricción del registro diario, culpa por abandono de racha ("sesgo de todo o nada") y falta de refuerzo positivo inmediato.
  - *Solución Basada en Psicología del Comportamiento:*
    1. **Puntos Rinde:** Micro-recompensa táctil y visual al guardar compras o consultar la calculadora cambiaria (tope diario anti-abuso de 5 acciones).
    2. **Rachas Protegidas y Botón "Hoy no gasté nada 👍":** Valida el autocontrol en días sin compras manteniendo la racha activa; salvavidas de racha (*Streak Freeze*).
    3. **Puesta al Día Semanal:** Recordatorio sobrio de fin de semana para escanear facturas acumuladas y calibración honesta de fin de mes sin reproches.
    4. **Canje Pro:** Posibilidad de canjear puntos por días de *Rinde Más Pro* (sin anuncios) y tokens adicionales de escaneo.

---

## Fase 6.1 (Remanente): Catálogo de Categorías
- **Revisión y Expansión de Categorías por Defecto:** `Pendiente` Evaluar la incorporación de nuevas categorías predeterminadas de uso habitual (ej. 'Vestimenta' / 'Ropa' o afines) para evitar la sobreutilización de 'Otros'. Requiere coordinar: asignación de color e icono en UI, ampliación de sinónimos en `AppConstants.normalizarCategoria`, actualización de prompts de categorización en IA (Cloudflare Worker), y paridad matemática/visual en el panel web.

---

## Fase 7: Arquitectura de Producción, Confiabilidad y Deuda Técnica

### Bloque A: Saneamiento de Deuda Técnica e Higiene de Repositorio (Auditoría Argon)

| Ítem / Área | Prioridad | Estado | Detalle |
| :--- | :---: | :---: | :--- |
| **Seguridad de Keystore de producción** | P0 | `Pendiente de validación 🧪` | `.jks` retirado de Git; firma desde GitHub Secrets con guardas de SHA-1/SHA-256 en CI (build 664). Falta rotación de upload key tras aprobación de Producción. |
| **Generar y versionar `pubspec.lock`** | P0 | `Completada ✅` | Versionado y verificado idéntico al generado por Flutter 3.47.9; CI falla si se desvía. |
| **Fijar versión de Flutter en CI** | P0 | `Completada ✅` | `flutter-version: '3.47.9'` fijado en `.github/workflows/build_apk.yml`. |
| **Desacoplar Cold Start en `main.dart`** | P0 | `Pendiente de validación 🧪` | Desacoplado cold start con `runApp()` inmediato y servicios diferidos post-frame. |
| **Coordinador Único de Sincronización (`SyncCoordinator`)** | P0 | `Pendiente de validación 🧪` | Centralizado en `SyncCoordinator` con cerrojo, debounce 2s y throttle 5m. |
| **Bandeja de Intenciones en Notificaciones** | P0 | `Pendiente de validación 🧪` | Consumo de `pendingAction` sincronizado con `ScanQueueProvider.ready`. |
| **Eliminar auto-commits de error en CI** | P0 | `Completada ✅` | Logs desacoplados como artefactos de GitHub Actions (Build 641). |
| **Neutralización tasas 850/474 en auto-reparaciones** | P0 | `Completada ✅` | Neutralizada la auto-reparación en segundo plano en `main_screen.dart` (commit `de17323`). |
| **Purgar `firebase_functions/node_modules/` de Git** | P1 | `Completada ✅` | Purgados 2.115 archivos del índice de Git sin afectar código local. |
| **Desvincular `test_results.txt` de Git** | P1 | `Completada ✅` | Desvinculado del índice y añadido a `.gitignore`. |
| **Centralizar `_convertBudgetToLens`** | P1 | `Diferida a E0-03` | Se resolverá en la unificación de lectura multimoneda (Fase 0 E0-03). |
| **Eliminar `cloud_functions` de `pubspec.yaml`** | P1 | `Completada ✅` | Paquete nunca importado en Dart; eliminado del `pubspec.yaml` y del `pubspec.lock`. |
| **Búsqueda histórica eficiente (tabla normalizada)** | P2 | `Pendiente` | Mantener en memoria mientras no haya lentitud; migrar a SQL indexado ante métricas > 300ms. |
| **Crear `ShoppingListProvider` / Repository** | P2 | `Pendiente` | Pantallas y chat siguen tocando `DatabaseHelper.instance` directo sin capa intermedia. |
| **Actualizar `README.md` a la realidad** | P2 | `Pendiente` | Sigue listando Cloud Functions y 8 archivos inexistentes del proyecto inicial. |
| **Archivar 24 docs Markdown de la raíz en `docs/`** | P2 | `Pendiente` | Planes históricos `DOC_*.md` finalizados siguen dispersos en la raíz del repositorio. |
| **Eliminar binarios locales y `fix.py`** | P3 | `Pendiente` | `app-release.apk` (57 MB), `scratch/*.apk` (~300 MB) y script temporal `fix.py` en disco. |

### Bloque B: Infraestructura y Capacidades de Producción (Bank-Grade)
- **Evaluación de Firebase AI Logic (`firebase_vertexai`):** `Pendiente` Evaluar migración de llamadas REST al SDK de Firebase Vertex AI en Flutter, integrando Firebase App Check y Remote Config.
- **Despliegue Dinámico y Configuración Remota (Firebase Remote Config):** `Pendiente` Configurar cuotas mensuales de IA, textos y parámetros de modelos desde el servidor sin requerir nuevo APK.
- **Manejo de Casos Borde en Facturas Locales (Corner Cases):** `Pendiente` Refinamiento para facturas térmicas dobladas, comprobantes mixtos con ítems en Bs y total en USD/"Ref", y marcadores de IVA exento/gravado.
- **Procesamiento Background Nativo:** `Pendiente` Migrar la cola local en Dart a un Background Worker real del sistema operativo (WorkManager / Firebase Cloud Tasks) para asegurar procesamiento incluso con la app cerrada.
- **Extracción Asistida por Confianza (Confidence Scores):** `Pendiente` Retorno de nivel de confianza por dato extraído con alerta "⚠️ Revisar" y diccionario personal local de aprendizaje.
- **Cifrado de Extremo a Extremo en Nube (E2EE / Zero-Knowledge Sync):** `Pendiente` Cifrado local con AES-256 de gastos y comprobantes antes de persistir en Firestore utilizando clave derivada de la contraseña del usuario.

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
- **Cuota Gratuita Base y Prevención del Anti-patrón Rial:** Prohibido imponer cuotas mensuales artificialmente bajas (ej. 10 a 15 facturas al mes) en la etapa de lanzamiento. El escaneo opera de forma abierta y generosa para el uso cotidiano familiar, protegido por el límite anti-abuso de 50 peticiones/día por UID en Cloudflare Gateway (`SEC-13`). El registro manual y por voz se mantienen siempre 100% ilimitados y gratuitos.
- **Publicidad en Transiciones Naturales:** Anuncios discretos tras guardar gastos para cubrir el costo de inferencia de usuarios gratuitos, cumpliendo Better Ads Standards.
- **Rinde Más Pro ($1,99/mes o $19,99/año):**
  - Experiencia Cero Publicidad (Zero Ads).
  - Categorías personalizadas ilimitadas (icono y color propio).
  - Exportación contable avanzada (PDF mensual con balance limpio; Excel/CSV con desglose completo ítem por ítem).
  - Sincronización y respaldo de fotos de comprobantes en la nube.
  - Consultas analíticas profundas al Asistente IA con comparativa de meses previos.
  - Modo Contable y Desglose Tributario Formal: Selector en Más para alternar entre Modo Anaquel (con IVA) y Modo Fiscal (base imponible desglosada), con exportación de libro fiscal de compras en Excel/PDF.
  - Soporte BYOK (*Bring Your Own Key*): Opción en Más para usuarios avanzados que conecten su propia clave de Google AI Studio / Gemini sin costo de servidor.
- **Optimización del Embudo de Conversión (Funnel):** Medición de eventos con Firebase Analytics y Paywalls contextuales no invasivos.
- **Métrica de Validación Financiera:** Meta de generar los primeros $50 USD en 30-60 días con 500-1.000 usuarios activos.
- **Alertas Proactivas de Inflación y Desvío:** Notificaciones inteligentes cuando productos frecuentes suban de precio o el ritmo de gasto comprometa el mes.
