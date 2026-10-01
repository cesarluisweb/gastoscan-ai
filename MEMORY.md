# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a GEMINI.md.

## Estado Actual Inmediato
- **Rama:** `main` (limpia, sincronizada con remoto).
- **Fase activa:** Fase 7 (Arquitectura de Producción) y Fase 5 (Lanzamiento).
- **Últimos hitos:** Sistema Híbrido de Document Scanner, OCR Local Bundled y Búsqueda FTS5 (SQLite v14, persistencia temprana en scan_queue, fallback adaptativo semántico y Gemini Texto).

## Decisiones Técnicas y de Negocio Recientes
- **Percepción Local vs Interpretación Nube:** Document Scanner y ML Kit Text Recognition corren on-device. Gemini Texto procesa JSON a partir del OCR. Fallback automático a Gemini Visión ante baja calidad o discrepancia >15%.
- **Persistencia Temprana:** Captura -> Recorte -> OCR -> SQLite (`scan_queue`) -> Red. Si se corta el internet, el texto ya está guardado.
- **Invariante FTS5:** Búsqueda profunda en facturas es una optimización no crítica; si el motor del teléfono carece de FTS5, se degrada a `LIKE`.
- **Meta de Ahorro:** Presupuesto General - Meta Ahorro = Límite para Gastar. Categorías validan contra el límite. Cero fricción contable.
- **Monetización:** Anuncios intersticiales únicamente tras guardar factura (transición natural); nunca al abrir ni en captura de fotos.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.

## Próximo Paso Inmediato
- Monitorear pipeline CI de GitHub Actions tras push.

