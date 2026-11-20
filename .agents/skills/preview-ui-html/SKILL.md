---
name: preview-ui-html
description: >-
  Genera una vista previa HTML interactiva a escala móvil (360 dp y 390 dp) con los tokens reales
  de AppColors antes de implementar cambios visuales en Flutter y compilar en GitHub Actions CI.
  Usar ante rediseños de pantallas, hojas inferiores, tarjetas, modales o formularios.
---

# Vista Previa UI en HTML Pre-CI (Rinde Más)

Como el entorno local no tiene Flutter SDK, valida los cambios visuales en HTML interactivo antes
de editar Dart o lanzar un build en GitHub Actions.

## Cuándo activar
- Rediseños de pantallas, `BottomSheet`, diálogos, tarjetas o barras de navegación.
- Cualquier ajuste visual donde importe el espaciado, el contraste o el corte de texto en `360 dp`.
- Omitir en cambios puramente lógicos, correcciones de copy triviales o pruebas unitarias.

## Procedimiento paso a paso

1. **Leer fuentes visuales reales:**
   - Consulta `DESIGN.md` y `lib/core/constants/app_colors.dart` para usar los valores hexadecimales exactos.
   - Revisa el widget Dart actual (y componentes de referencia, p. ej. `more_tools_grid.dart`) antes de preguntar decisiones ya resueltas en el código.
2. **Resolver decisiones abiertas antes de dibujar:**
   - Si hay ambigüedades de diseño, haz preguntas cortas una a la vez con una opción recomendada clara.
3. **Construir la vista previa HTML (`generative_ui`):**
   - Lee la skill integrada `generative_ui` para cumplir el formato y las reglas de tamaño.
   - Guarda un `.html` autocontenido en el directorio de artefactos (`UserFacing: true`, `RequestFeedback: false`).
   - Incluye siempre:
     - **Selector de ancho `360 dp` / `390 dp`** para verificar que títulos y subtítulos no desborden ni se corten en pantallas estrechas.
     - **Tokens exactos de `AppColors`** (`#F9FAFB`, `#FFFFFF`, `#FEF08A`, `#FACC15`, `#111827`, `#6B7280`, `#9CA3AF`, `#E5E7EB`, etc.) sobre contexto real de la app.
     - **Interactividad básica** (abrir/cerrar modal, tocar opciones o estados relevantes) para evaluar ergonomía.
   - **Ubicación:**
     - Componente compacto (`<= 450 px`, p. ej. `BottomSheet` o tarjeta): incrustar en línea con `<agent-embed>`.
     - Pantalla completa (`> 450 px`): entregar como artefacto independiente en el panel lateral.
4. **Esperar aprobación de César:**
   - No edites archivos `.dart` ni hagas `git push` hasta que César apruebe la maqueta o indique los ajustes finales.
5. **Implementar 1:1 en Flutter y validar en CI:**
   - Traduce medidas, radios, colores e iconos con fidelidad exacta a Dart.
   - Actualiza los widget tests afectados y verifica con `scripts/wait_ci.ps1`.
