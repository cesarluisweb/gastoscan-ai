# Plan de Rediseño de Navegación — Rinde Más

## Resumen de Cambios Aprobados y Refinados

| Punto | Antes | Implementado y Refinado |
|-------|-------|--------------------------|
| Estructura Nav | Inicio - Lista - [+] - Asistente - Perfil | **Inicio - Gastos - [+] - Análisis - Más** |
| Tab 0: Inicio | Dashboard con lista completa y pie chart | **Dashboard enfocado**: Hero Card ("Este mes has gastado" + barra de presupuesto con días restantes), Asistente IA (consejo inteligente con acceso directo al chat manteniendo la barra inferior), Pie Chart con botón "Ver análisis completo", y 5 últimos "Gastos realizados" con botón "Ver todos los gastos" |
| Tab 1: Gastos | No existía | **Historial completo dedicado**: Buscador por comercio y producto, selector de mes, y lista de compras agrupadas cronológicamente por encabezados de fecha ("Hoy, 26 Sep", "Ayer, 25 Sep", etc.) |
| FAB Central [+] | Sin cambios | Tomar Foto (IA), Subir de Galería (IA), Dictar Gasto (Voz), Ingreso Manual |
| Tab 2: Análisis | No existía | **Análisis visual y presupuestos**: Tarjeta prominente de Presupuesto Mensual General arriba del gráfico, Pie Chart de distribución, lista ordenada de todas las categorías de mayor a menor gasto con sus límites y alertas de exceso |
| Tab 3: Más | Anteriormente "Perfil" | **Hub consolidado**: Respaldo en la nube con Google, navegación interna a Lista de Compras y Asistente IA (manteniendo el menú inferior), tasas BCV, ajustes de fotos y exportación CSV/MD |

## Principios UX Aplicados
1. **Hick's Law**: 4 destinos claros + FAB central de acción primaria.
2. **Fitts's Law**: FAB central equidistante de ambas manos para captura inmediata.
3. **Progressive Disclosure**: La pantalla de Inicio no abruma; quien quiera detalle de facturas entra a Gastos, y quien quiera análisis presupuestario entra a Análisis.
4. **Miller's Law**: Información agrupada en chunks lógicos y digeribles (fechas agrupadas, presupuestos centralizados).
5. **Jakob's Law**: Patrón familiar consistente con las aplicaciones financieras más exitosas.
