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
    6. **Tasas, Parser y Distribución (Bloques 3 y D - Puntos 1, 2 y 7):** `ExchangeRatesData.esReferencia` con timestamp solo ante dato en vivo, badge "Tasa de referencia" en Más, parser VE centralizado `tryParseAmount`, herencia de moneda en presupuestos y distribución fail-closed en CI.
    7. **Resiliencia y Observabilidad en Gemini Gateway:** Depuración de modelos retirados (1.5 y 2.0 que causaban 404 enmascarado como 429), logging estructurado en Worker para `wrangler tail`, compresión de imágenes optimizada a 1200x1600 q82 (de 2MB a ~300KB), y backoff con jitter + respeto de `Retry-After` en Worker y cola.

## Decisiones Técnicas y de Negocio Recientes
- **Transparencia en Errores de Gemini:** El gateway ya no agrupa 404, 503 y 429 en un solo mensaje genérico. Cada estado reporta su causa real sin enmascarar modelos muertos como límites de cuota.
- **Compresión Eficiente para Visión:** 1200x1600 con calidad 82 preserva al 100% la nitidez OCR y reduce el payload un 80%, evitando timeouts y exceso de TPM.
- **Presupuestos sin Escrituras Fantasmas:** En meses vacíos, `GastoProvider` adopta en memoria el presupuesto del mes previo sin escribir en SQLite ni alterar timestamps de sincronización.
- **Rutas Calientes O(1) e Índices:** `softDeleteGasto` no recarga toda la BD; consultas de gastos e ítems usan hidratación en lotes con `WHERE gasto_id IN (...)` e índices dedicados (DB v15).
- **Mutadores con Estado y Feedback Real:** `guardarTodoElPresupuesto`, `setPresupuestoGeneral`, etc., retornan `Future<bool>`, limpian `_errorMessage` al iniciar y mapean excepciones a mensajes amigables para el usuario.
- **Protección contra Compras de $0.00:** Dictado por voz lanza excepción explícita si no se detecta monto, impidiendo registros fantasmas.
- **Tasas sin invenciones (Punto 7):** `getAllTodayRates({client})` inyectable para tests; `esReferencia=true` sin tocar timestamp cuando no hay dato en vivo; `SettingsProvider.tasasSonReferencia` gobierna el badge; política: nunca inventar ratios, aproximar con tasa USD o neutro.
- **Parser VE centralizado (Punto 1):** `tryParseAmount(raw, {isPrice})` en `core/utils/amount_parser.dart`; formularios usan `isPrice:false`; `_guardar` rechaza texto no vacío inválido con SnackBar en vez de guardar 0.
- **Herencia de moneda (Punto 2):** las categorías usan `monedaPresupuesto` salvo override explícito; `copiarPresupuestosMesAnteriorSiVacio` eliminado (código muerto, sin llamadores).
- **Distribución fail-closed:** paso FTP sin `continue-on-error` + verificación HEAD post-subida; paso de artefactos eliminado.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Paso de artefactos de CI eliminado: era el único consumidor de la cuota (500 MB) y tenía `retention-days: 1`. Liberar cuota vieja en `Settings → Actions → Storage`.
- En cPanel multidominio, el Document Root es `/home/user/dominio.com/`, no siempre `public_html/`.

## Próximo Paso Inmediato
- Desplegar Worker (`npx wrangler deploy` en cloudflare_worker) y verificar CI de GitHub Actions.
