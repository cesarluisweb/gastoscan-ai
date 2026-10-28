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

### 2.3 Uso Exclusivo del Amarillo
El color amarillo (`AppColors.primaryDark` preferiblemente) queda reservado de forma estricta y exclusiva para:
1. **Iconos:** Símbolos visuales al inicio de tarjetas o botones (`prefixIcon`, `leading`).
2. **Contenedores de fondo:** Cajas de acento o badges gráficos (con texto explícito en negro).
3. **Bordes activos:** Indicadores de selección o foco en tarjetas y chips.

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

### 6.4 Semántica de Color Separada en Medidores de Gasto vs. Saldo
- **Verde Exclusivo para Saldo Restante:** El color verde (`Color(0xFF16A34A)`) se reserva EXCLUSIVAMENTE para cifras de capacidad disponible (`Disponible para gastar`, `Te sobraron`). Queda estrictamente prohibido usar verde en rellenos de barras de progreso que miden dinero ya gastado, para evitar ambigüedad semántica (gastar no es saldo a favor).
- **Relleno de Barra de Gasto (`LinearProgressIndicator`):**
  1. *Estado normal / saludable:* Pizarra oscuro neutro de marca (`Color(0xFF1E293B)`), alineado con el color del texto del monto gastado, sobre fondo gris claro (`Color(0xFFF1F5F9)`).
  2. *Estado de precaución:* Ámbar (`Color(0xFFF59E0B)`) al superar el 85% del límite o cuando la meta de ahorro entra en proyección `enRiesgo`.
  3. *Estado excedido:* Rojo (`AppColors.error` / `Color(0xFFDC2626)`), cruzando físicamente el divisor hacia la derecha.

### 6.5 Jerarquía de Tres Niveles del Resumen Financiero (Modelo Mental V3)
Para evitar saturación visual y fatiga cognitiva, las tarjetas de balance mensual no deben apilar múltiples números gigantes en 32sp ni mostrar porcentajes abstractos:
- **Nivel 1 (Héroe Único):** Saldo disponible restante (`Disponible para gastar`) en 32sp verde negrita con selector compacto tipo Binance (`USD BCV ▾`). Si está excedido, pastilla roja compacta `Excedido del límite` con saldo negativo en rojo.
- **Nivel 2 (Contexto Horizontal Equilibrado):** Fila sobre la barra con `Gastado: $ X` a la izquierda y `Límite: $ Y ✏️` (tocable) a la derecha.
- **Nivel 3 (Barra con Asignación y Meta):** Barra lineal de 10dp con marcador vertical gris oscuro y pie con estado de meta (`Protegida` / `En riesgo`).
- **Desacoplamiento Pedagógico:** El cálculo del ritmo diario permitido (`$ X/día durante Y días restantes`) y las sugerencias de moderación se delegan dinámicamente al componente del `Asistente IA` (`AiInsightCard`), manteniendo la tarjeta de resumen limpia y enfocada en los 3 números clave.
