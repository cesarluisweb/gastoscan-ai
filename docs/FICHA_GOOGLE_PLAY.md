# Ficha Oficial de Google Play Store: Rinde Más

Documento preparado para copiar y pegar directamente en la consola de Google Play Console.

---

## 1. Datos Principales de la Ficha

### Nombre de la aplicación (Máximo 30 caracteres)
```
Rinde Más: Control de Gastos
```

### Nombre de paquete / Application ID
```
com.cesarluis.rindemas
```

### Descripción breve (Máximo 80 caracteres)
```
Control de gastos en Bs y $ a tasa BCV. Sin bancos y con respaldo en tu Google.
```

---

## 2. Descripción Completa (Máximo 4000 caracteres)

```
Lleva el control real de tu dinero en Venezuela sin compartir datos bancarios ni contraseñas. Rinde Más te ayuda a organizar tus compras en bolívares y dólares a tasa oficial BCV, con escaneo inteligente de facturas y presupuestos mensuales.

🛡️ TU PRIVACIDAD ES LO PRIMERO: CERO BANCOS
A diferencia de otras aplicaciones, en Rinde Más tu seguridad no es negociable:
• Cero accesos bancarios: Nunca te pediremos tus claves de banco, números de tarjeta, accesos a SMS ni credenciales financieras.
• Almacenamiento en tu teléfono: Tus transacciones viven de forma local en tu dispositivo. Funciona al 100% sin conexión a internet.
• Respaldo privado en tu Google: Si decides sincronizar o cambiar de teléfono, tus facturas se respaldan de manera cifrada en tu propia cuenta de Google. Nadie más tiene acceso a tus datos.
• Sin venta de información: No vendemos ni compartimos tu información con empresas ni anunciantes. Nos sostenemos con publicidad no intrusiva y una opción de pago único para eliminar anuncios.

📸 NO ESCRIBAS A MANO: ESCANEO DE FACTURAS CON IA
• Toma una foto a tu factura o recibo de compra.
• Nuestra inteligencia artificial extrae cada producto con su precio unitario, cantidad y total.
• Registra compras en segundos sin perder tiempo tecleando ítems uno por uno.

💵 MULTIMONEDA CON TASA OFICIAL BCV
• Registra tus compras en Bolívares (VES) o Dólares (USD).
• Conversión automática con la tasa oficial del Banco Central de Venezuela (BCV) actualizada diariamente.
• Conoce con exactitud cuánto gastas en ambas divisas sin calculadoras externas.

📊 PRESUPUESTOS QUE TE PROTEGEN DE GASTAR DE MÁS
• Asigna un presupuesto general para el mes y montos específicos por categoría (Alimentos, Transporte, Salud, Hogar, etc.).
• Visualiza barras de progreso que te muestran en tiempo real cuánto te queda disponible antes de llegar a cero.
• Alertas preventivas cuando estés cerca de sobrepasar el límite asignado.

🤖 ASISTENTE FINANCIERO INTEGRADO
• ¿En qué se te fue el dinero este mes? Pregúntaselo directamente por chat a tu asistente personal.
• Recibe resúmenes claros, consejos de ahorro y respuestas inmediatas sin enredarte con hojas de cálculo.

🛒 LISTA DE COMPRAS SIN DESPERDICIOS
• Anota los productos que necesitas antes de salir de casa.
• Al escanear o registrar tu factura, la app detecta los artículos y los tacha automáticamente de tu lista.

💻 PANEL WEB SINCRONIZADO
• Revisa tus presupuestos y registra gastos desde tu computadora o tablet ingresando a rindemas.cesarluis.com/panel con tu misma cuenta de Google.

Haz rendir tu dinero hoy mismo. Descarga Rinde Más gratis y toma el control de tus finanzas personales en Venezuela.
 
---
Fuente de información y aviso importante:
Las tasas de cambio denominadas "Dólar BCV" y "Euro BCV" corresponden a información pública publicada por el Banco Central de Venezuela (BCV). Puedes consultar la fuente original en: https://www.bcv.org.ve/

Rinde Más es una aplicación independiente de finanzas personales. No representa, no está afiliada, respaldada ni patrocinada por el Banco Central de Venezuela (BCV) ni por ninguna otra entidad gubernamental o política. Las tasas mostradas son de carácter informativo y referencial para tus registros de gastos personales.
```

---

## 3. Formulario de Seguridad de los Datos (Data Safety en Google Play)

### URLs Obligatorias
* **URL de la Política de Privacidad:** `https://rindemas.cesarluis.com/privacidad`
* **URL de Solicitud de Eliminación de Cuenta y Datos:** `https://rindemas.cesarluis.com/eliminar-cuenta`

### Respuestas directas para completar el cuestionario obligatorio en Play Console (Seguridad de los Datos):

| Pregunta en Consola | Respuesta | Explicación y Justificación Técnica |
| :--- | :--- | :--- |
| **¿La app recopila o comparte datos de usuario?** | **Sí (Solo recopilación)** | Se recopilan datos exclusivamente para las funciones solicitadas por el usuario (respaldo en la nube opcional y procesamiento de comprobantes/chat con IA). |
| **¿Los datos se comparten con terceros?** | **No** | Cumple con las excepciones de Google Play: 1) Proveedores de servicios (Cloudflare y Google Gemini en modo gestionado de pago procesan datos en tránsito exclusivamente por cuenta del desarrollador sin fines comerciales ni publicitarios). 2) Excepción de transferencia dirigida por el usuario (en modo BYOK el usuario inicia y autoriza expresamente la conexión con su propia cuenta de Google AI Studio con advertencia previa). Ningún dato se vende ni comparte con redes de publicidad ni intermediarios. |
| **¿Los datos se transmiten mediante conexión segura (HTTPS/TLS)?** | **Sí** | Todo el tráfico entre la aplicación, Firebase, Cloudflare Gateway y las APIs viaja cifrado bajo HTTPS/TLS. |
| **¿Proporcionas una forma para que los usuarios soliciten que se eliminen sus datos?** | **Sí** | La app incluye botón directo (*Más > Eliminar cuenta y datos*) y existe URL pública externa para solicitarlo sin instalar la app (`https://rindemas.cesarluis.com/eliminar-cuenta`). |
| **¿Qué tipos de datos se recopilan?** | **1. Información personal (Nombre y correo)**<br>**2. Fotos y vídeos (Fotos de recibos)**<br>**3. Datos financieros/compras (Registros de gastos)** | • **Nombre y correo:** Opcional (solo si vincula Google Sign-In o email para respaldar).<br>• **Fotos:** Opcional (solo si usa la cámara/galería para escanear facturas con IA; procesadas efímeramente sin retención persistente en el servidor).<br>• **Historial de gastos:** Opcional (se guardan localmente en SQLite y se sincronizan cifrados en Firestore solo si el usuario activa respaldo). |
| **¿Los datos son necesarios o el usuario puede elegir si se recopilan?** | **Opcional en todos los casos** | La app es 100% funcional de forma local y offline sin crear cuenta, sin escanear con IA y sin sincronizar en la nube. |

---

## 4. Palabras Clave ASO (Búsquedas en Venezuela)

* `control de gastos venezuela`
* `presupuesto bolivares y dolares`
* `tasa bcv gastos`
* `escanear facturas ia`
* `finanzas personales venezuela`
* `administrador de dinero sin bancos`
* `gastos bcv`

---

## 5. Especificaciones de Assets Gráficos

* **Ícono de la aplicación:** 512 x 512 px (formato PNG de 32 bits, hasta 1 MB).
* **Gráfico de funciones / Imagen destacada (Portada):** 1024 x 500 px (PNG o JPEG, sin texto pequeño, ilustrativo).
* **Capturas de pantalla del teléfono:** Mínimo 2, idealmente de 4 a 8 en resolución 1080 x 1920 px (o 1080 x 2400 px).

---

## 6. Textos para Gráficos y Capturas de Pantalla (Screenshots)

1. **Captura 1 (Privacidad y Cero Bancos):**
   * *Titular:* **Tus finanzas son tuyas: 100% sin conexión bancaria**
   * *Subtítulo:* Tus datos se quedan en tu teléfono con respaldo privado en tu Google.
2. **Captura 2 (Escáner OCR):**
   * *Titular:* **Fotografía tu factura. La IA hace el resto**
   * *Subtítulo:* Extrae cada producto, cantidad y precio sin teclear nada.
3. **Captura 3 (Multimoneda BCV):**
   * *Titular:* **Bolívares y Dólares con tasa oficial BCV**
   * *Subtítulo:* Conversión instantánea para saber exactamente cuánto gastas.
4. **Captura 4 (Presupuestos):**
   * *Titular:* **Presupuestos que te avisan antes de quedarte en cero**
   * *Subtítulo:* Barras de control por categoría para no pasarte del límite.
5. **Captura 5 (Asistente IA):**
   * *Titular:* **Tu asistente financiero personal**
   * *Subtítulo:* Pregúntale en qué se te fue el sueldo y recibe respuestas claras.

---

## 7. Notas para los Revisores de Google Play (App Access / Demo Notes)

```
Instrucciones para el revisor:
- La aplicación opera por defecto en modo local (SQLite) sin requerir registro ni inicio de sesión obligatorio.
- Todas las funciones principales (escaneo de comprobantes, presupuestos, lista de compras y asistente) son accesibles de forma inmediata.
- Para verificar la sincronización opcional con Google, puede utilizar cualquier cuenta de Google estándar en 'Más > Respaldo y Sincronización'.
- La app no solicita credenciales bancarias, accesos SMS ni números de tarjeta.
```

