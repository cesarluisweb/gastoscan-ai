# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **UI-08 (ReviewExpenseScreen: Moneda & Monto Superior, Rediseño Visual):** `Pendiente de validación 🧪`. CI verde (Android build 590, commit `4539170`). 407 pruebas unitarias y de widgets pasando. Rediseño visual sin textos amarillos sobre blanco, input total único unificado bajo selector de moneda, preservación nominal estricta al alternar monedas, productos compactos en 3 filas y sticky footer anclado. Listo para pruebas en *Rinde Más Dev*.
- **UI-06, Desglose Bimonetario & Alineación Visual:** `Pendiente de validación 🧪`. CI verde (Android build 582, commit `9df2ada`). Web validada en vivo vía HTTP 200 en `https://rindemas.cesarluis.com/panel/`.

## Decisiones Técnicas y de Negocio Recientes
- Modelo de Negocio & Anti-patrón Rial: Descartadas cuotas mensuales bajas artificiales (10-15 facturas/mes). La app ofrece escaneo abierto para compras familiares protegido únicamente por el límite anti-abuso de 50 facturas/día en Cloudflare Gateway (`SEC-13`). Rinde Más Pro se enfoca en valor agregado (cero ads, PDF/Excel contable, fotos en la nube, categorías libres, BYOK).
- Plan de Crecimiento y Tracción: Registradas en documentos definitivos las tácticas de micro-creadores de compras y hogar (25-54 años), post de victoria en Reddit (`r/vzla`), videos Formato F (Dilema del Bolívar) y botón de referidos por WhatsApp (`UX-06`).
- Redes Sociales & Video #2: Consolidado en TikTok a 1.1K vistas, 44 likes, 7 guardados, +9 seguidores (77% mujeres 25-54a, 92.7% VE). Instagram Reels: 209 vistas, 21s retención media (56.7%), skip rate 41.4%, like rate 21.6%, +7 seguidores y 17 visitas al perfil (84.8% Feed por colaboración con `lili9077p`). Reglas: avatar femenino de compras del hogar, gancho directo al seg 0:02, cierre al perfil, comentario fijado, colaboración obligatoria en Reels, historias con sticker en zona segura (>3cm borde inferior) sin texto en caption y notas de DMs de 60 caracteres.
- Rediseño de `PendingExpenseCard`: Fondo marfil sutil (`#FFFDF5`), borde ámbar suave (`#FEF08A`), icono leading de alto contraste (`Color(0xFF92400E)` sobre `#FEF9C3`), padding vertical reducido a 11dp (más compacto), eliminación de solapamiento de fecha/estado y botón interactivo `Por revisar →` cuando monto <= 0.
- Nomenclatura canónica de 4 lentes establecida: `USD BCV`, `VES Bolívares`, `USDT P2P` y `EUR BCV` (sin paréntesis decorativos). En vistas compactas: `USD`, `VES`, `USDT`, `EUR`. Removida mención «Binance» de UI de tasas y calculadora cambiaria a favor de `USDT P2P`.
- Web Fase 4: Autenticación por correo/contraseña (`signInWithEmailAndPassword`, `createUserWithEmailAndPassword`, `sendPasswordResetEmail`) integrada en `panel.astro` con mensajes traducidos.
- Web Fase 5: Edición de compras, desglose dinámico y reactividad de facturas al lente multimoneda corregida en `panel.astro`.
- Desglose Bimonetario y Corrección de Alineación Global: En `CategoryChart`, dona ajustada a 112dp con separación de 16dp de la lista, porcentajes alineados a la izquierda en columna dedicada de ancho fijo (`SizedBox(width: 28)`), montos alineados a la derecha (`SizedBox(width: 58)`). En `SummaryCard`, icono del cochino de meta de ahorro actualizado a amarillo (`AppColors.primaryDark`). En `ExpenseCard`, monto secundario en gris (`textSecondary`). Visor de comprobante simplificado ergonómicamente.
- Almacenamiento de Fotos: Título de tarjeta en `MoreScreen` renombrado a `Almacenamiento de fotos`. Guardado local activado por defecto (`defaultGuardarFotos = true`), respetando ajustes explícitos previos. Listo para el próximo push.
- Comprobantes y Galería: Selección múltiple en lote y borrado individual en `ReceiptGalleryScreen` y `ReceiptViewerDialog` (elimina solo el archivo físico en el teléfono preservando intactos los registros de gastos). Añadido enlace directo «Ver o editar gasto» en visor a pantalla completa.
- Entrada por Voz y Asistente IA: Modo especializado `dictado_gasto` con `toolConfig` forzado (`mode: "ANY"`), aislamiento de descripciones limpias de ítems (sin verbos ni comercios), normalización de fracciones/kilos (`500g` -> 0.5), cálculo de precio unitario por kilo (`monto / cant`), soporte de compras sin precio (`monto = 0.00` para revisión), respeto a `monedaPrincipal` por defecto, protección de `_totalOriginalCtrl` en `ReviewExpenseScreen`, fallback heurístico local sin bloqueos, limpieza inmediata del campo de texto al enviar nota de voz y frase aclaratoria «Antes de registrarlo, dime: ¿cuánto te costó en total?».

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.

## Próximo Paso Inmediato
- Esperar validación de César en *Rinde Más Dev* (build 590) con el formulario de revisión rediseñado, comprobantes y flujo de voz.
