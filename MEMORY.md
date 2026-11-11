# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (commit `b50ebbc`; CI Android build 678 en verde, run 42918807157; orientación vertical fijada con `DeviceOrientation.portraitUp`).
- **Acceso a Producción Google Play:** Segunda ventana de prueba cerrada en curso (Día 3/14 cumplido con 12 evaluadores activos). AAB `1.5.0+669` en Play Console. Fin estimado: ~19/11/2026.
- **Seguridad, Cuotas, Galería e Integridad (A1a, B2, C1, C2) — `Completada ✅`:** Visto bueno de César en *Rinde Más Dev* (Build 672/676). Cuota D1 (50/día UID, 20k global, VET UTC-4, fail-closed). Worker DESPLEGADO (/health 200). B2: copia en galería por defecto y sin aviso en manuales. C1/C2: saneamiento de montos y SemanticValidator al 50%. B1 planificado en `docs/DOC_REGLAS_FIRESTORE_B1.md`. Despliegue automático de reglas cortado.
- **Seguridad de firma (P0) — `Pendiente de validación 🧪`:** `android_template/rindemas.jks` fuera de Git; firma inyectada desde Secrets. CI verificado con SHA-256 en build 671.
- **Reproducibilidad (P0) — `Completada ✅`:** Flutter fijado en `3.47.9`, `pubspec.lock` versionado con guarda anti-drift.
- **Artefacto para Play:** `app-release-aab` del run 42918807157 (build 678).
- **Artefacto para pruebas en teléfono:** `rindemas-dev-apk` del run 42918807157 (*Rinde Más Dev* build 678).
- **Sincronización Panel Web (Fase 5)** y **Selector de Mes en AppBar:** `Pendiente de validación 🧪` (CI verde, falta visto bueno visual de César).
- **RM-03 (Fase 0A / E0-02, E0-03 y E0-04) — `Completada ✅`:** Visto bueno explícito de César otorgado en *Rinde Más Dev* (Build 678). Lentes monetarios independientes (`E0-03`), sincronización atómica con CAS, defensa de tombstones, allowlist web `A-09` y confirmación de cambio de monto `A-15` (`E0-04`) cerrados.
- **Próximo Paso Inmediato:** Validar en teléfono físico el fix de teclado/caja multilínea en `ChatScreen` y el botón de guardado al final del scroll en `ReviewExpenseScreen`; elegir diseño en `MoreScreen` (`b171c76f`) y ejecutar `E0-05b`.

## Decisiones Técnicas y de Negocio Recientes
- **Rotación de la clave de subida: diferida** hasta que Google apruebe el acceso a Producción. No reinicia la revisión, pero el reset tarda 24-72 h y bloquearía una subida inmediata. El repositorio público conserva el `.jks` en el historial, por lo que la rotación sigue siendo necesaria.
- **No hay JDK local:** `keytool` no existe en la máquina de César. Cualquier generación/exportación de keystore debe hacerse vía GitHub Actions o instalando Temurin.
- **`versionCode = BASE_BUILD + github.run_number`:** nunca renombrar ni recrear `build_apk.yml` (reinicia `run_number` y el código retrocedería, causando rechazo en Play).
- AppBarMonthSelector: Nombre completo del mes sin año ('Noviembre'), conmutación automática a 3 letras ('Nov') ante `effectiveMaxWidth < 145`, flechas negras transparentes (19 dp) y borde amarillo de acento (`AppColors.primaryDark`) fuera del mes actual.
- Navegación mensual: Flechas directas integradas en la cápsula y diálogo de 12 meses accesible al pulsar el texto central.
- Formulario de gastos y teclado (UX): Barra inferior de totales y guardado anclada al borde físico (cubierta por teclado) para proteger el viewport vertical y evitar asfixia del formulario (regla oficial en DESIGN.md 4.7).
- Toda aceptación exige CI en verde; la inspección estática no sustituye pruebas.
- **Redes Sociales (Consenso Muse 09/11):** Bio = Canal de WhatsApp directo (`/channel/0029VbEPwHLDJ6H678QLlN1H`). Reels con colaboración manual obligatoria a `@lili9077p`. Voz calmada/asesor. Test A/B horario: Lunes 7:00 PM vs Miércoles 6:00 PM. Cierre: *"el enlace del canal está en el perfil"*.
- **Prueba Piloto ASD-STE100:** Regla de estilo técnico operativo agregada a `AGENTS.md` a prueba; retirar si genera rigidez o fricción innecesaria.
- **Asistente IA (Chat UX):** Ocultamiento de sugerencias rápidas con teclado abierto y auto-scroll suave (~250 ms) al último mensaje condicionado a proximidad del final, preservando scroll si se lee historial antiguo.
- **Sistema de Diseño Interactivo:** Creado `docs/design-system.html` (autocontenido, con `localStorage`, validador WCAG/`DESIGN.md` en vivo y botón de exportación `Antes → Después` para aplicar ajustes).

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido marcar Tareas Críticas como `Completada ✅` sin visto bueno explícito de César en *Rinde Más Dev*.
