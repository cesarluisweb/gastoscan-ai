# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (commit `75f3965`; CI Android build 671 en verde, run 42853151974; CI Web build 23 en verde, run 42852053353).
- **Acceso a Producción Google Play:** Segunda ventana de prueba cerrada en curso (Día 3/14 cumplido con 12 evaluadores activos). AAB `1.5.0+669` en Play Console. Fin estimado: ~19/11/2026.
- **Seguridad, Cuotas, Galería e Integridad (A1a, B2, C1, C2) — `Pendiente de validación 🧪`:** CI build 671 en verde sobre commit `75f3965` (650 tests). Cuota D1 (50/día UID, 20k global, VET UTC-4, fail-closed). B2: copia en galería del sistema activada por defecto. C1/C2: saneamiento de montos y SemanticValidator al 50% en visión. Pendiente explícito: `wrangler deploy` del Worker y decisión sobre reglas de Firestore. Falta prueba en dispositivo.
- **Seguridad de firma (P0) — `Pendiente de validación 🧪`:** `android_template/rindemas.jks` fuera de Git; firma inyectada desde Secrets. CI verificado con SHA-256 en build 671.
- **Reproducibilidad (P0) — `Completada ✅`:** Flutter fijado en `3.47.9`, `pubspec.lock` versionado con guarda anti-drift.
- **Artefacto para Play:** `app-release-aab` del run 42853151974 (build 671).
- **Artefacto para pruebas en teléfono:** `rindemas-dev-apk` del run 42853151974 (*Rinde Más Dev* build 671).
- **Sincronización Panel Web (Fase 5)** y **Selector de Mes en AppBar:** `Pendiente de validación 🧪` (CI verde, falta visto bueno visual de César).
- **RM-03 (Fase 0A / E0-02) — `Completada ✅`:** CI Build 665 en verde. Visto bueno explícito de César recibido.
- **RM-03 (Fase 0A / E0-03) — `Pendiente de validación 🧪`:** Lectores móviles, pantallas y panel web completados (H-1, H-2, A-16, D-06, D-07). Lentes monetarios independientes, denominaciones canónicas en `MoreScreen` y `CurrencyCalculatorScreen`, panel web Astro validado. Guía de pruebas en `docs/DOC_E0_03_LECTORES_MULTIMONEDA.md`.
- **Próximo Paso Inmediato:** Validación por César en teléfono físico (*Rinde Más Dev* build 671) siguiendo la guía de `docs/DOC_E0_03_LECTORES_MULTIMONEDA.md`.

## Decisiones Técnicas y de Negocio Recientes
- **Rotación de la clave de subida: diferida** hasta que Google apruebe el acceso a Producción. No reinicia la revisión, pero el reset tarda 24-72 h y bloquearía una subida inmediata. El repositorio público conserva el `.jks` en el historial, por lo que la rotación sigue siendo necesaria.
- **No hay JDK local:** `keytool` no existe en la máquina de César. Cualquier generación/exportación de keystore debe hacerse vía GitHub Actions o instalando Temurin.
- **`versionCode = BASE_BUILD + github.run_number`:** nunca renombrar ni recrear `build_apk.yml` (reinicia `run_number` y el código retrocedería, causando rechazo en Play).
- AppBarMonthSelector: Nombre completo del mes sin año ('Noviembre'), conmutación automática a 3 letras ('Nov') ante `effectiveMaxWidth < 145`, flechas negras transparentes (19 dp) y borde amarillo de acento (`AppColors.primaryDark`) fuera del mes actual.
- Navegación mensual: Flechas directas integradas en la cápsula y diálogo de 12 meses accesible al pulsar el texto central.
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.
- **Redes Sociales (Consenso Muse 09/11):** Bio = Canal de WhatsApp directo (`/channel/0029VbEPwHLDJ6H678QLlN1H`). Reels con colaboración manual obligatoria a `@lili9077p`. Voz calmada/asesor. Test A/B horario: Lunes 7:00 PM vs Miércoles 6:00 PM. Cierre: *"el enlace del canal está en el perfil"*.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido marcar Tareas Críticas como `Completada ✅` sin visto bueno explícito de César en *Rinde Más Dev*.
