# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (commit `6ed34c4`; CI Android build 666 en verde, run 42835194258).
- **Acceso a Producción Google Play:** Segunda ventana de prueba cerrada en curso (Día 3/14 cumplido con 12 evaluadores activos). AAB `1.5.0+669` en Play Console. Fin estimado: ~19/11/2026.
- **Seguridad y Parche de IA en Worker (A1a, A2, C1) — `Pendiente de validación 🧪`:** Cuota compartida persistente con Cloudflare D1 (50/día por UID, 20.000 global), fail-closed estricto (503 si DB no disponible), corte diario en VET (UTC-4), 401 opaco sin fugas y topes de salida (4096 / 8192). 13 tests locales en verde (`workers/test/quota.test.js`); CI aún no corrió sobre estos últimos cambios.
- **Seguridad de firma (P0) — `Pendiente de validación 🧪`:** `android_template/rindemas.jks` fuera de Git; respaldo en `C:\Users\cesar\Documents\RindeMas-Backup-Keystore`. Firma inyectada desde Secrets `ANDROID_KEYSTORE_*`. CI aborta si el SHA-1 restaurado ≠ `D3850D17…` o si el AAB no firma con SHA-256 `B206E47B…`.
- **Reproducibilidad (P0) — `Completada ✅`:** Flutter fijado en `3.47.9`, `pubspec.lock` versionado con guarda anti-drift y `cloud_functions` eliminado.
- **Artefacto para Play:** `app-release-aab` del run 42835194258 (build 666).
- **Artefacto para pruebas en teléfono:** `rindemas-dev-apk` del run 42835194258 (*Rinde Más Dev* build 666).
- **Sincronización Panel Web (Fase 5)** y **Selector de Mes en AppBar:** `Pendiente de validación 🧪` (CI verde, falta visto bueno visual de César).
- **RM-03 (Fase 0A / E0-02) — `Completada ✅`:** CI Build 665 en verde. Visto bueno explícito de César recibido. Transición a `E0-03` (U3/U4: lectores móviles, pantallas y panel web).
- **Próximo Paso Inmediato:** Auditoría del estado real de `E0-03` (U3/U4) en el repositorio y ejecución de los puntos pendientes.

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
