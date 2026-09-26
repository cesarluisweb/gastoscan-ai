# Plan de Rediseño de Navegación — Rinde Más

## Resumen de Cambios Aprobados

| Punto | Antes | Implementado |
|-------|-------|--------------|
| Estructura Nav | Inicio - Lista - [+] - Asistente - Perfil | **Inicio - Gastos - [+] - Análisis - Más** |
| Tab 0: Inicio | Dashboard con lista completa y pie chart | **Dashboard enfocado**: Hero Card dual (gastado + restante), Asistente IA (consejo inteligente), Pie Chart, y vista previa de últimos gastos con botón "Ver todos" |
| Tab 1: Gastos | No existía | **Historial completo dedicado**: Buscador, selector de mes, chips de categorías y lista de gastos |
| FAB Central [+] | Sin cambios | Tomar Foto (IA), Subir de Galería (IA), Dictar Gasto (Voz), Ingreso Manual |
| Tab 2: Análisis | No existía | **Análisis visual y presupuestos**: Pie chart, presupuesto general, presupuestos por categoría y modal de configuración |
| Tab 3: Más | Anteriormente "Perfil" | **Hub consolidado**: Respaldo en la nube con Google, acceso a Lista de Compras, acceso a Asistente IA, tasas BCV, fotos y exportación CSV/MD |

## Principios UX Aplicados
1. **Hick's Law**: 4 destinos claros + FAB central de acción primaria.
2. **Fitts's Law**: FAB central equidistante de ambas manos para captura inmediata.
3. **Progressive Disclosure**: La pantalla de Inicio no abruma; quien quiera detalle de facturas entra a Gastos, y quien quiera análisis presupuestario entra a Análisis.
4. **Miller's Law**: Información agrupada en chunks lógicos y digeribles.
5. **Jakob's Law**: Patrón familiar consistente con las aplicaciones financieras más exitosas.
