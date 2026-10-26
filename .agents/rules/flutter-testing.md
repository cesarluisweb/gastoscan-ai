---
trigger: glob
globs: "test/**/*.dart"
description: "Convenciones para pruebas unitarias y de widgets, configuración de viewports, mocks y aserciones."
---

# Convenciones de Pruebas en Flutter (test/)

## 1. Importaciones y Sintaxis en Pruebas
- **Tolerancia Cero a Imports Huérfanos (`unused_import`):** En CI, `flutter analyze` se ejecuta con la bandera `--fatal-warnings`. Todo import no utilizado en archivos de prueba (`test/**/*.dart`) romperá el build. Verificar y remover imports antes de commitear.
- **Búsqueda de Texto en Widgets Enriquecidos:** Cuando se use `find.textContaining` para evaluar montos o textos renderizados mediante `RichText` o `Text.rich`, especificar obligatoriamente `findRichText: true` para evitar falsos negativos por renderizado compuesto.

## 2. Configuración de Viewport y Renderizado en Pruebas
- **Pantallas con Scroll (Vertical y Horizontal):** En widget tests de pantallas con `ListView`, carruseles o chips desplazables (`Axis.horizontal`), definir siempre en `setUp()` un viewport amplio:
  ```dart
  binding.window.physicalSizeTestValue = const Size(2500, 4000);
  binding.window.devicePixelRatioTestValue = 1.0;
  ```
  Limpiar el valor en `tearDown()` con `binding.window.clearPhysicalSizeTestValue()`.
- **Renderizado Fuera de Pantalla:** Usar `skipOffstage: false` en los `find.text(...)` o `find.byKey(...)` para evitar falsos negativos ocasionados por renderizado perezoso fuera del viewport.
- **Visibilidad Explícita en Formularios con Scroll (`ensureVisible`):** En pruebas sobre pantallas extensas (`ReviewExpenseScreen`, formularios con múltiples tarjetas), antes de invocar `tester.tap()` o `tester.enterText()` sobre campos, botones o chips secundarios, invocar obligatoriamente `await tester.ensureVisible(finder)` seguido de `await tester.pumpAndSettle()`. Esto evita fallos de hit-test cuando los widgets quedan desplazados fuera de los límites de la pantalla del árbol de renderizado.

## 3. Resiliencia y Aislamiento de Firebase
- **Validación de Instancia Activa:** Todo widget o servicio que interactúe con `FirebaseAuth` o Firestore debe validar `Firebase.apps.isNotEmpty` antes de instanciar streams o métodos, garantizando que los tests de widgets se ejecuten limpiamente sin requerir un backend simulado.

## 4. Mocks y Fakes de Arquitectura
- **Firmas Exactas en Fakes:** Al implementar clases simuladas (`FakeGastoProvider`, `FakeSettingsProvider`), replicar con exactitud la firma de los métodos reales, respetando si los parámetros son posicionales o nombrados.
- **Invariante al Modificar Métodos de `GastoProvider`:** Antes de agregar parámetros opcionales o nombrados a métodos públicos de `GastoProvider` (ej. `getSpentForCategory`, `isCategoryOverBudget`, `guardarTodoElPresupuesto`), buscar todas las subclases Fake/Mock en `test/` (`gasto_provider_budget_test.dart`, `dashboard_screen_test.dart`, `budget_bottom_sheet_test.dart`). Si no se actualizan sus `@override`, `flutter analyze` fallará en CI por incompatibilidad de firmas.
- **`ScanQueueProvider` en Tests de Widgets:** Debe instanciarse siempre con `autoProcess: false` para evitar que `loadQueue()` acceda a la base de datos real (`DatabaseHelper`), programe notificaciones o mantenga timers activos que bloqueen `pumpAndSettle()`. En el bloque `tearDown()`, invocar siempre `scanQueueProvider.dispose()`.
- **Sobrescritura en Fakes de `DatabaseHelper`:** Si un fake extiende `DatabaseHelper.test()`, sobrescribir `resetStaleProcessingScanQueueItems()` devolviendo `Future<int>` (no `void`), evitando invocar la base de datos física.
- **Mocks con `noSuchMethod` para APIs Externas:** Al simular plugins de terceros con firmas cambiantes o complejas (`speech_to_text`, clientes HTTP), extender `Fake implements InterfazExterna` y manejar las llamadas mediante:
  ```dart
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #listen) return null;
    return super.noSuchMethod(invocation);
  }
  ```
  Evitar overrides manuales con parámetros `dynamic` que rompan tipado estricto.
- **Desactivación de Carga en Fakes con Constructor Asíncrono:** Todo fake o mock de un proveedor que dispare carga asíncrona en su constructor (ej. `SettingsProvider`) DEBE invocar explícitamente `super(autoLoad: false)` en su constructor para evitar que la carga inicial altere los contadores de llamadas o compita de forma no determinista con las pruebas.

## 5. Aserciones Robustas y Determinismo
- **Aserciones de Moneda y Formato:** Evitar evaluar cadenas literales completas que combinen texto y montos formateados (ej. evitar `find.textContaining('de $100.00 está')`). Validar por separado las frases clave con `contains` independientes (ej. `find.textContaining('Tu meta de ahorro')` y `find.textContaining('comprometida')`), evitando falsos negativos por diferencias de separadores decimales (`.` vs `,`) o espacios de `NumberFormat`.
- **Desambiguación de Montos y Textos Recurrentes:** En pantallas con múltiples tarjetas o desgloses analíticos (donde un mismo monto puede repetirse en totales, gráficos, listas o pies de página), PROHIBIDO usar `find.textContaining(...)` global con `findsOneWidget`. Se debe:
  1. Acotar la búsqueda a su contenedor específico usando `find.descendant`:
     ```dart
     expect(
       find.descendant(
         of: find.byKey(const Key('id_contenedor_o_tarjeta')),
         matching: find.textContaining(CurrencyFormatter.formatUsd(monto)),
       ),
       findsOneWidget,
     );
     ```
  2. O bien, extraer el widget inspeccionado por su `Key` dedicada y validar su contenido textual directamente:
     ```dart
     final widgetText = tester.widget<Text>(find.byKey(const Key('id_widget')));
     final plainText = widgetText.textSpan?.toPlainText() ?? widgetText.data ?? '';
     expect(plainText, contains('Texto esperado'));
     ```
- **Aserciones sobre `RichText`:** Las funciones `find.text()` y `find.textContaining()` no inspeccionan widgets `RichText` a menos que se indique explícitamente `findRichText: true`. Cuando el componente a verificar use `RichText` o `TextSpan` (ej. montos en moneda compuesta), usar:
  ```dart
  expect(find.textContaining(r'$ 30,00', findRichText: true), findsOneWidget);
  ```
- **Determinismo Temporal Obligatorio:** En pruebas cuya lógica dependa del día del mes o cierres de ciclo, inyectar siempre una fecha determinista a través del parámetro `currentDate`. Prohibido evaluar lógica temporal dependiendo de `DateTime.now()`.
- **Sincronización ante Refactors de UI:** Al modificar o sustituir componentes visuales (ej. banners globales por tarjetas individuales), actualizar inmediatamente las `Key` y selectores esperados en los tests asociados antes de enviar cambios al CI.
- **Aserciones de Geometría en Diálogos Flotantes (`Dialog`):** Al evaluar la posición o anclaje (`getTopLeft`, `getBottomLeft`) de un diálogo modal, la `Key` de prueba DEBE asignarse a la superficie visible interior (`ConstrainedBox`, `Material` o `Container`), NUNCA al widget `Dialog` raíz. El widget `Dialog` abarca todo el lienzo de la ruta en coordenadas `(0, 0)`, por lo que consultar su posición superior siempre evaluará en `0.0`.
- **Aislamiento en Pruebas de BottomSheets y Diálogos:** Para validar geometría, márgenes de seguridad o insets de teclado en hojas desplegables y modales, PROHIBIDO montar pantallas complejas completas (`MainScreen`, `ReviewExpenseScreen`) en viewports estrechos (360x640dp) si no es el objeto directo de la prueba. Se debe evaluar la hoja en aislamiento montando un `Scaffold` básico con un botón disparador que llame a la función estática (`Clase.show(...)` o `Clase.mostrar(...)`).
- **Cero Advertencias en Archivos de Test:** El pipeline de CI corre con `--fatal-warnings`. Prohibido dejar importaciones huérfanas (`unused_import`) o advertencias en los archivos dentro de `test/`.
