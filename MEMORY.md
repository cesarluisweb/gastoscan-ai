# MEMORIA DE TRABAJO (Rinde Más)
> Máximo ~50 líneas. Una idea por línea. Lo permanente se gradúa a `AGENTS.md`, `DESIGN.md` o `.agents/rules/`.

## Estado Inmediato
- **Rama:** `main`. Árbol limpio.
- **Docs reorganizados:** raíz con 6 `.md`; todo lo técnico en `docs/`; histórico en `docs/archive/2026-Q4/`.
- **Router de documentación:** `docs/INDEX.md`.
- **Mapa de código:** `docs/CODE_MAP.md` se regenera con `node scripts/gen_code_map.js`; el hook de pre-commit lo actualiza.

## Tareas en Curso
- **Resiliencia Offline (avatar caché, tasas auto-refresco y Dictar gasto offline):** `Implementada 🔧` en `af9d076` (`docs/DOC_RESILIENCIA_OFFLINE.md`); `wait_ci.ps1` reportó `SIN RUN`, pendiente verificar CI y validar en dispositivo. Reglas graduadas a `.agents/rules/resiliencia-offline.md`, `ia-ocr-voz.md`, `dinero-datos.md` y `revisor-adversarial/SKILL.md`.
- **AI-09 (detección fotos y facturas duplicadas):** Planificada en `ROADMAP.md` y documentada en `docs/DOC_PLAN_DETECCION_DUPLICADOS.md`. Pendiente definición de esquema SQLite (`v20`, candidato a agrupar `tasa_iva_pct INTEGER NULL` si hace falta).
- **AI-10 (reporte funcional de respuestas de IA):** `Pendiente de validación 🧪` (APK build 731, run `44927415737`, SHA `ca86859`; reglas build 6; web build 34, HTTP 200). Colección Firestore `ai_reports`, diálogo con motivo y comentario (chips borde gris/amarillo), purga al borrar cuenta. Doc: `docs/DOC_REPORTE_RESPUESTAS_IA.md`. Falta `deploy_rules.yml` manual (`DEPLOY`) y prueba física. Panel web sigue local.
- **UX-17 (compartir Rinde Más por WhatsApp):** Planificada en `docs/DOC_PLAN_UX17_COMPARTIR_WHATSAPP.md` (App, Panel Web, Landing + Open Graph); diferida hasta tener el enlace público de Google Play.
- **Pendientes de cierre administrativo:** firma P0 (rotar upload key tras aprobar Producción), solicitud de Producción en Google Play y `wrangler deploy` aparte para `'R'` (8%) en Worker.

## Completadas
- **AI-06 (imputación IVA en precios de anaquel — B-2):** ✅ Validada en dispositivo por César (21/11/2026, APK build 732, run `44928418260`, `d25af1d`; Web build 33; Firestore build 5). Revisión al papel + `Con IVA`, mini-selector `G · 16% ▾`, hoja rápida con `Deshacer`, pausa del comparador ante descuadre, detector de 1 culpable y guardado seguro. Reglas graduadas a `DESIGN.md`, `dinero-datos.md` y `revisor-adversarial/SKILL.md`.
- **AI-08 (consejos dinámicos en Inicio):** ✅ Validada en dispositivo por César (21/11/2026, APK build 733, run `44928504292`, SHA `1ab66fa`; Worker `a3975df5`). Lecciones graduadas a `.agents/rules/ia-ocr-voz.md` y `flutter-testing.md` (`docs/DOC_CONSEJOS_DINAMICOS_INICIO.md`).
- **Confirmación Eliminar comprobante + botón borrar en AppBar al editar (`ReviewExpenseScreen`) y recuperación local (`ReceiptPhotoRegistry`):** ✅ Validadas en dispositivo por César (21/11/2026, builds 728 `f629b6e` y 734 `a2b1504`). Reglas graduadas a `privacidad-seguridad.md`, `flutter-desarrollo.md` y `revisor-adversarial/SKILL.md`.
- **Herramientas Panel Web Bloque 1 (Calculadora + Asistente IA):** ✅ Aprobada por César (20/11/2026, build 32, run `44784979988`, `3df3104`, 29/29 tests en CI). Lecciones graduadas a `.agents/rules/web.md` §5 y `.agents/skills/sincronizar-panel-web/SKILL.md`.
- **UX-20 (ítems en ReviewExpenseScreen):** ✅ Validada en dispositivo por César (build 712, `18ae858`, CI verde). Regla graduada a `DESIGN.md` §4.9. Idea pendiente: evaluar término "conceptos" vs "artículos".
- **UX Calculadora Cambiaria (`CurrencyCalculatorScreen`):** ✅ build 714 (`0cc94bd`, run `44539128258`). Autofocus y teclado al abrir/limpiar/swap/tasa personalizada, prefijo `Bs.` fijo, placeholder `22px` negrita y `onDrag`.
- **Rediseño desplegable central (`MainScreen.showAddMenu`):** ✅ build 713 (`8092209`, run `44522447802`). Barrita superior, sin `X`, cajas amarillas `40×40` *outlined*, textos sin IA y flechas derechas.
- **Resaltado de búsqueda en ExpenseCard:** ✅ build 708 (`0a37f8d`, run `43606952757`). Subraya y enmarca ítems y comercios coincidentes.
- **Validadas en dispositivo por César (13/11/2026):** ✅ `UX-14` (build 704, `873367e`), Selector de Mes en AppBar (build 649), Fase 5 Web (build 20), Comparador de Precios v2 (build 700), MoreScreen `UI-02` (build 703) y Arquitectura de Arranque Local-First.
- **Limpieza de ROADMAP.md y reorganización de docs:** ✅ builds 701 y 702 (`856aa67`, `e827d86`). Raíz con 6 `.md`, histórico en `docs/archive/2026-Q4/`, `docs/INDEX.md` y `docs/CODE_MAP.md`.
- **Dictado por voz:** ✅ build 692, `1fdd815`.
- **RM-03 E0-02, E0-03 y E0-04:** ✅ build 678.
- **Reproducibilidad:** ✅ Flutter `3.47.9` y `pubspec.lock` versionado.

## Producción
- **Google Play:** acceso a producción en revisión desde 04/11/2026.
- **Prueba cerrada:** 14 días completados (20/10 a 03/11) con 12 evaluadores; cero crashes y cero ANR.

## Decisiones Técnicas
- Resaltado en búsquedas: `AppColors.primaryLight` + subrayado negro en fragmento; contenedor suave en fila del ítem; prefijo de cantidad aislado para evitar falsos positivos numéricos.
- `versionCode = BASE_BUILD + github.run_number`; nunca recrear `build_apk.yml`.
- Sin JDK local: toda firma se genera en GitHub Actions.
- Rotación de la clave de subida diferida hasta aprobar producción.
- AppBarMonthSelector: mes completo, 3 letras bajo 145 dp, borde amarillo fuera del mes actual.
- Barra de totales anclada al borde físico para proteger el viewport del teclado (`DESIGN.md` 4.7).
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.
- Comparador de precios: compara por unidad comprada en ticket (`total / cant`), no por peso/volumen (kg/L pendiente en Fase 8).
- Redes: bio con Canal de WhatsApp; colab con `@lili9077p`; ganchos: ceguera del Pago Móvil y memoria histórica (exámenes/repuestos).
- Estilo ASD-STE100 en período de prueba; retirar si genera fricción.

## Errores a Evitar
- No encadenar `&&` ni usar `>` en PowerShell.
- No hay Flutter SDK local: todo build y test va por CI.
- Nunca marcar tarea crítica como ✅ sin visto bueno de César.
