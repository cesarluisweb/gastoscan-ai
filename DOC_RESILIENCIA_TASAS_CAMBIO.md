# DOC: Resiliencia de Tasas de Cambio Multifuente (BCV / Paralelo)

## 1. Contexto y Diagnóstico Forense

### Problema Reportado
A partir de compilaciones recientes, la app Android quedó persistentemente mostrando `40.00 Bs / USD` (semilla por defecto `AppConstants.defaultTasaCambio`), nunca actualizaba a la tasa real del BCV (~880 Bs), y el botón manual de sincronización en "Más" no mostraba cambios ni errores.

Al cambiar temporalmente `defaultTasaCambio = 850.0`, la app pasó a mostrar exactamente `850.00 Bs`, demostrando de forma concluyente que la app consumía la constante por defecto y que la sincronización en vivo no surtía efecto.

### Causas Raíz Identificadas
1. **Punto Único de Fallo para la Tasa Oficial:** La tasa oficial del BCV solo se consultaba en un único dominio (`ve.dolarapi.com/v1/dolares/oficial`). Si este dominio sufría bloqueos por operadoras en Venezuela (Cantv, Movistar, Digitel) o fallos de red en el móvil, `usd` quedaba en `0.0`. La cascada con `jsDelivr` solo existía para fechas históricas y nunca se consultaba para el día de hoy.
2. **Máscara de Éxito Parcial:** Si Yadio respondía entregando el valor de `USDT`, la bandera `fetchedAny` se activaba y `getAllTodayRates` devolvía `esReferencia: false` a pesar de que `usd` era `0.0`. En consecuencia, `SettingsProvider` solo actualizaba USDT, dejaba USD en la semilla `40.00` y desactivaba `_tasasSonReferencia`, mostrando erróneamente un badge de "✓ Actualizada hoy" junto al valor semilla de `40.00 Bs`.
3. **Silenciamiento de Errores en la Sincronización Manual:** `actualizarTasaAutomatica` no contaba con bloque `catch` (solo `try/finally`), por lo que cualquier excepción asíncrona se perdía silenciosamente sin notificar al usuario.
4. **Bloqueo Secuencial por Firestore en `loadSettings`:** `loadSettings` esperaba una lectura de Firestore (`syncSettingsFromFirestore`) sin timeout antes de leer las tasas de caché y antes de disparar `actualizarTasaAutomatica`. En redes móviles inestables, esto congelaba el arranque de la sincronización de tasas.

---

## 2. Solución Arquitectónica Implementada

### A. Endpoint Agregado en Cloudflare Worker (`/tasas`)
- **Ruta:** `GET https://rindemas-gateway.cesarluispuntocom.workers.dev/tasas`
- **Naturaleza:** Público (sin autenticación requerida para permitir lectura sin sesión).
- **Ventaja:** La salida hacia las fuentes corre desde la infraestructura de Cloudflare (egress global), inmune a bloqueos por IP de operadoras venezolanas.
- **Caché en Memoria:** TTL de 5 minutos en el Worker para reducir llamadas a fuentes aguas arriba.
- **Códigos:** Retorna `200` con `{usd, eur, usdt, fecha}` o `503` si ninguna fuente respondió para que el cliente caiga a sus fuentes directas.

### B. Cascada Multifuente Independiente por Divisa en la App Móvil
En `ExchangeRateService.getAllTodayRates`:
- **USD BCV:** Gateway propio → DolarAPI Oficial (`ve.dolarapi.com`) → Yadio Oficial (`api.yadio.io` campo `official.rate`) → jsDelivr Espejo BCV (`cdn.jsdelivr.net`).
- **EUR BCV:** Gateway propio → DolarAPI Euros (`ve.dolarapi.com`) → jsDelivr Espejo EUR (`cdn.jsdelivr.net`).
- **USDT P2P:** Gateway propio → Yadio P2P (`api.yadio.io`) → DolarAPI Paralelo (`ve.dolarapi.com`).
- **Prioridad Preservada con Short-Circuit:** Si el Gateway agregado devuelve la divisa, no se ejecutan las cascadas de red individuales, minimizando el consumo de datos.

### C. Vigencia por Divisa (`ExchangeRatesData`)
- Nuevos campos booleanos: `usdEsReferencia`, `eurEsReferencia`, `usdtEsReferencia`.
- Que una divisa secundaria (USDT) llegue en vivo ya no oculta que el USD oficial esté en referencia.
- `esReferencia` se mantiene como getter de compatibilidad (`usdEsReferencia && eurEsReferencia && usdtEsReferencia`).

### D. Purga de Valores Inverosímiles y Preferencia de Caché
- Se introduce `AppConstants.tasaMinimaPlausible = 50.0`.
- Al inicializar `SettingsProvider`, cualquier valor menor a 50 (como la semilla de 40 persistida en SharedPreferences) se purga automáticamente y se reemplaza por la última tasa verosímil en caché (`cached_rate_usd`), desatascando dispositivos afectados.

### E. Desacoplamiento de Red en `loadSettings`
- Preferencias locales y tasas de caché se cargan de forma síncrona en memoria primero.
- `notifyListeners()` y el render inicial ocurren de inmediato.
- La sincronización de API Key con Firestore se ejecuta en segundo plano con un `timeout` estricto de 8 segundos.

### F. Observabilidad y Reintento por Conectividad
- `SettingsProvider` escucha `ConnectivityService.onConnectivityChanged`. Al recuperar conexión tras arrancar offline, reintenta la sincronización automáticamente si la tasa sigue en referencia.
- El botón de sincronización manual (`refresh_rates_btn`) en `MoreScreen` ejecuta con `forzar: true` (bypasseando la caché en memoria) y muestra un `SnackBar` informativo indicando el éxito o el motivo del fallo.

---

## 3. Guía de Pruebas Paso a Paso para César

### Prueba 1: Carga en Frío con Internet
1. Instalar el nuevo APK compilado.
2. Abrir la app e ir a la pestaña **Más** > **Tasas de Cambio**.
3. **Resultado Esperado:** 
   - El chip muestra `✓ Actualizada hoy`.
   - **Dólar BCV:** Muestra la tasa oficial en vivo (~880.xx Bs / USD).
   - **Euro BCV:** Muestra la tasa oficial en vivo (~985.xx Bs / EUR).
   - **USDT Binance:** Muestra la tasa P2P en vivo (~1005.xx Bs / USDT).
   - En ningún caso debe verse `40.00 Bs`.

### Prueba 2: Sincronización Manual con Feedback
1. En **Más** > **Tasas de Cambio**, pulsar el botón circular de refresco (icono de flecha circular).
2. **Resultado Esperado:**
   - Aparece un spinner de progreso breve (~1-3 segundos).
   - Al terminar, se despliega un SnackBar en la parte inferior: *"Tasas actualizadas desde las fuentes oficiales."* con fondo amarillo y texto negro de alto contraste.

### Prueba 3: Comportamiento Offline y Recuperación
1. Activar el Modo Avión en el teléfono.
2. Cerrar la app por completo (forzar detención) y volver a abrirla.
3. Ir a **Más** > **Tasas de Cambio**.
4. **Resultado Esperado:**
   - La app muestra la última tasa conocida en caché (~880 Bs).
   - El chip muestra `⚠ Tasa de referencia`.
5. Desactivar el Modo Avión (recuperar red).
6. **Resultado Esperado:**
   - La app detecta la conectividad y actualiza automáticamente a `✓ Actualizada hoy` en segundo plano sin intervención del usuario.

### Prueba 4: Creación de Gastos con Tasa BCV
1. Ir a la pantalla de agregar o revisar gasto (`ReviewExpenseScreen`).
2. Seleccionar divisa **USD** con monto 10.
3. Observar el campo o chip de equivalencia en Bolívares.
4. **Resultado Esperado:** El cálculo se realiza a la tasa oficial (~8800 Bs) y no a 400 Bs.

---

## 4. Despliegue del Worker Cloudflare (rindemas-gateway)
El endpoint `/tasas` ya está integrado en el código fuente de `workers/src/index.js` y `cloudflare_worker/src/index.js`. 
Para publicar los cambios al Worker en producción:
```powershell
cd "C:\Development\Control de gastos VE\cloudflare_worker"
npx wrangler deploy
```
*Nota: La app móvil funciona de inmediato gracias a la cascada directa cliente (jsDelivr + Yadio + DolarAPI). El despliegue del worker añade la capa de máxima resiliencia contra bloqueos de operadoras.*
