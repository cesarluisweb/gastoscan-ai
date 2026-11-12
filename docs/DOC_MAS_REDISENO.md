# Documento Técnico: Rediseño Modular de la Pantalla «Más» (`MoreScreen`)

## Resumen Ejecutivo
Se implementó el rediseño completo de `MoreScreen` pasando de 11 tarjetas apiladas (~2.066 líneas en un solo archivo monolítico) a una arquitectura modular de ~1.5 alturas de pantalla ordenada por frecuencia de uso real.

## Cambios Principales

### 1. Componentes Modulares Nuevos
- `lib/ui/widgets/more/more_rates_card.dart`:
  - Cabecera con icono oficial `Icons.currency_exchange` en `AppColors.primaryDark`.
  - Insignia real de frescura de tasa (`✓ Actualizada hoy`, `Última registrada`, `Sin tasa disponible`, `Tasa manual`) con botón `Key('refresh_rates_btn')`.
  - 3 columnas compactas con `FittedBox(fit: BoxFit.scaleDown)`: Dólar BCV, Euro BCV, USDT P2P.
  - Fila con selector oficial `CurrencyLensDropdown` (`Key('more_currency_lens_dropdown')`).
  - Nota legal breve del BCV (`Key('more_rates_bcv_disclaimer')`) y enlace `Key('more_rates_bcv_source_link')`.
- `lib/ui/widgets/more/more_tools_grid.dart`:
  - Cuadrícula 2×2 con altura fija (104dp) e iconos Material Outlined.
  - **Lista de Compras** (`Key('more_menu_shopping_list')`): contador real dinámico desde SQLite (`$n pendientes` o `Prepara tus compras`).
  - **Calculadora** (`Key('more_menu_currency_calculator')`): subtítulo `Bs. ⇄ Divisas`.
  - **Comprobantes** (`Key('more_menu_view_receipts')`): conteo mensual (`$n fotos en $mes`).
  - **Asistente IA** (`Key('more_menu_chat_ai')`): fondo `AppColors.primaryDark` (`#FACC15`) con icono y textos en negro estricto (`AppColors.textPrimary`), subtítulo `Consulta tus finanzas`.

### 2. Tarjeta Maestra de Ajustes (2 Filas)
- **Preferencias y datos** (`Key('more_group_preferences')`):
  - Switch accesible de «Guardar copia en la galería del teléfono» con subtítulo completo sobre el álbum Rinde Más.
  - Exportación en dos botones limpios: `Excel (.csv)` y `Texto (.md)`.
  - Acceso a `Notificaciones y avisos` (`Key('more_menu_notifications')`).
- **Soporte y comunidad** (`Key('more_group_support')`):
  - WhatsApp oficial (`Key('more_menu_support_whatsapp')`).
  - Sitio web (`Key('more_menu_website')`).
  - Donaciones / Apoyar el proyecto ☕ (`Key('more_menu_donate')`).

### 3. Gestión de Cuenta y Zona de Peligro
- **Cuenta Vinculada:**
  - Avatar, nombre/correo, pastilla `✓ Sincronización activa` y botón `Key('btn_ajustes_cuenta')` (`⚙️`).
  - Al abrir los ajustes de cuenta: botón `Cerrar sesión` y tarjeta de `Zona de Peligro` (`Key('btn_eliminar_cuenta')`).
  - El diálogo destructivo exige escribir **"ELIMINAR"** en `Key('delete_account_confirm_input')` para activar el botón `Eliminar definitivamente`, conservando la casilla de borrar fotos locales y la reautenticación por contraseña si aplica.
- **Usuario Invitado / Anónimo:**
  - Aviso de privacidad local intacto.
  - Botones de acción directa `Vincular con Google` (`Key('btn_vincular_google')`) y `Vincular con correo` (`Key('btn_vincular_email')`).
  - Botón sutil `Borrar datos de este teléfono` (`Key('btn_borrar_datos_local')`).

### 4. Pie de Página Discreto
- Enlaces rápidos subrayados:
  - `Aviso BCV` (`Key('more_menu_legal_disclaimer')`) $\rightarrow$ abre diálogo oficial del BCV.
  - `Privacidad` (`Key('more_menu_privacy_policy')`) $\rightarrow$ abre `https://rindemas.cesarluis.com/privacidad`.
  - `Términos` (`Key('more_menu_terms')`) $\rightarrow$ abre `https://rindemas.cesarluis.com/terminos`.
- Versión de la app con botón `Google Play` (`Key('btn_ver_google_play')`).

---

## Guía de Verificación en Dispositivo Físico (*Rinde Más Dev*)

| Paso | Acción en Dispositivo | Evidencia archivo:línea | Resultado Esperado |
| :--- | :--- | :--- | :--- |
| **1. Cabecera y AppBar** | Abrir la pestaña «Más» desde la barra inferior | `lib/ui/screens/more_screen.dart#L370-L417` | Mantiene selector de mes, botón de búsqueda y botón de Asistente IA (fondo blanco, borde gris, sin pintar de amarillo). |
| **2. Cuenta vinculada** | Verificar la tarjeta superior de cuenta | `lib/ui/screens/more_screen.dart#L479-L560` | Se visualiza el avatar, correo, pastilla verde `✓ Sincronización activa` y el icono de engranaje `⚙️` a la derecha. |
| **3. Ajustes de cuenta** | Tocar el icono `⚙️` en la tarjeta de cuenta | `lib/ui/screens/more_screen.dart#L775-L855` | Se abre la hoja inferior con «Cerrar sesión» y la «Zona de Peligro» en fondo rojo suave. |
| **4. Confirmación ELIMINAR** | Tocar «Eliminar cuenta y datos» en la hoja de cuenta | `lib/ui/screens/more_screen.dart#L1180-L1215` | El botón «Eliminar definitivamente» está inactivo. Al tipear `ELIMINAR` (o `eliminar`) se habilita en rojo. *(Cancelar para no borrar la cuenta).* |
| **5. Tasas y Lente** | Observar la tarjeta de Tasas y tocar el selector de moneda | `lib/ui/widgets/more/more_rates_card.dart#L50-L180` | Muestra Dólar BCV, Euro BCV y USDT P2P. Despliega las 4 monedas mediante `CurrencyLensDropdown`. |
| **6. Bento 2x2** | Verificar los 4 bloques de herramientas | `lib/ui/widgets/more/more_tools_grid.dart#L25-L95` | Muestra contador dinámico en Lista de Compras, Comprobantes con fotos del mes, y Asistente IA con fondo amarillo y textos estrictamente negros. |
| **7. Preferencias y datos** | Tocar la fila «Preferencias y datos» | `lib/ui/screens/more_screen.dart#L665-L745` | Se abre la hoja con el switch de galería (persistente), botones de exportar Excel/Texto y fila de Notificaciones. |
| **8. Soporte y Enlaces legales** | Tocar «Soporte y comunidad» y revisar el pie | `lib/ui/screens/more_screen.dart#L747-L773` y `#L857-L895` | La hoja abre WhatsApp/Sitio/Donar. En el pie se pueden pulsar `Aviso BCV`, `Privacidad`, `Términos` y `Google Play`. |
