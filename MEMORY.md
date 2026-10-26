# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa, Marketing inicial) y Fase 6.2 (Finanzas y UX).
- **Hito de Marketing:** Video #1 publicado en Instagram Reels y TikTok (`@rindemas.app`). Canal de WhatsApp alcanza 15 suscriptores orgánicos. Preparando Video #2 (gancho físico real).
- **CI Móvil Reciente:** Build 555 en verde (`CI 40355952613 | success | 7fbbe3d`). Artefactos `rindemas-dev-apk` y `app-release-aab` listos en GitHub Actions.
- **Acción Reciente (Anclaje de Bottom Sheets & Diálogo Auth Flotante):**
  1. Patrón canónico *shrink-wrapped* (`Material` + `SafeArea(top: false)` sin `Center` vertical) en `VoiceExpenseSheet`, `BudgetBottomSheet`, selector de comprobante (`ReviewExpenseScreen`) y menú (+) (`MainScreen`).
  2. `BudgetBottomSheet`: remoción de padding excesivo inferior con `Flexible(fit: FlexFit.loose)` y `ConstrainedBox(maxHeight: 0.88h)`.
  3. `AuthModalSheet` migrada a `AuthEmailDialog` (`Dialog` centrado sobre scrim, `PopScope` durante carga, `dispose()` de controladores y errores amigables).
  4. Tests de geometría y ciclo de vida en verde (`sheet_geometry_test.dart` y `auth_dialog_test.dart`).
  5. Documento técnico de tarea crítica: [docs/DOC_AUTENTICACION_MODAL.md](docs/DOC_AUTENTICACION_MODAL.md). Estado: `Pendiente de validación 🧪`.
- **Acción Previa (FIN-09 Equivalencias Multimoneda Inmutables):** SQLite v18 (`total_eur`, `tasa_eur`), divulgación progresiva en VES y paridad al céntimo.

## Decisiones Técnicas y de Negocio Recientes
- En `isScrollControlled: true`, la hoja modal NO debe usar `Center` ni `Align(alignment: Alignment.bottomCenter)` como raíz, ya que fuerzan altura completa y destruyen el anclaje natural de Flutter.
- El diálogo de autenticación usa `Dialog` nativo con `SingleChildScrollView` y límites responsivos (`maxWidth: 480`).
- Textos y spinners dentro de botones en diálogos estrechos deben usar `Flexible(overflow: TextOverflow.ellipsis)` para evitar desbordes horizontales de `RenderFlex`.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Iniciar UI-06: Unificación del orden canónico de monedas (USD -> VES -> USDT -> EUR) en nalysis_screen.dart, more_screen.dart y modal de presupuestos en panel.astro.
