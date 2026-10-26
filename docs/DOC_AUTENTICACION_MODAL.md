# Documento Técnico: Migración a Diálogo Flotante de Autenticación y Vinculación (`AuthEmailDialog`)

**Estado:** Completada ✅ (Validado en dispositivo físico por César)

## 1. Contexto y Justificación
En versiones previas, la vinculación e inicio de sesión con correo (`mostrarModalAutenticacionEmail`) utilizaba `showModalBottomSheet` con `backgroundColor: AppColors.background` y `isScrollControlled: true`. Debido a la presencia de un widget `Center` y la expansión natural de la ruta modal a pantalla completa, la interfaz se pintaba completamente de blanco con franjas vacías arriba y abajo del formulario, rompiendo la apariencia de ventana modal y oscureciendo el fondo de la aplicación.

Adicionalmente, se detectaron áreas de mejora técnica:
1. **Fugas de controladores:** `emailController` y `passwordController` se creaban en el closure y no poseían ciclo de vida formal con `dispose()`.
2. **Tratamiento de excepciones:** En caso de fallos inesperados de red o plataforma, se exponía `e.toString()` directamente al usuario, contraviniendo las directrices de privacidad y calidad de microcopy de Rinde Más.
3. **Peligro de contexto desmontado:** `ScaffoldMessenger.of(context)` se invocaba tras `Navigator.pop(modalContext)`, arriesgando la silenciación del mensaje de éxito.

---

## 2. Arquitectura Implementada

### 2.1 Componente `AuthEmailDialog` (`lib/ui/widgets/auth_modal_sheet.dart`)
- **Presentación:** Invocado vía `showDialog` con `barrierDismissible: true`.
- **Superficie Visual:** Widget `Dialog` con fondo `AppColors.surface`, bordes redondeados (`BorderRadius.circular(20)`), e `insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24)`.
- **Scroll Seguro:** `SingleChildScrollView` dentro de `ConstrainedBox(maxWidth: 480)` que soporta la apertura del teclado virtual en pantallas de 360x640dp sin desbordamientos de `RenderFlex`.
- **Ciclo de Vida:** Extraído a `StatefulWidget` con `dispose()` garantizado para `_emailCtrl` y `_passwordCtrl`.
- **Protección Durante Carga:**
  - `PopScope(canPop: !_isLoading)` bloquea el botón atrás físico mientras la autenticación o sincronización está en curso.
  - Al estar cargando, el intento de toque en el `ModalBarrier` externo no descarta el diálogo.
- **Captura Segura de Contexto:** `ScaffoldMessenger.of(context)` y `SettingsProvider` se capturan antes de cerrar el diálogo con `Navigator.pop(context)`.
- **Sanitización de Errores:** Bloque `catch (_)` que despliega un mensaje amigable en español (*"Ocurrió un error al procesar la solicitud. Verifica tu conexión e intenta de nuevo."*) sin exponer trazas técnicas crudas.

---

## 3. Estado de la Tarea y Gobernanza
- **Clasificación:** Tarea Crítica (`AGENTS.md` §4, punto 8: autenticación y vinculación).
- **Estado Oficial en `ROADMAP.md`:** `Pendiente de validación 🧪`.
- **Regla de Cierre:** El agente NO marca `Completada ✅`. La confirmación requiere la validación explícita de César en *Rinde Más Dev*.

---

## 4. Guía de Validación Paso a Paso para César (*Rinde Más Dev*)

1. **Descarga e Instalación:**
   - Descargar el artefacto `rindemas-dev-apk` desde el resumen de la corrida en GitHub Actions.
   - Instalar o actualizar *Rinde Más Dev* (`com.cesarluis.rindemas.dev`) en el teléfono físico.
2. **Apertura de la Ventana:**
   - Ir a la pestaña **Más** $\rightarrow$ Tocar **Vincular cuenta con correo** (o iniciar sesión).
   - **Verificación visual:** Comprobar que la ventana flote centrada en la pantalla con esquinas redondeadas y fondo oscuro semitransparente (*scrim*) visible alrededor, SIN franjas blancas que llenen la pantalla.
3. **Prueba de Teclado:**
   - Tocar el campo de correo y contraseña para desplegar el teclado.
   - Comprobar que los campos y el botón "Vincular y Respaldar" suban cómodamente sin desbordarse ni cortarse.
4. **Prueba de Cancelación y Cierre:**
   - Tocar la `X` superior o el área oscura exterior: el diálogo debe cerrarse suavemente.
5. **Prueba de Vinculación / Inicio de Sesión:**
   - Probar el flujo con un correo y contraseña de prueba:
     - Comprobar que mientras muestra *"Vinculando y sincronizando..."*, tocar afuera o el botón atrás NO cierre el diálogo a medias.
     - Al completar, verificar la notificación de éxito en la parte inferior de la pantalla.
