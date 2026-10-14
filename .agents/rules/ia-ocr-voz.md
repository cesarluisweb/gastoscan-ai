---
trigger: model_decision
description: "Consultar al modificar extracción OCR con Gemini, prompts de IA, reconocimiento por voz, desambiguación de intenciones o la cola de escaneo."
---

# Inteligencia Artificial: OCR, Asistente y Reconocimiento de Voz

## 1. Extracción de Facturas con IA (Gemini OCR)
- **Prompt de Manejo de Decimales:** En prompts de extracción OCR, NUNCA instruir "no usar comas" (la IA tiende a eliminarlas inflando los montos). Ordenar explícitamente:
  > *"Si el precio usa coma (ej. 12,50), reemplázala por un punto (12.50)."*
- **Moneda Unificada en Facturas Mixtas:** Para facturas venezolanas con ítems expresados en Bolívares (VES) y total de referencia en USD ("Ref"), la IA DEBE extraer todos los montos en la moneda de los ítems (VES) para prevenir discrepancias en balances.
- **Pipeline Híbrido de Percepción (Ahorro de Tokens):**
  1. *Fase 1 (OCR Local):* Toda captura ejecuta primero Google ML Kit en el teléfono sin consumo de red ni costes de API.
  2. *Fase 2 (Envío Solo Texto):* Si el texto extraído posee validación semántica suficiente (score >= 6 en montos, fechas y términos fiscales), se envía exclusivamente el texto a Gemini (`analyzeReceiptText`), reduciendo el consumo de tokens en un 70-80%.
  3. *Fase 3 (Fallback a Visión):* Si el texto es borroso o insuficiente, se activa el modo multimodal enviando la imagen comprimida a 1200x1600 px, calidad 82% JPEG.

## 2. Flujo de Cola y Gestión de Archivos
- **Revisión Continua en Lote ("Guardar y siguiente"):** Al procesar múltiples facturas listas en cola, la pantalla debe ofrecer avance directo mediante `Navigator.pushReplacement`. Los modales de vinculación o fricción deben posponerse hasta completar la última factura del lote o pulsar "Guardar y salir".
- **Borrado Seguro de Imágenes Temporales:** Cuando múltiples registros provengan de una misma fotografía física, queda prohibido invocar `ImageService.deleteTempFile` sin antes verificar que no existan otros registros pendientes en `scan_queue` o en SQLite que dependan de dicho archivo.

## 3. Asistente Financiero y Desambiguación de Intenciones
- **Desambiguación Obligatoria (Gasto vs. Lista de Compras):** Si el usuario solicita anotar productos sin monto (ej. *"anota una harina pan"*), el asistente NUNCA debe asumir la intención. Debe preguntar textualmente:
  > *"¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?"*
- **Doble Capa de Protección en Código:** En `chat_screen.dart`, cualquier ejecución de la herramienta `registrar_gasto` con monto cero o sin números en el mensaje del usuario debe ser interceptada localmente para formular la pregunta antes de guardar.
- **Cotejo Universal con Lista de Compras:** Todo gasto registrado en la app (vía formulario manual, escáner, voz o chat) DEBE contrastar sus productos contra los pendientes en `getPendingShoppingItems()`, marcando automáticamente como comprados los ítems coincidentes.

## 4. Entrada por Voz y Ciclo de Micrófono
- **Buffer Acumulativo de Reconocimiento:** Dado que `SpeechToText.listen` reinicia su búfer de palabras, la interfaz debe acumular el texto previo (`previousText + val.recognizedWords`), impidiendo pérdidas de información al pausar o retomar.
- **Tolerancia y Duración:** Configurar siempre `pauseFor: Duration(seconds: 10)` y `listenFor: Duration(seconds: 60)`.
- **Detención Automática y Silenciosa:** Si el usuario interactúa manualmente con la pantalla (toca un campo de texto, hace scroll, pulsa un botón de navegación o la app pasa a segundo plano `didChangeAppLifecycleState`), el micrófono DEBE detenerse inmediatamente de forma silenciosa, preservando intacto el texto reconocido hasta el momento.
- **Arquitectura de Dictado Multigasto:**
  - *Un solo comercio:* No encolar en SQLite (`queueItemId: null`); navegar directamente a `ReviewExpenseScreen`.
  - *Dos o más comercios distintos en la misma frase:* Encolar todos los registros en `ScanQueueProvider` en estado `ready` con `image_path: ''` y abrir el primero pasando su `queueItemId` para habilitar el flujo continuo secuencial.
- **Respeto de Divisa Dictada:** Respetar estrictamente la moneda indicada por el usuario (VES, USD, EUR, USDT), prohibiéndose forzar USD por defecto si se especificó otra moneda.
