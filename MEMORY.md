# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main` (commit `1fdd815`; CI Android build 692 en verde, run 43428721902).
- **Acceso a Producción Google Play:** Segunda ventana de prueba cerrada en curso (Día 3/14 cumplido con 12 evaluadores activos). AAB `1.5.0+669` en Play Console. Fin estimado: ~19/11/2026.
- **Corrección Dictado por Voz — `Pendiente de validación 🧪`:** CI en verde (build 692, `1fdd815`). `VoiceExpenseSheet` y `ChatScreen` acumulan segmentos tras pausas sin borrar dictado previo; `GeminiService.resolveSpokenExpenseDate` evita fechas alucinadas y `GastoProvider.agregarGasto` alinea mes/año seleccionado.
- **Rediseño MoreScreen (UI-02) — `Pendiente de validación 🧪`:** CI en verde (build 691, `da92c24`). `MoreRatesCard`, `MoreToolsGrid` (4 tiles unificados en blanco) y `BcvLegalDisclaimerCard` (compartido con Calculadora). Ajustes en 3 filas (`Preferencias y datos` con `Moneda de reportes`, `Soporte` y `Sobre Rinde Más`) + pie pasivo de versión. Guía en `docs/DOC_MAS_REDISENO.md`. Requiere visto bueno de César en *Rinde Más Dev*.
- **Seguridad, Cuotas, Galería e Integridad (A1a, B2, C1, C2) — `Completada ✅`:** Visto bueno de César en *Rinde Más Dev* (Build 672/676). Cuota D1 (50/día UID, 20k global, VET UTC-4, fail-closed). Worker DESPLEGADO (/health 200). B2: copia en galería por defecto y sin aviso en manuales. C1/C2: saneamiento de montos y SemanticValidator al 50%. B1 planificado en `docs/DOC_REGLAS_FIRESTORE_B1.md`. Despliegue automático de reglas cortado.
- **Artefacto para pruebas en teléfono:** `rindemas-dev-apk` del run 43428721902 (*Rinde Más Dev* build 692).
- **Seguridad de firma (P0) — `Pendiente de validación 🧪`:** `android_template/rindemas.jks` fuera de Git; firma inyectada desde Secrets. CI verificado con SHA-256 en build 671.
- **Reproducibilidad (P0) — `Completada ✅`:** Flutter fijado en `3.47.9`, `pubspec.lock` versionado con guarda anti-drift.
- **Artefacto para Play:** `app-release-aab` del run 43058347857 (build 680).
- **Sincronización Panel Web (Fase 5)** y **Selector de Mes en AppBar:** `Pendiente de validación 🧪` (CI verde, falta visto bueno visual de César).
- **RM-03 (Fase 0A / E0-02, E0-03 y E0-04) — `Completada ✅`:** Visto bueno explícito de César otorgado en *Rinde Más Dev* (Build 678). Lentes monetarios independientes (`E0-03`), sincronización atómica con CAS, defensa de tombstones, allowlist web `A-09` y confirmación de cambio de monto `A-15` (`E0-04`) cerrados.
- **Próximo Paso Inmediato:** Validar en teléfono físico (`rindemas-dev-apk` build 692) la corrección de dictado por voz (`1fdd815`), el rediseño de `MoreScreen` (`UI-02`) y los ajustes de UX/transiciones; luego ejecutar `E0-05b`.
- **Microcopy en formularios (gastaste + opcional):** Implementado y alineado en Flutter y Panel Web Astro.
- **Ajustes de UX y Transiciones (Gasto, Lista, Herramientas, Chat):**
  - Registrar gasto: Retroceso sin confirmación si no se anotó ningún dato (comercio, monto, ítems o foto).
  - Lista de compras: Mayúscula automática al iniciar escritura (`TextCapitalization.sentences`) y SnackBar flotante de 2 s con contraste estricto que se limpia al salir.
  - Transiciones sutiles: `AnimatedSwitcher` (220 ms, curva cúbica y deslizamiento vertical suave) en apertura y cierre de Lista de compras, Calculadora, Comprobantes y Asistente IA.
- **Nuevas ideas en ROADMAP:** `UX-18` (gráfica mensual en Análisis) y `AI-07` (sugerencias verticales y botón WhatsApp en chat).

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
- **Revisor Adversarial Pre-CI:** Skill creada en `.agents/skills/revisor-adversarial/SKILL.md` e indexada en `AGENTS.md` para auditar `git diff` mediante subagente antes de cada `git push` de código.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido marcar Tareas Críticas como `Completada ✅` sin visto bueno explícito de César en *Rinde Más Dev*.
