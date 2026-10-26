# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Auditoría Argon (Lotes 1, 2, 3 y 4):** Todos cerrados y aprobados.
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **UI-06 & Web (Fase 4 y 5):** Nomenclatura unificada limpia `USD BCV`, `VES Bolívares`, `USDT P2P`, `EUR BCV` (y versión corta `USD`, `VES`, `USDT`, `EUR`) aplicada en móvil y web. Login con correo/contraseña implementado en `panel.astro`.

## Decisiones Técnicas y de Negocio Recientes
- Nomenclatura canónica de 4 lentes establecida: `USD BCV`, `VES Bolívares`, `USDT P2P` y `EUR BCV` (sin paréntesis decorativos). En vistas compactas: `USD`, `VES`, `USDT`, `EUR`.
- Web Fase 4: Autenticación por correo/contraseña (`signInWithEmailAndPassword`, `createUserWithEmailAndPassword`, `sendPasswordResetEmail`) integrada en `panel.astro` con mensajes traducidos.
- Web Fase 5: Edición de compras y desglose dinámico validada en `panel.astro`. Compilación estática Astro exitosa.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.

## Próximo Paso Inmediato
- Commitear cambios a `main`, monitorear CI y validar despliegue en `rindemas.cesarluis.com/panel/`.
