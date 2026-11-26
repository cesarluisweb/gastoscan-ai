# MEMORIA DE TRABAJO (Rinde Más)
> Máximo ~50 líneas. Una idea por línea. Lo permanente se gradúa a `AGENTS.md`, `DESIGN.md` o `.agents/rules/`.

## Estado Inmediato
- **Rama:** `main`. Árbol limpio.
- **Docs reorganizados:** raíz con 6 `.md`; todo lo técnico en `docs/`; histórico en `docs/archive/2026-Q4/`.
- **Router de documentación:** `docs/INDEX.md`.
- **Mapa de código:** `docs/CODE_MAP.md` se regenera con `node scripts/gen_code_map.js`; el hook de pre-commit lo actualiza.

## Tareas en Curso
- **Resiliencia y Visibilidad de Sincronización App ↔ Web:** `Pendiente de validación 🧪` (CI verde: móvil run `45646396832` build `740`, SHA `04b7ff4`; web build `36`, reglas build `9`, SHA `46a01f7`; `docs/DOC_RESILIENCIA_SINCRONIZACION_APP_WEB.md`). `SyncRunReport` con aislamiento por documento en pull, propagación real de errores a `SyncCoordinator`, estado en vivo + botones circulares parejos en 1.ª tarjeta de `Más`, banner persistente en Inicio, `firestoreId`/`ocrText` preservados al editar, reemplazo completo de presupuestos y auto-refresco + botón `Actualizar` en `panel.astro`.
- **RET-02 (Notificación diaria de tasa de cambio L–V 8:30 AM VET):** `Pendiente de validación 🧪` (CI verde: run `45450349971`, build `737`, SHA `47f661f`, `v1.6.0`; Worker `566a8c79-6efc-4389-bcbc-83773bd67594` con `FIREBASE_SERVICE_ACCOUNT_JSON` cargado, 24/24 tests y 1.er envío real FCM OK `6137537734076172547` el 25/11/2026 a `anuncios_generales` para cubrir `v1.5.0`; pasar `DAILY_RATES_TOPIC` a `"tasa_diaria"` al publicar `v1.6.0` en Play; `docs/DOC_NOTIFICACION_TASA_DIARIA.md`). Pendiente confirmación de llegada en dispositivo.
- **Resiliencia Offline (avatar caché, tasas auto-refresco y Dictar gasto offline):** `Implementada 🔧` en `af9d076` (`docs/DOC_RESILIENCIA_OFFLINE.md`); `wait_ci.ps1` reportó `SIN RUN`, pendiente verificar CI y validar en dispositivo. Reglas graduadas a `.agents/rules/resiliencia-offline.md`, `ia-ocr-voz.md`, `dinero-datos.md` y `revisor-adversarial/SKILL.md`.
- **AI-09 (detección fotos y facturas duplicadas):** Planificada en `ROADMAP.md` y documentada en `docs/DOC_PLAN_DETECCION_DUPLICADOS.md`. Pendiente definición de esquema SQLite (`v20`, candidato a agrupar `tasa_iva_pct INTEGER NULL` si hace falta).
- **AI-11 (Asistente IA Contextual — Etapas 0, 1 y 2):** Planificada en `ROADMAP.md`; auditoría y diseño de Etapa 0 en `docs/DOC_PLAN_ASISTENTE_CONTEXTUAL_E0.md` (sin código aún). Hallazgos: Chat normal sin `hiddenSignals`, `top_productos_mes` sin normalización fiscal `AI-06`/orden `total_usd`, proyección enviada en días 1–3 y `brecha_capturada` residual en web `ai-assistant.js:456`.
- **UX-17 (compartir Rinde Más por WhatsApp):** Planificada en `docs/DOC_PLAN_UX17_COMPARTIR_WHATSAPP.md` (App, Panel Web, Landing + Open Graph); diferida hasta tener el enlace público de Google Play.
- **Pendientes de cierre administrativo:** firma P0 (rotar upload key tras aprobar Producción) y **Google Play Producción 3.ª ventana (21/11–06/12/2026): AAB `739 (1.5.0)` en envío; próxima actualización `REL-03` (~30/11) en `1.6.0` inyecta `android.hardware.screen.portrait` `required="false"` en CI**. *(Worker `'R'` 8% + cron `tasa_diaria` ya desplegados en `0a387358`).*

## Completadas
- **UX-21 + REL-04 + REL-03 (`v1.6.0`):** ✅ Validada por César (26/11/2026, móvil run `45626426264` build `738`/`versionCode 743`, web build `35`, reglas build `8`, SHA `e1303bb`; `docs/DOC_UX21_DUPLICAR_GASTO.md`). `version.json` sigue en `1.0.0/1` hasta Producción abierta (`ci-distribucion.md:30`). AAB listo para Actualización #2 en Play Console.
- **AI-10 (reporte funcional de respuestas de IA):** ✅ Confirmada en Firebase por César (21/11/2026, APK build 731, reglas build 6, web build 34). Colección `ai_reports`, purga al borrar cuenta. Doc: `docs/DOC_REPORTE_RESPUESTAS_IA.md`.
- **AI-06 (imputación IVA en precios de anaquel — B-2):** ✅ Validada en dispositivo por César (21/11/2026, APK build 732, run `44928418260`, `d25af1d`; Web build 33; Firestore build 5). Revisión al papel + `Con IVA`, mini-selector `G · 16% ▾`, hoja rápida con `Deshacer`, pausa del comparador ante descuadre, detector de 1 culpable y guardado seguro. Reglas graduadas a `DESIGN.md`, `dinero-datos.md` y `revisor-adversarial/SKILL.md`.
- **AI-08 (consejos dinámicos en Inicio):** ✅ Validada en dispositivo por César (21/11/2026, APK build 733, run `44928504292`, SHA `1ab66fa`; Worker `a3975df5`). Corregida invalidación de caché por firma FNV-1a + frescura diaria + cuota 3/día + debounce 3 s (CI verde: run `45652738532`, build `741`, SHA `f472a8b`, `Pendiente de validación 🧪`) y ampliada el 26/11/2026 con 3 tips curados (8 total) y micro-hábito (CI verde: run `45826508910`, build `742`, SHA `f5783f3`; Worker `45291d82`). Lecciones graduadas a `.agents/rules/ia-ocr-voz.md` y `flutter-testing.md` (`docs/DOC_CONSEJOS_DINAMICOS_INICIO.md`).
- **Confirmación Eliminar comprobante + botón borrar en AppBar al editar (`ReviewExpenseScreen`) y recuperación local (`ReceiptPhotoRegistry`):** ✅ Validadas en dispositivo por César (21/11/2026, builds 728 `f629b6e` y 734 `a2b1504`). Reglas graduadas a `privacidad-seguridad.md`, `flutter-desarrollo.md` y `revisor-adversarial/SKILL.md`.
- **Herramientas Panel Web Bloque 1 (Calculadora + Asistente IA):** ✅ Aprobada por César (20/11/2026, build 32, run `44784979988`, `3df3104`, 29/29 tests en CI). Lecciones graduadas a `.agents/rules/web.md` §5 y `.agents/skills/sincronizar-panel-web/SKILL.md`.
- **UX-20 (ítems en ReviewExpenseScreen):** ✅ Validada en dispositivo por César (build 712, `18ae858`, CI verde). Regla graduada a `DESIGN.md` §4.9. Idea pendiente: evaluar término "conceptos" vs "artículos".
- **UX Calculadora Cambiaria (`CurrencyCalculatorScreen`):** ✅ build 714 (`0cc94bd`, run `44539128258`). Autofocus y teclado al abrir/limpiar/swap/tasa personalizada, prefijo `Bs.` fijo, placeholder `22px` negrita y `onDrag`.
- **Rediseño desplegable central (`MainScreen.showAddMenu`):** ✅ build 713 (`8092209`, run `44522447802`). Barrita superior, sin `X`, cajas amarillas `40×40` *outlined*, textos sin IA y flechas derechas.
- **Resaltado de búsqueda en ExpenseCard:** ✅ build 708 (`0a37f8d`, run `43606952757`). Subraya y enmarca ítems y comercios coincidentes.
- **Validadas en dispositivo por César (13/11/2026):** ✅ `UX-14` (build 704, `873367e`), Selector de Mes en AppBar (build 649), Fase 5 Web (build 20), Comparador de Precios v2 (build 700), MoreScreen `UI-02` (build 703) y Arquitectura de Arranque Local-First.
- **Limpieza de ROADMAP.md y reorganización de docs:** ✅ builds 701 y 702 (`856aa67`, `e827d86`). Raíz con 6 `.md`, histórico en `docs/archive/2026-Q4/`, `docs/INDEX.md` y `docs/CODE_MAP.md`.
- **Reproducibilidad:** ✅ Flutter `3.47.9` y `pubspec.lock` versionado.

## Producción
- **Google Play:** segunda prueba cerrada de 14 días finalizada el 20/11/2026; nueva solicitud de producción enviada el 20/11/2026 (en revisión).
- **Prueba cerrada:** dos ciclos de 14 días completados con 12 evaluadores; cero crashes y cero ANR.

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
