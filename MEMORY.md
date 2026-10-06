# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Lanzamiento / Preparación Google Play) y Fase 6.1.
- **Últimos hitos:** 
  1. **Tasas por Fecha y Días Hábiles:** `ExchangeRateService.getRateForDate` busca automáticamente la tasa del último día hábil anterior si la factura corresponde a fin de semana o feriado sin cotización oficial BCV.
  2. **Integración Web + Donaciones:** "Visitar sitio web" y "Apoyar el proyecto ☕" en Más; sección `#donar` en landing page.
  3. **Robustez de Cola de Escaneo (Bloques 1 y 1b):** Protección de fotos compartidas, hoja inferior modal en banner para descarte individual de pendientes/error, tests con archivos reales en disco (Directory.systemTemp), y 0 advertencias en analizador.
  4. **Gate Estricto de CI:** `flutter analyze --fatal-warnings --no-fatal-infos` activo en GitHub Actions y pasando en verde al 100%.
  5. **Base de Datos y Asincronía (Bloque 2 - Puntos 8, 9 y 10):** Eliminación de consultas N+1 con hidratación en lotes, índices en SQLite v15 (`items_gasto.gasto_id`, `scan_queue.status`, `gastos.synced`), borrado lógico directo O(1), adopción de presupuestos en memoria sin escrituras fantasmas, mutadores asíncronos con `Future<bool>` y control de errores amigables.

## Decisiones Técnicas y de Negocio Recientes
- **Presupuestos sin Escrituras Fantasmas:** En meses vacíos, `GastoProvider` adopta en memoria el presupuesto del mes previo sin escribir en SQLite ni alterar timestamps de sincronización.
- **Rutas Calientes O(1) e Índices:** `softDeleteGasto` no recarga toda la BD; consultas de gastos e ítems usan hidratación en lotes con `WHERE gasto_id IN (...)` e índices dedicados (DB v15).
- **Mutadores con Estado y Feedback Real:** `guardarTodoElPresupuesto`, `setPresupuestoGeneral`, etc., retornan `Future<bool>`, limpian `_errorMessage` al iniciar y mapean excepciones a mensajes amigables para el usuario.
- **Protección contra Compras de $0.00:** Dictado por voz lanza excepción explícita si no se detecta monto, impidiendo registros fantasmas.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- En cPanel multidominio, el Document Root es `/home/user/dominio.com/`, no siempre `public_html/`.
- Mantener `retention-days: 1` en artefactos de CI para no saturar el límite de 500 MB en GitHub Free.

## Próximo Paso Inmediato
- Iniciar Bloque 3: Monedas, Categorías y Tasas (Puntos 1, 2, 3 y 7 de auditoría).
