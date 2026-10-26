# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Lote 3 (Sincronización Cloud/Offline y SQLite):** CI en verde (Build 561). Estado: `Pendiente de validación 🧪` en dispositivo físico (*Rinde Más Dev*).
- **Lote 4 (Auditoría Argon — UI/UX, Rendimiento y Resiliencia en Bs):** CI en verde confirmado (Build 565, commit `8c816d5`). Estado: `Pendiente de validación 🧪` en dispositivo físico (*Rinde Más Dev*).
- **Fase 5 (Google Play):** Closed Testing activo con evaluadores (período de 14 días).
- **Marketing:** Video #1 publicado en Instagram Reels y TikTok (`@rindemas.app`). Canal de WhatsApp con 15 suscriptores orgánicos.

## Decisiones Técnicas y de Negocio Recientes
- Lote 4 cerrado en CI: virtualización `ListView.builder` y eliminación de doble `jsonDecode` en historial, blindaje contra desbordes `RenderFlex` con `FittedBox` y `ConstrainedBox` en pantallas de 360dp con cifras en Bs, escáner ML Kit integrado en botón `+`, evaluación OCR unificada en `LocalOcrService.evaluateRawText` y eliminación del directorio redundante `cloudflare_worker/`.
- Aprendizajes graduados a `AGENTS.md` y `.agents/rules/flutter-desarrollo.md` vía `/learn`: lectura obligatoria UTF-8 en PowerShell 5.1 y reglas de resiliencia `RenderFlex` en 360dp.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true` para acceso a la API de GitHub.

## Próximo Paso Inmediato
- Realizar pruebas manuales de Lote 3 y Lote 4 en dispositivo físico (*Rinde Más Dev*) antes de promocionar cambios a Google Play.
