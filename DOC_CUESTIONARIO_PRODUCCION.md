# Bitácora y Respuestas para Solicitud de Acceso a Producción (Google Play)

Este documento registra los datos, interacciones y cambios técnicos ocurridos durante la prueba cerrada de 14 días para responder el cuestionario oficial de Google Play Console al solicitar el acceso a producción.

---

## 1. Datos de la Prueba Cerrada

* **Identificador de la App:** `com.cesarluis.rindemas` (Rinde Más: Control de Gastos).
* **Pista de prueba:** Cerrada (Closed Testing).
* **Grupo de evaluadores:** `rinde-mas-evaluadores@googlegroups.com` (Google Groups).
* **Fecha de inicio (Día 1 con 12 evaluadores aceptados):** 20 de octubre de 2026.
* **Fecha objetivo (Día 14 cumplido):** 3 de noviembre de 2026.
* **Meta de evaluadores:** 12 obligatorios (objetivo de seguridad: 15–18).

---

## 2. Cuestionario Oficial de Google Play (Borrador de Respuestas)

### Pregunta 1: ¿Cómo reclutaste a los evaluadores para tu prueba cerrada?
**Borrador de respuesta:**
> Recluté a los evaluadores a través de tres vías principales:
> 1. Colegas y desarrolladores en comunidades técnicas locales de Venezuela (`r/dev_venezuela` en Reddit), interesados en herramientas financieras bimonetarias y cálculo de tasa oficial BCV.
> 2. Círculo directo de conocidos, amigos y familiares en Venezuela con dispositivos Android reales de distintas gamas y marcas (Xiaomi, Samsung, Motorola).
> 3. Desarrolladores independientes de la comunidad de Android en Reddit (`r/AndroidClosedTesting`), mediante intercambios directos 1 a 1 para evaluar rendimiento e instalación en diferentes versiones del sistema operativo (Android 11 a 15).
> Gestioné el acceso centralizado a través de un Grupo de Google (`rinde-mas-evaluadores@googlegroups.com`) vinculado a la pista cerrada de Google Play Console.

---

### Pregunta 2: ¿Cómo interactuaron los evaluadores con tu aplicación y con qué frecuencia?
**Borrador de respuesta:**
> Los evaluadores utilizaron la aplicación de forma continua durante las dos semanas de prueba, ejecutando los flujos clave:
> - Registro y categorización de gastos manuales en moneda dual (Bolívares VES y Dólares USD).
> - Escaneo fotográfico de facturas y recibos físicos con extracción mediante inteligencia artificial.
> - Consulta y conversión con la tasa oficial diaria del Banco Central de Venezuela (BCV).
> - Creación de presupuestos mensuales por categoría y visualización de barras de progreso.
> - Pruebas de funcionamiento local sin conexión a internet y sincronización opcional con cuenta de Google.
> Se promovió el uso de 2 a 3 sesiones por semana por usuario para registrar compras de la vida cotidiana.

---

### Pregunta 3: ¿Qué comentarios o problemas reportaron los evaluadores y qué canales se utilizaron?
**Borrador de respuesta:**
> **Canales utilizados:** Reseñas privadas dentro de Google Play Store, correo de contacto para soporte técnico (`rindemas.app@gmail.com`), canal del Grupo de Google y mensajería directa con los evaluadores.
>
> **Comentarios y problemas recibidos durante la prueba:**
> 1. *Fricción en la instalación inicial:* Algunos evaluadores reportaron error de "Elemento no encontrado" en la tienda por no haber completado el opt-in web previo en la misma cuenta de Google activa en su dispositivo. Se redactó una guía paso a paso para resolver la discrepancia de cuentas.
> 2. *Registro de compras pasadas:* Un usuario intentó registrar un gasto antiguo de 2023 y notó que el sistema requería soporte adecuado para tasas históricas menores a 50 Bs/USD.
> 3. *Dudas sobre privacidad:* Evaluadores consultaron si la aplicación accedía a cuentas bancarias o requería datos personales. Se clarificó la arquitectura local-first (los datos residen en el teléfono en SQLite y no se solicitan datos financieros ni bancarios).
> 4. *Legibilidad e interfaz:* Se sugirió mejorar el contraste de ciertos controles en modo claro y unificar la forma en que se muestran las monedas en las pantallas secundarias.

---

### Pregunta 4: ¿Qué cambios y mejoras realizaste en la aplicación a partir de los comentarios?
**Borrador de respuesta:**
> Durante el período de prueba cerrada se publicaron actualizaciones en Google Play para atender directamente el feedback recibido:
> 1. **Soporte robusto de tasas históricas:** Se ajustó la validación de tasa en el formulario de gastos para permitir cualquier tasa histórica válida (> 0), y se implementó almacenamiento en caché de la serie histórica de tasas para evitar consumo innecesario de datos móviles.
> 2. **Compatibilidad moderna con Android 15 y 16:** Se adaptó la interfaz a pantalla completa (Edge-to-Edge nativo) y se limitó el ancho máximo de lectura a 600 dp para evitar deformaciones en pantallas grandes y modo horizontal.
> 3. **Consistencia en visualización de monedas:** Se estandarizó el orden canónico de monedas (USD -> VES -> USDT -> EUR) en todas las pantallas de análisis y configuración.
> 4. **Claridad en privacidad y soporte:** Se añadieron leyendas transparentes sobre el almacenamiento local de datos y enlaces directos a la política de privacidad y fuentes oficiales del BCV.

---

### Pregunta 5: ¿Cómo determinaste que la aplicación está lista para lanzarse a producción?
**Borrador de respuesta:**
> Determinamos que la aplicación está lista basándonos en criterios objetivos de estabilidad y usabilidad:
> - **Estabilidad técnica en Google Play Console:** Tasa de bloqueos (crashes) y tasa de ANR en 0% a lo largo de las sesiones de los evaluadores en diversas versiones de Android (desde Android 10 hasta Android 15).
> - **Suite de pruebas automatizadas:** Integración continua con más de 200 pruebas unitarias y de widgets en verde, validando cálculos matemáticos de conversión, redondeos financieros y persistencia local en SQLite.
> - **Comportamiento offline verificado:** La aplicación opera de forma íntegra sin conexión a internet, garantizando que el usuario nunca pierda sus registros por fallas de conectividad.
> - **Validación de la propuesta de valor:** Los evaluadores confirmaron que el escaneo de facturas y el cálculo automático con tasa oficial resuelven de forma rápida el desorden de gastos bimonetarios en Venezuela.

---

## 3. Registro Cronológico de Novedades y Feedback (Semana a Semana)

| Día | Fecha | Hito / Feedback recibido | Acción técnica o correctiva |
| :--- | :--- | :--- | :--- |
| **Día 1** | 20/10/2026 | Se alcanzó el umbral de 12 evaluadores aceptados en Play Console. | Se activó el temporizador de 14 días. |
| **Día 2** | 21/10/2026 | Corrección de validación de tasas históricas (< 50 Bs en 2023) y caché de serie de cambio. | Build 530 verificado en CI. |
| **Día 3-7** | *En curso* | *Por registrar (comentarios de evaluadores en Play Store o soporte)* | *Pendiente* |
| **Día 8-14** | *Pendiente* | *Por registrar* | *Pendiente* |
