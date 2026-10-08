# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Finalizadas Fases 1 a 6 (Estabilidad IA, Comprobantes persistentes, Reportes Privacidad, Mejoras UI Tasas).
- **Últimos hitos:** 
  1. **Sistema de Diseño y Reglas Modulares (`DESIGN.md` y `AGENTS.md`):** Reglas visuales extraídas a `DESIGN.md` para reducir consumo de tokens. Reglas globales unificadas en el estándar `AGENTS.md`.
  2. **Corrección de Contraste Cromático:** Textos sobre fondo amarillo estandarizados en negro (`Colors.black` en `Badge.count` y `SnackBar`). Textos sobre fondo blanco estandarizados en negro (acciones como "Gestionar") y gris (categorías en desglose `it.categoria`), eliminando texto amarillo sobre blanco.
  3. **Autenticación Agnóstica de Correo y Alias (Addy.io / Dominios Propios):** Soporte en `SyncService` y `GastoProvider` para registrar o iniciar sesión con cualquier correo/contraseña sin forzar la cuenta de Google de Android.
  4. **Frases Predeterminadas en Asistente IA (`ChatScreen`):** Barra de chips de sugerencia rápida con envío directo, auto-scroll y enriquecimiento de contexto.
  5. **Pausa Real y Tolerancia en Dictado por Voz:** Ciclo no destructivo acumulativo en `VoiceExpenseSheet`, umbral de 10s de silencio, 60s total e indicadores de estado.
  6. **Gate Estricto de CI:** Pruebas unitarias/widgets al 100% en verde y compilación automatizada de APK release.

## Decisiones Técnicas y de Negocio Recientes
- **Fuente de Verdad de Estilos en `DESIGN.md`:** La paleta `AppColors`, reglas de contraste y snippets de maquetación residen en `DESIGN.md`. `AGENTS.md` mantiene solo guardrails y punteros compactos.
- **Pausa No Destructiva en Dictado:** `VoiceExpenseSheet` preserva texto acumulado entre sesiones (`previousText`), amplía silencio a 10s y tiempo total a 60s.
- **Modelos Sintéticos con `creadoEn`:** Borradores de `GastoModel` en colas deben incluir siempre `creadoEn` obligatorio.
- **Cero Duplicidad en Comprobantes:** Fotos registradas en álbum "Rinde Más" vía `gal` (MediaStore) sin clonar archivos.
- **Mocks con `noSuchMethod` para Plugins:** En tests, clases de dependencias externas se simulan extendiendo `Fake` y delegando en `noSuchMethod`.
- **Cache-Buster en APKs OTA:** URLs de descarga y verificación de APK llevan `?b=$BUILD_NUM` para evitar descargas cacheadas por Cloudflare.

## Errores y Fricciones a Evitar
- No tocar `android/` localmente (CI regenera con `flutter create`).
- En CI, `curl` para logs devuelve 403; los fallos de test se leen en `test_results.txt` tras `git pull --rebase`.
- Prohibido `>` en PowerShell; usar siempre tubería `... | Out-File -Encoding utf8`.
- Contraste estricto en UI (`DESIGN.md`): Texto sobre amarillo SIEMPRE negro (`Colors.black`); texto sobre blanco SIEMPRE negro o gris, NUNCA amarillo.
- No omitir `creadoEn` al construir instancias dummy de `GastoModel`.
- No reiniciar `SpeechToText.listen` sin preservar el búfer acumulado previo.

## Próximo Paso Inmediato
- Monitorear ejecución del pipeline en GitHub Actions hasta confirmar `success` tras el push de la reestructuración documental.
