---
name: sincronizar-panel-web
description: Procedimiento para portar y sincronizar flujos, formularios y cálculos financieros desde la app móvil Flutter hacia el panel web Astro.
---

# Procedimiento de Sincronización Móvil -> Panel Web

Esta habilidad se activa cuando una tarea requiera alinear o sincronizar pantallas, formularios o lógica de negocio de la app Flutter (`ReviewExpenseScreen`, etc.) con el panel web (`landing/src/pages/panel.astro`).

## 1. Mapeo Inicial contra la Pantalla Móvil
1. Identificar la pantalla Flutter de referencia (ej. `lib/ui/screens/review_expense_screen.dart`).
2. Mapear la jerarquía exacta de tarjetas, etiquetas, proporciones de columnas (ej. 35/65 descripción/categoría) y flujos de divulgación progresiva.
3. Contrastar con `.agents/rules/dinero-datos.md`:
   - Orden canónico de monedas: `USD -> VES -> USDT -> EUR`.
   - Exclusiones de divisas (ej. no existe liquidación en Bs. P2P para EUR).
   - Inmutabilidad y preservación de centavos originales al reabrir en edición.

## 2. Extracción de Módulos Puros (Sin Acoplamiento al DOM)
Para evitar scripts monolíticos inmanejables en `panel.astro`:
- Aislar la lógica de cálculo y conversión en librerías puras en `landing/src/lib/` (ej. `expense-money.js`, `category-classifier.js`).
- El cálculo matemático debe aceptar objetos simples y devolver totales con centavos exactos (`computeExpenseTotals`, `computeItemCents`).
- Prohibido acoplar la matemática financiera al DOM de Astro.

## 3. Pruebas Automatizadas con Node Nativo
Antes de tocar el DOM o Astro:
1. Crear o actualizar pruebas en `landing/test/*.test.js` usando el test runner nativo de Node (`node --test`).
2. Verificar la tabla de casos dorados de dinero (C1 a C6):
   - VES directo.
   - Divisa con pago en Bs. indexado a BCV.
   - Divisa con pago en Bs. indexado a P2P.
   - EUR directo y en Bs.
   - Preservación estricta de centavos cuando el ítem no ha sido modificado.

## 4. Adaptación en Astro y Accesibilidad
1. Actualizar el marcado HTML en `landing/src/pages/panel.astro`.
2. Para modales superpuestos, usar siempre clases de valor arbitrario (`z-[100]`) y `style="z-index: 100;"` para prevenir fallos de apilamiento en Tailwind.
3. Proteger totales dictados/manuales (`totalEditadoManualmente`).
4. Proveer diálogos de decisión en lugar de `window.confirm()`.

## 5. Verificación y Despliegue
1. Ejecutar las pruebas unitarias: `node --test landing/test/*.test.js`.
2. Compilar Astro localmente para validar que no haya errores de bundling ni variables duplicadas: `npm --prefix landing run build`.
3. Commitear y pushear a `main`.
4. Monitorear el CI con `powershell -ExecutionPolicy Bypass -File scripts/wait_ci.ps1`.
5. Validar HTTP 200 en `https://rindemas.cesarluis.com/panel`.
