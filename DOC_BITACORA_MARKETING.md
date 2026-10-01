# Bitácora y Aprendizajes de Marketing de Guerrilla: Rinde Más

Este documento registra la estrategia real ejecutada en comunidades, los textos exactos utilizados, las métricas de alcance, el tipo de respuestas de los usuarios y los aprendizajes aplicables tanto para Rinde Más como para el lanzamiento de futuras aplicaciones en el mercado hispanohablante / venezolano.

---

## 1. El Experimento: Lanzamiento Orgánico en Reddit (Día 1)

* **Fecha de ejecución:** 30 de Septiembre de 2026.
* **Objetivo:** Validar interés real, recopilar feedback técnico/UX y captar los primeros testers sin presupuesto publicitario.
* **Canales utilizados:**
  1. `r/AskVenezuela` (Público general consumidor).
  2. `r/dev_venezuela` (Comunidad de desarrolladores y perfiles técnicos).

---

## 2. Publicaciones Exactas Utilizadas

### A. En `r/AskVenezuela` (Enfoque en el Problema y Pregunta Abierta)
* **Título del Post:**
  > *¿Usarían una app que escanee las facturas de sus compras con IA, organice los gastos del mes y les dé recomendaciones de ahorro según sus compras?*
* **Cuerpo del Post:**
  > *Desarrollé una aplicación para resolver el problema de los tickets de papel que se borran y el desorden de calcular gastos en bolívares y dólares con la tasa oficial.*
  > 
  > *Tomas foto a la factura, la IA extrae cada producto con su precio, lo clasifica por categoría contra un presupuesto mensual y el asistente integrado analiza en qué estás gastando para darte recomendaciones de ahorro.*
  > 
  > *Estoy terminando la fase de pruebas para lanzarla en Google Play y me gustaría saber si le ven utilidad real o qué función le agregarían.*
  > 
  > *Si a alguien le interesa probarla y darme su opinión, dejen un comentario o escríbanme y les comparto el acceso.*

### B. En `r/dev_venezuela` (Enfoque Técnico y de Colega a Colega)
* **Título del Post:**
  > *Construí una app en Flutter con IA para escanear facturas en Venezuela y manejar cuentas en bolívares y dólares (feedback / testers)*
* **Cuerpo del Post:**
  > *Desarrollé este proyecto personal para resolver un dolor cotidiano: el desorden de las facturas de supermercado y el cálculo constante entre bolívares y dólares a tasa oficial del Banco Central.*
  > 
  > *La app toma la foto de la factura, procesa los productos y montos con Gemini Flash, y organiza los gastos contra un presupuesto mensual. Los datos se guardan de forma local en SQLite.*
  > 
  > *Estoy preparando el lanzamiento en Google Play y necesito feedback de la comunidad sobre la interfaz y el rendimiento de la extracción. Si quieren probarla: https://rindemas.cesarluis.com/*
  > 
  > *Agradezco comentarios sinceros sobre la arquitectura, la experiencia de usuario o fallos que encuentren.*

---

## 3. Resultados y Métricas de Rendimiento (Primeras 12 Horas)

* **Alcance:** Más de **2.700 vistas** orgánicas.
* **Audiencia geográfica:** **77.1% en Venezuela**, 7.7% EE.UU., 2.4% Colombia.
* **Posicionamiento:** Post **#5 del día** en `r/AskVenezuela`.
* **Interacción:** 38+ comentarios y 75% de upvote ratio.
* **Conversión a descargas:** Múltiples descargas directas del APK desde la web.

---

## 4. Tipología de Comentarios y Reacciones Recibidas

```
+------------------------------------+---------------------------------------+
| Tipo de Reacción                   | Comentarios Clave                     |
+------------------------------------+---------------------------------------+
| 🟢 Deseo de Compra y Descarga      | "La necesito, toma mi dinero y cállate"|
|                                    | "Los gastos hormiga me tienen loco"   |
|                                    | "Pásame el link y la pruebo"          |
+------------------------------------+---------------------------------------+
| 🟡 Objeción de Privacidad (Mayor)  | "No le confío mis cosas a apps de     |
|                                    |  terceros, me da miedo el SENIAT/banco"|
|                                    | "Venden data a empresas como en USA"  |
|                                    | "Solo si es de código abierto"        |
+------------------------------------+---------------------------------------+
| 🔵 Feedback Técnico de Valor       | Detección de IVA (E/G/16%) por ítem   |
|                                    | Quitar "$ 0.00" en facturas en cola   |
|                                    | Monitorear tokens devueltos por Gemini|
+------------------------------------+---------------------------------------+
| 🟣 Comparación con Competidores    | Ex-usuarios de Rial agotados de tener |
|                                    | que registrar entradas y transferencias|
+------------------------------------+---------------------------------------+
```

---

## 5. Respuestas Estratégicas Utilizadas (El Tono de César)

### A. Ante el Miedo a la Privacidad y el SENIAT:
> *"Es totalmente comprensible. La app no pide vinculación con bancos, números de cuenta ni contraseñas. Funciona guardando los datos en el teléfono y respaldándolos en la nube vinculados a tu cuenta privada de Google para que no los pierdas, sin intermediarios ni compartir información con terceros. Gracias por el comentario, me ayuda a seguir dándole prioridad a la privacidad."*

### B. Ante el Purista del Código Abierto / F-Droid:
> *"Jajaja, lo más cerca que te puedo ofrecer ahorita es que si no inicias sesión con Google, el 100% de los datos se quedan confinados en el SQLite local de tu teléfono sin tocar ningún servidor. Pero el día que Gemini sea gratis y los servidores no cobren, te la subo a F-Droid sin pestañear xD"*

### C. Ante los Usuarios de Excel:
> *"El que es un máster en Excel se queda en Excel y le va genial, esto es más para tenerlo automático en el teléfono en 3 segundos saliendo del súper."*

---

## 6. Grandes Aprendizajes para Futuros Lanzamientos

1. **No usar carruseles publicitarios en comunidades:** Los posts con formato de pregunta honesta o proyecto personal tienen 10x más interacción que un flyer comercial.
2. **La privacidad es la objeción #1 en Latinoamérica:** En cualquier app financiera, el titular principal debe responder a: *"¿Me van a pedir el banco o me van a espiar?"*.
3. **El Modo 100% Local es un argumento de oro:** Poder decir *"si no inicias sesión, el 100% de los datos se queda en tu teléfono sin tocar ningún servidor"* desarma al 90% de los escépticos.
4. **Menos fricción contable gana a apps complejas:** Frente a competidores tipo Rial que exigen cuadrar bancos e ingresos, el valor de Rinde Más es la simplicidad: presupuesto mensual + foto/voz para registrar salidas.
5. **El feedback de desarrolladores es auditoría gratuita:** Publicar en subreddits de programación (`r/dev_venezuela`) aporta sugerencias de arquitectura, optimización de costos y corrección de casos borde que un usuario común no nota.
