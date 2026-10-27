# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **UI-06 & Web (Fase 4 y 5):** `Pendiente de validación 🧪`. CI verde (Android build 567 y Web build 9, commit `e31866c`). Web validada en vivo vía HTTP 200 en `https://rindemas.cesarluis.com/panel/`.

## Decisiones Técnicas y de Negocio Recientes
- Nomenclatura canónica de 4 lentes establecida: `USD BCV`, `VES Bolívares`, `USDT P2P` y `EUR BCV` (sin paréntesis decorativos). En vistas compactas: `USD`, `VES`, `USDT`, `EUR`. Removida mención «Binance» de UI de tasas y calculadora cambiaria a favor de `USDT P2P`.
- Web Fase 4: Autenticación por correo/contraseña (`signInWithEmailAndPassword`, `createUserWithEmailAndPassword`, `sendPasswordResetEmail`) integrada en `panel.astro` con mensajes traducidos.
- Web Fase 5: Edición de compras y desglose dinámico validada en `panel.astro`.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.

## Próximo Paso Inmediato
- Esperar validación visual de César en *Rinde Más Dev* (build 567) y en el panel web (`rindemas.cesarluis.com/panel/`).
