# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 3 de Auditoría Integral implementada (FIN-07, FIN-08, UX-03, UX-05, SEC-12, OCR-01). En proceso de validación por CI y pruebas.
- **Últimos hitos:** 
  1. **Auditoría Fase 3 Implementada:** Días históricos en SummaryCard (FIN-07), montos > 0 (FIN-08), búsqueda cross-month (UX-03), navegación unificada chat (UX-05), versionado worker en workers/ (SEC-12), deduplicación SHA-256 en cola (OCR-01).
  2. **Play Store en Revisión:** Versión 433 (Build 430, targetSdk=36) en revisión por Google Play Console.
  3. **Despliegue Web Verificado:** Landing y panel activos en producción (HTTP 200).

## Decisiones Técnicas y de Negocio Recientes
- **SHA-256 Nativo:** Implementación sin dependencias externas para deduplicación de imágenes.
- **Búsqueda Global:** `ExpenseHistoryScreen` consulta todos los meses si hay término de búsqueda activo.
- **Navegación Chat:** Exclusivamente `Navigator.push` para mantener el árbol de navegación determinista.

## Errores y Fricciones a Evitar
- `targetSdk` debe mantenerse en 36 o superior para Google Play.
- Toda conversión de divisas debe pasar por `CurrencyFormatter` y las tasas dinámicas de `settings`.

## Próximo Paso Inmediato
- Monitorear GitHub Actions CI tras git push hasta confirmar `conclusion: success`.
- Entregar guía de pruebas a César para validación en dispositivo.
