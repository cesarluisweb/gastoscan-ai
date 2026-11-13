# Bitácora y Respuestas para Solicitud de Acceso a Producción (Google Play)

Este documento registra los datos, interacciones y cambios técnicos ocurridos durante la prueba cerrada de 14 días para responder el cuestionario oficial de Google Play Console al solicitar el acceso a producción.

---

## 1. Datos de la Prueba Cerrada

* **Identificador de la App:** `com.cesarluis.rindemas` (Rinde Más: Control de Gastos).
* **Pista de prueba:** Cerrada (Closed Testing).
* **Grupo de evaluadores:** `rinde-mas-evaluadores@googlegroups.com` (Google Groups).
* **Fecha de inicio (Día 1 con 12 evaluadores aceptados):** 20 de octubre de 2026.
* **Fecha objetivo (Día 14 cumplido):** 3 de noviembre de 2026 (Completado con 12 evaluadores sin interrupciones).
* **Fecha de envío de solicitud a producción:** 4 de noviembre de 2026, 07:42 AM.
* **Estado actual:** En revisión por el equipo de Google Play (estimado: 7 días o menos).

---

## 2. Respuestas Oficiales Enviadas en Google Play Console

### Sección 1: Información sobre tu prueba cerrada

1. **¿Cómo reclutaste usuarios para tu prueba cerrada?**
   > Recluté evaluadores mediante dos canales: familiares y amigos en Venezuela con distintos teléfonos Android y comunidades técnicas de desarrolladores en Reddit, coordinados vía un Grupo de Google.

2. **¿Cómo de fácil te ha resultado reclutar testers para tu aplicación?**
   > *Opción seleccionada:* Ni difícil ni fácil.

3. **Describe las interacciones que has recibido de los testers durante la prueba cerrada:**
   > Los evaluadores usaron las funciones principales: registro manual bimonetario (VES/USD), escaneo de facturas con IA, cálculo de tasa oficial BCV y listas de compras. Su uso fue coherente con un usuario real, registrando gastos cotidianos 2 a 3 veces por semana y probando el modo sin conexión.

4. **Resume los comentarios que has recibido de los testers e indica cómo los has recogido:**
   > Recogí comentarios por reseñas privadas de Play Store, correo de soporte y el Grupo de Google. Solicitaron admitir tasas históricas antiguas (<50 Bs/USD en 2023), aclaraciones sobre privacidad (datos locales en el teléfono sin acceso bancario) y ajustes de contraste en modo claro.

---

### Sección 2: Sobre tu aplicación

1. **¿A qué audiencia va dirigida tu aplicación?**
   > Va dirigida a personas y familias en Venezuela que manejan sus finanzas cotidianas en un entorno bimonetario (bolívares y dólares), y que necesitan registrar gastos diarios, consultar tasas oficiales del BCV y planificar presupuestos mensuales sin depender de conexiones bancarias complejas.

2. **Describe cómo tu aplicación aporta valor a los usuarios:**
   > Simplifica la economía bimonetaria permitiendo registrar compras en segundos mediante escaneo de facturas con IA y conversión automática con tasa oficial BCV. Funciona sin internet (local-first) con almacenamiento seguro en el teléfono, ofreciendo control de presupuestos sin fricción.

3. **¿Cuántas descargas esperas que tenga tu aplicación durante el primer año?**
   > *Opción seleccionada:* Entre 0 y 10.000.

---

### Sección 3: Preparación para producción

1. **¿Qué cambios has realizado en tu aplicación basándote en lo que has aprendido durante tu prueba cerrada?**
   > Ajusté la validación para admitir tasas históricas pasadas, optimicé el contraste en modo claro, mejoré la visualización de presupuestos mensuales con un medidor de saldo disponible intuitivo y reforcé la extracción de fechas en el escaneo de facturas para evitar discrepancias de formato.

2. **¿Cómo decidiste que tu aplicación estaba lista para pasar a producción?**
   > Por estabilidad técnica: 0% de bloqueos (crashes) y ANRs en Play Console durante los 14 días, suite automatizada con más de 580 pruebas en verde en cada versión, funcionamiento sin conexión 100% verificado en SQLite y confirmación de los evaluadores en los flujos de escaneo y presupuesto.

---

## 3. Registro Cronológico de Novedades y Feedback

| Día | Fecha | Hito / Feedback recibido | Acción técnica o correctiva |
| :--- | :--- | :--- | :--- |
| **Día 1** | 20/10/2026 | Se alcanzó el umbral de 12 evaluadores aceptados en Play Console. | Se activó el temporizador de 14 días. |
| **Día 2** | 21/10/2026 | Validación de tasas históricas (< 50 Bs en 2023) y caché de serie de cambio. | Build 530 verificado en CI. |
| **Día 4-5** | 24/10/2026 | Check-in intermedio con evaluadores por Google Groups. Foco en cálculo BCV, voz y compras. | Refuerzo de guía de reseñas privadas en Google Play. |
| **Día 6-13** | 25/10 - 02/11 | Optimización visual de presupuestos ("Tanque que se vacía") y triple escudo de fechas OCR. | Builds 640 y 641 en CI con 587 tests en verde. Despliegue web en producción. |
| **Día 14** | 03/11/2026 | Cumplidos 14 días ininterrumpidos con 12 evaluadores activos. Se habilitó botón de acceso a producción. | Cero crashes, cero ANRs en consola. |
| **Hito** | 04/11/2026 | Cuestionario completado y solicitud de acceso a producción enviada formalmente (07:42 AM). | Espera de revisión de Google (7 días o menos). |

---

## 4. Estado Verificado en Play Console (05/11/2026)

**Comprobación directa del panel** (`Panel de control → Producción`):

- **Producción:** `Inactivo`. La app sigue distribuida únicamente por prueba cerrada.
- **Mensaje literal de la consola:**
  > *"Hemos recibido tu solicitud de acceso a producción. Estamos revisando tu formulario de solicitud. Enviaremos un correo al propietario de la cuenta con las novedades. Este proceso suele tardar 7 días o menos, pero en ocasiones puede llevar más tiempo."*
- **Fecha de la solicitud:** miércoles 04/11/2026, 07:42.
- **Correo de notificación:** se enviará a la cuenta propietaria del proyecto (César).

### Qué implica mientras dure la revisión
1. **No se puede crear un release de producción**: el botón de producción permanece bloqueado hasta la aprobación.
2. El AAB `1.5.0` (código de versión `669`, run de CI `42091003101`) se sube a **prueba cerrada** con normalidad; la revisión de acceso a producción no se reinicia por subir builds a ese canal.
3. Cuando Google apruebe, se **promociona el mismo artefacto** a producción (sin recompilar). Se recomienda despliegue escalonado (20% → 100%).
4. La ficha de Play, la política de privacidad y la declaración de Seguridad de los Datos ya están publicadas y no requieren cambios para esta versión.
