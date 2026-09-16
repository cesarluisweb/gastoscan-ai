const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineString } = require("firebase-functions/params");

const geminiApiKey = defineString("GEMINI_API_KEY");

exports.analyzeReceipt = onCall(
  { region: "us-central1", maxInstances: 10 },
  async (request) => {
    // 1. Validar auth
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const imageBase64 = request.data.imageBase64;
    if (!imageBase64) {
      throw new HttpsError("invalid-argument", "Falta la imagen base64.");
    }

    const key = geminiApiKey.value();
    const model = "gemini-2.5-flash";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;

    const systemPrompt = `
Analiza la imagen de este recibo o factura comercial. Extrae con precisión quirúrgica todos los datos legibles. 
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
      "descripcion": "Nombre del producto o servicio",
      "cantidad": 1.0,
      "precio_unitario": 0.00,
      "total": 0.00,
      "categoria": "Alimentación" | "Salud" | "Higiene" | "Educación" | "Hogar" | "Servicios" | "Transporte" | "Otros"
    }
  ]
}
Para cada ítem, identifica la "categoria" correcta basándote en el nombre del producto (por ejemplo, si el producto es arroz o comida, asigna "Alimentación"). 
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
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      const responseText = await response.text();

      if (!response.ok) {
        throw new HttpsError("internal", `Error API Gemini: ${response.status}`);
      }

      const data = JSON.parse(responseText);
      const candidates = data.candidates || [];
      if (candidates.length === 0) {
        throw new HttpsError("internal", "Respuesta vacía de Gemini.");
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
      throw new HttpsError("internal", "Fallo al procesar la factura.", error.message);
    }
  }
);
