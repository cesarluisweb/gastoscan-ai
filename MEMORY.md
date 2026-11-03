# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase A & Fase 5:** Integradas en `main`; Closed Testing activo en Google Play.
- **Sprint Teléfono (ReviewExpenseScreen & Selectores):** `Pendiente de validación 🧪`. CI verde (Android build 633, commit `00c8f1c`, 579 pruebas pasando).
  - Inicialización desde `settings.monedaPrincipal` sin colisiones asíncronas.
  - Re-selección de moneda activa y método de liquidación como no-op estricto.
  - Cambio de moneda sin conversión de importe escrito ni artículos.
  - Gastos indexados: preservación de bolívares ante cambio de fecha y bloqueo de `EUR + BS_USDT`.
  - Nomenclatura `VES Bs.` generalizada y descripciones breves en Más (`Dólar oficial`, `Bolívares`, `Dólar digital`, `Euro oficial`).
- **Artefacto para pruebas:** Descargar `rindemas-dev-apk` desde el run de CI 41661857244 (*Rinde Más Dev*).

## Decisiones Técnicas y de Negocio Recientes
- ReviewExpenseScreen: `_userTouchedCurrency` evita sobrescribir preferencia cuando el usuario interactúa manualmente.
- `_buildLiquidacionPill` y selector de divisas no mutan estado si la opción pulsada ya está activa.
- Coexistencia de revisión en teléfono: `com.cesarluis.rindemas.dev` (*Rinde Más Dev*), preservando app oficial.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Entorno local sin Flutter SDK; pruebas y builds se ejecutan exclusivamente en GitHub Actions CI.
- Prohibido hacer commit o push sin autorización expresa de César.
