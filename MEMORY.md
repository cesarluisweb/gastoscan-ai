# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 3 de Auditoría Integral (FIN-07, FIN-08, UX-03, UX-05, SEC-12, OCR-01) en `Pendiente de validación 🧪`.
- **Últimos hitos:** 
  1. **CI en Verde y Despliegue Confirmado:** Run `38667931891` exitoso (`conclusion: success`). Build y release APK generados.
  2. **Landing y Panel Activos:** Verificado HTTP 200 en `https://rindemas.cesarluis.com`.
  3. **Auditoría Fase 3:** Días históricos en SummaryCard (FIN-07), montos > 0 (FIN-08), búsqueda cross-month (UX-03), navegación unificada chat (UX-05), versionado worker en workers/ (SEC-12), deduplicación SHA-256 en cola (OCR-01).

## Decisiones Técnicas y de Negocio Recientes
- **SHA-256 Nativo:** Aritmética determinista de 32 bits (`Uint32List` y máscaras seguras) sin librerías externas.
- **Búsqueda Global:** `ExpenseHistoryScreen` consulta todo el historial cuando hay texto de búsqueda activo.
- **Navegación Chat:** Exclusivamente `Navigator.push` para mantener el árbol de navegación determinista.

## Errores y Fricciones a Evitar
- `flutter analyze --fatal-warnings` no tolera campos declarados sin uso ni imports faltantes.
- Los mocks de pruebas de cola de escaneo deben poder insertarse en SQLite incluso si no existe archivo físico en disco.

## Próximo Paso Inmediato
- César valida en dispositivo físico las 6 mejoras de Fase 3 con la guía en `DOC_AUDITORIA_FASE_3.md`.
