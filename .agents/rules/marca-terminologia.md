---
trigger: model_decision
description: "Consultar al redactar o modificar textos de interfaz, modales, notificaciones push, reportes exportados o vocabulario de facturas, fotos y comprobantes."
---

# Consistencia de Marca Global y Terminología Oficial

## 1. Identidad de Marca Oficial
- **Nombre Oficial Único:** El nombre oficial y definitivo de la aplicación es **Rinde Más** (`AppConstants.appName`).
- **Prohibición de Nombres Anteriores:** Queda estrictamente prohibido utilizar nombres anteriores (como *GastoScan AI*, *GastosCan AI* o *GastoScan*) en pantallas, botones, reportes exportados (Markdown, CSV), modales, notificaciones o documentación pública.

## 2. Terminología Estricta: Prohibición de "Tickets"
- **Regla Fundamental:** Queda terminantemente prohibido utilizar el término **"tickets"** para referirse a los comprobantes de compra. En español venezolano y neutro debe utilizarse siempre **"facturas"** o **"comprobantes"**.

## 3. Ciclo de Vida Terminológico de Escaneo
Para garantizar coherencia y precisión en la experiencia de usuario, los términos se rigen estrictamente por la fase del flujo:

| Fase del Flujo | Término Obligatorio | Ejemplos de Microcopy | Prohibiciones Específicas |
|---|---|---|---|
| **Pre-Análisis** (Captura, Cola, En proceso, Sin conexión, Pausado) | **"Foto(s)"** o **"Imágenes"** | *"Analizando foto(s) con IA..."*<br>*"3 fotos guardadas sin conexión"*<br>*"Fotos en cola"* | Prohibido decir "factura(s)" o "ticket(s)" (la app aún no ha analizado la imagen ni sabe cuántas facturas contiene). |
| **Post-Análisis** (Revisión de gastos, Notificaciones push, Guardado) | **"Factura(s)"** | *"Factura lista para revisar"*<br>*"2 facturas listas"*<br>*"Guardar factura"* | Prohibido decir "ticket(s)" o "comprobante(s)". Prohibido mezclar términos en un mismo diálogo. |
| **Histórico / Guardado** (Detalle de gasto, Galería, Adjuntos) | **"Comprobante(s)"** | *"Adjuntar comprobante"*<br>*"Ver comprobante"*<br>*"Galería de comprobantes"* | Prohibido en botones o banners durante la captura o análisis activo. |

- **Prohibición de Mezcla:** Queda prohibido titular un modal como "Comprobante" si los botones de acción dicen "Guardar Factura". El vocabulario debe mantenerse uniforme en toda la vista.
- **Avisos Neutros en Cola de Procesamiento:** En SnackBars y banners de progreso de cola, referirse a "imágenes" o "comprobantes" (ej. *"Analizando imagen con IA..."*), evitando asumir que una fotografía física corresponde únicamente a una sola factura.
