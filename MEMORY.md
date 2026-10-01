# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main` (limpia, sincronizada con remoto).
- **Fase activa:** Fase 5 (Marketing / Lanzamiento) y Fase 6.1 (Feedback de comunidad).
- **Últimos hitos:** Implementada Meta Mensual de Ahorro / Inversión (SQLite v13, SavingsHealthCalculator determinista con período de gracia, límite para gastar, estados semafóricos y alertas IA).

## Decisiones Técnicas y de Negocio Recientes
- **Meta de Ahorro:** Presupuesto General - Meta Ahorro = Límite para Gastar. Categorías validan contra el límite. Cero fricción contable (sin etiquetar gastos impulsivos).
- **Dominio Puro:** `SavingsHealthCalculator` es Dart puro desacoplado de UI e IA. Días 1-3 período de gracia para no alertar compras iniciales.
- **Monetización:** Anuncios intersticiales únicamente tras guardar factura (transición natural); nunca al abrir ni en captura de fotos.
- **Asistente IA:** Desambiguación obligatoria si no hay monto ("¿Gasto o lista de compras?").
- **Precisión contable:** Cálculos matemáticos en código Dart y centavos enteros, no en la IA.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.

## Próximo Paso Inmediato
- Avanzar con la fase 5: Preparativos de Google Play Console (20 testers) o Tasa y Moneda Paralela (Fase 6.1).

