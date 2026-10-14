---
trigger: glob
globs: "test/**/*.dart"
description: "Convenciones para pruebas unitarias y de widgets, configuración de viewports, mocks y aserciones."
---

# Convenciones de Pruebas en Flutter (test/)

## 1. Configuración de Viewport y Renderizado en Pruebas
- **Pantallas con Scroll (Vertical y Horizontal):** En widget tests de pantallas con `ListView`, carruseles o chips desplazables (`Axis.horizontal`), definir siempre en `setUp()` un viewport amplio:
  ```dart
  binding.window.physicalSizeTestValue = const Size(2500, 4000);
  binding.window.devicePixelRatioTestValue = 1.0;
  ```
  Limpiar el valor en `tearDown()` con `binding.window.clearPhysicalSizeTestValue()`.
- **Renderizado Fuera de Pantalla:** Usar `skipOffstage: false` en los `find.text(...)` o `find.byKey(...)` para evitar falsos negativos ocasionados por renderizado perezoso fuera del viewport.

## 2. Resiliencia y Aislamiento de Firebase
- **Validación de Instancia Activa:** Todo widget o servicio que interactúe con `FirebaseAuth` o Firestore debe validar `Firebase.apps.isNotEmpty` antes de instanciar streams o métodos, garantizando que los tests de widgets se ejecuten limpiamente sin requerir un backend simulado.

## 3. Mocks y Fakes de Arquitectura
- **Firmas Exactas en Fakes:** Al implementar clases simuladas (`FakeGastoProvider`, `FakeSettingsProvider`), replicar con exactitud la firma de los métodos reales, respetando si los parámetros son posicionales o nombrados.
- **Mocks con `noSuchMethod` para APIs Externas:** Al simular plugins de terceros con firmas cambiantes o complejas (`speech_to_text`, clientes HTTP), extender `Fake implements InterfazExterna` y manejar las llamadas mediante:
  ```dart
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #listen) return null;
    return super.noSuchMethod(invocation);
  }
  ```
  Evitar overrides manuales con parámetros `dynamic` que rompan tipado estricto.

## 4. Aserciones Robustas y Determinismo
- **Aserciones de Moneda y Formato:** Evitar evaluar cadenas literales completas que combinen texto y montos formateados (ej. evitar `find.textContaining('de $100.00 está')`). Validar por separado las frases clave con `contains` independientes (ej. `find.textContaining('Tu meta de ahorro')` y `find.textContaining('comprometida')`), evitando falsos negativos por diferencias de separadores decimales (`.` vs `,`) o espacios de `NumberFormat`.
- **Determinismo Temporal Obligatorio:** En pruebas cuya lógica dependa del día del mes o cierres de ciclo, inyectar siempre una fecha determinista a través del parámetro `currentDate`. Prohibido evaluar lógica temporal dependiendo de `DateTime.now()`.
- **Sincronización ante Refactors de UI:** Al modificar o sustituir componentes visuales (ej. banners globales por tarjetas individuales), actualizar inmediatamente las `Key` y selectores esperados en los tests asociados antes de enviar cambios al CI.
