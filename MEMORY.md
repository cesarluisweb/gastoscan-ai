# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 6.2 y Fase 5 (Closed Testing activa con 12 evaluadores).
- **Tareas recientes:** `UI-01`, `UI-05`, `UX-06`, `UX-07`, `UX-11`, `AI-02`, `AI-03`, `AI-04`, `SEC-13` `Completada ✅`. `FIN-09` `Pendiente de validación 🧪`.
- **Documentación Técnica:** [ROADMAP.md](ROADMAP.md) y [DOC_FASE_6_2.md](DOC_FASE_6_2.md) actualizados.

## Decisiones Técnicas y de Negocio Recientes
- **Bug Fix OCR (Montos Enteros IA a Céntimos):** `_parseAmount` en `GeminiExtractionResult` tenía `isPrice = true` por defecto. En capturas de PayPal o Pago Móvil donde Gemini devolvía un entero (ej. `$25`), el parser lo trataba como dígitos de céntimos convirtiéndolo en `0.25`. Solución: `value is num` se retorna directamente en `amount_parser.dart` y `isPrice = false` por defecto en extracción IA.
- **FIN-09 (UX Ingreso de Monto en Calculadora):** Texto inicial cambiado a `'1'`. Al pulsar o enfocar los campos de divisa o Bs., se selecciona automáticamente todo el texto (`TextSelection(0, length)`) para sobreescribir al instante sin borrar. Añadido botón rápido de borrado `X` (`suffixIcon: IconButton(Icons.clear)`).
- **UX-11 (Feedback Vinculación/Sincronización):** Completada y aprobada por César.
- **AI-04 (Persistencia de Chat y Exclusión Fiscal IVA):** Completada y aprobada por César.
- **AI-02 (Detección de Pagos Digitales):** Funciona por defecto en el pipeline unificado de escaneo OCR; bug de montos enteros resuelto.
- **Google Play (Closed Testing):** Pista cerrada activa en Play Console con 12 evaluadores requeridos.

## Errores y Fricciones a Evitar
- **Regla Estricta DESIGN.md §2.2:** Prohibido texto amarillo sobre fondo blanco/claro. El amarillo (`AppColors.primaryDark` / `primary`) solo se permite en iconos, bordes activos o fondos cuyo texto sea estrictamente negro.
- `AppConstants.categorias`: El catálogo canónico son 8 categorías fijas.
- Íconos de categorías deben consultarse exclusivamente vía `AppConstants.getCategoryIcon(cat)`.
- `ScanQueueProvider` en tests de widgets: instanciar siempre con `autoProcess: false` y llamar `dispose()` en `tearDown` para evitar timeouts de `pumpAndSettle`.
- En `amount_parser.dart`: Nunca asumir que cadenas sin punto ni coma son céntimos cuando provienen de extracción IA o campos de formulario (`isPrice` debe ser `false`).

## Próximo Paso Inmediato
- Confirmar CI en verde tras push con corrección de OCR y UX de calculadora cambiaria.
- Prueba manual en dispositivo por César para validar selección rápida de monto en calculadora y escaneo de capturas PayPal/Pago Móvil.


