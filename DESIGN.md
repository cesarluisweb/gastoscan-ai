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
