# Plan: Frases Predeterminadas en el Asistente IA (Rinde Más)

## 1. Contexto y Objetivo
Añadir a la pantalla del **Asistente IA** (`ChatScreen`) 5 frases predeterminadas que el usuario pueda presionar para enviarlas de forma inmediata como mensaje de texto a la IA, sin necesidad de redactarlas manualmente.

---

## 2. Frases Predeterminadas Propuestas
Alineadas con los datos del contexto financiero (`gastos_mes`, totales, presupuestos y lista de compras):

1. **"¿Cuánto he gastado este mes?"** (Icono: billetera)
   - Consulta el balance y total acumulado del mes en USD y VES.
2. **"¿En qué categoría he gastado más?"** (Icono: gráfico de torta)
   - Identifica la categoría de mayor impacto en los gastos del mes.
3. **"¿Qué tengo en mi lista de compras?"** (Icono: checklist)
   - Revisa rápidamente los artículos pendientes en la lista de compras.
4. **"¿Cómo voy con mi presupuesto?"** (Icono: ahorro / alcancía)
   - Evalúa el consumo actual respecto al límite presupuestario configurado.
5. **"Dame un resumen de mis gastos"** (Icono: analítica)
   - Genera una síntesis ejecutiva del comportamiento de gastos reciente.

---

## 3. Diseño UI/UX
- **Ubicación:** Barra horizontal deslizante situada justo encima del cuadro de entrada de texto y micrófono.
- **Estilo:** Chips redondeados con fondo limpio (`AppColors.surface`), borde fino (`AppColors.border`), texto legible (`AppColors.textPrimary` - nunca amarillo) e icono alusivo.
- **Interacción:** Al tocar un chip, el mensaje se envía al instante; la vista hace auto-scroll hacia el final y los chips se inhabilitan temporalmente durante el procesamiento para evitar peticiones duplicadas.

---

## 4. Archivos Involucrados
- `lib/ui/screens/chat_screen.dart`: Integración de chips de sugerencia rápida, soporte de envío directo por parámetro en `_sendMessage`, `ScrollController` para desplazamiento automático e inyección de dependencias para tests.
- `test/screens/chat_screen_test.dart`: Suite de pruebas unitarias para validar renderizado de frases, pulsación y envío inmediato.
