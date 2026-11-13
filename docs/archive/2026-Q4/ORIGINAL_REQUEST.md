# Original User Request

## 2026-09-15T18:08:40Z

# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Craft prompt → get user approval → delegate to teamwork_preview
> Requested team: Escuadrón de agentes a gran escala (full team)

Implementar el bloque completo de la Fase 6 de "Rinde Más" (App Flutter). El objetivo es agregar 4 funcionalidades avanzadas manteniendo la arquitectura actual (SQLite local + Sincronización) sin romper la UI.

Working directory: H:\My Drive\Documentos\Trabajo\Control de gastos VE
Integrity mode: development

## Requirements

### R1. Subida Múltiple de Facturas
- Modificar el flujo actual de escaneo desde la galería para permitir seleccionar múltiples imágenes a la vez.
- Al seleccionar varias, deben enviarse directamente al `ScanQueueProvider` (cola en segundo plano) existente, volviendo al Dashboard para que se procesen de forma silenciosa.

### R2. Buscador de Gastos
- Agregar un ícono de lupa en la barra superior (AppBar) del `DashboardScreen` que despliegue un campo de texto.
- Al escribir, la lista de gastos mostrada debe filtrarse en tiempo real por comercio o nombre del producto.

### R3. Presupuestos por Categoría
- Permitir al usuario definir un monto máximo mensual para cada categoría existente.
- Mostrar una alerta visual (ej. una pequeña barra de progreso roja bajo la categoría) en el Dashboard si los gastos del mes superan el presupuesto asignado.

### R4. Recordatorios de Inactividad (Push Locales)
- Integrar notificaciones push locales (usando un paquete como `flutter_local_notifications`).
- Programar una notificación automática para que se dispare si el usuario no abre la app o no registra un gasto en 3 días.

## Acceptance Criteria

### Verificación Programática y Manual
- [ ] **Múltiple:** El selector de imágenes permite marcar >1 foto. Al confirmar, el `DashboardScreen` muestra el banner amarillo de "procesando" con los items encolados.
- [ ] **Buscador:** Escribir "Cafe" en la barra superior oculta instantáneamente los gastos que no coinciden con ese texto.
- [ ] **Presupuesto:** Asignar $50 a Comida, y registrar un gasto de $60 en Comida hace que se dibuje un indicador visual de exceso (color rojo) en la UI de esa categoría.
- [ ] **Recordatorio:** El código compila correctamente con los permisos de Android requeridos para notificaciones locales, y existe la función de scheduling para 3 días.
