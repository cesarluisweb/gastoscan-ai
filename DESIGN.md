# Sistema de Diseño UI y Guía de Estilos (Rinde Más)

Este documento es la **fuente de verdad oficial y estricta** para todos los componentes visuales, tipografía, paleta de colores, reglas de contraste y patrones de interacción de la aplicación **Rinde Más**.

---

## 1. Paleta de Colores Oficial (`AppColors`)

Los colores de la aplicación están definidos en `lib/core/constants/app_colors.dart`. Su uso no es arbitrario y debe seguir esta asignación:

| Token | Valor Hex | Rol y Uso Exclusivo |
| :--- | :--- | :--- |
| `AppColors.background` | `#F9FAFB` | Fondo general de pantallas (gris súper claro). |
| `AppColors.surface` / `card` | `#FFFFFF` | Fondo de tarjetas, hojas modales y diálogos. |
| `AppColors.cardLighter` | `#F3F4F6` | Contenedores secundarios, chips inactivos y campos. |
| `AppColors.primary` | `#FBF18F` | Amarillo pastel de acento (Asistente IA, botones principales, burbujas chat). |
| `AppColors.primaryLight` | `#FEF08A` | Amarillo claro para badges y estados suaves. |
| `AppColors.primaryDark` | `#FACC15` | Amarillo de alto impacto para **iconos**, bordes activos y contenedores gráficos. |
| `AppColors.secondary` | `#0F172A` | Azul medianoche / pizarra oscura para textos de alto contraste y botones oscuros. |
| `AppColors.textPrimary` | `#111827` | Negro / gris carbón para títulos, montos y textos de máxima legibilidad. |
| `AppColors.textSecondary` | `#6B7280` | Gris medio para subtítulos, etiquetas secundarias y metadatos. |
| `AppColors.textMuted` | `#9CA3AF` | Gris claro para placeholders, divisores sutiles y timestamps pasivos. |
| `AppColors.border` | `#E5E7EB` | Bordes de tarjetas, campos e inputs. |
| `AppColors.error` | `#EF4444` | Alertas de presupuesto excedido, errores y acciones destructivas. |

---

## 2. Reglas de Contraste Estricto y Jerarquía Cromática

### 2.1 Fondo Amarillo -> Texto SIEMPRE Negro
Cualquier widget con fondo amarillo (`AppColors.primary`, `AppColors.primaryLight` o `AppColors.primaryDark`) **TIENE TERMINANTEMENTE PROHIBIDO USAR TEXTO BLANCO**.
- El texto debe ser explícitamente `Colors.black` o `AppColors.textPrimary`.
- **Aplica sin excepción a:**
  - `SnackBar` con fondo amarillo.
  - `Badge` e insignias numéricas (`Badge.count`).
  - Botones (`ElevatedButton` principal).
  - Chips de filtro seleccionados.
  - Avatares con iniciales (`CircleAvatar`).
  - Banners de notificación y procesamiento.

### 2.2 Fondo Blanco/Claro -> Texto Negro o Gris (NUNCA Amarillo)
Sobre fondos blancos o claros (`AppColors.card`, `AppColors.surface`, `AppColors.background`), **NINGÚN TEXTO PUEDE SER AMARILLO**. El amarillo sobre fondo claro carece de contraste y es ilegible.
- **Negro (`AppColors.textPrimary`):** 
  - Títulos y encabezados.
  - Montos principales de compras y balances.
  - Textos de botones planos (`TextButton`), enlaces interactivos (ej. *"Gestionar"*, *"Ver comprobante"*).
  - Nombres principales de ítems o comercios.
- **Gris (`AppColors.textSecondary` o `AppColors.textMuted`):**
  - Categorías de ítems dentro de listas o desgloses (`it.categoria`).
  - Fechas, horas, tasas de cambio informativas y notas secundarias.
  - Mensajes de ayuda (`helperText`) y estados complementarios.

### 2.2.1 Cursor de Texto (`cursorColor` y `textSelectionTheme`)
- Sobre fondos blancos o claros (`AppColors.card`, `AppColors.surface`, campos de texto), el cursor titilante `|` **DEBE SER SIEMPRE NEGRO** (`AppColors.textPrimary` o `Colors.black`).
- Queda terminantemente prohibido el cursor amarillo en campos de texto (evita la herencia automática del `primary` de Material 3). Se configura globalmente en `ThemeData.textSelectionTheme`:
  ```dart
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: AppColors.textPrimary,
    selectionColor: Color(0x33FFE600),
    selectionHandleColor: AppColors.primaryDark,
  ),
  ```

### 2.2.2 Selector de Fecha (`DatePickerDialog` y `datePickerTheme`)
- En el calendario mensual de selección de fecha (`DatePickerThemeData`), el número del día actual (`todayForegroundColor`) **DEBE SER SIEMPRE NEGRO** (`Colors.black`).
- Queda prohibido el número amarillo sobre fondo blanco o fondos claros por falta de contraste.
- El círculo del día actual debe tener **relleno amarillo suave** (`AppColors.primaryLight` cuando no está seleccionado, y `AppColors.primary` cuando está seleccionado) con borde definido `AppColors.primaryDark` (ancho 1.5px), garantizando visibilidad inmediata y contraste 100% accesible.

### 2.3 Uso Exclusivo del Amarillo
El color amarillo (`AppColors.primaryDark` preferiblemente) queda reservado de forma estricta y exclusiva para:
1. **Iconos:** Símbolos visuales al inicio de tarjetas o botones (`prefixIcon`, `leading`).
2. **Contenedores de fondo:** Cajas de acento o badges gráficos (con texto explícito en negro).
3. **Bordes activos de campos:** Indicador de selección o foco en inputs (`TextField.focusedBorder`), **NUNCA en el contenedor o tarjeta exterior que envuelve la fila** (el contenedor debe mantener `AppColors.border`).
4. **Iconos Temáticos de Ahorro:** El icono de cochino (`Icons.savings_outlined`) en metas y tarjetas de balance debe ser explícitamente `AppColors.primaryDark` (amarillo marca de alto contraste en fondo blanco), nunca marrón ni ámbar tostado.

### 2.4 Tarjetas de Borrador y Estados Pendientes de Validación (IA)
Para componentes que representen compras o facturas no confirmadas (`PendingExpenseCard`):
1. **Fondo y Superficie:** Prohibido usar fondos amarillos planos intensos en la tarjeta completa para evitar fatiga visual cuando hay múltiples facturas en cola. Usar fondo marfil suave cálido (`#FFFDF5`), armónico con `GlobalScanQueueBanner`, con borde ámbar suave (`#FEF08A`, ancho 1.2px).
2. **Contraste de Estado:** Los badges o textos de advertencia/pendiente DEBEN usar ámbar oscuro (`Color(0xFF92400E)`) sobre pastilla ámbar claro (`Color(0xFFFEF3C7)` o `#FEF9C3`), garantizando contraste WCAG AAA superior a 7:1. Prohibido usar texto o iconos ámbar claro sobre fondos amarillos.
3. **Acción Faltante:** Si la factura carece de monto detectado, mostrar un botón interactivo de acción directa con fondo amarillo de marca y texto negro explícito (`Por revisar →`).
4. **Densidad y Ergonomía:** Mantener padding vertical compacto ($\le 12\text{dp}$, idealmente $11\text{dp}$) y márgenes entre 8dp y 10dp para permitir visualizar múltiples elementos sin scroll excesivo.

---

## 3. Patrones de Código Dart Recomendados

### 3.1 `Badge.count` (Insignias numéricas)
```dart
Badge.count(
  count: badgeCount,
  backgroundColor: AppColors.primaryDark,
  textColor: Colors.black, // OBLIGATORIO: Negro sobre amarillo
  child: iconWidget,
)
```

### 3.2 `SnackBar` con Fondo de Acento
```dart
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text(
      'Gasto registrado con éxito',
      style: TextStyle(color: Colors.black), // OBLIGATORIO: Negro explícito
    ),
    backgroundColor: AppColors.primaryDark, // o AppColors.primary
    duration: Duration(seconds: 2),
  ),
);
```

### 3.3 Botón de Acción Principal (`ElevatedButton`)
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.black, // OBLIGATORIO: Texto e icono negros
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  ),
  onPressed: _onAction,
  child: const Text('Guardar Factura', style: TextStyle(fontWeight: FontWeight.bold)),
)
```

### 3.4 Enlace o Botón de Texto en Tarjeta Blanca (`TextButton`)
```dart
TextButton(
  onPressed: () => _gestionar(),
  child: const Text(
    'Gestionar',
    style: TextStyle(
      color: AppColors.textPrimary, // OBLIGATORIO: Negro sobre tarjeta blanca
      fontSize: 13,
      fontWeight: FontWeight.bold,
    ),
  ),
)
```

### 3.5 Desglose de Ítems en Tarjeta de Gasto
```dart
Row(
  children: [
    Expanded(
      flex: 3,
      child: Text(
        '${it.cantidad}x ${it.descripcion}',
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
    ),
    Expanded(
      flex: 2,
      child: Text(
        it.categoria,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600), // Gris
        overflow: TextOverflow.ellipsis,
      ),
    ),
    Text(
      itemPriceText,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
    ),
  ],
)
```

### 3.6 Diálogos de Confirmación (`AlertDialog`)
En cualquier modal de decisión o confirmación sobre fondo blanco/claro:
- **Acción Neutral / Cancelar ("Cancelar", "Volver", "Más tarde"):** Texto gris obligatorio (`AppColors.textSecondary`). Prohibido usar amarillo o dejarlo sin estilo.
- **Acción Destructiva ("Eliminar", "Descartar"):** Texto rojo explícito (`AppColors.error`).
- **Acción Principal Afirmativa ("Guardar", "Confirmar"):** `ElevatedButton` amarillo (`AppColors.primary`) con texto negro (`AppColors.textPrimary` o `Colors.black`).

```dart
AlertDialog(
  backgroundColor: AppColors.card,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  title: const Text('Descartar cambios', style: TextStyle(color: AppColors.textPrimary)),
  content: const Text('¿Deseas descartar el formulario?', style: TextStyle(color: AppColors.textSecondary)),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(ctx, false),
      child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
    ),
    TextButton(
      onPressed: () => Navigator.pop(ctx, true),
      child: const Text('Descartar', style: TextStyle(color: AppColors.error)),
    ),
  ],
)
```

---

## 4. Reglas de Maquetación y Componentes UI

1. **Prevención de `RenderFlex overflow` en Filas (`Row`):**
   - Siempre que un `Row` combine un `Icon` y un widget `Text` descriptivo o título, envolver el `Text` en `Expanded` (o `Flexible`). Previene desbordamientos en teléfonos estrechos o con fuentes grandes del sistema.
2. **Botón Único en Listas Dinámicas:**
   - En formularios con listas desplazables de ítems (como productos de una compra), **no duplicar** botones de agregar arriba y abajo. Usar un único botón de ancho completo al final de la lista para respetar el flujo natural de scroll.
3. **Contenedores para `ListTile` (Flutter 3.24+):**
   - NUNCA envolver `ListTile` o `SwitchListTile` en `Container(decoration: BoxDecoration(...))`. Usar siempre widget `Material` con `shape: RoundedRectangleBorder(...)` y `clipBehavior: Clip.antiAlias` para evitar excepciones de renderizado de tinta.
4. **Banners Concurrentes No Excluyentes:**
   - Si existen múltiples tareas en segundo plano (OCR en curso, ítems pendientes de revisión, alertas), apilar verticalmente en `Column` compacto, nunca con `if / else if` que oculte tareas activas.
5. **Reutilización y Homologación de Componentes Transversales:**
   - Cualquier control interactivo o componente visual compartido por más de una pantalla (ej. `MonthSelectorBar`, filtros, selectores de fecha) DEBE residir como widget modular reutilizable en `lib/ui/widgets/`. Queda prohibido duplicar árboles de widgets equivalentes entre pantallas.
   - Estos componentes comunes compartidos entre pantallas de primer nivel (Inicio, Gastos, Análisis, Comprobantes) DEBEN ubicarse directamente sobre el fondo de la pantalla (`AppColors.background`), sin envoltorios redundantes (`Container(color: AppColors.surface)`) ni bordes locales que generen franjas inconsistentes.
6. **Ergonomía y Anti-Redundancia en Visores de Pantalla Completa (Modales Multimedia):**
   - **Acciones Principales al Alcance del Pulgar:** En visores a pantalla completa (`ReceiptViewerDialog` o modales multimedia), las acciones primarias, de edición o destructivas («Ver o editar gasto», «Eliminar foto») DEBEN ubicarse en una barra inferior fija (`bottomNavigationBar`).
   - **Barra Superior Limpia y Despejada:** El `AppBar` se reserva exclusivamente para el botón de cerrar (`X`), título del comercio, fecha/monto y, a lo sumo, una única acción de salida (`Compartir`). Queda prohibido duplicar en el `AppBar` acciones que ya están presentes abajo, evitando saturación visual y el truncamiento del título.
   - **Cero Acciones Superfluas en Archivos Locales:** Prohibido incluir botones como "Descargar" o "Guardar en galería" para imágenes o documentos que ya se encuentran almacenados localmente en el teléfono.

---

## 5. Tono de Voz y Microcopy

1. **Terminología Estricta:**
   - Utilizar siempre el término **"facturas"** o **"comprobantes"**. Queda prohibido el término *"tickets"*.
   - El nombre de la aplicación es **Rinde Más** (`AppConstants.appName`).
2. **Español Venezolano / Neutro:**
   - Vocabulario claro, directo y cercano sin caer en informalidad excesiva.
   - Claridad en divisas: Bolívares (VES), Dólares (USD), Euros (EUR), Binance USDT (USDT).
3. **Microcopy de Tranquilidad y Privacidad:**
   - En pantallas de autenticación o respaldo: *"Solo usamos tu cuenta para respaldar tus facturas en tu propio espacio privado. Sin bancos ni contraseñas."*
   - Cero jerga corporativa: Directo a la utilidad del usuario sin rodeos.

---

## 6. Patrones de UX Financiera y Claridad Numérica

### 6.1 Saldo Restante vs. Ingresos
- **Prohibición del signo `+` en Saldos Restantes:** NUNCA anteponer el signo `+` a montos de saldo restante para gastar (ej. evitar `+$444,00`). En interfaces financieras, el signo `+` en verde comunica un ingreso de dinero (*inflow*).
- **Etiquetado Claro:** Usar siempre términos que reflejen capacidad de gasto restante: *"Disponible"*, *"Disponible para gastar"* o *"Te queda"*, reservando el signo `-` en rojo exclusivamente para cuando el presupuesto o límite sea superado (*"Presupuesto superado por -$X"*).

### 6.2 Semántica de Metas de Ahorro
- Evitar términos ambiguos como únicamente *"Protegida"*. Utilizar etiquetas explícitas que identifiquen la meta: *"Ahorro protegido"*, *"Ahorro en riesgo"* o *"Ahorro comprometido"*.

### 6.3 Accesibilidad y Contraste WCAG en Textos Secundarios
- En interfaces web y móviles, los textos secundarios (metadatos, promedios, subtítulos informativos y enlaces de acción) deben mantener un contraste mínimo de 4.5:1 (WCAG AA). Queda prohibido usar grises excesivamente claros (`text-slate-400` en web o colores por debajo de `AppColors.textSecondary` en móvil) en elementos interactivos o informativos clave.

### 6.4 Semántica de Medidores: Tanque de Saldo Disponible vs. Barras de Asignación y Proporción
- **Tanque de Saldo Disponible (Barras de Consumo):**
  Las barras de presupuesto mensuales en la tarjeta principal (`SummaryCard`), en la pantalla de análisis (`AnalysisScreen._buildGeneralBudgetCard`), en el control por categorías (`CategoryChart`) y en el panel web (`panel.astro`) miden **saldo disponible restante** que se reduce de derecha a izquierda (`100% → 0%`) a medida que se ejecutan gastos, alineadas conceptualmente con el monto héroe superior (`Disponible para gastar`).
  1. *Escala base:* Escala siempre sobre el presupuesto general (`budget > 0`).
  2. *Estado normal / saludable:* Verde (`AppColors.balancePositive` / `#16A34A`) en barras generales o el color de identidad de la categoría (`AppColors.categoryColors[cat]`) en `CategoryChart`, sobre carril gris claro (`AppColors.trackNeutral` / `#F1F5F9`).
  3. *Estado de precaución:* Ámbar de alto contraste (`AppColors.caution` / `#D97706`) cuando queda `<= 15%` de capacidad antes de tocar la rayita de ahorro o el fondo del tanque (`usedRatio >= 0.85`). No mezclar con la proyección lineal `enRiesgo`, la cual se comunica exclusivamente en el badge de ahorro y en `AiInsightCard`.
  4. *Estado de ahorro invadido (`límite < gasto < presupuesto`):* Toda la reserva de ahorro (`0%` hasta el marcador) entra en emergencia: el saldo que aún queda vivo de ahorro se pinta de rojo fuerte (`AppColors.errorStrong` / `#DC2626`), el tramo de ahorro ya consumido se tiñe de rojo suave (`AppColors.errorTint` / `#FEE2E2`), y el marcador vertical cambia a rojo fuerte.
  5. *Estado de tanque agotado (`gasto >= presupuesto`):* Relleno al `0%` con todo el carril teñido en rojo suave (`AppColors.errorTint` / `#FEE2E2`) y borde rojo sutil (`AppColors.errorBorder` / `#FCA5A5`), evitando que un sobregasto se confunda con una barra inactiva.
- **Barras de Asignación y Proporción Estadística:**
  Las barras de configuración de presupuestos en hojas modales (`BudgetBottomSheet`) y la distribución de compras en radiografías (`PurchaseRadiographyCard`) no representan saldo en tanque sino asignación o proporciones acumulativas de `0%` a `100%`, manteniendo el avance tradicional hacia la derecha.

### 6.5 Jerarquía de Tres Niveles del Resumen Financiero (Modelo Mental V3)
Para evitar saturación visual y fatiga cognitiva, las tarjetas de balance mensual no deben apilar múltiples números gigantes en 32sp ni mostrar porcentajes abstractos:
- **Nivel 1 (Héroe Único):** Saldo disponible restante (`Disponible para gastar`) en 32sp verde negrita con selector compacto tipo Binance (`USD BCV ▾`). Si está excedido, pastilla roja compacta `Excedido del límite` con saldo negativo en rojo.
- **Nivel 2 (Contexto Horizontal Equilibrado):** Fila sobre la barra con `Gastado: $ X` a la izquierda y `Límite: $ Y ✏️` (tocable) a la derecha.
- **Nivel 3 (Barra de Tanque con Reserva de Ahorro):** Barra lineal de 10dp con marcador vertical (`2dp`, sobresaliendo `3dp` arriba y abajo) posicionado a la izquierda en `metaAhorro / presupuestoGeneral`. La barra se vacía de derecha a izquierda hacia dicho marcador. Si el gasto cruza la rayita invadiendo el ahorro, la zona de ahorro se tiñe de emergencia en rojo (`#DC2626` vivo + `#FEE2E2` comido) y el marcador vertical pasa a rojo fuerte.
- **Desacoplamiento Pedagógico:** El cálculo del ritmo diario permitido (`$ X/día durante Y días restantes`) y las sugerencias de moderación se delegan dinámicamente al componente del `Asistente IA` (`AiInsightCard`), manteniendo la tarjeta de resumen limpia y enfocada en los 3 números clave.

### 6.6 Tarjeta de Distribución de Gastos (Dona y Lista Equilibrada)
Para evitar que la dona se vea miniaturizada o que invada los márgenes de la tarjeta:
1. **Diámetro y Escala:** La dona debe tener un diámetro de 130px (`width: 130`, `height: 130`, `centerSpaceRadius: 41`, `radius: 24`), ocupando aproximadamente el 44% del ancho útil de la tarjeta.
2. **Inicio de la Lista en el Centro:** Con una separación de 14px tras la dona, la lista de categorías debe comenzar exactamente en el medio de la tarjeta (~48.6% del ancho).
3. **Columna de Porcentajes Fija:** El porcentaje debe estar en una columna fija de 28px (`SizedBox(width: 28)`), con texto alineado a la izquierda (`TextAlign.left`) y en gris (`AppColors.textSecondary`), situada entre el nombre y el monto.
4. **Columna de Montos a la Derecha:** Los montos se fijan a la derecha con `SizedBox(width: 58)` en `AppColors.textPrimary` (negro) mediante `FittedBox(alignment: Alignment.centerRight)`.
5. **Densidad Vertical:** El padding vertical por fila de categoría debe ser de 3px para balancear la altura de las 5 categorías con la altura de la dona sin estirar la tarjeta.
6. **Monto Secundario en Desgloses Bimonetarios:** En tarjetas con doble divisa (`ExpenseCard`, etc.), el monto secundario (ej. equivalente en Bs. bajo lente divisa) debe ir en gris (`AppColors.textSecondary`) y tamaño reducido, para que no compita jerárquicamente con el monto principal en negro.
