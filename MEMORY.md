# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Finalizadas Fases 1 a 6 (Estabilidad IA, Comprobantes persistentes, Reportes Privacidad, Mejoras UI Tasas).
- **Últimos hitos:** 
  1. **Modernización y Paridad del Panel Web (Fases 1 y 2):** Implementación de `meta_ahorro` en Firestore y modal web, validaciones reactivas de categorías contra límite real, y cálculo determinista de salud financiera (`calculateSavingsHealth`) con chips de estado (`Protegida`, `En riesgo`, `Comprometida`), ritmo diario y barra de consumo relativo.
  2. **Documentación de Roadmap y Especificación Web:** Planificación registrada en `ROADMAP.md` (Fase 8.1) y detalle técnico en `DOC_MODERNIZACION_PANEL_WEB.md`.
  3. **Sistema de Diseño y Reglas Modulares (`DESIGN.md` y `AGENTS.md`):** Reglas visuales extraídas a `DESIGN.md`.
  4. **Autenticación Agnóstica de Correo y Alias (Addy.io / Dominios Propios):** Soporte en `SyncService` y `GastoProvider`.
  5. **Gate Estricto de CI:** Pruebas unitarias/widgets al 100% en verde y compilación automatizada de APK release.

## Decisiones Técnicas y de Negocio Recientes
- **Paridad Web en Presupuestos:** El panel web preserva y sincroniza `meta_ahorro` con Firestore sin sobreescribir la configuración del teléfono, validando límites antes de guardar.
- **Motor Determinista de Salud en Web:** Replicación en JavaScript de `SavingsHealthCalculator` para cálculo de ritmo diario y estatus de ahorro.
- **Fuente de Verdad de Estilos en `DESIGN.md`:** Paleta `AppColors` y reglas de contraste en `DESIGN.md`.
- **Mocks con `noSuchMethod` para Plugins:** En tests, dependencias externas se simulan con `Fake` y `noSuchMethod`.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Contraste estricto en UI (`DESIGN.md`): Texto sobre amarillo SIEMPRE negro (`Colors.black`); texto sobre blanco SIEMPRE negro o gris, NUNCA amarillo.
- No omitir `creadoEn` al construir instancias dummy de `GastoModel`.

## Próximo Paso Inmediato
- Notificar al usuario con la guía de pruebas de las Fases 1 y 2 del panel web y esperar su visto bueno antes de marcar como completado en `ROADMAP.md`.
