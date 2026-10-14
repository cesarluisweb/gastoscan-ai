# Reglas Técnicas del Proyecto (Rinde Más)

## 0. Identidad del Proyecto y Entorno
- **Nombre y Propósito:** Rinde Más (`AppConstants.appName`) es una aplicación de finanzas personales *Local-First* para Venezuela, enfocada en presupuestos bimonetarios (VES/USD), tasas oficiales del BCV, escaneo OCR de facturas con IA y listas de compras, sin conciliaciones bancarias complejas ni múltiples cuentas.
- **Stack Tecnológico:** Flutter (Dart), Astro + Tailwind (Web), SQLite (`sqflite`), Firebase Auth y Cloud Firestore, Cloudflare Workers (Gateway de IA), Google Gemini API y GitHub Actions (CI/CD).
- **Ruta de Trabajo Oficial:** `C:\Development\Control de gastos VE`. Prohibido operar o buscar archivos en rutas del Disco H.
- **Sin Flutter Local:** El SDK de Flutter NO está instalado en la máquina local del usuario. Todo build, análisis estático y suite de pruebas se ejecuta exclusivamente en la nube mediante GitHub Actions CI.

## 1. Entorno PowerShell Seguro (Windows)
- **Codificación UTF-8 Obligatoria:** Al crear o modificar archivos con PowerShell (`Set-Content`, `Out-File`), usar SIEMPRE el parámetro `-Encoding UTF8`. Omitirlo corrompe acentos y caracteres especiales.
- **Prohibición del Operador `>`:** Prohibido usar el operador de redirección `>` en PowerShell (guarda en UTF-16 LE). Usar siempre tuberías: `... | Out-File archivo.ext -Encoding utf8`.
- **Separador de Comandos en PowerShell 5.1:** Prohibido encadenar comandos con `&&` (provoca `ParserError`). Utilizar siempre el punto y coma `;` o invocar comandos en pasos independientes.

## 2. Semáforo Ejecutivo de Autonomía

### 🟢 Siempre (Incondicional):
- **Monitoreo de CI tras Git Push:** Monitorear activamente GitHub Actions vía API tras cada `git push` hasta confirmar `conclusion: success` antes de notificar al usuario.
- **Canal Único de Publicación Web:** GitHub Actions es el único canal autorizado para desplegar la landing page y el panel a producción en Firebase Hosting. Tras el push a `main`, validar vía HTTP que los cambios estén visibles en `https://rindemas.cesarluis.com`.
- **Idioma y Localización:** Mantener textos de interfaz y respuestas en español neutro/venezolano.
- **Contraste y Paleta (`DESIGN.md`):** Fondo amarillo $\rightarrow$ texto SIEMPRE negro (`Colors.black` o `AppColors.textPrimary`). Fondo blanco/claro $\rightarrow$ texto negro o gris, NUNCA amarillo. El amarillo queda reservado exclusivamente para iconos, contenedores con texto negro y bordes de acento activo.
- **Protocolo de Memoria:** Consultar `MEMORY.md` al iniciar una tarea y actualizarlo al finalizarla.
- **Iteración Rápida:** Romper el análisis e iterar hacia la acción (editar/probar) en un máximo de 2 lecturas por bloque de código.

### ⚠️ Pregunta antes (Consultar a César):
- Añadir, eliminar o actualizar dependencias en `pubspec.yaml` o `package.json` (instalar existentes con `npm install` está permitido).
- Modificar esquemas de datos (tablas SQLite, índices, colecciones o reglas de Firestore).
- Cambiar la arquitectura de navegación principal o flujos de autenticación.
- Eliminar archivos existentes de código o documentación.
- Alternar la visibilidad del repositorio a Público ante emergencias de cuota agotada de GitHub Actions.

### 🚫 Nunca (Prohibiciones estrictas en una línea):
- Modificar archivos en `android/` de forma manual o local (CI los regenera).
- Usar el operador `>` o el operador `&&` en PowerShell.
- Cantar victoria o decir que la app "está lista para descargar" tras un commit sin confirmar CI en verde.
- Ejecutar `firebase deploy` en local salvo emergencia técnica expresa autorizada por César.
- Alojar archivos binarios `.apk` en `landing/public/` o `landing/dist/` (Firebase Spark los bloquea con HTTP 400).
- Usar dominios con proxy naranja de Cloudflare como `FTP_SERVER` en CI/CD (bloquea el puerto 21 de FTP).
- Introducir conciliación bancaria o microgestión de múltiples cuentas (anti-filosofía de Rinde Más).
- Utilizar ratios de cambio cableados o asumir paridad 1:1 entre divisas (multimoneda determinista obligatoria).
- Inventar categorías fuera de las 8 canónicas oficiales de `AppConstants.categorias`.
- Implementar cobros digitales dentro de la app Android fuera de Google Play Billing (riesgo de suspensión de cuenta).
- Prometer paquetes de IA vitalicia ilimitada en planes o microcopy.
- Escribir contraseñas, tokens o API keys en texto plano en archivos versionados por git.
- Afirmar que los datos se guardan en el "Google Drive personal" o saturar la interfaz con tecnicismos como "Firebase".
- Ejecutar bucles de relectura redundante (`view_file` más de 2 veces sobre el mismo rango sin cambios intermedios).

## 3. Protocolo de Memoria Dinámica (`MEMORY.md`)
1. **Al iniciar:** Leer `MEMORY.md` para situarse en el estado inmediato de trabajo.
2. **Al finalizar:** Actualizar `MEMORY.md` con el estado final, decisiones tomadas y errores a evitar.
3. **Brevedad Estricta:** Mantener `MEMORY.md` en máximo ~50 líneas, depurando apuntes obsoletos.
4. **Graduación Obligatoria:** Si una lección o patrón se vuelve permanente, moverlo al archivo definitivo correspondiente (`AGENTS.md`, `DESIGN.md`, `PROJECT.md` o `.agents/rules/`) y eliminarlo de `MEMORY.md`.
5. **Prohibido Anotar Solo en MEMORY.md:** Cuando César pida 'anotar algo', registrarlo de inmediato en su documento definitivo. `MEMORY.md` es solo un borrador volátil de trabajo inmediato.

## 4. Protocolo de Documentación y ROADMAP

### Estados Oficiales de Tareas en `ROADMAP.md`:
- `Pendiente`: Tarea planificada no iniciada.
- `Implementada 🔧`: Código commiteado en `main` y CI en curso o aún no confirmado en verde.
- `Pendiente de validación 🧪`: CI en verde (`conclusion: success`) y, si aplica, verificación HTTP en producción; pendiente de prueba manual por César.
- `Completada ✅`:
  - **Tareas no críticas:** El agente puede marcarla cuando CI esté en verde y se hayan completado las verificaciones técnicas. Si requiere prueba en dispositivo no cubierta por CI, mantenerla en 🧪 y avisar a César.
  - **Tareas críticas:** El agente se detiene obligatoriamente en `Pendiente de validación 🧪`. **Solo César marca `Completada ✅`** tras su visto bueno explícito.

### Definición Estricta de Tareas Críticas:
Se considera Tarea Crítica cualquier cambio que involucre:
1. Dinero, monedas (VES/USD/EUR/USDT), tasas de cambio o cálculos financieros.
2. Autenticación, sesiones y manejo de credenciales o tokens.
3. Esquemas de datos (migraciones SQLite, índices, colecciones o reglas de Firestore).
4. Sincronización en la nube (`SyncService`) y borrado de cuentas o purga de datos.
5. Refactorizaciones que afecten a dos o más subsistemas simultáneamente (móvil, web, Cloudflare Worker).
6. Monetización: Google Play Billing, anuncios (Better Ads), cuotas de IA y planes.
7. Publicación: releases del APK/AAB a Play Store y cambios de configuración de hosting o dominios.
8. Flujos de usuario de onboarding, login/vinculación y escaneo/revisión de compras.
9. Modificaciones que afecten afirmaciones públicas sobre privacidad, seguridad, tratamiento de datos, términos, precios, límites o promesas a usuarios.

*Protocolo para Tareas Críticas:* Registrar los cambios en un documento técnico dedicado (`DOC_*.md`), proveer a César una guía de pruebas paso a paso y esperar su visto bueno antes de dar por cerrada la tarea.

## 5. Índice de Consulta Directa ("Si vas a hacer X, consulta Y")

Antes de ejecutar tareas en áreas específicas, consulta la regla modular o skill correspondiente:

- **Código Dart, maquetación de widgets, imports o modelos:** Consulta [`.agents/rules/flutter-desarrollo.md`](./.agents/rules/flutter-desarrollo.md).
- **Pruebas unitarias, de widgets, fakes o mocks en Dart:** Consulta [`.agents/rules/flutter-testing.md`](./.agents/rules/flutter-testing.md).
- **Landing page, panel web, Astro o `firebase.json`:** Consulta [`.agents/rules/web.md`](./.agents/rules/web.md).
- **Compilar y publicar la landing o panel web:** Ejecuta la skill [`.agents/skills/desplegar-landing/SKILL.md`](./.agents/skills/desplegar-landing/SKILL.md).
- **Pipeline de CI/CD, inyección en Android o BanaHosting FTP:** Consulta [`.agents/rules/ci-distribucion.md`](./.agents/rules/ci-distribucion.md).
- **Diagnosticar fallos de CI o leer reportes de tests remotos:** Ejecuta la skill [`.agents/skills/diagnosticar-ci/SKILL.md`](./.agents/skills/diagnosticar-ci/SKILL.md).
- **Cloudflare Worker, autenticación JWT de Firebase o endpoints de IA:** Consulta [`.agents/rules/gateway-cloudflare.md`](./.agents/rules/gateway-cloudflare.md).
- **Montos, monedas, tasas, presupuestos mensuales o categorías:** Consulta [`.agents/rules/dinero-datos.md`](./.agents/rules/dinero-datos.md).
- **Extracción OCR con Gemini, prompts de IA, voz o desambiguación:** Consulta [`.agents/rules/ia-ocr-voz.md`](./.agents/rules/ia-ocr-voz.md).
- **Autenticación, Firestore, almacenamiento local o privacidad:** Consulta [`.agents/rules/privacidad-seguridad.md`](./.agents/rules/privacidad-seguridad.md).
- **Textos de interfaz, modales, notificaciones o microcopy de facturas:** Consulta [`.agents/rules/marca-terminologia.md`](./.agents/rules/marca-terminologia.md).
- **Respuestas para comunidades (Reddit), soporte o marketing:** Consulta [`.agents/rules/comunicacion-marketing.md`](./.agents/rules/comunicacion-marketing.md) y la skill [`.agents/skills/respuestas-comunidad/SKILL.md`](./.agents/skills/respuestas-comunidad/SKILL.md).
- **Cuotas de Gemini, modelos vigentes o IDs operativos:** Consulta [`docs/GATEWAY.md`](./docs/GATEWAY.md).
- **Modelo de negocio, visión estratégica y roadmap:** Consulta [`PROJECT.md`](./PROJECT.md) y [`ROADMAP.md`](./ROADMAP.md).
- **Tokens de interfaz y reglas visuales:** Consulta [`DESIGN.md`](./DESIGN.md).
