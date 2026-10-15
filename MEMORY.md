# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 3 de Auditoría Integral (FIN-07, FIN-08, UX-03, UX-05, SEC-12, OCR-01) en `Pendiente de validación 🧪`.
- **Últimos hitos:** 
  1. **CI en Verde y Despliegue Confirmado:** Run `38676630395` exitoso (`conclusion: success`). Build y release APK generados.
  2. **Landing y Panel Activos:** Verificado HTTP 200 en `https://rindemas.cesarluis.com`.
  3. **Barra Inferior en Chat IA:** Preservada con auto-ocultamiento ante apertura de teclado para dar espacio vertical a los mensajes.
  4. **Preguntas IA Depuradas:** Presupuesto, meta de ahorro, categoría mayor, tasa oficial BCV (con inyección en contexto) y lista de compras.

## Decisiones Técnicas y de Negocio Recientes
- **Barra en Chat:** Integrado en `MainScreen` con `PopScope`. Barra y FAB se ocultan si `viewInsets.bottom > 0` (teclado abierto).
- **Preguntas IA:** Eliminadas preguntas redundantes con el Inicio. Tasa BCV (USD/EUR) inyectada en `contextData` para respuestas exactas.
- **SHA-256 Nativo:** Aritmética determinista de 32 bits (`Uint32List` y máscaras seguras) sin librerías externas.

## Errores y Fricciones a Evitar
- `SettingsProvider` expone `tasaCambioVesEur`, no `tasaCambioEurUsd`.
- Al reajustar navegación en `MainScreen`, verificar compatibilidad de tests en `navigation_test.dart` y `more_screen_test.dart`.

## Próximo Paso Inmediato
- César valida en dispositivo físico las mejoras con la guía en `DOC_AUDITORIA_FASE_3.md`.
