# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Fase 5 (Closed Testing activa) y resolución de `FIN-12` (tasas BCV en vivo).
- **Acción Crítica Reciente:** Implementada solución integral `FIN-12` para eliminar de raíz el problema de congelamiento en 40 Bs / USD:
  1. Cascada cliente independiente por divisa (Gateway propio → DolarAPI → Yadio oficial → jsDelivr espejo BCV).
  2. Banderas de vigencia desacopladas por divisa (`usdEsReferencia`, `eurEsReferencia`, `usdtEsReferencia`).
  3. Purga automática de valores < 50 Bs en caché previa (`AppConstants.tasaMinimaPlausible = 50.0`).
  4. Desacoplamiento de red en `loadSettings` (tasas locales primero, Firestore en background con timeout de 8s).
  5. Feedback con SnackBar de alto contraste en botón manual y reintento reactivo por conectividad.
  6. Endpoint `/tasas` en Cloudflare Worker (`rindemas-gateway`) listo para desplegar.
- **Documentación Técnica:** [DOC_RESILIENCIA_TASAS_CAMBIO.md](DOC_RESILIENCIA_TASAS_CAMBIO.md) y [ROADMAP.md](ROADMAP.md).

## Decisiones Técnicas y de Negocio Recientes
- La restauración previa a Build 470 demostró que el congelamiento en 40 no era regresión de FIN-11 sino fragilidad estructural de punto único de fallo en `ve.dolarapi.com` combinada con reporte falso de vigencia al recibir solo USDT.
- Repositorio público durante desarrollo; visibilidad se restablece a privado al culminar la fase.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`), prohibido bucle activo turno a turno.

## Próximo Paso Inmediato
- Push a `main`, monitorear CI de compilación (Build 496), desplegar worker si aplica y validar en teléfono de César según guía de [DOC_RESILIENCIA_TASAS_CAMBIO.md](DOC_RESILIENCIA_TASAS_CAMBIO.md).
