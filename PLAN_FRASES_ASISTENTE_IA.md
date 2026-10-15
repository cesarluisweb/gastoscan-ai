# Plan: Frases Predeterminadas en el Asistente IA (Rinde Más)

## 1. Contexto y Objetivo
Añadir a la pantalla del **Asistente IA** (`ChatScreen`) 5 frases predeterminadas que el usuario pueda presionar para enviarlas de forma inmediata como mensaje de texto a la IA, sin necesidad de redactarlas manualmente.

---

## 2. Frases Predeterminadas Implementadas
Cada chip representa una habilidad analítica distinta de la IA sin botones de acción directa para no contaminar datos accidentales al explorar por curiosidad:

1. **"¿Qué gastos pequeños están sumando más de lo que parece?"** (Icono: lupa - `Icons.search_rounded`)
   - Habilidad: Detección de fugas y gastos hormiga.
2. **"¿Qué gastos podría reducir sin afectar lo esencial?"** (Icono: tijeras - `Icons.content_cut_rounded`)
   - Habilidad: Recorte inteligente y optimización de presupuesto.
3. **"¿Qué productos o gastos me han subido de precio?"** (Icono: tendencia - `Icons.trending_up_rounded`)
   - Habilidad: Comparativa de precios e inflación histórica.
4. **"¿En qué días o momentos del mes suelo gastar más?"** (Icono: calendario - `Icons.calendar_month_rounded`)
   - Habilidad: Detección de patrones temporales y estacionalidad.
5. **"¿Qué suelo comprar cada mes que aún no he comprado?"** (Icono: checklist - `Icons.checklist_rounded`)
   - Habilidad: Planificación y compras recurrentes pendientes.

---

## 3. Diseño UI/UX
- **Ubicación:** Barra horizontal deslizante situada justo encima del cuadro de entrada de texto y micrófono.
- **Estilo:** Chips redondeados con fondo limpio (`AppColors.surface`), borde fino (`AppColors.border`), texto legible (`AppColors.textPrimary` - nunca amarillo) e icono alusivo.
- **Interacción:** Al tocar un chip, el mensaje se envía al instante; la vista hace auto-scroll hacia el final y los chips se inhabilitan temporalmente durante el procesamiento para evitar peticiones duplicadas.

---

## 4. Archivos Involucrados
- `lib/ui/screens/chat_screen.dart`: Integración de chips de sugerencia rápida, soporte de envío directo por parámetro en `_sendMessage`, `ScrollController` para desplazamiento automático e inyección de dependencias para tests.
- `test/screens/chat_screen_test.dart`: Suite de pruebas unitarias para validar renderizado de frases, pulsación y envío inmediato.
