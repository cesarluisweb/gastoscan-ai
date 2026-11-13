---
name: revisor-adversarial
description: Auditoría adversarial pre-CI con subagente independiente para detectar bugs de ciclo de vida en dispositivo físico antes de `git push`.
---

# Revisor Adversarial Pre-CI (Rinde Más)

Esta skill define el protocolo obligatorio de revisión adversarial con «ojos frescos» antes de enviar cambios de código (`lib/`, `test/`, `landing/`, `cloudflare-worker/`) a GitHub Actions CI. Su propósito es atrapar en segundos fallos de dispositivo físico y de compilación que las pruebas superficiales pasan por alto, ahorrando corridas de CI de ~12 minutos.

---

## 1. Cuándo Ejecutar Esta Skill

Ejecutar **obligatoriamente antes de `git commit` / `git push`** cuando el cambio modifique:
- Pantallas, hojas modales o widgets interactivos en `lib/ui/` (especialmente formularios, teclados, scroll o navegación).
- Proveedores de estado, servicios o base de datos en `lib/providers/`, `lib/services/` o `lib/data/`.
- Lógica financiera, tasas o sincronización en `landing/src/pages/panel.astro`.

*(Excepción: cambios exclusivamente documentales en archivos `.md` cubiertos por `paths-ignore`).*

---

## 2. Procedimiento Paso a Paso (Subagente Independiente)

Para evitar el sesgo de confirmación del agente autor, la revisión **no** debe hacerse solo leyendo por encima el propio código: se debe invocar un subagente de solo lectura (`invoke_subagent` con `TypeName: "research"` o un subagente definido con `define_subagent` sin herramientas de escritura).

### Paso 1: Lanzar el Subagente Revisor Adversarial
Invocar `invoke_subagent` con:
- **`TypeName`:** `"research"` (o `"revisor-adversarial"` si ya fue definido en la sesión).
- **`Role`:** `"Revisor Adversarial Pre-CI"`
- **`Prompt`:** Indicar explícitamente los archivos modificados y exigir la verificación de la **Lista de Control Adversarial (Sección 3)**, pidiendo un veredicto estricto (`APROBADO` o `RECHAZADO`) con `archivo:línea` exacta de cada hallazgo.

### Paso 2: Resolver Hallazgos Antes del Push
- Si el veredicto es **`RECHAZADO`**, corregir todos los puntos señalados en el código y en los tests antes de hacer `git commit`.
- Prohibido hacer `git push` ignorando un hallazgo bloqueante del revisor adversarial.

---

## 3. Lista de Control Adversarial (Checklist Pre-CI)

El subagente revisor debe auditar implacablemente los siguientes 6 vectores sobre los archivos modificados:

### Vector 1: Reconciliación del Árbol de Elementos (`Widget.canUpdate`) y Foco
- **Hermanos condicionales (`if (...)`) en `Column`, `Row`, `Stack` o `ListView`:**
  - Si un hijo aparece o desaparece dinámicamente (p. ej. `if (!isKeyboardOpen) Container(...)`, `if (isLoading) Padding(...)`), ¿tienen `Key` explícita y única tanto el widget condicional como los hermanos adyacentes del mismo `runtimeType` (`Container`, `Padding`, `SizedBox`)?
  - *Peligro crítico:* Sin `Key`, `MultiChildRenderObjectElement.updateChildren` evalúa `Widget.canUpdate(oldWidget, newWidget) == true` por coincidencia de `runtimeType`, reutiliza el primer `Element` y desmonta el último al final de la lista. Si el último contiene un `TextField` / `EditableTextState` activo, su `deactivate()` ejecuta `_closeInputConnectionIfNeeded()` (`TextInput.hide`) y cierra el teclado de Android en milisegundos.
- **Unicidad de `Key`:** Verificar que ningún widget condicional duplique una `Key` que ya exista en otra parte activa del mismo árbol visual (`bottomNavigationBar` vs cuerpo scrollable).

### Vector 2: `Scaffold` Anidados e Insets del Teclado Virtual (`viewInsets.bottom`)
- **Consumo de `MediaQuery` por `Scaffold` padre:**
  - Si una pantalla con `Scaffold` (como `ChatScreen`) se renderiza dentro del `body` de otro `Scaffold` padre (como `MainScreen` con `resizeToAvoidBottomInset: true`), el `Scaffold` padre envuelve su `body` en `MediaQuery.removeViewInsets(removeBottom: true)`.
  - Por tanto, dentro del hijo, `MediaQuery.of(context).viewInsets.bottom` valdrá siempre `0.0` en dispositivo real aunque en un test aislado funcione.
  - Verificar que la detección de teclado use un helper con fallback a `View.maybeOf(context).viewInsets.bottom / view.devicePixelRatio` y que `didChangeMetrics()` dispare `if (mounted) setState(() {});`.
- **Animación progresiva de teclado en Android (10–15 frames):**
  - En un teléfono real, `viewInsets.bottom` no salta de `0` a `300` en 1 frame (como en `flutter_test`), sino gradualmente (`0 -> 24 -> 80 -> 190 -> 300`).
  - Verificar que ninguna bandera booleana (ej. `_wasNearBottomBeforeKeyboard = false`) se apague en el primer frame de subida (`24 px`), dejando el auto-scroll incompleto a mitad de camino.

### Vector 3: Compilación Estricta en CI (`flutter analyze --fatal-warnings --fatal-infos`)
- **Imports huérfanos o faltantes:** Verificar cada símbolo nuevo en `lib/` y `test/` contra la cabecera de `import`. Un solo `unused_import` rompe el CI.
- **Promoción de nulos en Dart:** Si una variable anulable ya fue validada en una condición previa, prohibido usar `!` o `!= null` redundantes dentro del bloque (`unnecessary_non_null_assertion` / `unnecessary_null_comparison`).
- **Firmas en Fakes de prueba:** Si se tocó un método en un `Provider`, `Repository` o `DatabaseHelper`, verificar con búsqueda global en `test/` que todos los `Fake` mantengan la firma idéntica (`invalid_override` o `UnimplementedError`).
- **Identificadores ASCII:** Cero tildes o `ñ` en nombres de variables, funciones o clases.

### Vector 4: Resiliencia Visual en `360 dp` y Reglas de `DESIGN.md`
- **Contraste:** Fondo amarillo (`AppColors.primary` / `primaryLight` / `primaryDark`) $\rightarrow$ texto e icono SIEMPRE negros (`Colors.black` o `AppColors.textPrimary`). Prohibido texto o icono amarillo sobre fondo blanco.
- **Desbordes `RenderFlex`:** En filas (`Row`) con textos y montos en bolívares (`Bs. 15.850.420,00`), exigir `Expanded`/`Flexible` en etiquetas y `FittedBox(fit: BoxFit.scaleDown)` en montos. En botones con icono/spinner dentro de diálogos, envolver el texto en `Flexible`.

### Vector 5: Robustez Real de las Pruebas en `test/`
- **Pruebas que realmente fallan ante el bug:**
  - En pruebas de teclado y `TextField`, exigir:
    ```dart
    final editableBefore = tester.state<EditableTextState>(find.byType(EditableText));
    expect(tester.testTextInput.isVisible, isTrue);
    // ... cambio de viewInsets ...
    final editableAfter = tester.state<EditableTextState>(find.byType(EditableText));
    expect(identical(editableBefore, editableAfter), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    ```
  - Si la pantalla vive dentro de `MainScreen`, montar el test envolviendo la pantalla en un `Scaffold` padre para reproducir el `removeViewInsets` real de producción.
- **Limpieza de ciclo de vida en `tearDown`:** Verificar `autoLoad: false`, `autoProcess: false`, `SharedPreferences.setMockInitialValues({})` y `tester.view.reset`.

### Vector 6: Seguridad de Árbol Git
- Antes de ejecutar `git add`, verificar `git status -s` para no incluir archivos retenidos o de otras tareas que no correspondan al commit actual (prohibido `git add .` o `git add -A` a ciegas).
