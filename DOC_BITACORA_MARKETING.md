# Bitácora y Aprendizajes de Marketing de Guerrilla: Rinde Más

Este documento registra la estrategia real ejecutada en comunidades, los textos exactos utilizados, las métricas de alcance, el tipo de respuestas de los usuarios y los aprendizajes aplicables tanto para Rinde Más como para el lanzamiento de futuras aplicaciones en el mercado hispanohablante / venezolano.

---

## 1. El Experimento: Lanzamiento Orgánico en Reddit

* **Fecha de inicio:** 30 de Septiembre de 2026.
* **Objetivo:** Validar interés real, recopilar feedback técnico/UX y captar los primeros testers sin presupuesto publicitario.
* **Canales utilizados:**
  1. `r/AskVenezuela` (Público general consumidor).
  2. `r/dev_venezuela` (Comunidad de desarrolladores y perfiles técnicos).
  3. `r/vzla` (Comunidad principal de venezolanos - 150k+ miembros).

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

### C. En `r/vzla` (Enfoque Amplio con Argumento de Privacidad y Modo Local)
* **Título del Post:**
  > *Hice una app para escanear facturas con IA y controlar gastos en bolívares y dólares a tasa BCV (busco opiniones / testers)*
* **Cuerpo del Post:**
  > *Desarrollé este proyecto personal cansado de dos cosas: las facturas de papel térmico del supermercado que se borran en el bolsillo y el desorden de calcular mentalmente entre bolívares y dólares con la tasa oficial.*
  > 
  > ***Cómo funciona:***
  > * *Le tomas foto a la factura (o dictas por voz) y la IA desglosa los productos con sus precios y categoría en 2 segundos.*
  > * *Lleva el control contra un presupuesto mensual y te dice cuánto te queda para gastar en el mes.*
  > 
  > ***Sobre la privacidad (sé que en el país este tema es clave):***
  > * *No pide cuentas bancarias, números de tarjeta ni contraseñas.*
  > * *Si no inicias sesión con Google, el 100% de los datos se queda confinado únicamente en la memoria local de tu teléfono sin tocar ningún servidor.*
  > 
  > *Estoy terminando la fase de pruebas para el lanzamiento en Google Play. Si alguien quiere probarla y darme su opinión sincera sobre la extracción o la interfaz, la puede descargar directo desde la web: https://rindemas.cesarluis.com/*
  > 
  > *Cualquier fallo, crítica o sugerencia me ayuda un montón para seguir mejorándola.*

---

## 3. Resultados y Métricas de Rendimiento (Primeras 24 Horas)

* **Alcance acumulado:** Más de **3.000 vistas** orgánicas.
* **Audiencia geográfica:** **77.1% en Venezuela**, 7.7% EE.UU., 2.4% Colombia.
* **Posicionamiento:** Post **#5 del día** en `r/AskVenezuela`.
* **Interacción:** 45+ comentarios combinados y 75% de upvote ratio.
* **Conversión a descargas:** Decenas de descargas directas del APK desde la web.

---

## 4. Tipología de Comentarios y Reacciones Recibidas

```
+------------------------------------+---------------------------------------+
| Tipo de Reacción                   | Comentarios y Validaciones Clave      |
+------------------------------------+---------------------------------------+
| 🟢 Deseo de Compra y Descarga      | "La necesito, toma mi dinero y cállate"|
|                                    | "Los gastos hormiga me tienen loco"   |
|                                    | "Pásame el link y la pruebo"          |
+------------------------------------+---------------------------------------+
| 🟡 Objeción de Privacidad (Mayor)  | "No le confío mis cosas a apps de     |
|                                    |  terceros, me da miedo el SENIAT/banco"|
|                                    | "Google tiene demasiados datos míos"  |
|                                    | "Solo si es de código abierto"        |
+------------------------------------+---------------------------------------+
| 🔵 Feedback Técnico y Validación   | ✅ Leyó facturas de Farmatodo y Forum |
|                                    |    sin ningún error (confirmado)      |
|                                    | * Detección de IVA (E/G/16%) por ítem |
|                                    | * Quitar "$ 0.00" en facturas en cola |
|                                    | * Usar intersticiales para cubrir IA  |
|                                    | * Reto: facturas informales de chinos |
+------------------------------------+---------------------------------------+
| 🟣 Comparación con Competidores    | Ex-usuarios de Rial agotados de tener |
|                                    | que registrar entradas y transferencias|
+------------------------------------+---------------------------------------+
```

---

## 5. Respuestas Estratégicas Utilizadas (El Tono de César)

### A. Ante el Miedo a la Privacidad y el SENIAT:
> *"Es totalmente comprensible. La app no pide vinculación con bancos, números de cuenta ni contraseñas. Funciona guardando los datos en el teléfono y respaldándolos en la nube vinculados a tu cuenta privada de Google para que no los pierdas, sin intermediarios ni compartir información con terceros. Gracias por el comentario, me ayuda a seguir dándole prioridad a la privacidad."*

### B. Ante el usuario que no quiere vincular su cuenta Google:
> *"Precisamente así funciona por defecto. Si no inicias sesión con Google, la app no sube absolutamente nada a la nube y el 100% de los datos se quedan confinados en la memoria interna de tu propio teléfono (SQLite local). La opción de Google es estrictamente opcional por si alguien cambia de celular y no quiere perder sus registros. Si prefieres privacidad total, la usas sin iniciar sesión y listo."*

### C. Ante el Purista del Código Abierto / F-Droid:
> *"Jajaja, lo más cerca que te puedo ofrecer ahorita es que si no inicias sesión con Google, el 100% de los datos se quedan confinados en el SQLite local de tu teléfono sin tocar ningún servidor. Pero el día que Gemini sea gratis y los servidores no cobren, te la subo a F-Droid sin pestañear xD"*

### D. Ante los Usuarios de Excel:
> *"El que es experto en Excel le va buenísimo. Te confieso que no sabía que Excel tenía esa opción. De todas maneras, seguro alguien encontrará más práctico descargar una app que se enfoque en hacer precisamente esto."*

---

## 6. Grandes Aprendizajes para Futuros Lanzamientos

1. **No usar carruseles publicitarios en comunidades:** Los posts con formato de pregunta honesta o proyecto personal tienen 10x más interacción que un flyer comercial.
2. **La privacidad es la objeción #1 en Latinoamérica:** En cualquier app financiera, el titular principal debe responder de inmediato: *"¿Me van a pedir el banco o me van a espiar?"*.
3. **El Modo 100% Local es un argumento de oro:** Poder decir *"si no inicias sesión, el 100% de los datos se queda en tu teléfono sin tocar ningún servidor"* desarma al 90% de los escépticos.
4. **Menos fricción contable gana a apps complejas:** Frente a competidores tipo Rial que exigen cuadrar bancos e ingresos, el valor de Rinde Más es la simplicidad: presupuesto mensual + foto/voz para registrar salidas.
5. **El feedback de desarrolladores es auditoría gratuita:** Publicar en subreddits de programación (`r/dev_venezuela`) aportó validación de que lee Farmatodo/Forum y sugerencias de arquitectura de costos.
6. **Monetización de IA con Anuncios Intersticiales:** En modelos Freemium donde la IA cuesta por token (Gemini), los anuncios intersticiales (pantalla completa en transiciones) pagan entre 5x y 10x más que los banners y cubren holgadamente el costo mensual de la API por usuario.
7. **No forzar ni insistir con el login:** Mantener una experiencia 100% funcional sin cuenta obligatoria genera mucha mayor adopción y confianza en usuarios primerizos.
