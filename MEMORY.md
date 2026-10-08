# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Finalizadas Fases 1 a 6 (Estabilidad IA, Comprobantes persistentes, Reportes Privacidad, Mejoras UI Tasas).
- **Últimos hitos:** 
  1. **Modernización y Paridad del Panel Web (Fases 1, 2 y 3):** Implementación de `meta_ahorro` y salud financiera en web; resolución de discrepancias en USD; integración de cotizaciones en vivo (USD BCV, EUR BCV, USDT Binance/Yadio); paridad matemática con SQLite (`DatabaseHelper.getMonthlyTotals`); selector de 4 divisas (USD, VES, EUR, USDT) y persistencia de tasa real en Firestore.
  2. **Documentación de Roadmap y Especificación Web:** Registrado en `ROADMAP.md` (Fase 8.1) y detalle técnico en `DOC_MODERNIZACION_PANEL_WEB.md`.
  3. **Sistema de Diseño y Reglas Modulares (`DESIGN.md` y `AGENTS.md`):** Reglas visuales extraídas a `DESIGN.md`.
  4. **Autenticación Agnóstica de Correo y Alias (Addy.io / Dominios Propios):** Soporte en `SyncService` y `GastoProvider`.
  5. **Actualización de Textos de la Landing:** Integración de multimoneda ampliada (Euro BCV, USDT), meta de ahorro, funcionamiento offline, sincronización segura en Firebase y ajuste de métodos de donación (PayPal, Binance Pay, Pago Móvil). Compilación exitosa en Astro.
  6. **Gate Estricto de CI:** Pruebas unitarias/widgets al 100% en verde y compilación automatizada de APK release.

## Decisiones Técnicas y de Negocio Recientes
- **Paridad Web en Presupuestos y Monedas:** El panel web preserva y sincroniza `meta_ahorro` y soporta 4 divisas sin alterar tasas locales. Compras en USD, EUR y USDT guardan su tasa real en Firestore para no descalabrar las conversiones en el móvil.
- **Motor Determinista de Salud en Web:** Replicación en JavaScript de `SavingsHealthCalculator` para cálculo de ritmo diario y estatus de ahorro.
- **Fuente de Verdad de Estilos en `DESIGN.md`:** Paleta `AppColors` y reglas de contraste en `DESIGN.md`.
- **Mocks con `noSuchMethod` para Plugins:** En tests, dependencias externas se simulan con `Fake` y `noSuchMethod`.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Contraste estricto en UI (`DESIGN.md`): Texto sobre amarillo SIEMPRE negro (`Colors.black`); texto sobre blanco SIEMPRE negro o gris, NUNCA amarillo.
- No omitir `creadoEn` al construir instancias dummy de `GastoModel`.

## Próximo Paso Inmediato
- Probar en producción/hosting tras CI y esperar visto bueno del usuario sobre las Fases 1, 2 y 3.
