const functions = require("firebase-functions");
const { defineString } = require("firebase-functions/params");

const geminiApiKey = defineString("GEMINI_API_KEY");

const fallbackModels = [
  "gemini-flash-latest",
  "gemini-3.5-flash",
  "gemini-3.6-flash",
  "gemini-3.7-flash",
  "gemini-3.8-flash"
];

exports.analyzeReceipt = functions
  .runWith({ timeoutSeconds: 180, memory: "512MB" })
  .https.onCall(async (data, context) => {
    // 1. Validar auth
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const imageBase64 = data.imageBase64;
    if (!imageBase64) {
      throw new functions.https.HttpsError("invalid-argument", "Falta la imagen base64.");
    }

    const key = geminiApiKey.value();
    let modelIndex = 0;

    const systemPrompt = `
Analiza la imagen con máxima precisión. Si la imagen contiene MÚLTIPLES facturas, recibos o comprobantes de pago distintos en la misma foto, identifica y extrae cada uno por separado en una lista de facturas. Si contiene solo una factura, devuelve una lista con ese único elemento.

Reglas estrictas para los productos de cada factura:
1. "descripcion": Transcribe el nombre legible, claro y completo del producto. Si el texto en la factura viene abreviado o cortado por la impresora térmica (por ejemplo "TOLLAS" -> "Toallas Húmedas", "ARRZ SUP" -> "Arroz Superior"), interpreta el contexto comercial y coloca un nombre descriptivo, limpio y bien escrito en español. No dejes caracteres truncados o incomprensibles.
2. Decimales: Extrae con exactitud los montos numéricos. Usa SIEMPRE el PUNTO (.) como separador de decimales. Si el precio en la factura usa una coma como decimal (ej. 12,50), DEBES reemplazarla por un punto (12.50), NO la elimines.
3. Moneda Unificada: Todos los precios extraídos (ítems y total_original) DEBEN estar estrictamente en la misma moneda. Si los ítems están detallados en Bolívares (VES), extrae el total_original en Bolívares (ignorando el total Ref en USD) y coloca "moneda": "VES".
4. "categoria": Asigna a cada ítem individual una de las categorías válidas ("Alimentación", "Salud", "Higiene", "Educación", "Hogar", "Servicios", "Transporte", "Otros") según el tipo de producto.
5. "impuesto_iva" y marcadores fiscales: En facturas fiscales venezolanas, los ítems suelen marcarse al final como (E) Exento o (G) Gravado al 16% (o alícuotas reducidas). En cada ítem, extrae "alicuota_fiscal": "E" para exento, o "G" para gravado. En el campo general "impuesto_iva", extrae el monto total del IVA liquidado (suele decir "Total IVA", "IVA 16%", "Impuesto"). Si toda la factura es exenta o no tiene IVA desglosado, coloca 0.00.

Devuelve EXCLUSIVAMENTE un objeto JSON válido con la siguiente estructura, sin texto adicional ni bloques markdown:
{
  "facturas": [
    {
      "comercio": "Nombre del establecimiento o persona receptora",
      "fecha": "YYYY-MM-DD",
      "moneda": "VES" | "USD" | "EUR",
      "total_original": 0.00,
      "tasa_cambio": 0.00,
      "impuesto_iva": 0.00,
      "items": [
        {
          "descripcion": "Nombre claro y completo del producto",
          "cantidad": 1.0,
          "precio_unitario": 0.00,
          "total": 0.00,
          "categoria": "Alimentación" | "Salud" | "Higiene" | "Educación" | "Hogar" | "Servicios" | "Transporte" | "Otros",
          "alicuota_fiscal": "E" | "G" | null
        }
      ]
    }
  ]
}
Si un dato no es legible o no aplica, coloca null. Si es un comprobante de Pago Móvil o transferencia bancaria, coloca en "comercio" el beneficiario y en "items" una sola línea con el concepto.
`;

    const payload = {
      contents: [
        {
          role: "user",
          parts: [
            { inline_data: { mime_type: "image/jpeg", data: imageBase64 } },
            { text: systemPrompt },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: "application/json",
      },
    };

    try {
      let response;
      let responseText = "";
      const retries = 3;

      for (let i = 0; i < retries; i++) {
        const currentModel = fallbackModels[modelIndex];
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${currentModel}:generateContent?key=${key}`;

        try {
          response = await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
            signal: AbortSignal.timeout(25000)
          });

          responseText = await response.text();

          if (response.ok) {
            break; // Éxito
          } else if (response.status === 429 || response.status === 404 || response.status === 503 || response.status >= 500) {
            modelIndex++;
            if (modelIndex < fallbackModels.length) {
              console.warn(`Error ${response.status} con ${currentModel}. Cambiando a ${fallbackModels[modelIndex]}...`);
              i--; // No gastar intento al saltar de modelo
              continue;
            } else {
              console.error(`Error final API Gemini: ${response.status}`, responseText);
              if (response.status === 429) {
                throw new functions.https.HttpsError("resource-exhausted", "Límite de solicitudes de Gemini alcanzado (Error 429). Intenta de nuevo en unos momentos.");
              }
              throw new functions.https.HttpsError("unavailable", "Servidores de Gemini saturados o no disponibles temporalmente (Error 503). Intenta más tarde.");
            }
          } else if (response.status === 402) {
            console.error("Error 402 créditos agotados:", responseText);
            throw new functions.https.HttpsError("resource-exhausted", "Créditos prepagados de Gemini agotados (Error 402). Se requiere recargar saldo en Google AI Studio.");
          } else {
            console.error(`Error final API Gemini: ${response.status}`, responseText);
            throw new functions.https.HttpsError("internal", `Error API Gemini: ${response.status}`);
          }
        } catch (err) {
          if (err instanceof functions.https.HttpsError) throw err;
          
          modelIndex++;
          if (modelIndex < fallbackModels.length) {
            console.warn(`Timeout o falla de red con ${currentModel} (${err.name || err.message}). Cambiando a ${fallbackModels[modelIndex]}...`);
            i--; 
            continue;
          } else {
            console.error(`Error final de red/timeout:`, err);
            throw new functions.https.HttpsError("unavailable", "Tiempo de espera agotado al conectar con los servidores de inteligencia artificial.");
          }
        }
      }

      const parsedData = JSON.parse(responseText);
      const candidates = parsedData.candidates || [];
      if (candidates.length === 0) {
        throw new functions.https.HttpsError("internal", "Respuesta vacía de Gemini.");
      }

      // Registro de métricas de consumo de tokens y costo por escaneo
      const usageMetadata = parsedData.usageMetadata || {};
      const promptTokens = usageMetadata.promptTokenCount || 0;
      const candidatesTokens = usageMetadata.candidatesTokenCount || 0;
      const totalTokens = usageMetadata.totalTokenCount || 0;
      const estimatedCostUsd = ((promptTokens * 0.10) + (candidatesTokens * 0.40)) / 1000000;
      console.log(`[TokenMetrics] analyzeReceipt | Modelo: ${fallbackModels[modelIndex]} | Tokens: ${totalTokens} (Prompt: ${promptTokens}, Salida: ${candidatesTokens}) | Costo est: $${estimatedCostUsd.toFixed(6)} USD`);

      let rawText = candidates[0]?.content?.parts?.[0]?.text || "";
      
      rawText = rawText.replace(/^```json\s*/m, "").replace(/\s*```$/m, "").trim();
      const firstBrace = rawText.indexOf("{");
      const lastBrace = rawText.lastIndexOf("}");
      if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
        rawText = rawText.substring(firstBrace, lastBrace + 1);
      }

      return JSON.parse(rawText);
    } catch (error) {
      console.error(error);
      if (error && error.code) throw error;
      throw new functions.https.HttpsError("internal", "Fallo al procesar la factura.", error.message);
    }
  });


exports.chatWithAnalyst = functions
  .runWith({ timeoutSeconds: 60, memory: "256MB" })
  .https.onCall(async (data, context) => {
    const { messages, contextData } = data;
    if (!messages || !Array.isArray(messages)) {
      throw new functions.https.HttpsError("invalid-argument", "Faltan los mensajes o no es un arreglo.");
    }

    const key = geminiApiKey.value();
    let modelIndex = 0;

    const systemPrompt = `Eres un asistente financiero y de compras experto y amigable para un usuario en Venezuela dentro de la app Rinde Más.
Tu objetivo es analizar los gastos mensuales del usuario, responder sus dudas con base en los datos proporcionados y gestionar su lista de compras.
Da respuestas cortas, directas y prácticas en español venezolano natural.
Evita usar saludos largos o excesos de formalidad, ve directo al grano.

REGLA DE DESAMBIGUACIÓN (ESTRICTA Y OBLIGATORIA):
- NUNCA inventes precios o montos si el usuario no los mencionó explícitamente.
- Si el usuario dice claramente que ya gastó, compró o pagó algo Y menciona montos/precios o un comercio (ej. "gasté 10$ en el mercado", "pagué 200 bolívares de pasaje"), regístralo como gasto con la función "registrar_gasto".
- Si el usuario dice claramente que lo anote en la "lista de compras", "tengo que comprar", "para comprar" o similar, usa las funciones de lista de compras ("agregar_items_lista_compras", etc.).
- Si el usuario NO menciona un monto ni precio y la frase es ambigua (ejemplos: "anota una harina pan", "anota un champú", "agrega café", "pon 2 leches", "guarda champú"): TIENES ESTRICTAMENTE PROHIBIDO LLAMAR A registrar_gasto O INVENTAR UN PRECIO. En este caso NO EJECUTES NINGUNA FUNCIÓN y responde EXACTAMENTE con este texto:
"¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?"

REGLAS PARA LISTA DE COMPRAS:
- Si el usuario pide agregar uno o varios productos a la lista de compras, invoca "agregar_items_lista_compras".
- Si pide cambiar o renombrar un producto existente, invoca "modificar_item_lista_compras".
- Si pide eliminar o quitar productos de la lista, invoca "eliminar_items_lista_compras".
- Si pide marcar productos como comprados o pendientes, invoca "marcar_items_lista_compras".
- Si pregunta qué tiene en su lista de compras, responde directamente listando los productos de su lista actual.

Regla para registrar gastos por voz: Si el usuario te dicta registrar un gasto con precios en múltiples monedas mezcladas (ej. un ítem en dólares y otro en bolívares), CONVIERTE mentalmente todos los precios a una sola moneda unificada (la que predomine o USD) usando una tasa de cambio lógica antes de enviarlos a la función registrar_gasto. La app no soporta múltiples monedas en el mismo ticket.

Aquí están los datos del usuario en formato JSON (gastos del mes y lista de compras actual):
${JSON.stringify(contextData)}
`;

    const geminiMessages = [
      { role: "user", parts: [{ text: systemPrompt }] },
      { role: "model", parts: [{ text: "Entendido, estoy listo para analizar los gastos." }] }
    ];

    for (const msg of messages) {
      geminiMessages.push({
        role: msg.role === "assistant" ? "model" : "user",
        parts: [{ text: msg.text }]
      });
    }

    const payload = {
      contents: geminiMessages,
      tools: [
        {
          functionDeclarations: [
            {
              name: "registrar_gasto",
              description: "Registra un gasto en la app ÚNICAMENTE si el usuario especifica un monto/precio pagado y confirma que es un gasto realizado. PROHIBIDO llamar a esta función si el usuario solo pide anotar productos sin indicar precio.",
              parameters: {
                type: "object",
                properties: {
                  comercio: { type: "string", description: "Nombre del local o 'General' si no se especifica." },
                  fecha: { type: "string", description: "Fecha en formato YYYY-MM-DD. Usa la fecha actual si no dice otra." },
                  total_usd: { type: "number", description: "Monto total estimado en dólares." },
                  categoria: { type: "string", description: "Una de: Alimentación, Salud, Educación, Hogar, Servicios, Transporte, Otros." },
                  items: {
                    type: "array",
                    description: "Lista de productos comprados y sus precios estimados.",
                    items: {
                      type: "object",
                      properties: {
                        descripcion: { type: "string" },
                        cantidad: { type: "number" },
                        precio_unitario: { type: "number" }
                      }
                    }
                  }
                },
                required: ["comercio", "fecha", "total_usd", "categoria", "items"]
              }
            },
            {
              name: "agregar_items_lista_compras",
              description: "Agrega uno o varios productos a la lista de compras del usuario.",
              parameters: {
                type: "object",
                properties: {
                  nombres: {
                    type: "array",
                    description: "Lista de nombres de los productos a agregar a la lista de compras.",
                    items: { type: "string" }
                  }
                },
                required: ["nombres"]
              }
            },
            {
              name: "modificar_item_lista_compras",
              description: "Modifica o renombra un producto en la lista de compras del usuario.",
              parameters: {
                type: "object",
                properties: {
                  nombre_actual: { type: "string", description: "Nombre del producto actual a modificar." },
                  nuevo_nombre: { type: "string", description: "Nuevo nombre para el producto." }
                },
                required: ["nombre_actual", "nuevo_nombre"]
              }
            },
            {
              name: "eliminar_items_lista_compras",
              description: "Elimina uno o varios productos de la lista de compras del usuario.",
              parameters: {
                type: "object",
                properties: {
                  nombres: {
                    type: "array",
                    description: "Lista de nombres de los productos a eliminar.",
                    items: { type: "string" }
                  }
                },
                required: ["nombres"]
              }
            },
            {
              name: "marcar_items_lista_compras",
              description: "Marca productos de la lista de compras como comprados o pendientes.",
              parameters: {
                type: "object",
                properties: {
                  nombres: {
                    type: "array",
                    description: "Lista de nombres de los productos a marcar.",
                    items: { type: "string" }
                  },
                  comprado: {
                    type: "boolean",
                    description: "true si fue comprado, false si está pendiente."
                  }
                },
                required: ["nombres", "comprado"]
              }
            }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.5,
      },
    };

    try {
      let response;
      let responseText = "";

      for (let i = 0; i < fallbackModels.length; i++) {
        const currentModel = fallbackModels[modelIndex];
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${currentModel}:generateContent?key=${key}`;

        try {
          response = await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
            signal: AbortSignal.timeout(20000)
          });

          responseText = await response.text();
          if (response.ok) {
            break;
          } else {
            modelIndex++;
            if (modelIndex < fallbackModels.length) continue;
            console.error("Error respuesta Gemini API:", response.status, responseText);
            throw new functions.https.HttpsError("internal", `Error API Gemini: ${response.status}`);
          }
        } catch (err) {
          if (err instanceof functions.https.HttpsError) throw err;
          modelIndex++;
          if (modelIndex < fallbackModels.length) continue;
          throw new functions.https.HttpsError("unavailable", "Fallo al conectar con Gemini.", err.message);
        }
      }

      const responseData = JSON.parse(responseText);
      const candidates = responseData.candidates || [];
      if (candidates.length === 0) {
        throw new functions.https.HttpsError("internal", "Respuesta vacía de Gemini.");
      }

      // Registro de métricas de consumo de tokens y costo
      const usageMetadata = responseData.usageMetadata || {};
      const promptTokens = usageMetadata.promptTokenCount || 0;
      const candidatesTokens = usageMetadata.candidatesTokenCount || 0;
      const totalTokens = usageMetadata.totalTokenCount || 0;
      const estimatedCostUsd = ((promptTokens * 0.10) + (candidatesTokens * 0.40)) / 1000000;
      console.log(`[TokenMetrics] chatWithAnalyst | Modelo: ${fallbackModels[modelIndex]} | Tokens: ${totalTokens} (Prompt: ${promptTokens}, Salida: ${candidatesTokens}) | Costo est: $${estimatedCostUsd.toFixed(6)} USD`);

      const part = candidates[0]?.content?.parts?.[0];
      
      if (part?.functionCall) {
        return { 
          functionCall: {
            name: part.functionCall.name,
            args: part.functionCall.args
          } 
        };
      }

      return { text: part?.text || "" };
    } catch (error) {
      console.error(error);
      if (error && error.code) throw error;
      throw new functions.https.HttpsError("internal", "Fallo al conectar con Gemini.", error.message);
    }
  });
