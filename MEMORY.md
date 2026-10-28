# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase 5 (Google Play):** Closed Testing activo con 20 evaluadores (período de 14 días).
- **UI-08 (ReviewExpenseScreen: Moneda & Monto Superior):** `Pendiente de validación 🧪`. CI verde (Android build 580, commit `15a0af4`). 403 pruebas unitarias y de widgets pasando. APK compilado y listo para pruebas en *Rinde Más Dev*.
- **UI-06, Desglose Bimonetario & Web:** `Pendiente de validación 🧪`. Web validada en vivo vía HTTP 200 en `https://rindemas.cesarluis.com/panel/`.

## Decisiones Técnicas y de Negocio Recientes
- Redes Sociales & Video #2: Consolidado en TikTok a 1.1K vistas, 44 likes, 7 guardados y +9 seguidores ganados. Retención media 11.41s. Demografía validada: 77% mujeres (57% de 35 a 54 años), 92.7% Venezuela. Mayor interacción al seg 0:01 (rostro humano) y abandono típico al seg 0:02. Instagram skip rate 44.4%. Consultas orgánicas graduadas a Formato F. Reglas de oro: avatar femenino de compras del hogar, gancho directo al seg 0:02, cierre señalando al perfil y comentario fijado.
- Rediseño de `PendingExpenseCard`: Fondo marfil sutil (`#FFFDF5`), borde ámbar suave (`#FEF08A`), icono leading de alto contraste (`Color(0xFF92400E)` sobre `#FEF9C3`), padding vertical reducido a 11dp (más compacto), eliminación de solapamiento de fecha/estado y botón interactivo `Por revisar →` cuando monto <= 0.
- Nomenclatura canónica de 4 lentes establecida: `USD BCV`, `VES Bolívares`, `USDT P2P` y `EUR BCV` (sin paréntesis decorativos). En vistas compactas: `USD`, `VES`, `USDT`, `EUR`. Removida mención «Binance» de UI de tasas y calculadora cambiaria a favor de `USDT P2P`.
- Web Fase 4: Autenticación por correo/contraseña (`signInWithEmailAndPassword`, `createUserWithEmailAndPassword`, `sendPasswordResetEmail`) integrada en `panel.astro` con mensajes traducidos.
- Web Fase 5: Edición de compras, desglose dinámico y reactividad de facturas al lente multimoneda corregida en `panel.astro`.
- Desglose Bimonetario y Corrección de Alineación Global: Erradicado el antipatrón de envolver montos de la derecha en `Flexible` (que forzaba un reparto 50/50 con el `Expanded` izquierdo dejando los montos en el centro) en `ExpenseCard`, `CategoryChart` (desglose y presupuestos por categoría), `CurrencyRadiographyCard`, `PurchaseRadiographyCard` y `AnalysisScreen`. Todos los montos ahora usan `ConstrainedBox(maxWidth)` + `FittedBox` y quedan pegados a la derecha. Añadido desglose bimonetario de artículos en móvil y web.
- Almacenamiento de Fotos: Título de tarjeta en `MoreScreen` renombrado a `Almacenamiento de fotos`. Guardado local activado por defecto (`defaultGuardarFotos = true`), respetando ajustes explícitos previos. Listo para el próximo push.
- Entrada por Voz y Asistente IA: Modo especializado `dictado_gasto` con `toolConfig` forzado (`mode: "ANY"`), aislamiento de descripciones limpias de ítems (sin verbos ni comercios), normalización de fracciones/kilos (`500g` -> 0.5), cálculo de precio unitario por kilo (`monto / cant`), soporte de compras sin precio (`monto = 0.00` para revisión), respeto a `monedaPrincipal` por defecto, protección de `_totalOriginalCtrl` en `ReviewExpenseScreen` y fallback heurístico local sin bloqueos.

## Errores y Fricciones a Evitar
- No encadenar comandos con `&&` ni usar redirección `>` en PowerShell.
- Monitoreo de CI por proceso dormido único (`scripts/wait_ci.ps1`) con `BypassSandbox: true`.

## Próximo Paso Inmediato
- Esperar validación visual de César en *Rinde Más Dev* (build 580) de la nueva pantalla de registro y edición de gastos (`ReviewExpenseScreen`).
