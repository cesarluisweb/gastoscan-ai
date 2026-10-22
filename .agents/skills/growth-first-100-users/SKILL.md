---
name: growth-first-100-users
description: Guía paso a paso y playbook táctico para publicar 'Rinde Más' en Google Play, gestionar el período de prueba cerrada de 14 días y escalar a los primeros 100 usuarios activos en Venezuela sin inversión publicitaria.
---

# Playbook de Lanzamiento y Primeros 100 Usuarios: Rinde Más

Esta skill guía la ejecución táctica para publicar la aplicación en Google Play Store y conseguir los primeros 100 usuarios activos en Venezuela con presupuesto cero.

---

## 1. El Embudo de Adquisición (Etapas Clave)

```
[Etapa 1: Cuenta y Build] -> [Etapa 2: Prueba Cerrada 14 Días] -> [Etapa 3: Producción + ASO] -> [Etapa 4: Tráfico Orgánico a 100 Usuarios]
```

1. **Etapa 1:** Registro de desarrollador en Google Play y generación de compilación de producción (`.aab`).
2. **Etapa 2:** Período activo de 14 días continuos de prueba cerrada (Closed Testing) y recopilación de evidencias de uso.
3. **Etapa 3:** Aprobación y publicación abierta con ficha optimizada para búsquedas en Venezuela (ASO).
4. **Etapa 4:** Tráfico de guerrilla mediante comunidades especializadas y videos cortos demostrativos.

---

## 2. Etapa 1: Preparación Técnica para Google Play

### Requisitos Previos y Pago desde Venezuela
* **Cuenta de desarrollador:** Pago único de $25 USD en [Google Play Console](https://play.google.com/console).
* **Ruta Verificada de Pago de $25 USD (Venezuela):**
  * **Rechazo Prepago (`OR_CCR_61`):** Google Play Console **rechaza tarjetas prepago directas** como Zinli para el pago inicial de $25.
  * **Ruta Verificada y Probada:** `Zinli` → `OKX P2P` (USDT) → `OKX Pay` → `OKX Card` (Mastercard virtual) → `Google Payments` ($25 USD).
  * **Titularidad:** Los datos del método de pago P2P deben coincidir con el titular verificado de la cuenta OKX.
* **Tipo de cuenta:** Cuenta Personal (rápida, pero muestra el nombre legal del desarrollador en la ficha) vs Cuenta de Empresa (requiere D-U-N-S, dominio web y verificación de varias semanas).
* **Formato de entrega:** Google Play exige formato Android App Bundle (`.aab`), no `.apk`.
* **Keystore firmado:** La llave privada de firma debe estar configurada en los Secrets de GitHub Actions para que el pipeline genere el `.aab` automáticamente.
* **Política de Privacidad:** URL pública requerida obligatoriamente por Google Play (alojada en `rindemas.cesarluis.com/privacidad`).
* **Programa para Pequeñas Empresas (Comisión reducida):** Inscribirse en el *Google Play Small Business Program* para reducir la comisión de Google en suscripciones y compras integradas del 30% al 15% (hasta el primer millón de USD anual).

### Checklist de Ficha Básica y Assets
* **Nombre de la app:** `Rinde Más: Control de Gastos` (máx. 30 caracteres).
* **Descripción breve (80 caracteres):** `Escanea facturas con IA, controla tu dinero en bolívares y dólares a tasa BCV.`
* **Categoría y Formularios:** Finanzas / Herramientas. Completar cuestionario IARC de clasificación y declaración de app financiera (sin acceso bancario).
* **Assets obligatorios:**
  * Ícono: 512 x 512 px (PNG 32 bits).
  * Imagen destacada (Feature Graphic / Portada): 1024 x 500 px (PNG/JPEG).
  * Capturas de pantalla: Mínimo 2, sugerido 1080 x 1920 px.

---

## 3. Etapa 2: Seguimiento de Prueba Cerrada (Closed Testing - 14 Días)

Google Play exige para cuentas personales nuevas creadas después de noviembre de 2023 que los evaluadores independientes permanezcan inscritos y con actividad en una prueba cerrada durante **14 días consecutivos** antes de habilitar la solicitud de publicación a producción.

### Protocolo de Activación y Soporte Técnico para Evaluadores Activos
1. **Grupo de Google:** Los evaluadores están inscritos en `rinde-mas-evaluadores@googlegroups.com`.
2. **Opt-in de Google Play:**
   * El evaluador debe ingresar al enlace web de opt-in: `https://play.google.com/apps/testing/com.cesarluis.rindemas` y pulsar el botón azul **"Convertirse en evaluador"**.
   * *Importante:* Si el usuario no realiza este opt-in, el botón "Actualizar" de la app o el enlace de la tienda arrojará error *"No se ha encontrado el elemento"*.
3. **Instalación y Actualización Directa:**
   * Enlace en tienda: `https://play.google.com/store/apps/details?id=com.cesarluis.rindemas`

### Bitácora Obligatoria para Solicitud de Producción (Apply for Production)
Al finalizar los 14 días, Google evaluará la solicitud mediante un formulario obligatorio. Se debe llevar registro activo de:
1. **Dispositivos reales evaluados:** Registrar modelos exactos reportados por evaluadores (ej. Redmi Note 11S, Samsung Galaxy, etc.).
2. **Uso real de funciones principales:** Pruebas de persistencia local en SQLite, filtros por mes, escaneo de facturas con IA, cálculo de tasas BCV/P2P y presupuestos mensuales.
3. **Feedback recopilado y fallos reportados:** Respuestas de evaluadores, capturas enviadas y confirmación de estabilidad (cero crashes).
4. **Versiones desplegadas y corregidas:** Historial de entregas en la pista cerrada (`v1.0.4+4`, etc.) durante los 14 días.

### Tiempos de Revisión y Regla de Lanzamiento
* **Primera versión:** La revisión inicial de una app nueva en Google Play suele demorar entre 3 y 7 días hábiles.
* **Actualizaciones posteriores:** Suelen aprobarse en cuestión de 1 a 2 horas.
* **Regla de oro:** No anunciar fechas de lanzamiento públicas ni iniciar campañas en redes hasta contar con la aprobación definitiva en la consola.

---


## 4. Etapa 3: Optimización para Tienda (ASO para Venezuela)

El 70% de las descargas en utilidades provienen de personas buscando palabras exactas en el buscador de la tienda.

* **Ficha Oficial para Google Play:** Consultar y copiar los textos definitivos de título, descripción breve, descripción completa y formulario Data Safety desde [`FICHA_GOOGLE_PLAY.md`](../../FICHA_GOOGLE_PLAY.md) en la raíz del repositorio.

### Palabras Clave de Búsqueda Frecuente
* `control de gastos venezuela`
* `presupuesto bolívares y dólares`
* `escanear facturas ia`
* `tasa bcv gastos`
* `cuentas claras venezuela`

### Capturas de Pantalla con Mensaje Directo
Las imágenes en la tienda deben explicar el valor en 2 segundos:
1. **Captura 1 (El Dolor Principal):** Foto de factura arrugada + extracción automática. Texto: *"No anotes a mano. La IA extrae tus facturas en segundos."*
2. **Captura 2 (La Realidad Local):** Pantalla de gastos con conversión automática. Texto: *"Maneja Bolívares y Dólares con tasa oficial BCV."*
3. **Captura 3 (El Control):** Presupuesto mensual por categoría con barra de progreso. Texto: *"Presupuestos que te avisan antes de gastar de más."*

---

## 5. Etapa 4: Plan Táctico para Alcanzar los Primeros 100 Usuarios

Una vez aprobada la app en producción, se activan 3 canales de distribución directa sin gasto publicitario:

### Canal 1: Comunidades Específicas de Finanzas y Freelancers
* **Dónde:** `r/vzla` (Reddit), foros de freelancers que cobran en divisas y gastan en bolívares, grupos de Telegram de finanzas personales.
* **Enfoque del mensaje:** Compartir la app como una herramienta gratuita construida por necesidad propia para resolver el cálculo de tasas y el desorden de facturas físicas.
* **Objetivo:** 30 a 40 usuarios activos con alta retroalimentación.

### Canal 2: Video Demostrativo Corto (TikTok / Reels)
* **Formato:** Video vertical de 15 segundos sin introducciones:
  * *0 a 3s:* Toma directa de una factura larga de supermercado. Texto en pantalla: *"¿Cuánto gastaste aquí en dólares?"*
  * *4 a 10s:* Enfocar la app tomando la foto y ver cómo se extrae cada producto con su precio convertido a BCV.
  * *11 a 15s:* *"Disponible gratis en Google Play como Rinde Más."*
* **Objetivo:** 40 a 60 descargas directas impulsadas por la búsqueda del nombre en la tienda.

### Canal 3: Círculo Inmediato y Boca a Boca
* Compartir el enlace directo en estados de WhatsApp personales y de los primeros 20 testers.
* **Objetivo:** 20 a 30 usuarios recurrentes.

---

## 6. Embudo de Conversión (Funnel) y Monetización

```
[1. Impresión] -> [2. Ficha Google Play] -> [3. Descarga] -> [4. Onboarding Local] -> [5. Activación: 1er Escaneo] -> [6. Retención] -> [7. Pago / Pro]
```

1. **Activación Temprana:** Guiar al usuario a escanear su primera factura en los primeros 60 segundos de uso.
2. **Subvención Cruzada:** Usuarios gratuitos consumen cuota de 15-20 facturas/mes viendo anuncios en transiciones.
3. **Conversión a Rinde Más Pro ($1.99/mes o $19.99/año):** Disparador contextual al agotar cuota mensual o al solicitar reporte contable en PDF/Excel.

---

## 7. Métricas Clave de Control

| Métrica | Objetivo de Etapa | Qué indica |
| :--- | :--- | :--- |
| **Testers registrados** | 20 usuarios | Requisito cumplido de Google Play |
| **Días de prueba continua** | 14 días | Habilitación de botón de producción |
| **Tasa de conversión en tienda** | > 25% | La ficha y capturas explican bien el producto |
| **Activación (1er escaneo en día 1)** | > 60% de descargas | El usuario experimenta el valor de la app de inmediato |
| **Usuarios activos (Día 7)** | > 30% de los 100 | La app realmente soluciona el problema de registro |
| **Validación financiera inicial** | ~$50 USD en 30-60 días | Validación de disposición de pago (Pro / Ads) en el nicho |

---

## 8. Checklist Preventiva contra Rechazos en Tiendas (Google Play)

* **Eliminación de Cuenta en la App:** Debe existir un botón funcional dentro de la app para eliminar la cuenta y los datos asociados (`Más > Respaldo y Sincronización > Eliminar cuenta`). No se permite exigir un correo a soporte.
* **Cero Enlaces Rotos o Botones "Próximamente":** Los evaluadores rechazan apps que tengan botones inactivos que digan "próximamente" o links que devuelvan error 404.
* **Notas de Acceso de Prueba (App Access):** Indicar claramente en la consola que la app funciona 100% en modo local sin registro obligatorio y proporcionar instrucciones para probar la sincronización opcional con Google.
* **Declaración Financiera sin Solicitud Bancaria:** Aclarar en los formularios de la consola que la app no es una entidad financiera ni solicita credenciales bancarias.
* **Cobro Exclusivo con Google Play Billing:** Para la venta de suscripciones digitales (Rinde Más Pro), utilizar estrictamente el sistema de facturación de Google Play.

---

## 9. Mantenimiento Anual y Ciclo de Vida

* **Actualización Anual de Target SDK (`targetSdkVersion`):** Google exige actualizar anualmente el nivel de API de destino de Android. Si no se actualiza, la app deja de mostrarse a nuevos usuarios en versiones modernas del sistema operativo.
* **Monitoreo de Políticas:** Revisar periódicamente las advertencias de la consola de Google Play para resolver requerimientos de privacidad o seguridad antes de que venzan los plazos.


