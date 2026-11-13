# Reglas Técnicas del Proyecto (Rinde Más)

## 0. Identidad y Entorno
- **Producto:** Rinde Más (`AppConstants.appName`), finanzas personales *Local-First* para Venezuela. Presupuestos bimonetarios VES/USD, tasas BCV, OCR con IA y listas de compras. Sin conciliación bancaria ni múltiples cuentas.
- **Stack:** Flutter (Dart), Astro + Tailwind, SQLite (`sqflite`), Firebase Auth y Firestore, Cloudflare Workers (gateway de IA), Gemini y GitHub Actions.
- **Ruta oficial:** `C:\Development\Control de gastos VE`. Prohibido operar en rutas del Disco H.
- **Sin Flutter local:** builds, análisis y pruebas se ejecutan solo en GitHub Actions CI.

## 1. Entorno PowerShell Seguro (Windows)
- **UTF-8 obligatorio:** usa `-Encoding UTF8` en `Get-Content`, `Set-Content` y `Out-File`. PowerShell 5.1 lee ANSI por defecto y corrompe acentos.
- **Finales de línea:** normaliza con Node.js o con las herramientas del agente, nunca con PowerShell.
- **Prohibido `>`:** guarda en UTF-16 LE. Usa tuberías con `Out-File archivo -Encoding utf8`.
- **Prohibido `&&`:** en PowerShell 5.1 provoca `ParserError`. Usa `;` o pasos separados.
- **Git de solo lectura** (`status`, `diff`, `log`, `show`): sandbox estándar.
- **Git con escritura** (`add`, `commit`, `checkout`, `restore`), red (`push`, `fetch`) y `scripts/wait_ci.ps1`: sandbox con `BypassSandbox: true`.

## 2. Semáforo Ejecutivo

### 🟢 Siempre
- **CI por proceso dormido único:** tras cada `git push`, lanza una sola vez `scripts/wait_ci.ps1` en segundo plano (tope 25 min, cada 180 s). Prohibido `gh run watch` y consultar turno tras turno. **API:** sin token son 60 peticiones/hora por IP; con `GITHUB_TOKEN` son 5.000/hora. Nunca escribas el token en un archivo versionado. **Excepción:** si el push solo tocó rutas de `paths-ignore`, no lances el monitor.
- **Sin cantar victoria:** no anuncies éxito hasta `conclusion: success`. Si falla, reporta el fallo con su guía de corrección.
- **Publicación web:** solo GitHub Actions despliega landing y panel. Tras el push a `main`, valida por HTTP `https://rindemas.cesarluis.com`.
- **Idioma:** interfaz y respuestas en español neutro/venezolano.
- **Estilo técnico ASD-STE100 (en prueba):** máximo 20 palabras por frase en instrucciones; 25 en descripciones. Voz activa, una idea por frase, un término por concepto. Prefiere tablas o Mermaid.
- **Contraste:** fondo amarillo → texto negro. Fondo claro → texto negro o gris, nunca amarillo (ver `DESIGN.md`).
- **Memoria:** lee `MEMORY.md` al iniciar y actualízalo al terminar.
- **Auditoría de reglas:** tras editar `AGENTS.md`, `.agents/rules/` o `.agents/skills/`, ejecuta `scripts/check_rules.ps1` sin errores.
- **Iteración rápida:** máximo 2 lecturas por bloque de código antes de editar o probar.
- **Ahorro de contexto:** lee `docs/INDEX.md` antes de buscar docs y `docs/CODE_MAP.md` antes de buscar en `lib/` o `test/`. Lee solo rangos necesarios. Nunca leas `docs/archive/`, `scripts/legacy/`, `build_artifacts/` ni `node_modules`.
- **Higiene de tokens:** mantén la raíz libre de `DOC_*`/`PLAN_*` y archivos temporales. Archiva documentación cerrada en `docs/archive/` y no dejes carpetas de runs en `.agents/`.

### ⚠️ Pregunta antes (a César)
- Añadir, quitar o actualizar dependencias en `pubspec.yaml` o `package.json`.
- Cambiar esquemas SQLite, índices, colecciones o reglas de Firestore.
- Cambiar la navegación principal o los flujos de autenticación.
- Eliminar archivos de código o documentación.
- Alternar la visibilidad del repositorio (hoy público; vuelve a privado al terminar).
- Sincronizar al panel web cambios de formularios, flujos, reglas de negocio o cálculo financiero.

### 🚫 Nunca
- Editar `android/` a mano: CI lo regenera.
- Usar `>` o `&&` en PowerShell.
- Declarar la app lista para descargar sin CI en verde.
- Ejecutar `firebase deploy` local sin emergencia autorizada.
- Alojar `.apk` en `landing/public/` o `landing/dist/`: Firebase Spark responde HTTP 400.
- Usar como `FTP_SERVER` un dominio con proxy naranja de Cloudflare: bloquea el puerto 21.
- Introducir conciliación bancaria o microgestión de múltiples cuentas.
- Cablear ratios de cambio o asumir paridad 1:1 (solo USD/USDT).
- Inventar categorías fuera de las 10 de `AppConstants.categorias`.
- Implementar cobros digitales fuera de Google Play Billing.
- Prometer paquetes de IA vitalicia ilimitada.
- Escribir contraseñas, tokens o API keys en archivos versionados.
- Afirmar que los datos van al "Google Drive personal" ni saturar con "Firebase".
- Releer el mismo rango más de 2 veces sin cambios intermedios.
- Descargar el log completo de un job (HTTP 403) ni iterar consultas al API de GitHub.
- Silenciar excepciones con `catch (_) {}` en red, base de datos, `SharedPreferences`, autenticación o gateway de IA.
- Activar ofuscación o reescritura de bytecode: obligatorios `-dontobfuscate`, `-dontoptimize` y `-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod`.
- Ignorar o eliminar `pubspec.lock`.
- Exponer trazas de error o `PlatformException` al usuario final.

## 3. Memoria Dinámica (`MEMORY.md`)
1. Lee `MEMORY.md` al iniciar la tarea.
2. Actualízalo al terminar: estado, decisiones y errores.
3. Máximo ~50 líneas y una idea por línea. Depura lo obsoleto.
4. Si una lección es permanente, muévela a `AGENTS.md`, `DESIGN.md`, `PROJECT.md` o `.agents/rules/`.
5. Si César pide dejar algo por escrito, usa el documento definitivo, no solo `MEMORY.md`.

## 4. Documentación y ROADMAP

| Estado | Significado |
|---|---|
| `Pendiente` | Planificada, sin iniciar |
| `Implementada 🔧` | Commiteada en `main`; CI en curso o sin verificar |
| `Pendiente de validación 🧪` | CI en verde; falta prueba en dispositivo |
| `Completada ✅` | Aprobada |

- **Tarea crítica:** dinero, auth, esquemas de datos, sincronización, refactor multi-subsistema, monetización, publicación, onboarding/login/escaneo o afirmaciones públicas. Se detiene en 🧪 y solo César la marca ✅.
- **Documento técnico:** toda tarea crítica deja un `DOC_*.md` en `docs/` con guía de pruebas.
- **Guía de pruebas válida:** cita archivo:línea real de `lib/ui/`, ruta alcanzable, SHA y número de build. Prohibido inventar controles a partir de servicios o modelos.
- **No críticas:** el agente puede marcarlas ✅ si CI está en verde.

## 5. Índice de Consulta Directa
- **Documentación y rutas:** [`docs/INDEX.md`](./docs/INDEX.md).
- **Mapa de código (antes de buscar en `lib/`):** [`docs/CODE_MAP.md`](./docs/CODE_MAP.md).
- **Código Dart, widgets, importaciones:** [`.agents/rules/flutter-desarrollo.md`](./.agents/rules/flutter-desarrollo.md).
- **Pruebas, fakes y mocks:** [`.agents/rules/flutter-testing.md`](./.agents/rules/flutter-testing.md).
- **Auditoría adversarial pre-push:** [`.agents/skills/revisor-adversarial/SKILL.md`](./.agents/skills/revisor-adversarial/SKILL.md).
- **Landing, panel, Astro o `firebase.json`:** [`.agents/rules/web.md`](./.agents/rules/web.md).
- **Compilar y publicar web:** [`.agents/skills/desplegar-landing/SKILL.md`](./.agents/skills/desplegar-landing/SKILL.md).
- **CI/CD, inyección Android y artefactos:** [`.agents/rules/ci-distribucion.md`](./.agents/rules/ci-distribucion.md).
- **Diagnosticar CI:** [`.agents/skills/diagnosticar-ci/SKILL.md`](./.agents/skills/diagnosticar-ci/SKILL.md).
- **Cloudflare Worker, JWT y endpoints de IA:** [`.agents/rules/gateway-cloudflare.md`](./.agents/rules/gateway-cloudflare.md).
- **Montos, monedas, tasas y presupuestos:** [`.agents/rules/dinero-datos.md`](./.agents/rules/dinero-datos.md).
- **OCR, prompts y voz:** [`.agents/rules/ia-ocr-voz.md`](./.agents/rules/ia-ocr-voz.md).
- **Auth, Firestore, SQLite y privacidad:** [`.agents/rules/privacidad-seguridad.md`](./.agents/rules/privacidad-seguridad.md).
- **Textos de interfaz y microcopy:** [`.agents/rules/marca-terminologia.md`](./.agents/rules/marca-terminologia.md).
- **Comunidad, soporte y marketing:** [`.agents/rules/comunicacion-marketing.md`](./.agents/rules/comunicacion-marketing.md) y [`.agents/skills/respuestas-comunidad/SKILL.md`](./.agents/skills/respuestas-comunidad/SKILL.md).
- **Cuotas de Gemini y modelos:** [`docs/GATEWAY.md`](./docs/GATEWAY.md).
- **Negocio, visión y roadmap:** [`PROJECT.md`](./PROJECT.md) y [`ROADMAP.md`](./ROADMAP.md).
- **Tokens de interfaz:** [`DESIGN.md`](./DESIGN.md).
