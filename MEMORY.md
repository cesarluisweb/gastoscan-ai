# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y validación de motor multimoneda (FIN-11).
- **Acción Reciente:** Rediseño de tarjeta 'Total gastado' (`SummaryCard`) con selector desplegable flotante estilo Binance, jerarquía limpia Gastado/Disponible con barra al 100%, pie seguro con ritmo corto e ícono de meta coloreado, y unificación del orden canónico de monedas (`USD`, `VES`, `USDT`, `EUR`) en móvil y panel web.
- **Preservación:** Blindaje de R8 en `build_apk.yml` intacto (`-dontobfuscate`, `-dontoptimize`, `-keepattributes`), scripts operativos y reglas intactos.

## Decisiones Técnicas y de Negocio Recientes
- La causa de las tasas en 40 Bs era ofuscación de `Continuation` por R8. Con `-dontobfuscate`, `-dontoptimize`, `-keepattributes` y `proguardFiles("proguard-rules.pro")`, la firma JNI queda 100% protegida.
- El monto principal en `SummaryCard` está protegido con `FittedBox` dentro de `Flexible` sin envolver el botón selector de moneda para evitar que se encoja o desborde en Bolívares. En lente VES no se duplica 'Bs.' junto al selector '[ Bs. ▾ ]'.
- Orden canónico oficial de monedas unificado: USD, VES, USDT, EUR.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Monitoreo de CI en GitHub Actions y verificación en producción web y dispositivo físico.



