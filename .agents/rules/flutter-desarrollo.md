---
trigger: glob
globs: "lib/**/*.dart, test/**/*.dart"
description: "Convenciones de código Dart, maquetación de widgets, imports obligatorios, modelos y utilidades."
---

# Convenciones de Desarrollo en Dart y Flutter

## 1. Importaciones y Sintaxis
- **Rastreo e Inyección Obligatoria de Imports:** El CI detiene la compilación si falta una importación. Rastrear el origen de cada clase, modelo o servicio e inyectar el import correspondiente en la cabecera del archivo. No asumir inyección automática.
- **Identificadores ASCII Estrictos:** Prohibido utilizar caracteres no-ASCII (tildes, acentos, 'ñ') en nombres de variables, métodos, archivos o pruebas (ej. usar `gastoAlimentacion`, nunca `gastoAlimentación`).
- **Verificación de Miembros en Utilidades:** Antes de invocar métodos de utilidades compartidas (`DateFormatter`, `CurrencyFormatter`), verificar su firma e identificador exacto en el archivo fuente para prevenir roturas en CI (ej. `getMonthName` vs `obtenerNombreMes`).

## 2. Construcción y Comportamiento de Widgets
- **Acceso a Propiedades en StatefulWidget:** Al refactorizar a `StatefulWidget`, acceder a callbacks y parámetros del constructor utilizando siempre la referencia `widget.` (ej. `widget.onSetBudget`).
- **Keys de Widget Globalmente Únicos:** Todo widget que coexista en el árbol visual (BottomSheets, Dialogs, Overlays) DEBE tener una `Key` globalmente única. Si un componente existente usa `Key('edit_budget_$cat')`, un overlay superior no puede duplicarla; usar prefijos diferenciadores como `Key('edit_budget_bottom_$cat')`.
- **Contenedores Material para ListTile (Flutter 3.24+):** Prohibido envolver `ListTile` o `SwitchListTile` directamente dentro de un `Container` con `BoxDecoration(color: ...)`. Usar siempre un widget `Material` con `shape: RoundedRectangleBorder(...)` y `clipBehavior: Clip.antiAlias` para evitar fallos de renderizado de tinta.
- **Prevención de Desbordamientos (RenderFlex):** Envolver textos en `Expanded` dentro de filas (`Row`) con iconos. Mantener un botón único de agregar al final de listas dinámicas.
- **Reutilización Obligatoria de Componentes (DRY):** Si un patrón visual o interactivo (selectores de fecha/período, modales de confirmación, tarjetas resumen) se usa en 2 o más pantallas, DEBE abstraerse como widget modular en `lib/ui/widgets/`. Prohibido duplicar maquetación local idéntica.
- **Jerarquía y Estilo en Diálogos (`AlertDialog`):** Prohibido dejar botones `TextButton` sin estilo de color explícito en modales o diálogos. Los botones de cancelación o retorno ("Cancelar", "Volver", "Más tarde") DEBEN utilizar siempre `AppColors.textSecondary` (gris). Las acciones destructivas ("Eliminar", "Descartar") deben usar `AppColors.error` (rojo). Las confirmaciones afirmativas deben usar `ElevatedButton` (`AppColors.primary` con texto negro).

## 3. Modelos y Servicios
- **Instanciación de Modelos con Campos Requeridos:** Al crear instancias de `GastoModel` (para borradores, colas o pruebas), proveer siempre todos los campos obligatorios, incluyendo `creadoEn: DateTime.now().toIso8601String()`.
- **Determinismo Temporal:** Todo widget o servicio cuya lógica dependa de fechas o umbrales temporales (alertas de nuevo mes, proyecciones de gasto) DEBE aceptar un parámetro opcional `DateTime? currentDate` con fallback a `DateTime.now()`.
- **Lanzamiento de URLs Externas (`url_launcher`):** NUNCA condicionar la apertura web a `canLaunchUrl(uri)` (falla en Android 11+ sin declaraciones `<queries>`). Invocar directamente `await launchUrl(uri, mode: LaunchMode.externalApplication)` con fallback a `LaunchMode.platformDefault` dentro de un bloque `try/catch`.
