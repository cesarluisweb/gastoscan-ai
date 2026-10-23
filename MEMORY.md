# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y Fase 6.2 (Finanzas y UX).
- **CI Móvil Reciente:** Build 552 en verde (`CI 40001429888 | success | 7df0d49`). Artefactos `rindemas-dev-apk` y `app-release-aab` listos en GitHub Actions.
- **Acción Reciente (FIN-09 Equivalencias Multimoneda Inmutables & Refinamiento UX):**
  1. Base de datos SQLite v18: columnas inmutables `total_eur` y `tasa_eur`.
  2. `ReviewExpenseScreen` & `panel.astro`:
     - `USD` y `EUR`: `En divisa` reordenada en 1.ª posición (izquierda) y seleccionada por defecto en gastos nuevos.
     - `VES`: Divulgación progresiva. 3 columnas simultáneas visibles de inmediato (`USD BCV`, `EUR BCV`, `USDT P2P`), y chips/edición manual de tasa colapsados tras el botón `Ajustar tasas ▾` (con badge `Tasa personalizada activa` y botón `Icons.restart_alt`).
  3. Compras en `USDT`: cintillo limpio multimoneda sin pedir bolívares.
  4. Lentes financieros móviles y web unificados con paridad al céntimo.
  5. Documentación de tarea crítica: [docs/DOC_TASAS_EQUIVALENCIAS_MULTIMONEDA.md](docs/DOC_TASAS_EQUIVALENCIAS_MULTIMONEDA.md). Estado: `Pendiente de validación 🧪`.
- **Acción Previa (Lote 1 Argon):** Sanitización XSS en panel web, protección de clave BYOK en `FlutterSecureStorage`, cabecera `x-goog-api-key` y anti-CSV Injection.

## Decisiones Técnicas y de Negocio Recientes
- La tasa Euro nunca debe sobrescribir la tasa Dólar en memoria (`_tasaEurCtrl` y `_tasaCambioCtrl` son independientes).
- En pagos directos en divisa (`USDT`), no se exige tasa en bolívares en la UI, pero se guardan las tasas de la fecha para los lentes `Bs.` y `EUR`.
- Inmutabilidad estricta: los montos históricos en bolívares y divisas nunca se recalculan con tasas futuras.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Esperar validación física de César en *Rinde Más Dev* (Build 550) para marcar `FIN-09` como `Completada ✅`. Continuar con Lote 3 Argon (`docs/auditoria_integral_argon.md`).
