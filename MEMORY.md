# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (commit `5219134`; CI Android build 664 en verde, versión `1.5.0+669`).
- **Acceso a Producción Google Play:** Solicitud enviada el 04/11/2026 07:42. Al 05/11/2026 la consola muestra **Producción `Inactivo`** y *"Estamos revisando tu formulario de solicitud"* (7 días o menos). No se puede crear release de producción todavía; el AAB 1.5.0 (669) va a prueba cerrada.
- **Seguridad de firma (P0) — `Pendiente de validación 🧪`:** `android_template/rindemas.jks` fuera de Git; respaldo en `C:\Users\cesar\Documents\RindeMas-Backup-Keystore`. Firma inyectada desde Secrets `ANDROID_KEYSTORE_*`. CI aborta si el SHA-1 restaurado ≠ `D3850D17…` o si el AAB no firma con SHA-256 `B206E47B…`.
- **Reproducibilidad (P0) — `Completada ✅`:** Flutter fijado en `3.47.9`, `pubspec.lock` versionado (idéntico al del runner) con guarda anti-drift y `cloud_functions` eliminado. 638 pruebas en verde.
- **Artefacto para Play:** `app-release-aab` del run 42091003101 (build 664 → versionCode 669, versionName 1.5.0).
- **Artefacto para pruebas en teléfono:** `rindemas-dev-apk` del mismo run (*Rinde Más Dev* 1.5.0/669).
- **Sincronización Panel Web (Fase 5)** y **Selector de Mes en AppBar:** `Pendiente de validación 🧪` (CI verde, falta visto bueno visual de César).
- **Próximo Paso Inmediato:** César sube el AAB a prueba cerrada y valida el APK Dev 1.5.0/669.

## Decisiones Técnicas y de Negocio Recientes
- **Rotación de la clave de subida: diferida** hasta que Google apruebe el acceso a Producción. No reinicia la revisión, pero el reset tarda 24-72 h y bloquearía una subida inmediata. El repositorio público conserva el `.jks` en el historial, por lo que la rotación sigue siendo necesaria.
- **No hay JDK local:** `keytool` no existe en la máquina de César. Cualquier generación/exportación de keystore debe hacerse vía GitHub Actions o instalando Temurin.
- **`versionCode = BASE_BUILD + github.run_number`:** nunca renombrar ni recrear `build_apk.yml` (reinicia `run_number` y el código retrocedería, causando rechazo en Play).
- AppBarMonthSelector: Nombre completo del mes sin año ('Noviembre'), conmutación automática a 3 letras ('Nov') ante `effectiveMaxWidth < 145`, flechas negras transparentes (19 dp) y borde amarillo de acento (`AppColors.primaryDark`) fuera del mes actual.
- Navegación mensual: Flechas directas integradas en la cápsula y diálogo de 12 meses accesible al pulsar el texto central.
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido marcar Tareas Críticas como `Completada ✅` sin visto bueno explícito de César en *Rinde Más Dev*.
