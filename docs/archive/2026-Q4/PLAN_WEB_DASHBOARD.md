# Plan de Arquitectura e Implementación: Panel Web de Rinde Más

## 1. Diagnóstico del Estado Actual de Datos
Revisando el código de la aplicación, confirmamos lo siguiente:
1. **Los gastos e ítems SÍ se sincronizan en Firestore:** A través de `SyncService`, la app móvil ya sube todos los gastos y su desglose de productos a la colección `users/{uid}/gastos/{uuid}` en Cloud Firestore.
2. **Los presupuestos NO se sincronizan aún:** Las tablas `presupuestos_mensuales` y `presupuestos_categorias_mensuales` residen actualmente de forma exclusiva en el SQLite local del dispositivo móvil.
3. **Formato numérico en base de datos:** Los montos monetarios (`total_original`, `total_usd`, precios de ítems) se guardan en centavos (multiplicados por 100 como enteros) para evitar imprecisiones de coma flotante. La interfaz web debe dividir entre 100 para mostrarlos correctamente.

---

## 2. Comparación de Caminos Técnicos para la Web

```
+------------------------------------+---------------------------------------+
| Opción A: Flutter Web              | Opción B: Panel Web en Astro + SDK    |
+------------------------------------+---------------------------------------+
| ❌ Requiere emulador SQLite (WASM) | ✅ No requiere SQLite (lee Firestore)  |
| ❌ Plugins móviles crashean en web | ✅ Cero incompatibilidades nativas    |
| ❌ Descarga pesada (8-12 MB)       | ✅ Ultraligero (<100 KB) para Vzla   |
| ❌ Sin Flutter SDK local para test | ✅ Se prueba y compila localmente con |
|                                    |    Node.js en segundos                |
| ❌ 4 a 7 días de refactorización   | ✅ 1 a 2 días de desarrollo           |
+------------------------------------+---------------------------------------+
```

> [!IMPORTANT]
> **Decisión Arquitectónica:** Adoptaremos la **Opción B**. Desarrollaremos el panel dentro del proyecto existente de Astro (`landing/src/pages/panel.astro`), desplegándose directamente en `https://rindemas.cesarluis.com/panel`.

---

## 3. Alcance y Cronograma (1 a 2 Días)

### Día 1 & Día 2: Implementación Completa (✅ Implementado y Desplegado)
1. **Sincronización de Presupuestos (Móvil):**
   - [x] Extendido `SyncService` en Flutter para subir y descargar la configuración mensual de presupuestos en `users/{uid}/presupuestos/{anio_mes}`.
   - [x] Soporte para `actualizado_en` y sincronización bidireccional inmediata al cambiar presupuestos.
2. **Reglas de Seguridad en Firestore:**
   - [x] Actualizado `firestore.rules` permitiendo lectura/escritura autenticada en `users/{userId}/presupuestos/{document=**}`.
3. **Autenticación Web en Astro (`/panel`):**
   - [x] Botón *"Iniciar sesión con Google"* usando el SDK oficial de Firebase Web (`signInWithPopup`).
   - [x] Persistencia offline con IndexedDB para carga instantánea.
4. **Dashboard de Resumen y Métricas:**
   - [x] Selector de mes y año con controles de navegación rápida.
   - [x] Tarjetas de métricas: Presupuesto general, total gastado en USD y Bs, dinero disponible/exceso y conteo de facturas.
   - [x] Barras de progreso por categoría y barra general de consumo.
   - [x] Lista de facturas con desglose de ítems, productos y precios.
5. **Edición y Acciones Clave:**
   - [x] Modal de edición de presupuesto general y por categoría con validación en tiempo real.
   - [x] Modal de registro rápido de facturas/gastos optimizado para teclado de escritorio.
   - [x] Eliminación de facturas erróneas con borrado lógico sincronizable.

---

## 4. Cambios Propuestos por Componente

### A. Backend y Reglas de Firestore
#### [MODIFY] `firestore.rules`
Habilitar la colección de presupuestos para el usuario dueño:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/gastos/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /users/{userId}/presupuestos/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### B. Aplicación Móvil (Flutter)
#### [MODIFY] `lib/services/sync_service.dart`
- Agregar `syncPresupuestosToFirestore(User user)` y `syncPresupuestosFromFirestore(User user)`.
- Invocar estos métodos dentro del ciclo `syncBidirectional()`.

### C. Módulo Web (`landing/`)
#### [MODIFY] `landing/package.json`
- Instalar `firebase` (`npm install firebase`).
#### [NEW] `landing/src/pages/panel.astro`
- Interfaz del panel de control con soporte responsivo para móviles (iPhone Safari) y computadoras de escritorio.
- Componente de autenticación y carga reactiva de datos vía Firestore.
#### [MODIFY] `landing/src/pages/index.astro`
- Agregar en la barra de navegación superior el botón *"Iniciar Sesión"* o *"Ver mi cuenta"* que enlace a `/panel`.

---

## 5. Matriz de Riesgos y Mitigaciones

| Riesgo Técnico | Impacto | Mitigación |
| :--- | :--- | :--- |
| **Diferencias de huso horario** | Los gastos de fin de mes podrían agruparse en el mes incorrecto en la web. | Normalizar todas las consultas usando el campo `fecha` ISO (`YYYY-MM-DD`) ya existente en el modelo. |
| **Cálculo de montos en centavos** | Cifras multiplicadas por 100 en pantalla. | Función utilitaria centralizada en JavaScript: `const formatUsd = (cents) => (cents / 100).toFixed(2)`. |
| **Conflictos de edición concurrente** | Modificar un presupuesto en web y móvil al mismo tiempo. | Prioridad al último timestamp (`actualizado_en`) ya implementada en la arquitectura de sincronización. |

---

## 6. Plan de Verificación
1. **Prueba de Sincronización Móvil:** Registrar un gasto y asignar un presupuesto en el teléfono, verificar que aparezcan en la consola de Firebase.
2. **Prueba Web de Lectura:** Iniciar sesión en `localhost:4321/panel` con la cuenta de Google y confirmar que los números coinciden exactamente con la pantalla de la app móvil.
3. **Prueba de Edición Web:** Ajustar el presupuesto en la web, abrir la app móvil y confirmar que el presupuesto se actualice.
4. **Despliegue a Producción:** Compilar `landing` y desplegar con `firebase deploy --only hosting,firestore:rules --non-interactive`.
