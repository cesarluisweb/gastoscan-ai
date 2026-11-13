# MEMORIA DE TRABAJO (Rinde Más)
> Máximo ~50 líneas. Una idea por línea. Lo permanente se gradúa a `AGENTS.md`, `DESIGN.md` o `.agents/rules/`.

## Estado Inmediato
- **Rama:** `main`. Árbol limpio.
- **Docs reorganizados:** raíz con 6 `.md`; todo lo técnico en `docs/`; histórico en `docs/archive/2026-Q4/`.
- **Router de documentación:** `docs/INDEX.md`.
- **Mapa de código:** `docs/CODE_MAP.md` se regenera con `node scripts/gen_code_map.js`; el hook de pre-commit lo actualiza.

## Tareas en Curso
- **Comparador de Precios v2:** `Pendiente de validación 🧪` (build 700, `02233c6`). Doc en `docs/DOC_COMPARADOR_PRECIOS.md`.
- **Próximo paso:** prueba en dispositivo físico por César en *Rinde Más Dev*; luego retomar `E0-05b`.
- **Validaciones pendientes de César en *Rinde Más Dev*:** Comparador de Precios v2 (build 700), MoreScreen UI-02 (build 703, `cc89f5e`), Selector de Mes en AppBar (build 649, `0eb455a`), Fase 5 Web (build 20, `14003f7`), firma P0 (build 671).
- **UX-14 (estado vacío contextual):** `Implementada 🔧` (`5ac3684`).
- **Idea pendiente:** validar en dispositivo dictado por voz (build 692, `1fdd815`) junto al resto.

## Completadas
- **Reorganización de documentación y mapa de código:** ✅ builds 701 y 702 (`856aa67`, `e827d86`). Raíz con 6 `.md`, histórico en `docs/archive/2026-Q4/`, `docs/INDEX.md` y `docs/CODE_MAP.md` generado por script.
- **Dictado por voz:** ✅ build 692, `1fdd815`.
- **RM-03 E0-02, E0-03 y E0-04:** ✅ build 678.
- **Reproducibilidad:** ✅ Flutter `3.47.9` y `pubspec.lock` versionado.

## Producción
- **Google Play:** acceso a producción en revisión desde 04/11/2026.
- **Prueba cerrada:** 14 días completados (20/10 a 03/11) con 12 evaluadores; cero crashes y cero ANR.

## Decisiones Técnicas
- `versionCode = BASE_BUILD + github.run_number`; nunca recrear `build_apk.yml`.
- Sin JDK local: toda firma se genera en GitHub Actions.
- Rotación de la clave de subida diferida hasta aprobar producción.
- AppBarMonthSelector: mes completo, 3 letras bajo 145 dp, borde amarillo fuera del mes actual.
- Barra de totales anclada al borde físico para proteger el viewport del teclado (`DESIGN.md` 4.7).
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.
- Redes: bio con Canal de WhatsApp; colaboración manual con `@lili9077p`.
- Estilo ASD-STE100 en período de prueba; retirar si genera fricción.

## Errores a Evitar
- No encadenar `&&` ni usar `>` en PowerShell.
- No hay Flutter SDK local: todo build y test va por CI.
- Nunca marcar tarea crítica como ✅ sin visto bueno de César.
