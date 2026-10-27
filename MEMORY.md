# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **UI-06 & Web (Fase 4 y 5):** `Pendiente de validación 🧪`. CI verde (Android build 569, commit `1be30ad`, y Web build 9, commit `e31866c`). Web validada en vivo vía HTTP 200 en `https://rindemas.cesarluis.com/panel/`.

## Decisiones Técnicas y de Negocio Recientes
- Rediseño de `PendingExpenseCard`: Fondo marfil sutil (`#FFFDF5`), borde ámbar suave (`#FEF08A`), icono leading de alto contraste (`Color(0xFF92400E)` sobre `#FEF9C3`), padding vertical reducido a 11dp (más compacto), eliminación de solapamiento de fecha/estado y botón interactivo `Por revisar →` cuando monto <= 0.
- Nomenclatura canónica de 4 lentes establecida: `USD BCV`, `VES Bolívares`, `USDT P2P` y `EUR BCV` (sin paréntesis decorativos). En vistas compactas: `USD`, `VES`, `USDT`, `EUR`. Removida mención «Binance» de UI de tasas y calculadora cambiaria a favor de `USDT P2P`.
- Web Fase 4: Autenticación por correo/contraseña (`signInWithEmailAndPassword`, `createUserWithEmailAndPassword`, `sendPasswordResetEmail`) integrada en `panel.astro` con mensajes traducidos.
- Web Fase 5: Edición de compras, desglose dinámico y reactividad de facturas al lente multimoneda corregida en `panel.astro`.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.

## Próximo Paso Inmediato
- Esperar validación visual de César en *Rinde Más Dev* (build 569) y en el panel web (`rindemas.cesarluis.com/panel/`).
