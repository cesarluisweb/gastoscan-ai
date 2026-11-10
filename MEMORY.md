# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (commit `659ae07`; CI Android build 677 en verde, run 42877000686; CI Web build 26 en verde, run 42877000681; orientación vertical fijada con `DeviceOrientation.portraitUp`).
- **Acceso a Producción Google Play:** Segunda ventana de prueba cerrada en curso (Día 3/14 cumplido con 12 evaluadores activos). AAB `1.5.0+669` en Play Console. Fin estimado: ~19/11/2026.
- **Seguridad, Cuotas, Galería e Integridad (A1a, B2, C1, C2) — `Completada ✅`:** Visto bueno de César en *Rinde Más Dev* (Build 672/676). Cuota D1 (50/día UID, 20k global, VET UTC-4, fail-closed). Worker DESPLEGADO (/health 200). B2: copia en galería por defecto y sin aviso en manuales. C1/C2: saneamiento de montos y SemanticValidator al 50%. B1 planificado en `docs/DOC_REGLAS_FIRESTORE_B1.md`. Despliegue automático de reglas cortado.
- **Seguridad de firma (P0) — `Pendiente de validación 🧪`:** `android_template/rindemas.jks` fuera de Git; firma inyectada desde Secrets. CI verificado con SHA-256 en build 671.
- **Reproducibilidad (P0) — `Completada ✅`:** Flutter fijado en `3.47.9`, `pubspec.lock` versionado con guarda anti-drift.
- **Artefacto para Play:** `app-release-aab` del run 42877000686 (build 677).
- **Artefacto para pruebas en teléfono:** `rindemas-dev-apk` del run 42877000686 (*Rinde Más Dev* build 677).
- **Sincronización Panel Web (Fase 5)** y **Selector de Mes en AppBar:** `Pendiente de validación 🧪` (CI verde, falta visto bueno visual de César).
- **RM-03 (Fase 0A / E0-02) — `Completada ✅`:** CI Build 665 en verde. Visto bueno explícito de César recibido.
- **RM-03 (Fase 0A / E0-03) — `Pendiente de validación 🧪`:** Lectores móviles, pantallas y panel web completados (H-1, H-2, A-16, D-06, D-07). Lentes monetarios independientes, denominaciones canónicas en `MoreScreen` y `CurrencyCalculatorScreen`, panel web Astro validado. Guía de pruebas en `docs/DOC_E0_03_LECTORES_MULTIMONEDA.md`.
- **RM-03 (Fase 0A / E0-04) — `Pendiente de validación 🧪`:** Sincronización atómica, CAS optimista (`marcarGastoSincronizadoCondicional`), protección de tombstones (`ConflictoTombstoneRemoto`, prohibido borrado local con `synced == 0`), idempotencia post-crash (`sonContenidoNegocioIdentico` con normalización canónica de categorías), allowlist en panel web (`A-09`) y diálogo de confirmación de monto (`A-15`). CI Build 676 en verde (673 tests).
- **Próximo Paso Inmediato:** Validación en teléfono físico de E0-03 y E0-04 (*Rinde Más Dev* build 676).

## Decisiones Técnicas y de Negocio Recientes
- **Rotación de la clave de subida: diferida** hasta que Google apruebe el acceso a Producción. No reinicia la revisión, pero el reset tarda 24-72 h y bloquearía una subida inmediata. El repositorio público conserva el `.jks` en el historial, por lo que la rotación sigue siendo necesaria.
- **No hay JDK local:** `keytool` no existe en la máquina de César. Cualquier generación/exportación de keystore debe hacerse vía GitHub Actions o instalando Temurin.
- **`versionCode = BASE_BUILD + github.run_number`:** nunca renombrar ni recrear `build_apk.yml` (reinicia `run_number` y el código retrocedería, causando rechazo en Play).
- AppBarMonthSelector: Nombre completo del mes sin año ('Noviembre'), conmutación automática a 3 letras ('Nov') ante `effectiveMaxWidth < 145`, flechas negras transparentes (19 dp) y borde amarillo de acento (`AppColors.primaryDark`) fuera del mes actual.
- Navegación mensual: Flechas directas integradas en la cápsula y diálogo de 12 meses accesible al pulsar el texto central.
- Formulario de gastos y teclado (UX): Barra inferior de totales y guardado anclada al borde físico (cubierta por teclado) para proteger el viewport vertical y evitar asfixia del formulario (regla oficial en DESIGN.md 4.7).
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.
- **Redes Sociales (Consenso Muse 09/11):** Bio = Canal de WhatsApp directo (`/channel/0029VbEPwHLDJ6H678QLlN1H`). Reels con colaboración manual obligatoria a `@lili9077p`. Voz calmada/asesor. Test A/B horario: Lunes 7:00 PM vs Miércoles 6:00 PM. Cierre: *"el enlace del canal está en el perfil"*.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido marcar Tareas Críticas como `Completada ✅` sin visto bueno explícito de César en *Rinde Más Dev*.
