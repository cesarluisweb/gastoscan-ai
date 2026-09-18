const functions = require("firebase-functions");
const { defineString } = require("firebase-functions/params");

const geminiApiKey = defineString("GEMINI_API_KEY");

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
    const fallbackModels = ["gemini-3.6-flash", "gemini-3.7-flash", "gemini-3.8-flash"];
    let modelIndex = 0;

    const systemPrompt = `
Analiza la imagen de este recibo o factura comercial con máxima precisión.
Reglas estrictas para los productos:
1. "descripcion": Transcribe el nombre legible, claro y completo del producto. Si el texto en la factura viene abreviado o cortado por la impresora térmica (por ejemplo "TOLLAS" -> "Toallas Húmedas", "ARRZ SUP" -> "Arroz Superior"), interpreta el contexto comercial y coloca un nombre descriptivo, limpio y bien escrito en español. No dejes caracteres truncados o incomprensibles.
2. Cantidades y precios: Extrae con exactitud los montos numéricos (cantidad, precio unitario y total).
3. "categoria": Asigna a cada ítem individual una de las categorías válidas ("Alimentación", "Salud", "Higiene", "Educación", "Hogar", "Servicios", "Transporte", "Otros") según el tipo de producto.

Devuelve EXCLUSIVAMENTE un objeto JSON válido con la siguiente estructura, sin texto adicional ni bloques markdown:
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
      "categoria": "Alimentación" | "Salud" | "Higiene" | "Educación" | "Hogar" | "Servicios" | "Transporte" | "Otros"
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
    let delay = 3500; // 3.5s inicial para respetar límites de tasa de Gemini
    
    for (let i = 0; i < retries; i++) {
      const currentModel = fallbackModels[modelIndex];
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${currentModel}:generateContent?key=${key}`;

      try {
        response = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
          signal: AbortSignal.timeout(15000)
        });

        responseText = await response.text();

        if (response.ok) {
          break; // Exito
        } else if (response.status === 429 || response.status === 404 || response.status >= 500) {
          modelIndex++;
          if (modelIndex < fallbackModels.length) {
            console.warn(`Error ${response.status} con ${currentModel}. Cambiando a ${fallbackModels[modelIndex]}...`);
            i--; // No contar este intento
            continue;
          } else {
            console.error(`Error final API Gemini: ${response.status}`, responseText);
            if (response.status === 429) {
              throw new functions.https.HttpsError("resource-exhausted", "Límite de solicitudes de Gemini alcanzado. Intenta de nuevo en unos momentos.");
            }
            throw new functions.https.HttpsError("unavailable", "Servicio de Gemini no disponible temporalmente. Intenta más tarde.");
          }
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
          throw new functions.https.HttpsError("unavailable", "Falla de conexión o tiempo de espera agotado con los servidores de inteligencia artificial.");
        }
      }
    }


      const parsedData = JSON.parse(responseText);
      const candidates = parsedData.candidates || [];
      if (candidates.length === 0) {
        throw new functions.https.HttpsError("internal", "Respuesta vacía de Gemini.");
      }

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
      if (error && error.code) throw error; throw new functions.https.HttpsError("internal", "Fallo al procesar la factura.", error.message);
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
    const model = "gemini-3.6-flash";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;

    const systemPrompt = `Eres un asistente financiero experto y amigable para un usuario en Venezuela.
Tu objetivo es analizar los gastos mensuales del usuario y responder sus dudas con base en los datos proporcionados.
Da respuestas cortas, directas y prácticas. Si el usuario gasta mucho en algo, házselo saber.
Si no hay suficientes datos para responder una pregunta específica, recomiéndale seguir escaneando facturas.
Evita usar saludos largos o excesos de formalidad, ve directo al punto.
Aquí están los gastos del usuario de este mes en formato JSON:
${JSON.stringify(contextData)}
`;

    // Preparar historial de chat para Gemini
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
              description: "Registra un gasto manual en la aplicación cuando el usuario dicta qué compró.",
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
            }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.5,
      },
    };

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      const responseText = await response.text();
      if (!response.ok) {
        console.error("Error respuesta Gemini API:", response.status, responseText);
        throw new functions.https.HttpsError("internal", `Error API Gemini: ${response.status}`);
      }

      const responseData = JSON.parse(responseText);
      const candidates = responseData.candidates || [];
      if (candidates.length === 0) {
        throw new functions.https.HttpsError("internal", "Respuesta vacía de Gemini.");
      }

      const part = candidates[0]?.content?.parts?.[0];
      
      if (part?.functionCall) {
        // La IA decidió llamar a una herramienta
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
      throw new functions.https.HttpsError("internal", "Fallo al conectar con Gemini.", error.message);
    }
  });

