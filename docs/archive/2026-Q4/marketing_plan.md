# Plan de Marketing y Crecimiento: Rinde Más

**Objetivo:** Conseguir los primeros 100 usuarios activos y validar la app en el mercado venezolano.

## Fase 1: Validación Temprana (Estado Actual)
* **Meta Inmediata:** Conseguir al menos 5 usuarios cercanos (amigos/familiares) que prueben el APK actual.
* **Acción:** Instalar la app en sus teléfonos, pedirles que registren gastos reales y observar cómo interactúan con la interfaz. Recoger feedback directo sobre qué entienden y qué no.

## Fase 2: Despliegue Oficial en Google Play
*Una vez validado el MVP con los primeros usuarios, se procederá a eliminar la fricción del APK.*
* **Cuenta de Desarrollador:** Pagar registro en Google Play Console ($25 USD).
* **Pruebas Cerradas:** Reclutar a 20 testers (incluyendo a los 5 iniciales) para que prueben la app por 14 días (requisito obligatorio de Google para cuentas nuevas).
* **Automatización:** Conectar GitHub Actions para subir las nuevas versiones a la Play Store automáticamente.

## Fase 3: App Store Optimization (ASO) y Posicionamiento de Confianza
*Optimización para aparecer en las búsquedas de la tienda y derribar el miedo bancario.*
* **Ficha Completa:** Consultar el documento listo para producción [`FICHA_GOOGLE_PLAY.md`](FICHA_GOOGLE_PLAY.md).
* **Título oficial:** `Rinde Más: Control de Gastos`
* **Descripción Corta:** `Control de gastos en Bs y $ a tasa BCV. Sin bancos y con respaldo en tu Google.`
* **Pilar de Confianza en la Tienda:** Destacar en los primeros párrafos: *"Sin bancos, sin contraseñas, respaldo privado en tu Google"*.
* **Palabras Clave (Keywords):** Control de gastos venezuela, presupuesto en bolívares y dólares, finanzas personales venezuela, escanear facturas, tasa bcv gastos, administrador de dinero sin bancos.
* **Capturas de Pantalla (Efecto Wow):** 
    1. Privacidad y confianza: *"Tus finanzas son tuyas: 100% sin conexión bancaria"*.
    2. Foto de factura arrugada: *"No teclees más. La IA lee tus facturas"*.
    3. Multimoneda con tasa oficial: *"Maneja Bolívares y Dólares con tasa oficial BCV"*.
    4. Dashboard con presupuesto: *"Presupuestos que te avisan antes de quedarte en cero"*.
    5. Asistente IA: *"Pregúntale a la IA en qué se te fue el sueldo"*.

## Fase 4: Estrategia de Beta Testers (Escalando a 50 usuarios)
* **El "Pitch" para reclutar:** *"Estoy construyendo una app para que la inflación y el desastre de los bolívares/dólares no nos coma el sueldo. Necesito personas que quieran destrozarla y encontrar errores antes del lanzamiento oficial"*.
* **Canales de captación:** 
  1. Amigos de amigos y parejas.
  2. Grupos de WhatsApp de la oficina o universidad.
  3. Grupos de Facebook/Telegram de Freelancers o emprendedores en Venezuela.

## Fase 5: Go-to-Market de Guerrilla (TikTok / Reels)
*Uso de contenido orgánico altamente viralizable.*
* **Formato de Video (15 segundos):**
  * *Segundos 1-3 (Gancho):* Mostrar una factura de supermercado larga y arrugada. *"¿Alguien más odia anotar en qué se le fue la plata?"*
  * *Segundos 4-8 (La Magia):* Grabar la pantalla de la app tomando la foto y extrayendo los productos (Harina, Queso) con sus precios automáticamente.
  * *Segundos 9-15 (Llamado a la acción):* *"Hice esta app para venezolanos con tasa BCV automática. Busca 'Rinde Más' en la Play Store"*.

---

## 6. Mapeo de Subperfiles dentro del Nicho (Venezuela)
Entender las necesidades específicas de cada grupo para orientar los mensajes de marketing y la conversión:

1. **Asalariado / Consumidor Familiar:**
   * *Dolor:* El sueldo no rinde, las compras de supermercado se mezclan y los tickets térmicos se borran.
   * *Valor percibido:* Saber cuánto le queda para gastar en el mes sin sacar cuentas en servilletas.
   * *Ruta de monetización:* Uso gratuito con anuncios en esperas; conversión a Pro si agota cuota mensual de facturas.
2. **Freelancer / Profesional Multimoneda:**
   * *Dolor:* Cobra en USD/cripto, gasta en Bolívares en la calle y pierde el control del tipo de cambio.
   * *Valor percibido:* Visualización dual instantánea a tasa BCV y exportación mensual a CSV/Markdown.
   * *Ruta de monetización:* Candidato natural a Rinde Más Pro ($1.99/mes) por reportes contables y análisis financiero profundo.
3. **Comerciante Informal / Autoempleado:**
   * *Dolor:* Compra inventario o insumos en cadenas grandes (Forum, Makro) y necesita desglosar ítems y créditos fiscales sin pagar un software ERP complejo.
   * *Valor percibido:* Extracción automática de ítems, alícuotas de IVA y respaldo seguro.
   * *Ruta de monetización:* Rinde Más Pro ($1.99/mes o $19.99/año) por escaneo ilimitado en lote y reportes para control de costos.

---

## 7. Estrategia Build in Public y Automatización de Contenidos
* **Construir en Público (Build in Public):** Compartir abiertamente en Twitter/X, LinkedIn y Reddit los avances y retos técnicos (ej. "Cómo entrenamos la IA para leer facturas arrugadas con tasa BCV").
  * Genera confianza, auditoría y pre-adopción de usuarios técnicos de alto valor.
  * Separa la comunidad de soporte del público comercial final.
* **Automatización de Contenidos:**
  * Crear plantillas de videos de 15 segundos para TikTok e Instagram Reels reutilizando capturas de pantalla de extracciones reales.
  * Programar publicaciones recurrentes para mantener flujo constante de impresiones orgánicas sin interrumpir el desarrollo técnico.

---

## 8. Embudo de Conversión (Funnel) y Monetización Sostenible
*Monetizar es un producto independiente que requiere su propia experiencia y optimización.*

```
Impresión (Comunidades/Redes/ASO)
  └── Ficha de Tienda (Sin bancos, 100% privado)
        └── Descarga / Instalación (<25 MB)
              └── Onboarding (Modo 100% Local, sin registro forzado)
                    └── Activación (Primer escaneo exitoso o dictado por voz)
                          └── Retención (Presupuesto mensual + notificaciones locales)
                                └── Monetización (Intersticiales en flujo natural + Rinde Más Pro)
```

### Reglas de Conversión y Puntos de Cobro
1. **Registro Básico Siempre Ilimitado:** Registro manual y dictado por voz 100% gratuitos para siempre (diferenciador anti-Rial).
2. **Cuota Gratuita de IA:** 15 a 20 facturas al mes subvencionadas por anuncios intersticiales mostrados *únicamente* tras guardar un gasto.
3. **Paywall Contextual de Rinde Más Pro ($1.99/mes o $19.99/año):**
   * Se dispara cuando el usuario supera las 15-20 facturas del mes, intenta exportar a PDF contable o crea categorías personalizadas.
   * Mensaje claro: *"Escanea todas tus facturas sin límites y sin publicidad"*.
4. **Métrica de Validación Financiera:**
   * Meta de validación inicial: Lograr los primeros $50 USD en 30-60 días con 500-1.000 usuarios activos.
   * Con 1.000 usuarios activos y una conversión del 1% (10 suscriptores Pro a $1.99/mes = $19.90/mes), más los ingresos de intersticiales en transiciones, se cubren holgadamente los costos de tokens de Gemini Flash de toda la base.

---

## Skill de Agente Asociada
* Para la ejecución táctica paso a paso de este plan y el manejo de Google Play Console, consultar la skill [`.agents/skills/growth-first-100-users/SKILL.md`](.agents/skills/growth-first-100-users/SKILL.md).


