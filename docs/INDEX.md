# Índice de Navegación (Rinde Más)

> Lee esta tabla antes de buscar documentación. No abras `docs/archive/` salvo petición explícita de César.

## 1. Documentos raíz (siempre vigentes)

| Documento | Cuándo leerlo |
|---|---|
| `AGENTS.md` | Contrato operativo: autonomía, prohibiciones, entorno |
| `MEMORY.md` | Estado inmediato de trabajo y próximos pasos |
| `ROADMAP.md` | Tareas activas, estados y prioridades |
| `PROJECT.md` | Visión, modelo de negocio y estrategia |
| `DESIGN.md` | Tokens, paleta, tipografía y reglas visuales |
| `README.md` | Onboarding humano y stack |

## 2. Reglas modulares (`.agents/rules/`)

| Archivo | Activación | Tema |
|---|---|---|
| `flutter-desarrollo.md` | glob | Dart, widgets, imports, modelos |
| `flutter-testing.md` | glob | Pruebas unitarias y de widgets |
| `ci-distribucion.md` | glob | Pipeline, inyección Android, artefactos |
| `web.md` | glob | Astro, panel, cabeceras, paleta web |
| `gateway-cloudflare.md` | glob | Worker, JWT, cuotas, observabilidad |
| `dinero-datos.md` | model_decision | Montos, monedas, tasas, categorías |
| `ia-ocr-voz.md` | model_decision | Gemini, OCR, voz, desambiguación |
| `privacidad-seguridad.md` | model_decision | Auth, Firestore, SQLite, Data Safety |
| `marca-terminologia.md` | model_decision | Microcopy, modales, notificaciones |
| `comunicacion-marketing.md` | model_decision | Soporte, foros, bitácora de marketing |

## 3. Skills (`.agents/skills/`)

| Skill | Cuándo invocarla |
|---|---|
| `revisor-adversarial` | Auditoría pre-push de `git diff` |
| `diagnosticar-ci` | Fallos de GitHub Actions y reportes remotos |
| `desplegar-landing` | Build y despliegue de landing y panel |
| `sincronizar-panel-web` | Portar flujos de Flutter a Astro |
| `firebase-security-rules-auditor` | Auditoría de `firestore.rules` |
| `security-audit` | Revisión de seguridad amplia (costosa) |
| `material-3` | Componentes y tokens Material 3 |
| `flutter-apply-architecture-best-practices` | Arquitectura por capas en Flutter |
| `generador-contenido-redes` | Guiones y copys para redes |
| `respuestas-comunidad` | Respuestas en Reddit y soporte |
| `growth-first-100-users` | Publicación en Play y primeros 100 usuarios |

## 4. Documentos técnicos vigentes (`docs/`)

| Área | Documento |
|---|---|
| Dinero y tasas | `docs/DOC_TASAS_EQUIVALENCIAS_MULTIMONEDA.md`, `docs/DOC_PRECIOS_ANAQUEL_IVA.md` |
| Sincronización | `docs/DOC_E0_04_SYNC_CAS_TOMBSTONES.md`, `docs/DOC_SINCRONIZACION_OFFLINE.md`, `docs/DOC_SINCRONIZACION_PRESUPUESTO.md` |
| Arranque y auth | `docs/DOC_ARRANQUE_LOCAL_FIRST.md`, `docs/DOC_AUTENTICACION_MODAL.md`, `docs/DOC_CONFIGURACION_GOOGLE_SIGNIN.md` |
| IA y OCR | `docs/DOC_BYOK_GEMINI.md`, `docs/GATEWAY.md`, `docs/DOC_GUIA_PRUEBAS_SEGURIDAD_IA.md` |
| Gastos y UX | `docs/DOC_COMPARADOR_PRECIOS.md`, `docs/DOC_COMPROBANTES_Y_GALERIA.md`, `docs/DOC_ASISTENTE_LISTA_COMPRAS_Y_UX.md`, `docs/DOC_DICTADO_VOZ_CONTINUO.md`, `docs/DOC_MAS_REDISENO.md` |
| Panel web | `docs/DOC_SINCRONIZACION_PANEL_WEB.md`, `docs/DOC_MODERNIZACION_PANEL_WEB.md` |
| Categorías | `docs/DOC_AUTOCATEGORIZACION_LOCAL.md` |
| Play Store | `docs/DOC_FICHA_PLAY_STORE.md`, `docs/FICHA_GOOGLE_PLAY.md`, `docs/DOC_DECLARACION_SEGURIDAD_DATOS_PLAY.md`, `docs/DOC_CUESTIONARIO_PRODUCCION.md` |
| Marketing | `docs/DOC_BITACORA_MARKETING.md`, `docs/GUIA_BROADCAST_FIREBASE.md` |
| Firestore | `docs/DOC_REGLAS_FIRESTORE_B1.md` |
| Diseño | `docs/design-system.html` |

## 5. Contrato RM-03 (`docs/rm-03/`)

| Documento | Uso |
|---|---|
| `contrato-v1.2.md` | Contrato normativo multimoneda |
| `especificacion-consolidada-u1-u2.md` | Especificación de hitos U1-U2 |
| `estado-actual.md` | Estado de E0-02 a E0-04 |
| `decisiones.md` | Decisiones aprobadas (D-04, D-06, D-07) |
| `auditorias/` | Historial de reauditorías (solo consulta) |

## 6. Archivo histórico (`docs/archive/2026-Q4/`)

Contiene 25 documentos cerrados: planes viejos, auditorías, correcciones y el `ROADMAP_HISTORICO.md`.
No leer salvo que César pida antecedentes de una fase terminada.

## 7. Rutas que nunca se leen

`landing/node_modules/`, `workers/node_modules/`, `firebase_functions/node_modules/`, `landing/dist/`, `landing/.astro/`, `scripts/legacy/`, `build_artifacts/`.
