# Documento Técnico: Rediseño Modular de la Pantalla «Más» (`MoreScreen`)

## Resumen Ejecutivo
Se implementó el rediseño y refinamiento final de `MoreScreen`, reorganizando los 11 bloques monolíticos anteriores en una vista modular ordenada por frecuencia de uso y compartiendo el aviso legal del BCV mediante un widget reutilizable (`BcvLegalDisclaimerCard`).

## Cambios Principales

### 1. Componentes Modulares Nuevos y Compartidos
- `lib/ui/widgets/bcv_legal_disclaimer_card.dart`:
  - Tarjeta compartida de descargo e independencia respecto al BCV y enlace oficial.
  - Utilizada tanto al pie de `MoreScreen` (`Key('more_rates_bcv_disclaimer')`) como en `CurrencyCalculatorScreen` (`Key('calc_bcv_disclaimer_card')`).
- `lib/ui/widgets/more/more_rates_card.dart`:
  - Cabecera con icono oficial `Icons.currency_exchange` en `AppColors.primaryDark` (`#L58`).
  - Insignia real de frescura de tasa (`✓ Actualizada hoy`, `Última registrada`, `Sin tasa disponible`, `Tasa manual`) y botón `Key('refresh_rates_btn')` (`#L101`).
  - 3 columnas compactas con `FittedBox(fit: BoxFit.scaleDown)`: Dólar BCV (`#L126`), Euro BCV (`#L136`) y USDT P2P (`#L146`).
  - Sin selector de moneda ni texto legal interno para mantener la tarjeta enfocada solo en valores de mercado.
- `lib/ui/widgets/more/more_tools_grid.dart`:
  - Cuadrícula 2×2 dentro de `IntrinsicHeight` (`#L49`, `#L76`) con altura mínima de 104 dp para resistir escalado tipográfico `1.3x`.
  - **Lista de Compras** (`Key('more_menu_shopping_list')`, `#L55`): contador dinámico desde SQLite.
  - **Calculadora** (`Key('more_menu_currency_calculator')`, `#L65`): subtítulo `Bs. ⇄ Divisas`.
  - **Comprobantes** (`Key('more_menu_view_receipts')`, `#L82`): conteo mensual (`$n fotos en $mes`).
  - **Asistente IA** (`Key('more_menu_chat_ai')`, `#L92`): tarjeta unificada en blanco (`AppColors.card`) con insignia amarilla clara (`AppColors.primaryLight`, `#L134`) e icono en `AppColors.primaryDark` (`#L137`).

### 2. Tarjeta Maestra de Ajustes (3 Filas) y Hojas Inferiores
Todas las hojas usan el patrón canónico (`Padding(viewInsets.bottom)` $\rightarrow$ `Material` $\rightarrow$ `SafeArea(top: false)` $\rightarrow$ `SingleChildScrollView`):
- **Preferencias y datos** (`Key('more_group_preferences')`, `more_screen.dart#L714`):
  - **Moneda de reportes** mediante `CurrencyLensDropdown` (`Key('more_currency_lens_dropdown')`, `#L833`), envuelto en `AnimatedBuilder(animation: settings, ...)` para actualizar el valor visible al instante.
  - Switch accesible «Guardar copia en la galería del teléfono» (`#L842`).
  - Botones de exportación `Excel (.csv)` y `Texto (.md)` (`#L868-L902`).
  - Acceso a `Notificaciones y avisos` (`Key('more_menu_notifications')`, `#L907`).
- **Soporte y comunidad** (`Key('more_group_support')`, `more_screen.dart#L729`):
  - Escribir a soporte por WhatsApp (`Key('more_menu_support_whatsapp')`, `#L968`).
  - Visitar sitio web (`Key('more_menu_website')`, `#L981`).
  - Apoyar el proyecto ☕ (`Key('more_menu_donate')`, `#L994`).
- **Sobre Rinde Más** (`Key('more_group_about')`, `more_screen.dart#L744`):
  - Buscar actualizaciones con `UpdateService` (`Key('more_menu_check_updates')`, `#L1060`).
  - Ver en Google Play (`Key('btn_ver_google_play')`, `#L1103`).
  - Política de privacidad (`Key('more_menu_privacy_policy')`, `#L1116`).
  - Términos y condiciones (`Key('more_menu_terms')`, `#L1129`).

### 3. Gestión de Cuenta, Zona de Peligro y Pie de Página
- **Cuenta Vinculada** (`more_screen.dart#L530-L547`):
  - Avatar, nombre/correo, pastilla `✓ Sincronización activa` (en `Flexible` para pantallas estrechas) y botón `Key('btn_ajustes_cuenta')` (`#L540`).
  - La hoja `Cuenta y seguridad` (`#L1153-L1264`) contiene `Cerrar sesión` (`Key('btn_cerrar_sesion')`, `#L1192`) y la `Zona de Peligro` (`Key('btn_eliminar_cuenta')`, `#L1239`).
  - El diálogo destructivo exige escribir `ELIMINAR` en `Key('delete_account_confirm_input')` (`#L1374`) e incluye casilla opcional para borrar fotos locales.
- **Usuario Invitado / Anónimo** (`#L550-L635`):
  - Botones directos `Vincular con Google` (`Key('btn_vincular_google')`, `#L587`), `Correo` (`Key('btn_vincular_email')`, `#L611`) y `Borrar mis datos de este teléfono` (`Key('btn_borrar_datos_local')`, `#L631`).
- **Pie de Página Limpio** (`#L1267-L1289`):
  - `BcvLegalDisclaimerCard` al fondo de la pantalla, seguido únicamente por el texto pasivo `Rinde Más v$_currentAppVersion` (`Key('more_app_version_footer')`, `#L1283`).

---

## Guía de Verificación en Dispositivo Físico (*Rinde Más Dev*)

- **Artefacto:** `rindemas-dev-apk`
- **Build de CI:** 691 (Run `43282854678`)
- **Commit SHA:** `da92c24` (cambios de `MoreScreen` aterrizados desde `4039a92` y verificados en build `691`)

| Paso | Acción en Dispositivo | Evidencia archivo:línea | Resultado Esperado |
| :--- | :--- | :--- | :--- |
| **1. Cabecera y Orden** | Abrir la pestaña «Más» desde la barra inferior | `lib/ui/screens/more_screen.dart#L345-L430` | AppBar conserva selector de mes, búsqueda y botón de IA sin fondo amarillo. El cuerpo muestra Cuenta, Tasas, Bento 2×2, Ajustes y Pie BCV. |
| **2. Tarjeta de Tasas** | Revisar la tarjeta «Tasas de cambio» y tocar refrescar | `lib/ui/widgets/more/more_rates_card.dart#L58-L155` | Muestra Dólar BCV, Euro BCV, USDT P2P e insignia real de frescura con botón `↻`. Ya no muestra selector de moneda ni descargo BCV interno. |
| **3. Bento 2×2 Unificado** | Inspeccionar los 4 bloques de «Herramientas» y abrir Calculadora | `lib/ui/widgets/more/more_tools_grid.dart#L49-L140` y `lib/ui/screens/currency_calculator_screen.dart#L555` | Los 4 cuadros (incluido «Asistente IA») comparten fondo blanco con insignia amarilla suave. La Calculadora muestra la misma tarjeta BCV al pie. |
| **4. Preferencias y Moneda** | Tocar «Preferencias y datos» y cambiar «Moneda de reportes» | `lib/ui/screens/more_screen.dart#L714-L855` | Abre hoja inferior con selector `CurrencyLensDropdown` reactivo, switch de galería, botones `Excel (.csv)` / `Texto (.md)` y Notificaciones. |
| **5. Soporte y Sobre Rinde Más** | Tocar «Soporte y comunidad» y luego «Sobre Rinde Más» | `lib/ui/screens/more_screen.dart#L729-L756`, `#L929-L1150` | La fila 2 abre WhatsApp, Sitio web y Apoyar. La fila 3 abre Buscar actualizaciones, Google Play, Privacidad y Términos. |
| **6. Pie BCV y Versión** | Desplazar hasta el final de la pantalla «Más» | `lib/ui/screens/more_screen.dart#L1267-L1289` y `lib/ui/widgets/bcv_legal_disclaimer_card.dart#L6-L60` | Muestra la tarjeta compartida de aviso legal BCV con su enlace oficial y, debajo, únicamente `Rinde Más v<versión>` centrado. |
| **7. Ajustes de Cuenta** | Tocar el engranaje `⚙️` en la tarjeta de cuenta y probar «Eliminar cuenta» | `lib/ui/screens/more_screen.dart#L540`, `#L1153-L1255`, `#L1374-L1419` | Despliega «Cerrar sesión» y «Zona de Peligro». En el diálogo, el botón rojo se habilita solo al escribir `ELIMINAR` *(cancelar sin confirmar)*. |
