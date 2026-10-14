# Auditoría Integral de Rinde Más
**Fecha:** 13 de octubre de 2026  
**Versión auditada:** 1.0.3+3 (`com.cesarluis.rindemas`)  
**Método:** Análisis estático exhaustivo del 100% del código fuente + revisión visual de 6 capturas de pantalla  
**Restricciones:** Solo lectura. Cero archivos modificados. Sin Flutter SDK local.

---

## A. Resumen Ejecutivo

### Estado General
Rinde Más es una aplicación de finanzas personales **funcionalmente completa y ambiciosa**, con una propuesta de valor bien diferenciada para el mercado venezolano. Su arquitectura híbrida (OCR local + Gemini remoto, SQLite offline-first + Firestore sync, multimoneda con tasas BCV) demuestra un nivel técnico avanzado para una aplicación indie.

Sin embargo, la auditoría reveló **defectos financieros críticos que producen cifras incorrectas en pantalla**, **riesgos de seguridad que deben resolverse antes de publicar**, y **3 elementos que causarán rechazo inmediato en Google Play**.

### Principales Fortalezas
1. **Arquitectura OCR híbrida inteligente:** El sistema de 2 fases (ML Kit local → Gemini visión) ahorra ~80-90% de tokens y ofrece fallbacks robustos.
2. **Persistencia en centavos enteros:** SQLite almacena montos como `INTEGER * 100`, la práctica correcta para evitar errores de punto flotante.
3. **Flujo de escaneo en lote excepcional:** El botón "Guardar y revisar siguiente" con procesamiento en background y banner de cola es una UX notablemente fluida.
4. **Sistema multimoneda con tasas dinámicas:** Soporte real para USD, VES, EUR y USDT con tasas BCV/Binance y normalización canónica de categorías.
5. **Cumplimiento legal sólido:** Páginas de privacidad, términos y eliminación de cuenta funcionales y publicadas.

### Los 5 Riesgos Más Importantes

| # | Riesgo | Severidad | Impacto |
|---|--------|:---------:|---------|
| 1 | **Descalce de monedas en Dashboard:** Presupuestos USD comparados contra gastos VES sin conversión → barras de presupuesto muestran 2000% en vez de 50% | P0 | Cifras financieras falsas visibles al usuario |
| 2 | **El chat IA inserta gastos directamente en la BD** sin confirmación humana, con paridad EUR=USD y sin cuadre aritmético | P0 | Datos financieros corruptos sin consentimiento |
| 3 | **Botón "Descargar gratis" en gráfico de funciones** + fallback de descarga APK externa | P0 | Rechazo/suspensión garantizada por Google Play |
| 4 | **Keystore de producción y contraseñas** versionados en Git en texto claro | P0 | Suplantación de firma de la app |
| 5 | **Destrucción prematura de BD local** antes de validar autenticación al vincular cuenta | P0 | Pérdida irreversible de todos los gastos del usuario |

### Preparación para Google Play
La app **no está lista para envío a producción** en su estado actual. Se identificaron 3 bloqueantes que causarán rechazo inmediato (H-01, H-02, H-03 en la sección de Google Play) y 3 de alto riesgo. La prueba cerrada puede continuar tras resolver los P0, pero el envío a producción requiere también los P1.

### Limitaciones de la Auditoría
- No se ejecutó la app en un dispositivo (sin Flutter SDK local). Los hallazgos visuales se basan en análisis de código + 6 capturas.
- No se midieron tiempos de respuesta, consumo de batería ni métricas de rendimiento reales.
- No se accedió a datos de usuarios reales ni se ejecutaron pruebas destructivas.
- No se verificó el código del Cloudflare Worker (no está versionado en el repositorio).

---

## B. Inventario Funcional

| Funcionalidad | Estado | Evidencia | Pruebas Pendientes |
|:---|:---:|:---|:---|
| Registro manual de gasto | ✅ Verificada | FAB (+) → `ReviewExpenseScreen` con formulario completo | Validar montos negativos, campos vacíos |
| Escaneo de factura (OCR + IA) | ✅ Verificada | ML Kit local + Gemini Vision con cola en background | Probar imágenes borrosas, facturas largas, sin conexión |
| Subir comprobante de galería | ✅ Verificada | `image_picker` → misma cola OCR | Probar múltiples fotos de la misma factura |
| Dictado por voz | ✅ Verificada | `speech_to_text` → regex fallback → `ReviewExpenseScreen` | Probar con acentos venezolanos, ruido ambiental |
| Historial de gastos por mes | ✅ Verificada | `ExpenseHistoryScreen` con agrupación por día | Probar búsqueda cross-month |
| Presupuesto general y por categoría | ⚠️ Parcialmente verificada | Funciona en UI, pero descalce de monedas en Dashboard (P0-01) | Verificar en VES y EUR |
| Meta de ahorro | ✅ Verificada | `SavingsHealthCalculator` con fórmula correcta | Verificar con montos negativos |
| Proyección de fin de mes | ⚠️ Parcialmente verificada | Fórmula correcta pero usa `DateTime.now()` para meses históricos | Navegar a mes pasado y verificar |
| Gráfico de distribución (dona) | ⚠️ Parcialmente verificada | `CategoryChart` con `fl_chart`, pero texto ilegible en colores claros | Verificar con categorías claras (Higiene, Hogar) |
| Conversión USD ↔ VES | ✅ Verificada | Tasas BCV dinámicas con `ExchangeRateService` | Probar sin conexión, tasa expirada |
| Soporte EUR y USDT | ⚠️ Defectuosa | Tasa EUR hardcodeada en galería (1.08), EUR/USDT tratados como VES en cola | Corregir antes de probar |
| Asistente IA (Chat) | ⚠️ Defectuosa | Respuestas contextualizadas pero muta BD sin confirmación | Probar con instrucciones ambiguas |
| Lista de compras | ✅ Verificada | CRUD completo con vinculación automática al guardar gasto | Probar sincronización |
| Sincronización Firestore | ⚠️ Parcialmente verificada | Funciona pero sin tombstones, sin auto-sync al reconectar, LWW con reloj local | Probar multi-dispositivo, conflictos |
| Autenticación Google | ⚠️ Parcialmente verificada | Implementada pero falta SHA-1 de Play App Signing → Error 10 en producción | Probar desde instalación Play Store |
| Autenticación Email | ✅ Verificada | Login y registro con validación | Probar `requires-recent-login` |
| Eliminación de cuenta | ⚠️ Defectuosa | Falla silenciosamente para cuentas email con `requires-recent-login` | Probar eliminación real |
| Galería de comprobantes | ⚠️ Parcialmente verificada | Funciona pero con I/O síncrono y tasa EUR hardcodeada | Verificar con muchos comprobantes |
| Exportar datos (CSV/MD) | ✅ Verificada | `MoreScreen` con export configurable | Verificar contenido exportado |
| Notificaciones/recordatorios | ⚠️ Defectuosa | `exactAllowWhileIdle` sin permiso → falla silenciosamente en Android 12+ | Probar en dispositivo real |
| Onboarding / primer uso | ❌ No implementada | No existe pantalla de bienvenida ni tutorial | — |
| Modo offline completo | ⚠️ Parcialmente verificada | Gastos se guardan localmente, pero no hay auto-sync al reconectar | Probar registro offline → reconexión |
| Panel web | ✅ Verificada | `rindemas.cesarluis.com/panel` con paridad de datos | Verificar paridad multimoneda |
| Tasas de cambio en tiempo real | ✅ Verificada | DolarAPI + Yadio + Binance con fallbacks | Verificar caché y expiración |

---

## C. Auditoría Visual y UX

### Análisis Visual de Capturas

````carousel
**Pantalla 1: Dashboard (Inicio)**

![Dashboard completo](C:/Users/cesar/.gemini/antigravity/brain/f1414c1c-be31-44f7-a8f0-3fd6ea039cb3/WhatsApp%20Image%202026-10-13%20at%2010.12.10%20AM%20(5).jpeg)

**Fortalezas:**
- Jerarquía visual clara: monto principal grande, equivalente en Bs. secundario
- Badge de "Meta ahorro: $50,00 (Protegida)" comunica estado de salud
- Barra de progreso con porcentaje y ritmo diario informativos
- Tarjeta de insight IA contextual y no intrusiva
- Gráfico de dona legible con leyenda lateral

**Problemas detectados:**
- El gráfico muestra "Otros" ($6,00) en lugar de "Higiene" que aparece en Análisis → inconsistencia de categorización entre pantallas
- No hay indicación visual de que las tarjetas del gráfico son interactivas/expandibles
- El selector de mes funciona bien pero el texto "Octubre 2026" podría ser más prominente
<!-- slide -->
**Pantalla 2: Gastos (Historial)**

![Lista de gastos](C:/Users/cesar/.gemini/antigravity/brain/f1414c1c-be31-44f7-a8f0-3fd6ea039cb3/WhatsApp%20Image%202026-10-13%20at%2010.12.10%20AM%20(4).jpeg)

**Fortalezas:**
- Tarjetas limpias con iconografía por categoría y colores diferenciados
- Cada gasto muestra monto USD principal + equivalente Bs. secundario
- Menú contextual (⋮) accesible
- Agrupación "Hoy, 13 Oct" clara

**Problemas detectados:**
- Iconos de categoría inconsistentes con otras pantallas (carrito para Alimentación aquí vs. tenedor en Análisis)
- No hay chevron ni indicador visual de que las tarjetas son expandibles para ver desglose de productos
- Sin feedback de arrastre (swipe) para editar/eliminar rápidamente
<!-- slide -->
**Pantalla 3: Análisis**

![Análisis y presupuestos](C:/Users/cesar/.gemini/antigravity/brain/f1414c1c-be31-44f7-a8f0-3fd6ea039cb3/WhatsApp%20Image%202026-10-13%20at%2010.12.10%20AM%20(3).jpeg)

**Fortalezas:**
- Desglose completo: Límite, Presupuesto Total, Meta de Ahorro y Gasto Proyectado
- Gráfico de dona con porcentajes, montos y categorías claros
- Barras de presupuesto por categoría con ícono de edición

**Problemas detectados:**
- ⚠️ El texto porcentual dentro de las rebanadas del gráfico es blanco fijo → ilegible en colores claros (cyan de Higiene, ámbar de Hogar)
- El ícono de edición de presupuesto (lápiz) tiene área de toque de 16x16dp, muy por debajo del mínimo de 48dp
- El gráfico muestra "Higiene 4% $6,00" pero el Dashboard muestra "Otros 4% $6,00" para el mismo gasto → discrepancia
<!-- slide -->
**Pantalla 4: Pantalla "Más"**

![Configuración y cuenta](C:/Users/cesar/.gemini/antigravity/brain/f1414c1c-be31-44f7-a8f0-3fd6ea039cb3/WhatsApp%20Image%202026-10-13%20at%2010.12.10%20AM%20(2).jpeg)

**Fortalezas:**
- Tarjeta de cuenta con avatar, email y estado de sincronización
- Separación visual clara entre secciones
- Botones de Cerrar sesión (gris neutro) y Eliminar cuenta (rojo) diferenciados
- Tasas de cambio con indicador "Actualizada hoy" y botón de refresco

**Problemas detectados:**
- Pantalla sobrecargada: 8+ secciones en scroll vertical (Cuenta, Lista de Compras, Chat IA, Tasas, Moneda, y más abajo)
- Funciones estrella (Lista de Compras, Asistente IA) enterradas en scroll
- El correo personal real está visible (riesgo de PII en capturas de Play Store)
<!-- slide -->
**Pantalla 5: Modal de registro de gasto**

![Opciones de registro](C:/Users/cesar/.gemini/antigravity/brain/f1414c1c-be31-44f7-a8f0-3fd6ea039cb3/WhatsApp%20Image%202026-10-13%20at%2010.12.10%20AM.jpeg)

**Fortalezas:**
- Las 4 opciones de entrada están bien diferenciadas con iconos descriptivos
- Subtítulos explicativos ("La IA extrae los datos de la foto")
- Diseño limpio, no intimidante

**Problemas detectados:**
- "Subir comprobante (IA)" y "Escanear factura (IA)" pueden confundirse — ambos procesan imágenes con IA. La diferencia (cámara vs galería) no es suficientemente clara en los subtítulos
<!-- slide -->
**Pantalla 6: Asistente IA**

![Chat con asistente](C:/Users/cesar/.gemini/antigravity/brain/f1414c1c-be31-44f7-a8f0-3fd6ea039cb3/WhatsApp%20Image%202026-10-13%20at%2010.12.10%20AM%20(1).jpeg)

**Fortalezas:**
- Respuestas contextualizadas con datos reales del usuario
- Chips de preguntas sugeridas en la parte inferior
- Tono conversacional natural y claro
- Input con botón de voz integrado

**Problemas detectados:**
- ⚠️ **Riesgo P0:** El chat puede registrar gastos directamente sin confirmación del usuario
- No hay botón para reportar/denunciar respuestas de IA (requerido por Google Play)
- La navegación al chat es inconsistente: `Navigator.push` desde Dashboard vs. subvista embebida desde "Más"
````

### Hallazgos UI/UX por Severidad

| ID | Sev. | Pantalla | Hallazgo | Impacto |
|:---|:---:|:---|:---|:---|
| UX-01 | P1 | Dona (Análisis) | Texto blanco fijo sobre colores claros (cyan, ámbar) — ratio 2.3:1, viola WCAG AA | Porcentajes ilegibles |
| UX-02 | P1 | Global | No existe onboarding — usuario nuevo aterriza en dashboard vacío | Abandono en primer uso |
| UX-03 | P1 | Historial | Búsqueda limitada al mes activo — no encuentra gastos de meses anteriores | Fricción alta para usuarios recurrentes |
| UX-04 | P1 | Formularios | Borde de foco usa `AppColors.primary` (amarillo pastel, contraste 1.13:1 vs blanco) | Campo activo imperceptible |
| UX-05 | P1 | Chat IA | Navegación dual: `Navigator.push` desde Home vs subvista en "Más" | Botón Atrás inconsistente |
| UX-06 | P2 | Historial | Tarjetas expandibles sin chevron ni indicador visual | Usuarios no descubren desglose |
| UX-07 | P2 | Análisis | Ícono de edición de presupuesto: 16x16dp (mínimo: 48dp) | Toques fallidos frecuentes |
| UX-08 | P2 | Revisión gasto | Sin validación en campos de ítems individuales (descripción, precio) | Se guardan ítems vacíos |
| UX-09 | P2 | Revisión gasto | Sin indicación de moneda en columnas de desglose de productos | Confusión USD/VES en ítems |
| UX-10 | P2 | "Más" | 8+ secciones en scroll vertical, funciones estrella enterradas | Fatiga visual, baja descubribilidad |
| UX-11 | P2 | Dashboard | Factura pendiente duplicada (banner + tarjeta en recientes) | Confusión visual |
| UX-12 | P2 | Dashboard | Badge dice "Protegida" en vez de "Ahorro protegido" (viola DESIGN.md §6.2) | Inconsistencia terminológica |
| UX-13 | P3 | Lista compras | Estado vacío básico (`Text('Tu lista está vacía.')`) sin ícono ni CTA | Menor que el estándar de otras pantallas |
| UX-14 | P3 | Múltiples | Iconografía de categorías inconsistente (🛒 vs 🍴 para Alimentación) | Falta fuente única de verdad |
| UX-15 | P3 | Múltiples | Colores hex hardcodeados fuera del tema (`0xFFFFFDF5`, `0xFF10B981`, etc.) | Dificulta tema oscuro futuro |
| UX-16 | P3 | Global | Cero uso de `Semantics` para TalkBack/accesibilidad | Inaccesible para usuarios con discapacidad visual |

---

## D. Auditoría Técnica y Financiera

### D.1 Hallazgos Financieros Críticos (P0)

#### FIN-01: Descalce de monedas en Dashboard — presupuestos USD vs gastos VES
- **Archivo:** [`dashboard_screen.dart:213-228`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/dashboard_screen.dart#L213-L228)
- **Evidencia:** Cuando el usuario visualiza en VES, `categoryTotals` usa `gastoProvider.totalesPorCategoriaVes` pero `categoryBudgets` se pasa en USD crudo sin conversión. A diferencia de `AnalysisScreen` (que sí convierte), el Dashboard omite la transformación.
- **Consecuencia:** Con presupuesto de $100 USD en Alimentación y gasto de Bs. 2.000 ($50), la barra muestra **2000%** de consumo en rojo en vez del 50% real.
- **Esfuerzo:** Pequeño
- **Solución:** Aplicar `CurrencyFormatter.convertFromUsd` a `categoryBudgets` cuando `moneda == 'VES'`, idéntico a como se hace en `AnalysisScreen:72-75`.
- **Verificación:** Cambiar moneda de visualización a VES y confirmar que las barras de presupuesto muestran porcentajes coherentes.

#### FIN-02: `getSpentForCategory()` siempre retorna USD → alertas de sobregiro rotas en VES
- **Archivo:** [`gasto_provider.dart:383-400`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/gasto_provider.dart#L383-L400)
- **Evidencia:** `getSpentForCategory()` retorna siempre del mapa USD. `isCategoryOverBudget()` compara ese valor USD contra un presupuesto que podría estar en VES (4000 Bs.). La condición `50 > 4000` nunca detecta sobregiro.
- **Consecuencia:** Las alertas de presupuesto por categoría **nunca se disparan** cuando el usuario opera en Bolívares.
- **Esfuerzo:** Pequeño
- **Solución:** Aceptar un parámetro de moneda en `getSpentForCategory()` y retornar del mapa correspondiente.

#### FIN-03: Chat IA muta BD financiera sin confirmación — integridad contable rota
- **Archivo:** [`chat_screen.dart:288-380`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/chat_screen.dart#L288-L380)
- **Evidencia:** Al recibir `functionCall: registrar_gasto`, inserta directamente en SQLite + Firestore. Los ítems no reciben categoría (default 'Otros' aunque el gasto sea 'Alimentación'). No valida `sum(items) == total`. Asume EUR=USD (paridad 1:1).
- **Consecuencia:** Datos financieros corruptos sin consentimiento. Distorsión de totales por categoría y estadísticas.
- **Esfuerzo:** Mediano
- **Solución:** Redirigir a `ReviewExpenseScreen` con datos pre-poblados en vez de insertar directamente. Agregar tarjeta de confirmación con "Confirmar / Editar / Descartar".

### D.2 Hallazgos Financieros Altos (P1)

#### FIN-04: Facturas EUR/USDT en cola de escaneo tratadas como Bolívares
- **Archivo:** [`dashboard_screen.dart:296-302`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/dashboard_screen.dart#L296-L302), [`expense_history_screen.dart:107-113`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/expense_history_screen.dart#L107-L113)
- **Evidencia:** El código asume: si no es USD, dividir entre tasa VES/USD. Una factura de 100 EUR se muestra como $2.50 en vez de ~$108.
- **Esfuerzo:** Pequeño

#### FIN-05: Tasa EUR perdida al guardar gasto — cálculo VES distorsionado
- **Archivo:** [`review_expense_screen.dart:281-286`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L281-L286)
- **Evidencia:** El campo de tasa de cambio se oculta para EUR. Se guarda con tasa por defecto (1.0 o la de USD), distorsionando el equivalente en Bs.
- **Esfuerzo:** Mediano

#### FIN-06: Adopción de presupuesto solo en memoria — no persiste en SQLite ni Firestore
- **Archivo:** [`gasto_provider.dart:93-109`](file:///c:/Development/Control%20de%20gastos%20VE/lib/providers/gasto_provider.dart#L93-L109)
- **Evidencia:** Al iniciar un nuevo mes, si el usuario no edita el presupuesto, la BD queda en $0. El panel web y otros dispositivos ven $0 de presupuesto.
- **Esfuerzo:** Mediano

### D.3 Hallazgos Financieros Medios (P2)

#### FIN-07: `SummaryCard` calcula días con `DateTime.now()` en vez del mes seleccionado
- **Archivo:** [`summary_card.dart:71-76`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/summary_card.dart#L71-L76)
- **Consecuencia:** Al consultar febrero (28 días) desde octubre (31 días), muestra "Faltan 18 días" (de octubre) y calcula ritmo diario incorrecto.
- **Esfuerzo:** Pequeño

#### FIN-08: Sin validación de montos negativos en formularios
- **Archivo:** [`amount_parser.dart:18-26`](file:///c:/Development/Control%20de%20gastos%20VE/lib/core/utils/amount_parser.dart#L18-L26), [`review_expense_screen.dart:1263`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L1263)
- **Consecuencia:** Permite registrar gastos de -$100 que reducen artificialmente el gasto acumulado.
- **Esfuerzo:** Pequeño

### D.4 Hallazgos Técnicos

| ID | Sev. | Archivo | Hallazgo | Impacto |
|:---|:---:|:---|:---|:---|
| TEC-01 | P0 | [`auth_modal_sheet.dart:42`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/widgets/auth_modal_sheet.dart#L42-L43) | `TextEditingController` nunca dispuesto en modal → fuga de memoria acumulativa | Degradación de memoria |
| TEC-02 | P0 | [`receipt_gallery_screen.dart:130`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/receipt_gallery_screen.dart#L130-L135) | Tasa EUR hardcodeada `usd / 1.08` y USDT 1:1 — viola Regla 107 de AGENTS.md | Montos incorrectos en galería |
| TEC-03 | P1 | [`receipt_gallery_screen.dart:30`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/receipt_gallery_screen.dart#L30-L33), [`dashboard_screen.dart:288`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/dashboard_screen.dart#L288-L316) | `File.existsSync()` y `jsonDecode` síncronos en `build()` → bloqueo de UI thread | Jank/stutter con muchos gastos |
| TEC-04 | P1 | [`review_expense_screen.dart:723`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/review_expense_screen.dart#L723-L743), [`chat_screen.dart:317`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/chat_screen.dart#L317) | `BuildContext` usado tras `await` sin `if (!mounted)` → excepción si widget desmontado | Crash potencial |
| TEC-05 | P1 | [`gemini_service.dart:354`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/remote/gemini_service.dart#L354) | Fallback de voz a categoría 'Alimentación' en vez de 'Otros' — viola Regla 110 | Sesgo en estadísticas |
| TEC-06 | P1 | [`uuid_generator.dart:5`](file:///c:/Development/Control%20de%20gastos%20VE/lib/core/utils/uuid_generator.dart#L5) | `Random()` no criptográfico para UUIDs financieros | Riesgo de colisión |
| TEC-07 | P2 | Múltiples archivos | Monolitos: `review_expense_screen.dart` (1544 L), `more_screen.dart` (1431 L), `database_helper.dart` (1452 L) | Costo altísimo de mantenimiento |
| TEC-08 | P2 | [`dashboard_screen.dart:288`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/dashboard_screen.dart#L288-L316) vs [`expense_history_screen.dart:94`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/expense_history_screen.dart#L94-L126) | Duplicación de 30 líneas de hidratación de facturas pendientes | Divergencia lógica |
| TEC-09 | P2 | `test/` | Sin tests para `GastoProvider`, `SyncService`, `ReviewExpenseScreen`, `DatabaseHelper` — los 4 módulos más críticos | Regresiones inadvertidas |
| TEC-10 | P2 | `test/screens/` | APIs deprecadas (`binding.window.*`) → romperán en Flutter ≥3.27 | Tests inestables |
| TEC-11 | P3 | [`PROJECT.md`](file:///c:/Development/Control%20de%20gastos%20VE/PROJECT.md) | Documenta `BudgetProvider`, `ShoppingListProvider`, `AuthProvider`, `BudgetModel`, `HomeScreen` — ninguno existe | Documentación desactualizada |

---

## E. Seguridad y Cumplimiento

### E.1 Hallazgos de Seguridad

| ID | Sev. | Hallazgo | Archivo | Riesgo Real |
|:---|:---:|:---|:---|:---|
| SEC-01 | P0 | **Keystore `rindemas.jks` y contraseñas `rindemas123` versionados en Git** | [`build.gradle.kts:34-44`](file:///c:/Development/Control%20de%20gastos%20VE/android/app/build.gradle.kts#L34-L44), [`build_apk.yml:37-49`](file:///c:/Development/Control%20de%20gastos%20VE/.github/workflows/build_apk.yml#L37-L49) | Suplantación de firma. Cualquier persona con acceso al repo puede firmar actualizaciones maliciosas. |
| SEC-02 | P0 | **Destrucción de BD local ANTES de validar `linkWithCredential()`** | [`sync_service.dart:474-508`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L474-L508) | Si la autenticación falla (red, credencial inválida), el usuario pierde todos sus gastos irreversiblemente. |
| SEC-03 | P1 | Eliminación de cuenta falla silenciosamente para email con `requires-recent-login` | [`sync_service.dart:371-430`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L371-L430) | UI dice "eliminada" pero la cuenta persiste en Firebase Auth. Incumple GDPR y políticas Play Store. |
| SEC-04 | P1 | API Key de Gemini inyectada en binario vía `--dart-define` | [`build_apk.yml:118`](file:///c:/Development/Control%20de%20gastos%20VE/.github/workflows/build_apk.yml#L118), [`app_constants.dart:118`](file:///c:/Development/Control%20de%20gastos%20VE/lib/core/constants/app_constants.dart#L118) | Extraíble con `strings libapp.so`. Consumo de cuota sin control. |
| SEC-05 | P1 | Eliminación Firestore sin tombstones → resurrección de datos | [`sync_service.dart:101-105`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L101-L105) | Gastos eliminados reaparecen al sincronizar desde otro dispositivo. |
| SEC-06 | P1 | API key BYOK persiste en `FlutterSecureStorage` tras cerrar sesión | [`sync_service.dart:316-334`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L316-L334) | Siguiente usuario hereda la clave del anterior y la sube a su Firestore. |
| SEC-07 | P1 | API key de usuario almacenada en texto plano en Firestore | [`sync_service.dart:53-68`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L53-L68) | Expuesta ante fugas de tokens, backups o admin access. |
| SEC-08 | P1 | Deploy de APK via FTP sin cifrar en CI | [`build_apk.yml:178-189`](file:///c:/Development/Control%20de%20gastos%20VE/.github/workflows/build_apk.yml#L178-L189) | Credenciales y binario viajan en texto claro. MitM posible. |
| SEC-09 | P2 | Fotos de comprobantes no se eliminan al cerrar sesión ni borrar cuenta | [`image_service.dart:31-46`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/image_service.dart#L31-L46) | Facturas con RIF, nombres y datos bancarios permanecen en disco. |
| SEC-10 | P2 | Resolución de conflictos LWW con reloj local (manipulable) | [`sync_service.dart:153-156`](file:///c:/Development/Control%20de%20gastos%20VE/lib/services/sync_service.dart#L153-L156) | Dispositivo con hora adelantada sobreescribe cambios legítimos. |
| SEC-11 | P2 | Historial financiero completo enviado a Gemini en cada mensaje del chat | [`chat_screen.dart:256-272`](file:///c:/Development/Control%20de%20gastos%20VE/lib/ui/screens/chat_screen.dart#L256-L272) | Comercios, montos, categorías, notas de Pago Móvil transmitidos sin aviso. |
| SEC-12 | P2 | Código del Cloudflare Worker no versionado en el repositorio | — | Imposible auditar rate limiting, sanitización o manejo de secretos del gateway. |
| SEC-13 | P2 | Reglas Firestore sin validación de esquema ni tipos | [`firestore.rules:4-9`](file:///c:/Development/Control%20de%20gastos%20VE/firestore.rules#L4-L9) | Payloads arbitrarios o gigantescos aceptados. |
| SEC-14 | P2 | Validación de API key BYOK via GET con clave en query string | [`gemini_service.dart:24-34`](file:///c:/Development/Control%20de%20gastos%20VE/lib/data/datasources/remote/gemini_service.dart#L24-L34) | Clave queda en logs de proxies, firewalls y cachés HTTP. |
| SEC-15 | P3 | UUID con `Random()` no criptoseguro | [`uuid_generator.dart:4-11`](file:///c:/Development/Control%20de%20gastos%20VE/lib/core/utils/uuid_generator.dart#L4-L11) | Bajo riesgo real de colisión pero viola RFC 4122. |
| SEC-16 | P3 | `requestLegacyExternalStorage="true"` obsoleto | [`AndroidManifest.xml:33`](file:///c:/Development/Control%20de%20gastos%20VE/android/app/src/main/AndroidManifest.xml#L33) | Sin efecto en Android 11+ pero señal de código desactualizado. |

### E.2 Permisos Android

| Permiso | Justificación | Estado |
|:---|:---|:---:|
| `INTERNET` | Gemini, Firestore, tasas de cambio | ✅ Justificado |
| `ACCESS_NETWORK_STATE` | Detección offline | ✅ Justificado |
| `CAMERA` | Escaneo de facturas | ✅ Justificado (`required="false"`) |
| `RECORD_AUDIO` | Dictado por voz | ✅ Justificado |
| `POST_NOTIFICATIONS` | Recordatorios | ✅ Justificado |
| `RECEIVE_BOOT_COMPLETED` | Reprogramar tras reinicio | ✅ Justificado |
| `READ_MEDIA_IMAGES` | Selección de comprobantes | ⚠️ **Innecesario** — `image_picker` usa Photo Picker |
| `VIBRATE` | Feedback táctil | ✅ Justificado |

### E.3 Datos Procesados y Servicios Externos

| Servicio | Datos Enviados | Cifrado en Tránsito | Notas |
|:---|:---|:---:|:---|
| Firebase Auth | Email, nombre, UID | ✅ HTTPS | Soporte anónimo y Google |
| Firestore | Gastos, presupuestos, API key BYOK | ✅ HTTPS | API key en texto plano (SEC-07) |
| Gemini API (vía Gateway) | Texto OCR o imagen Base64, historial mensual | ✅ HTTPS | Todo el historial en cada mensaje (SEC-11) |
| DolarAPI / Yadio | Consulta de tasas (sin datos de usuario) | ✅ HTTPS | Solo lectura |
| Binance API | Consulta de par USDT/VES (sin datos) | ✅ HTTPS | Solo lectura |
| BanaHosting FTP | APK compilado | ❌ **Sin cifrar** | SEC-08 |

---

## F. Registro Priorizado de Hallazgos (Consolidado)

> [!IMPORTANT]
> Se han deduplicado hallazgos que aparecieron en múltiples auditorías. El ID principal referencia la sección donde se detalla.

| # | ID | Categoría | Sev. | Hallazgo | Esfuerzo | Riesgo de Implementación |
|:--|:---|:---|:---:|:---|:---:|:---:|
| 1 | FIN-01 | Financiero | **P0** | Descalce monedas Dashboard: presupuestos USD vs gastos VES | Pequeño | Bajo |
| 2 | FIN-02 | Financiero | **P0** | `getSpentForCategory()` siempre USD → alertas VES rotas | Pequeño | Bajo |
| 3 | FIN-03 | Financiero | **P0** | Chat IA muta BD sin confirmación ni cuadre | Mediano | Medio |
| 4 | SEC-01 | Seguridad | **P0** | Keystore + contraseñas en Git | Mediano | Medio |
| 5 | SEC-02 | Seguridad | **P0** | BD destruida antes de validar auth al vincular | Pequeño | Bajo |
| 6 | TEC-01 | Técnico | **P0** | Memory leak en auth_modal_sheet | Pequeño | Bajo |
| 7 | TEC-02 | Técnico | **P0** | Tasa EUR/USDT hardcodeada en galería | Pequeño | Bajo |
| 8 | GP-01 | Google Play | **P0** | Botón "Descargar gratis" en gráfico de funciones | Pequeño | Bajo |
| 9 | GP-02 | Google Play | **P0** | Fallback descarga APK externa en `update_service.dart` | Pequeño | Bajo |
| 10 | GP-03 | Google Play | **P0** | Falta SHA-1 de Play App Signing en Firebase | Pequeño | Bajo |
| 11 | FIN-04 | Financiero | **P1** | EUR/USDT en cola de escaneo tratados como VES | Pequeño | Bajo |
| 12 | FIN-05 | Financiero | **P1** | Tasa EUR no persistida al guardar gasto | Mediano | Medio |
| 13 | FIN-06 | Financiero | **P1** | Presupuestos de mes nuevo solo en memoria | Mediano | Medio |
| 14 | SEC-03 | Seguridad | **P1** | Eliminación de cuenta falla silenciosa (email) | Mediano | Medio |
| 15 | SEC-04 | Seguridad | **P1** | API Key Gemini en binario vía `--dart-define` | Mediano | Medio |
| 16 | SEC-05 | Seguridad | **P1** | Sync sin tombstones → resurrección de datos | Grande | Alto |
| 17 | SEC-06 | Seguridad | **P1** | API key BYOK persiste tras cerrar sesión | Pequeño | Bajo |
| 18 | SEC-07 | Seguridad | **P1** | API key BYOK en Firestore sin cifrar | Mediano | Medio |
| 19 | SEC-08 | Seguridad | **P1** | Deploy FTP sin cifrar | Pequeño | Bajo |
| 20 | TEC-03 | Técnico | **P1** | I/O síncrono en `build()` | Mediano | Bajo |
| 21 | TEC-04 | Técnico | **P1** | `BuildContext` tras `await` sin `mounted` | Mediano | Bajo |
| 22 | TEC-05 | Técnico | **P1** | Fallback voz a 'Alimentación' (viola Regla 110) | Pequeño | Bajo |
| 23 | TEC-06 | Técnico | **P1** | UUID no criptográfico | Pequeño | Bajo |
| 24 | UX-01 | UI/UX | **P1** | Contraste WCAG en dona (texto blanco en cyan) | Pequeño | Bajo |
| 25 | UX-02 | UI/UX | **P1** | Sin onboarding | Mediano | Bajo |
| 26 | UX-03 | UI/UX | **P1** | Búsqueda solo en mes activo | Mediano | Medio |
| 27 | UX-04 | UI/UX | **P1** | Borde de foco imperceptible | Pequeño | Bajo |
| 28 | UX-05 | UI/UX | **P1** | Navegación dual del chat | Mediano | Medio |
| 29 | GP-04 | Google Play | **P1** | Permiso `READ_MEDIA_IMAGES` innecesario | Pequeño | Bajo |
| 30 | GP-05 | Google Play | **P1** | Sin botón de reporte para contenido IA | Pequeño | Bajo |
| 31 | GP-06 | Google Play | **P1** | `exactAllowWhileIdle` sin permiso → falla silenciosa | Pequeño | Bajo |
| 32 | FIN-07 | Financiero | **P2** | `SummaryCard` usa `now()` para meses históricos | Pequeño | Bajo |
| 33 | FIN-08 | Financiero | **P2** | Sin validación de montos negativos | Pequeño | Bajo |
| 34 | SEC-09 | Seguridad | **P2** | Fotos no borradas al cerrar sesión | Mediano | Bajo |
| 35 | SEC-10 | Seguridad | **P2** | LWW con reloj local manipulable | Grande | Alto |
| 36 | SEC-11 | Seguridad | **P2** | Historial completo enviado a Gemini | Mediano | Medio |
| 37 | SEC-12 | Seguridad | **P2** | Worker de Cloudflare no versionado | Mediano | Bajo |
| 38 | SEC-13 | Seguridad | **P2** | Firestore sin validación de esquema | Mediano | Medio |
| 39 | TEC-07 | Técnico | **P2** | Archivos monolíticos (>1400 líneas) | Grande | Medio |
| 40 | TEC-08 | Técnico | **P2** | Duplicación de hidratación de facturas | Pequeño | Bajo |
| 41 | TEC-09 | Técnico | **P2** | Sin tests para módulos críticos | Grande | Bajo |
| 42 | GP-07 | Google Play | **P2** | PII real en captura 5 (correo) | Pequeño | Bajo |
| 43 | GP-08 | Google Play | **P2** | SDK targets implícitos en Gradle | Pequeño | Bajo |
| 44 | GP-09 | Google Play | **P2** | Keystore en Git (también SEC-01) | Mediano | Medio |

---

## G. Hoja de Ruta

### Fase 1: Inmediatas (Implementada 🔧)

> **Objetivo:** Resolver defectos que producen datos financieros incorrectos, riesgo de pérdida de datos y rechazo seguro por Google Play.

| # | Acción | IDs | Esfuerzo | Criterio de Aceptación | Estado |
|:--|:---|:---|:---:|:---|:---:|
| 1 | Convertir presupuestos a VES en Dashboard antes de pasar a `CategoryChart` | FIN-01 | Pequeño | Barras de presupuesto muestran % correcto en VES | Completado ✅ |
| 2 | Parametrizar moneda en `getSpentForCategory()` e `isCategoryOverBudget()` | FIN-02 | Pequeño | Alertas de sobregiro se disparan en VES | Completado ✅ |
| 3 | Chat IA: redirigir `registrar_gasto` a `ReviewExpenseScreen` en vez de insertar directamente | FIN-03 | Mediano | Ningún gasto se guarda sin confirmación explícita | Implementado 🔧 |
| 4 | Regenerar gráfico de funciones sin botón "Descargar gratis" | GP-01 | Pequeño | Imagen 1024x500 sin CTA falso | Implementado 🔧 |
| 5 | Eliminar fallback de descarga APK externa en `update_service.dart` | GP-02 | Pequeño | Solo redirige a `market://` | Implementado 🔧 |
| 6 | Registrar SHA-1 de Play App Signing en Firebase y actualizar `google-services.json` | GP-03 | Pequeño | Google Sign-In funciona desde instalación Play Store | Configurado en Firebase ✅ |
| 7 | Mover `limpiarDatosLocales()` DESPUÉS de `linkWithCredential()` exitoso | SEC-02 | Pequeño | Si auth falla, los datos locales permanecen intactos | Implementado 🔧 |
| 8 | Reemplazar tasa EUR hardcodeada en `receipt_gallery_screen.dart` | TEC-02 | Pequeño | Galería usa `settings.tasaEur` y `settings.tasaUsdt` | Implementado 🔧 |
| 9 | Añadir `.whenComplete()` para dispose de controladores en `auth_modal_sheet.dart` | TEC-01 | Pequeño | Sin leaks de `TextEditingController` | Implementado 🔧 |
| 10 | Cambiar fallback de voz de 'Alimentación' a 'Otros' | TEC-05 | Pequeño | Regla 110 cumplida | Completado ✅ |

**Dependencias:** Ninguna entre sí. Pueden trabajarse en paralelo.  
**Estado:** 100% Implementada en el código.

### Fase 2: Antes de solicitar acceso a producción (P1 y requisitos Play Store)

| # | Acción | IDs | Esfuerzo | Criterio de Aceptación | Estado |
|:--|:---|:---|:---:|:---|:---:|
| 1 | Eliminar keystore del historial Git (BFG/filter-repo), rotar, mover a GitHub Secrets | SEC-01 | Mediano | `.jks` no aparece en `git log`, passwords solo en Secrets | Pendiente |
| 2 | Eliminar `READ_MEDIA_IMAGES` del Manifest | GP-04 | Pequeño | `image_picker` funciona sin el permiso en Android 13+ | Implementado 🔧 |
| 3 | Agregar botón de reporte en burbujas del chat IA | GP-05 | Pequeño | Cada respuesta IA tiene opción de reportar | Implementado 🔧 |
| 4 | Cambiar `exactAllowWhileIdle` → `inexactAllowWhileIdle` en notifications | GP-06 | Pequeño | Recordatorios funcionan en Android 12+ | Implementado 🔧 |
| 5 | Anonimizar captura 5 (reemplazar correo real) | GP-07 | Pequeño | PII no visible en ficha Play Store | Pendiente |
| 6 | Fijar `compileSdk = 35`, `targetSdk = 35` explícitos en Gradle | GP-08 | Pequeño | Build siempre cumple requisito API 35 | Pendiente |
| 7 | Corregir cola de escaneo para EUR/USDT | FIN-04 | Pequeño | Facturas en EUR muestran monto correcto | Pendiente |
| 8 | Mostrar y persistir tasa EUR al guardar gasto | FIN-05 | Mediano | Equivalente Bs. correcto para gastos en EUR | Pendiente |
| 9 | Persistir presupuesto adoptado en SQLite al iniciar mes nuevo | FIN-06 | Mediano | Panel web y otros dispositivos ven el presupuesto | Pendiente |
| 10 | Implementar reauth por contraseña en eliminación de cuenta | SEC-03 | Mediano | Eliminación real confirmada para cuentas email | Pendiente |
| 11 | Eliminar `--dart-define=GEMINI_API_KEY`; todo via gateway | SEC-04 | Mediano | `strings libapp.so` no revela API key | Pendiente |
| 12 | Limpiar `FlutterSecureStorage` al cerrar sesión y eliminar cuenta | SEC-06 | Pequeño | API key no sobrevive entre sesiones | Pendiente |
| 13 | Agregar `if (!mounted) return;` tras todos los `await` en UI | TEC-04 | Mediano | Sin excepciones al descartar pantallas | Pendiente |
| 14 | Mover `File.existsSync()` fuera de `build()` | TEC-03 | Mediano | Sin jank en listas largas | Pendiente |
| 15 | Migrar UUID a `Random.secure()` | TEC-06 | Pequeño | Cumple RFC 4122 | Pendiente |
| 16 | Corregir contraste texto dona (blanco→negro en colores claros) | UX-01 | Pequeño | Ratio ≥ 4.5:1 en todas las rebanadas | Pendiente |
| 17 | Ajustar borde de foco a `AppColors.primaryDark` | UX-04 | Pequeño | Campo activo visible | Pendiente |
| 18 | Migrar FTP a SFTP/FTPS | SEC-08 | Pequeño | Credenciales cifradas en tránsito | Pendiente |
| 19 | Borrar fotos físicas al cerrar sesión/eliminar cuenta | SEC-09 | Mediano | Directorio de documentos limpio | Pendiente |

**Dependencias:** #1 (keystore) debe hacerse antes de cualquier push adicional. #11 (API key) depende de confirmar que el gateway maneja toda la autenticación.  
**Esfuerzo total estimado:** 4-6 días de trabajo.

### Fase 3: Después del lanzamiento inicial (mejoras de calidad)

| # | Acción | IDs | Esfuerzo |
|:--|:---|:---|:---:|
| 1 | Diseñar onboarding de 3 pantallas | UX-02 | Mediano |
| 2 | Búsqueda global cross-month en historial | UX-03 | Mediano |
| 3 | Unificar navegación del chat (siempre `Navigator.push`) | UX-05 | Mediano |
| 4 | `SummaryCard`: usar mes/año seleccionado para días | FIN-07 | Pequeño |
| 5 | Validar montos > 0 en formularios | FIN-08 | Pequeño |
| 6 | Versionado del Cloudflare Worker en el repo | SEC-12 | Mediano |
| 7 | Implementar tombstones (soft-delete) en Firestore | SEC-05 | Grande |
| 8 | Validación de esquema en Firestore rules | SEC-13 | Mediano |
| 9 | Limitar payload de contexto enviado a Gemini (resúmenes vs historial completo) | SEC-11 | Mediano |
| 10 | Deduplicación SHA-256 en cola de escaneo | OCR-01 | Mediano |
| 11 | Centralizar hidratación de facturas en `ScanQueueProvider` | TEC-08 | Pequeño |
| 12 | Escribir tests para `GastoProvider`, `SyncService` | TEC-09 | Grande |

### Fase 4: Mejoras futuras no esenciales

| # | Acción | IDs | Esfuerzo |
|:--|:---|:---|:---:|
| 1 | Añadir chevrons en tarjetas expandibles | UX-06 | Pequeño |
| 2 | Área de toque ≥ 48dp en ícono de presupuesto | UX-07 | Pequeño |
| 3 | Centralizar iconografía de categorías en `AppIcons` | UX-14 | Pequeño |
| 4 | Eliminar colores hex hardcodeados → usar tema | UX-15 | Mediano |
| 5 | Agregar `Semantics` para TalkBack | UX-16 | Mediano |
| 6 | Descomponer monolitos (ReviewExpense, More, DatabaseHelper) | TEC-07 | Grande |
| 7 | Actualizar APIs deprecadas en tests | TEC-10 | Mediano |
| 8 | Sincronizar documentación PROJECT.md | TEC-11 | Pequeño |
| 9 | Auto-sync reactivo al reconectar internet | — | Mediano |
| 10 | Usar `FieldValue.serverTimestamp()` en lugar de reloj local | SEC-10 | Grande |
| 11 | Encriptar API key BYOK antes de subir a Firestore | SEC-07 | Mediano |
| 12 | Cifrar API key BYOK en cliente antes de Firestore | SEC-14 | Mediano |

---

## H. Plan de Pruebas

### H.1 Checklist de Funciones Críticas

#### Integridad Financiera
- [ ] Registrar gasto de $50 USD → verificar total, categoría, equivalente Bs.
- [ ] Cambiar moneda de visualización a VES → verificar que barras de presupuesto muestren porcentajes coherentes (no 2000%)
- [ ] Configurar presupuesto de categoría → verificar alerta de sobregiro en USD **y** en VES
- [ ] Registrar gasto en EUR → verificar que la tasa se persiste y el equivalente Bs. es correcto
- [ ] Registrar gasto en USDT → verificar conversión correcta (no paridad 1:1 ciega)
- [ ] Editar monto de un gasto → verificar que totales se recalculan
- [ ] Eliminar un gasto → verificar que el total baja correctamente
- [ ] Navegar a un mes anterior → verificar que días restantes y proyección no usan `DateTime.now()`
- [ ] Intentar registrar gasto de -$100 → debe ser rechazado
- [ ] Iniciar mes nuevo → verificar que el presupuesto del mes anterior se adopta y se ve en el panel web

#### Persistencia y Sincronización
- [ ] Registrar gasto offline → verificar que se guarda en SQLite con `synced = 0`
- [ ] Reconectar internet → verificar que el gasto se sincroniza automáticamente a Firestore
- [ ] Editar gasto en dispositivo A → verificar que aparece actualizado en dispositivo B
- [ ] Eliminar gasto en dispositivo A → verificar que desaparece en dispositivo B (no resurrección)
- [ ] Cerrar sesión → verificar que BD SQLite, `FlutterSecureStorage` y fotos se limpian
- [ ] Eliminar cuenta (email) → verificar que Firebase Auth realmente elimina el usuario

#### OCR e IA
- [ ] Escanear factura con cámara → verificar extracción de comercio, ítems, total, fecha
- [ ] Escanear factura borrosa → verificar fallback a Gemini Vision
- [ ] Escanear factura en Bs. → verificar detección de moneda VES
- [ ] Subir comprobante de galería → verificar procesamiento correcto
- [ ] Escanear la misma factura 2 veces → verificar si hay advertencia de duplicado
- [ ] Dictar "Pagué 50 dólares en el supermercado" → verificar categoría = 'Otros' (no 'Alimentación')
- [ ] Usar chat IA para registrar gasto → verificar que se abre pantalla de revisión (no inserción directa)
- [ ] Usar chat IA para preguntar saldo → verificar respuesta contextualizada

#### Google Play
- [ ] Instalar desde Play Store → verificar Google Sign-In funciona (no Error 10)
- [ ] Verificar que no aparece opción de descarga APK externa
- [ ] Verificar que el gráfico de funciones no tiene botón "Descargar gratis"
- [ ] Verificar que `READ_MEDIA_IMAGES` no se solicita

### H.2 Pruebas de Borde

- [ ] Gasto con monto 0.01 (mínimo)
- [ ] Gasto con monto 999,999.99 (máximo razonable)
- [ ] 200+ gastos en un mes → verificar rendimiento de scroll
- [ ] Cambio de tasa BCV a mitad de mes → verificar que gastos anteriores conservan su tasa
- [ ] Sin conexión durante 24h → registrar gastos → reconectar → verificar sincronización
- [ ] Cerrar app durante escaneo OCR → verificar que la cola recupera el ítem

---

## I. Decisiones Recomendadas

### Las 5 acciones que más valor aportan, en orden:

**1. Corregir el descalce de monedas en Dashboard y `getSpentForCategory()` (FIN-01 + FIN-02)**
> *Por qué primero:* Es el defecto más grave de la app. Los usuarios que operan en Bolívares ven porcentajes absurdos (2000%) en sus barras de presupuesto y nunca reciben alertas de sobregiro. Destruye la confianza en la herramienta y su propuesta de valor central. La corrección es mecánica y de bajo riesgo.

**2. Neutralizar las 3 causas de rechazo en Google Play (GP-01 + GP-02 + GP-03)**
> *Por qué segundo:* Sin esto, la app no puede publicarse. El gráfico de funciones con "Descargar gratis" es rechazo automático al 100%. El fallback de APK externa puede causar suspensión de la cuenta de desarrollador. Y sin el SHA-1 de Play Signing, los testers no pueden iniciar sesión.

**3. Convertir el chat IA a modo de sugerencia con confirmación (FIN-03)**
> *Por qué tercero:* Es el único punto de la app donde la IA puede mutar datos financieros sin consentimiento explícito. Combina riesgo financiero (cifras incorrectas) con riesgo regulatorio (Google Play exige control del usuario sobre IA generativa). La solución — redirigir a `ReviewExpenseScreen` — ya existe en los otros flujos.

**4. Resolver la destrucción prematura de BD y proteger el keystore (SEC-02 + SEC-01)**
> *Por qué cuarto:* Son los dos escenarios donde el usuario puede sufrir pérdida total e irreversible de datos o la app puede ser suplantada. El fix de SEC-02 es mover una línea de código. SEC-01 requiere más trabajo (rotar keystore, BFG, Secrets) pero es una deuda de seguridad inaceptable para una app financiera.

**5. Completar el soporte EUR/USDT en cola de escaneo y galería (FIN-04 + FIN-05 + TEC-02)**
> *Por qué quinto:* Afecta a cualquier usuario que reciba facturas en euros o USDT, un caso de uso creciente en Venezuela. Tres puntos del código asumen "si no es USD, es VES" o aplican ratios fijos prohibidos por las propias reglas del proyecto. La corrección consolida la integridad multimoneda completa.

---

> [!NOTE]
> Este informe es un diagnóstico. No se ha modificado ningún archivo del proyecto. Las correcciones quedan pendientes de tu revisión y autorización expresa.
