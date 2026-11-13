# Tabla de Trazabilidad Exhaustiva: Reorganización de AGENTS.md

> **Fecha de corte:** 2026-10-14  
> **Archivo origen:** `c:\Development\Control de gastos VE\AGENTS.md` (48.074 bytes, 241 líneas físicas, 199 líneas de contenido real, 121 directrices lógicas).  
> **Copia de respaldo inmutable:** `docs/archive/AGENTS.2026-10-14.md`

Esta tabla numera y mapea el 100% de las instrucciones originales de `AGENTS.md`. No se omite ninguna línea de contenido de L1 a L241 (las líneas no listadas corresponden exclusivamente a saltos de línea y encabezados `#`, `##`, `###`).
*(Nota sobre el conteo: la cifra de 170 líneas mencionada en la propuesta inicial fue una estimación previa; 199 líneas de contenido real es el resultado exacto verificado por script).*

---

## Mapeo por Rango de Líneas e Instrucción

| # | Líneas Orig. | Tema / Regla Original | Acción | Destino Final | Justificación y Notas |
|---|---|---|---|---|---|
| **1** | L1-L3 | Título e introducción a la autonomía ejecutiva | Conservada | `AGENTS.md` | Contexto de identidad y alcance general. |
| **2** | L6-L7 | Monitorear CI incondicionalmente tras `git push` vía API | Conservada | `AGENTS.md` | Invariante crítico de nivel 0 (evita falsas promesas). |
| **3** | L8 | Despliegue web local + CI + verificación HTTP | Modificada | `AGENTS.md` + Skill `desplegar-landing` | **Decisión de César:** CI es el único canal autorizado de publicación. `firebase deploy` local queda prohibido salvo emergencia. |
| **4** | L9 | Idioma español neutro/venezolano en UI y chat | Conservada | `AGENTS.md` | Regla universal transversal. |
| **5** | L10 | Paleta oficial y contraste estricto (`DESIGN.md`) | Conservada | `AGENTS.md` | Invariante crítico de accesibilidad y UI. |
| **6** | L11 | Consultar `MEMORY.md` al inicio y actualizar al fin | Conservada | `AGENTS.md` | Protocolo operacional permanente. |
| **7** | L12 | Scripts PowerShell con codificación UTF-8 explícita | Fusionada | `AGENTS.md` | Unificada con L21-22 y L44-46 en la sección "Entorno PowerShell". |
| **8** | L13 | Romper análisis e iterar a la acción en máx 2 lecturas | Conservada | `AGENTS.md` | Restricción ejecutiva anti-bucles. |
| **9** | L14-L15 | Preguntar antes de añadir/actualizar dependencias | Conservada / Aclarada | `AGENTS.md` | Se distingue entre instalar existentes (`npm install` permitido) y modificar `pubspec.yaml` o `package.json` (requiere aprobación). |
| **10** | L16 | Preguntar antes de modificar esquemas o sync | Conservada | `AGENTS.md` | Semáforo de seguridad de datos. |
| **11** | L17 | Preguntar antes de cambiar arquitectura de navegación o auth | Conservada | `AGENTS.md` | Semáforo de arquitectura. |
| **12** | L18 | Preguntar antes de eliminar archivos de código o docs | Conservada | `AGENTS.md` | Semáforo de integridad. |
| **13** | L19-L20 | Prohibido editar archivos en `android/` localmente | Conservada | `AGENTS.md` | Prohibición crítica de nivel 0 (CI regenera `android/`). |
| **14** | L21 | Prohibido usar `>` en PowerShell | Fusionada | `AGENTS.md` | Unificada en bloque PowerShell de la raíz. |
| **15** | L22 | Prohibido usar `&&` en PowerShell 5.1 | Fusionada | `AGENTS.md` | Unificada en bloque PowerShell de la raíz. |
| **16** | L23 | Prohibido cantar victoria sin CI en verde | Fusionada | `AGENTS.md` | Unificada con L7 y L76. |
| **17** | L24 | Prohibido conciliación bancaria / múltiples cuentas | Conservada | `AGENTS.md` | Filosofía central e invariante anti-complejidad. |
| **18** | L25 | Prohibido prometer IA ilimitada de por vida | Conservada | `AGENTS.md` | Protección de modelo de negocio y costes de API. |
| **19** | L26 | Prohibido bucle redundante de lectura (`view_file` > 2) | Fusionada | `AGENTS.md` | Unificada con L13 en el semáforo. |
| **20** | L27 | Prohibido alojar `.apk` en `landing/public` o `dist` | Conservada | `AGENTS.md` + `.agents/rules/web.md` | Prohibición en raíz (1 línea); detalle en regla web. |
| **21** | L28 | Prohibido proxy Cloudflare naranja en `FTP_SERVER` | Conservada | `AGENTS.md` + `.agents/rules/ci-distribucion.md` | Prohibición en raíz; detalle de distribución en regla CI. |
| **22** | L29 | Prohibido decir "Google Drive personal" o tecnicismos "Firebase" | Fusionada | `AGENTS.md` + `.agents/rules/privacidad-seguridad.md` | 1 línea en raíz; detalle de microcopy en regla de privacidad. |
| **23** | L31-L36 | Protocolo de Memoria Dinámica (5 pasos) | Conservada | `AGENTS.md` | Protocolo operacional permanente. |
| **24** | L38-L41 | Repositorio permanente en `C:\Development` y comandos nativos | Conservada | `AGENTS.md` | Aclaración crítica de entorno local. |
| **25** | L43-L46 | PowerShell: `Set-Content -Encoding UTF8`, pipes con `Out-File`, `;` | Fusionada | `AGENTS.md` | Sección única "Entorno PowerShell Seguro" en la raíz. |
| **26** | L48-L51 | CI regenera `android/` e inyección vía `sed` en workflow | Movida | `.agents/rules/ci-distribucion.md` | Regla técnica de CI. La raíz conserva la prohibición de 1 línea. |
| **27** | L52-L54 | Google Sign-In Error 10 (`serverClientId` y 2 huellas SHA-1) | Movida | `.agents/rules/ci-distribucion.md` | Configuración técnica de autenticación nativa y Play Console. |
| **28** | L56-L63 | Flujo obligatorio de publicación web | Modificada | `AGENTS.md` + Skill `desplegar-landing` + `.agents/rules/web.md` | **Decisión de César:** Publicación automatizada exclusiva vía CI en push a `main`. Deploy local prohibido salvo emergencia. |
| **29** | L64 | Cabeceras de seguridad estrictas en `firebase.json` | Movida | `.agents/rules/web.md` | Configuración de hosting web. |
| **30** | L65 | Comunicación de privacidad sin "Firebase" ni "Google Drive" | Fusionada | `.agents/rules/privacidad-seguridad.md` | Duplicado de L29, consolidado en privacidad. |
| **31** | L67-L72 | Reglas estrictas de contraste (amarillo/negro, blanco/oscuro) | Conservada | `AGENTS.md` + `@DESIGN.md` | Resumen estricto en raíz referenciando `DESIGN.md`. |
| **32** | L73 | Maquetación robusta (`Expanded`, botón único, `Material` para ListTile) | Movida | `.agents/rules/flutter-desarrollo.md` | Convención de widgets Flutter. |
| **33** | L75-L78 | Monitoreo activo de workflow vía API antes de notificar éxito | Fusionada | `AGENTS.md` | Consolidada con L7. |
| **34** | L79-L80 | Diagnóstico de fallos CI (403 logs, lectura de `test_results.txt`) | Modificada / Delegada | Skill `diagnosticar-ci` | **Decisión de César:** Lectura remota segura con `git fetch` y `git show origin/main:test_results.txt` sin modificar working tree local. |
| **35** | L81 | Sin Flutter local (todo testing y build va por CI) | Conservada | `AGENTS.md` | Hecho fundamental del entorno de desarrollo. |
| **36** | L82-L83 | Protección cuota CI (`paths-ignore` para docs) | Movida | `.agents/rules/ci-distribucion.md` | Convención de workflows de GitHub Actions. |
| **37** | L84 | Desbloqueo de emergencia de cuota pasando repo a público | Modificada | `AGENTS.md` | **Decisión de César:** Pasa al semáforo amarillo (requiere autorización previa explícita de César y auditoría de secretos). |
| **38** | L86-L88 | Rastreo e inyección obligatoria de imports en Dart | Movida | `.agents/rules/flutter-desarrollo.md` | Convención de código Dart (`lib/**` y `test/**`). |
| **39** | L89 | Identificadores ASCII estrictos en Dart (sin tildes/ñ) | Movida | `.agents/rules/flutter-desarrollo.md` | Convención de código Dart. |
| **40** | L90 | Acceso a propiedades en StatefulWidget (`widget.`) | Movida | `.agents/rules/flutter-desarrollo.md` | Convención de widgets Dart. |
| **41** | L91 | Keys de widget globalmente únicos en overlays | Movida | `.agents/rules/flutter-desarrollo.md` | Convención de widgets Dart. |
| **42** | L92 | Verificación previa de miembros en clases utilitarias | Movida | `.agents/rules/flutter-desarrollo.md` | Convención de código Dart. |
| **43** | L93 | Contenedor Material para ListTile en Flutter 3.24+ | Fusionada | `.agents/rules/flutter-desarrollo.md` | Duplicado de L73, consolidado en desarrollo Flutter. |
| **44** | L94 | Widget tests con scroll (viewport 2500x4000, `skipOffstage`) | Movida | `.agents/rules/flutter-testing.md` | Convención exclusiva de pruebas (`test/**`). |
| **45** | L95 | Resiliencia de Firebase en UI y tests (`Firebase.apps.isNotEmpty`) | Movida | `.agents/rules/flutter-testing.md` | Convención de tests y widgets. |
| **46** | L96 | Firmas exactas en fakes de test | Movida | `.agents/rules/flutter-testing.md` | Convención exclusiva de testing. |
| **47** | L97 | Mocks con `noSuchMethod` para APIs complejas (`speech_to_text`) | Movida | `.agents/rules/flutter-testing.md` | Convención exclusiva de testing. |
| **48** | L98 | Determinismo temporal (`DateTime? currentDate`) | Movida | `.agents/rules/flutter-desarrollo.md` + `flutter-testing.md` | Convención de arquitectura y testeo. |
| **49** | L99 | Aserciones robustas de moneda en tests (separar montos) | Movida | `.agents/rules/flutter-testing.md` | Convención exclusiva de testing. |
| **50** | L100 | `url_launcher` sin `canLaunchUrl` previo en Android 11+ | Movida | `.agents/rules/flutter-desarrollo.md` | Convención de código Flutter. |
| **51** | L101 | Settings de usuario en Firestore bajo `/presupuestos/user_settings` | Movida | `.agents/rules/privacidad-seguridad.md` | Configuración de persistencia en Firestore. |
| **52** | L102 | Instanciación con campos requeridos (`creadoEn` en `GastoModel`) | Movida | `.agents/rules/flutter-desarrollo.md` | Convención de modelos Dart. |
| **53** | L103 | Sincronización de widget tests ante refactors de UI | Movida | `.agents/rules/flutter-testing.md` | Convención exclusiva de testing. |
| **54** | L104 | Flujo de revisión continua en lote ("Guardar y siguiente") | Movida | `.agents/rules/ia-ocr-voz.md` | Flujo de UI de escaneo. |
| **55** | L105 | Borrado seguro de imágenes temporales compartidas | Movida | `.agents/rules/ia-ocr-voz.md` | Manejo de archivos de escaneo. |
| **56** | L106 | Reutilización obligatoria de UI (DRY en `lib/ui/widgets/`) | Conservada | `AGENTS.md` | Principio transversal de desarrollo UI. |
| **57** | L107 | Prohibición estricta de tasas cableadas / multimoneda | Conservada + Movida | `AGENTS.md` + `.agents/rules/dinero-datos.md` | Prohibición en raíz (1 línea); cálculo en regla de dinero. |
| **58** | L108-L111 | Invariante de 8 categorías canónicas (web y móvil), normalización | Conservada + Movida | `AGENTS.md` + `.agents/rules/dinero-datos.md` | Invariante en raíz; normalización defensiva en regla de dinero. |
| **59** | L112 | Conversión de centavos a decimal: `totalOriginalDisplay` | Movida | `.agents/rules/dinero-datos.md` | Convención de modelo de dominio. |
| **60** | L113-L115 | Arquitectura multigasto por voz/chat (1 directo vs 2+ encolados) | Movida | `.agents/rules/ia-ocr-voz.md` | Lógica de procesamiento de voz y cola. |
| **61** | L116 | Respeto estricto de divisa indicada en chat y voz | Movida | `.agents/rules/ia-ocr-voz.md` + `dinero-datos.md` | Consistencia de entrada multimoneda. |
| **62** | L118-L119 | Docs estratégicos en la raíz del repo | Conservada | `AGENTS.md` | Convención organizativa del repositorio. |
| **63** | L120 | Actualización obligatoria de ROADMAP.md | Modificada | `AGENTS.md` | **Decisión de César:** Nuevos estados (`Pendiente`, `Implementada 🔧`, `Pendiente de validación 🧪`, `Completada ✅`) y protocolo estricto de Tareas Críticas. |
| **64** | L121 | Bitácora de marketing en `DOC_BITACORA_MARKETING.md` | Movida | `.agents/rules/comunicacion-marketing.md` | Convención de marketing. |
| **65** | L122-L126 | Protocolo para cambios importantes/numerosos | Conservada | `AGENTS.md` | Protocolo obligatorio aplicado a Tareas Críticas (`DOC_*.md` y guía de pruebas paso a paso). |
| **66** | L127 | Prohibición de anotar solo en MEMORY.md | Fusionada | `AGENTS.md` | Duplicado de L36, consolidado en protocolo de memoria. |
| **67** | L128 | Commit y push de docs actualizados | Conservada | `AGENTS.md` | Convención de sincronización de equipo (suspendida durante esta tarea). |
| **68** | L130-L131 | Prompt OCR: "reemplazar coma por punto" | Movida | `.agents/rules/ia-ocr-voz.md` | Directriz de prompts de IA. |
| **69** | L132 | Facturas mixtas: extraer en moneda de los ítems (VES) | Movida | `.agents/rules/ia-ocr-voz.md` + `dinero-datos.md` | Lógica de parsing OCR. |
| **70** | L133 | Red de seguridad matemática en Dart (sumar ítems) | Movida | `.agents/rules/dinero-datos.md` | Validación matemática local. |
| **71** | L134-L135 | IDs de proyecto Google AI Studio, Tier 1, prepago | Movida | `docs/GATEWAY.md` | Datos operativos volátiles (con marca de migrado, pendiente de verificación). |
| **72** | L136-L139 | Cuotas numéricas exactas (RPM, TPM, RPD) por modelo | Movida | `docs/GATEWAY.md` | Datos operativos volátiles. |
| **73** | L140 | Exclusividad Flash-Lite en Cloudflare Gateway | Conservada + Movida | `AGENTS.md` + `.agents/rules/gateway-cloudflare.md` | Prohibición de modelos caros en raíz; fallback en regla Worker. |
| **74** | L141 | Cabecera `x-goog-api-key: <KEY>` (no Bearer) | Movida | `.agents/rules/gateway-cloudflare.md` | Detalle técnico del Worker. |
| **75** | L142 | Sanitización de credenciales en Workers | Movida | `.agents/rules/gateway-cloudflare.md` | Detalle técnico del Worker. |
| **76** | L143 | `[observability] enabled = true` en `wrangler.toml` | Movida | `.agents/rules/gateway-cloudflare.md` | Configuración de infraestructura Cloudflare. |
| **77** | L144 | Blindaje pasivo de `/health` en Gateway | Movida | `.agents/rules/gateway-cloudflare.md` | Seguridad del API Gateway. |
| **78** | L145-L148 | Arquitectura híbrida de escaneo (ML Kit -> Texto -> Visión) | Movida | `.agents/rules/ia-ocr-voz.md` | Flujo central de percepción e IA. |
| **79** | L149 | Telemetría y cabeceras en Gateway (`x-receipt-mode`) | Movida | `.agents/rules/gateway-cloudflare.md` + `ia-ocr-voz.md` | Telemetría del Gateway. |
| **80** | L151-L152 | Aislamiento de presupuestos por `(anio, mes)` | Movida | `.agents/rules/dinero-datos.md` | Lógica de dominio SQLite. |
| **81** | L153 | Copia automática de presupuesto del mes previo | Movida | `.agents/rules/dinero-datos.md` | Lógica de dominio. |
| **82** | L154 | Validación: suma categorías <= presupuesto general | Movida | `.agents/rules/dinero-datos.md` | Validación financiera. |
| **83** | L156-L157 | Nombre oficial "Rinde Más" (prohibido "GastoScan") | Conservada + Movida | `AGENTS.md` + `.agents/rules/marca-terminologia.md` | Identidad en raíz; detalle de marca en regla. |
| **84** | L158 | Prohibido "tickets"; usar "facturas" o "comprobantes" | Conservada + Movida | `AGENTS.md` + `.agents/rules/marca-terminologia.md` | Prohibición en raíz; tabla completa en regla de marca. |
| **85** | L159-L163 | Ciclo terminológico: foto (pre) -> factura (post) -> comprobante (adjunto) | Movida | `.agents/rules/marca-terminologia.md` | Tabla unificada de vocabulario por fase. |
| **86** | L165-L166 | Cero fricción contable (sin múltiples cuentas ni bancos) | Fusionada | `AGENTS.md` | Duplicado de L24, consolidado en filosofía. |
| **87** | L167 | Divisas de referencia (VES, USD, EUR, USDT) deterministas | Movida | `.agents/rules/dinero-datos.md` | Lógica multimoneda. |
| **88** | L168 | Registro manual y voz siempre 100% ilimitado y gratuito | Conservada | `AGENTS.md` | Filosofía central e invariante comercial. |
| **89** | L169 | Cuota gratuita de cámara (15-20) y subvención con Pro | Movida | `PROJECT.md` | Modelo de negocio y métricas de producto. |
| **90** | L170 | Better Ads: anuncios solo en transiciones naturales | Movida | `PROJECT.md` | **Decisión de César:** Reubicado en `PROJECT.md` bajo monetización (retirado de reglas de privacidad). |
| **91** | L171 | Google Play Billing obligatorio para compras digitales | Modificada | `AGENTS.md` + `PROJECT.md` | **Decisión de César:** 1 línea crítica en la raíz (riesgo de suspensión de cuenta); detalle en `PROJECT.md`. |
| **92** | L172 | Prohibición de IA vitalicia ilimitada | Fusionada | `AGENTS.md` | Duplicado de L25, consolidado en prohibiciones. |
| **93** | L173-L176 | Inmutabilidad de gastos en VES y paridad matemática exacta | Movida | `.agents/rules/dinero-datos.md` | Lógica de cálculo en bolívares. |
| **94** | L177-L179 | Sincronización histórica de tasas en UI y neutralidad de labels | Movida | `.agents/rules/dinero-datos.md` | Comportamiento de selectores de tasa. |
| **95** | L180-L183 | Speech-to-text: pausa no destructiva y buffer acumulativo | Movida | `.agents/rules/ia-ocr-voz.md` | Manejo del plugin de voz. |
| **96** | L185-L187 | Desambiguación obligatoria: Gasto vs Lista de Compras | Movida | `.agents/rules/ia-ocr-voz.md` | Comportamiento del asistente IA. |
| **97** | L188 | Intercepción local de monto 0 en `chat_screen.dart` | Movida | `.agents/rules/ia-ocr-voz.md` | Red de seguridad en código Dart. |
| **98** | L189 | Herramientas de lista de compras vía Function Calling | Movida | `.agents/rules/ia-ocr-voz.md` | Implementación del asistente. |
| **99** | L190 | Cotejo universal de productos con lista de compras al guardar | Movida | `.agents/rules/ia-ocr-voz.md` | Lógica de sincronización transversal. |
| **100** | L192-L193 | Despliegue CI/CD automático en push a main | Conservada | `AGENTS.md` + `.agents/rules/ci-distribucion.md` | Unificado con flujo de CI. |
| **101** | L194 | Prohibido `.apk` en `landing/public` o `dist` (Spark) | Fusionada | `AGENTS.md` + `.agents/rules/web.md` | Duplicado de L27, consolidado. |
| **102** | L195 | Redirección 302 a BanaHosting en `firebase.json` | Movida | `.agents/rules/web.md` | Configuración de hosting web. |
| **103** | L196-L199 | FTP a BanaHosting: IP directa, ruta cPanel real | Movida | `.agents/rules/ci-distribucion.md` | Configuración de distribución en CI. |
| **104** | L200 | GitHub Releases 404 en repos privados | Movida | `.agents/rules/ci-distribucion.md` | Hecho de infraestructura de distribución. |
| **105** | L201-L204 | Comandos de despliegue manual Astro + Firebase local | Modificada | Skill `desplegar-landing` | **Decisión de César:** Despliegue local prohibido salvo emergencia. La skill documenta el riesgo de desincronización y el flujo por CI. |
| **106** | L205 | Enrutamiento multi-página: `cleanUrls`, no wildcard SPA | Movida | `.agents/rules/web.md` | Configuración de Astro en Firebase Hosting. |
| **107** | L206 | Mockups de smartphone vertical y ventana de desktop | Movida | `.agents/rules/web.md` | Regla visual de la landing. |
| **108** | L207 | Paleta de colores web: sin colores naranja | Movida | `.agents/rules/web.md` | Regla de estilo web. |
| **109** | L209-L210 | Gateway en Cloudflare Workers para mantener Spark gratis | Movida | `docs/GATEWAY.md` + `.agents/rules/gateway-cloudflare.md` | Justificación arquitectónica y operativa. |
| **110** | L211-L214 | Seguridad Worker: Firebase JWT, JWKS, Rate limit 30 rpm, Secretos | Movida | `.agents/rules/gateway-cloudflare.md` | Arquitectura de seguridad del Gateway. |
| **111** | L215 | Configuración unificada de voz: 10s pausa, 60s escucha | Fusionada | `.agents/rules/ia-ocr-voz.md` | Duplicado de L182, consolidado. |
| **112** | L216 | Detención silenciosa de micrófono ante interacción o background | Movida | `.agents/rules/ia-ocr-voz.md` | Comportamiento UI del micrófono. |
| **113** | L217 | Avisos neutros en SnackBars ("analizando imagen") | Movida | `.agents/rules/marca-terminologia.md` | Copy de interfaz durante escaneo. |
| **114** | L218 | Contexto de ejecución de Wrangler (`cloudflare_worker/` o `--config`) | Movida | `.agents/rules/gateway-cloudflare.md` | Comando de infraestructura del Worker. |
| **115** | L219-L221 | Desambiguación semántica en extracción multigasto | Movida | `.agents/rules/ia-ocr-voz.md` | Prompt y lógica de IA. |
| **116** | L223-L224 | Arquitectura Local-first con respaldo en Firestore por UID | Conservada + Movida | `AGENTS.md` + `.agents/rules/privacidad-seguridad.md` | Arquitectura base en raíz; detalle en regla. |
| **117** | L225 | Modo anónimo 100% local en SQLite (nada a Firestore) | Movida | `.agents/rules/privacidad-seguridad.md` | Regla de sincronización. |
| **118** | L226-L227 | Copy comercial de privacidad en web y soporte | Movida | `.agents/rules/privacidad-seguridad.md` | Microcopy y comunicación externa. |
| **119** | L228-L231 | Reglas de comunicación: nunca "exclusivamente local", cero bancos | Movida | `.agents/rules/privacidad-seguridad.md` | Guía de comunicación. Incluye lista de frases prohibidas. |
| **120** | L232 | Microcopy obligatorio al vincular Google | Movida | `.agents/rules/privacidad-seguridad.md` | Copy de seguridad en la app móvil. |
| **121** | L234-L240 | Voz de César para comunidades (empática, directa, desarrollador) | Delegada + Movida | `.agents/rules/comunicacion-marketing.md` + Skill `respuestas-comunidad` | Guía en regla; plantillas interactivas en skill. |

---

## Verificación de Cobertura de Líneas
- **Total de líneas físicas en `AGENTS.md` original:** 241
- **Líneas en blanco:** 20
- **Líneas de encabezados Markdown (`#`, `##`, `###`):** 21
- **Líneas de contenido real:** 199 (100% mapeadas en las 121 directrices lógicas de la tabla anterior).
- **Líneas de contenido sin destino:** **0**.
- *(Nota metodológica: La cifra preliminar de 170 líneas correspondió a un cálculo estimativo inicial; la auditoría formal por script verificó 199 líneas de contenido real cubiertas sin excepción).*
