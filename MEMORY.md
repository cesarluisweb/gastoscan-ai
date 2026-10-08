# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Finalizadas Fases 1 a 6 (Estabilidad IA, Comprobantes persistentes, Reportes Privacidad, Mejoras UI Tasas).
- **Últimos hitos:** 
  1. **Cuenta de Desarrollador Google Play Console Creada y Pagada ($25 USD):** Pago exitoso procesado mediante la ruta `Zinli` → `OKX P2P` → `OKX Pay` → `OKX Card` → `Google Payments`. Cuenta "Rinde Más" lista para configuración.
  2. **Actualización de Playbook y Aprendizaje (/learn):** Documentación técnica y skill `growth-first-100-users` actualizados con la ruta de pago (evitando error `OR_CCR_61`), el requisito de 12+ testers por 14 días y la bitácora obligatoria para la solicitud de producción.
  3. **Modernización y Paridad del Panel Web:** Integración de `meta_ahorro`, salud financiera, 4 divisas (USD, VES, EUR, USDT) y despliegue validado en Firebase Hosting (`rindemas.cesarluis.com`).
  4. **Gate Estricto de CI:** Pruebas unitarias/widgets al 100% en verde y compilación automatizada de APK release.

## Decisiones Técnicas y de Negocio Recientes
- **Estrategia de Lanzamiento Google Play:** Reclutamiento de 15 a 18 testers (margen de seguridad sobre los 12 mínimos) organizados por Google Groups (`rindemas-testers@googlegroups.com`), llevando registro de bugs y versiones para el formulario de producción.
- **Ruta Verificada de Pago en Venezuela:** Uso de OKX Card (Mastercard virtual) para salvar el bloqueo de tarjetas prepago directas (`OR_CCR_61`).

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Contraste estricto en UI (`DESIGN.md`): Texto sobre amarillo SIEMPRE negro; texto sobre blanco SIEMPRE negro o gris, NUNCA amarillo.

## Próximo Paso Inmediato
- Ajustar pipeline en CI para compilar el paquete `.aab` firmado junto al `.apk`, y proceder a la configuración inicial de la app en Play Console.
