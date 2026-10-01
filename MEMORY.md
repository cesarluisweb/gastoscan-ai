# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main` (limpia, sincronizada con remoto).
- **Fase activa:** Fase 5 (Marketing / Lanzamiento) y Fase 6.1 (Feedback de comunidad).
- **Últimos hitos:** Bienvenida mensual en UI/Chat, políticas de Better Ads y aprendizajes en marketing documentados.

## Decisiones Técnicas y de Negocio Recientes
- **Monetización:** Anuncios intersticiales únicamente tras guardar factura (transición natural); nunca al abrir ni en captura de fotos.
- **Asistente IA:** Desambiguación obligatoria si no hay monto ("¿Gasto o lista de compras?").
- **Precisión contable:** Cálculos matemáticos en código Dart y centavos enteros, no en la IA.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.

## Próximo Paso Inmediato
- Definir la siguiente tarea operativa según ROADMAP.md.
