/**
 * Rinde Más - Cloudflare Worker Gateway para Gemini
 * 
 * Funcionalidades:
 * 1. Autenticación: Valida el Firebase ID Token contra las claves públicas de Google (JWKS).
 * 2. Rate Limiting: Protege contra abusos limitando peticiones por UID de Firebase.
 * 3. Secrets: Inyecta GEMINI_API_KEY de forma segura desde los secretos de Cloudflare.
 * 4. Resiliencia: Fallback automático entre modelos de Gemini ante errores 429 / 503.
 */

const FALLBACK_MODELS = [
  "gemini-3.1-flash-lite",
  "gemini-3.5-flash-lite"
];

const JWKS_URL = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

// Cache de claves públicas en memoria del Worker
let cachedKeys = null;
let keysExpiry = 0;

// Rate limiting simple en memoria (30 peticiones por minuto por usuario)
const rateLimitMap = new Map();

function isRateLimited(uid, limit = 30, windowMs = 60000) {
  const now = Date.now();
  const userData = rateLimitMap.get(uid) || { count: 0, resetTime: now + windowMs };

  if (now > userData.resetTime) {
    userData.count = 1;
    userData.resetTime = now + windowMs;
    rateLimitMap.set(uid, userData);
    return false;
  }

  userData.count++;
  rateLimitMap.set(uid, userData);

  // Limpieza periódica de memoria
  if (rateLimitMap.size > 5000) {
    for (const [key, val] of rateLimitMap.entries()) {
      if (now > val.resetTime) rateLimitMap.delete(key);
    }
  }

  return userData.count > limit;
}

// Obtener y cachear claves públicas de Google
async function getGooglePublicKeys() {
  const now = Date.now();
  if (cachedKeys && now < keysExpiry) {
    return cachedKeys;
  }

  const res = await fetch(JWKS_URL);
  if (!res.ok) {
    throw new Error(`Error al obtener certificados de Google: ${res.status}`);
  }

  // Cachear por el tiempo indicado en Cache-Control o 1 hora por defecto
  const cacheHeader = res.headers.get("cache-control") || "";
  const maxAgeMatch = cacheHeader.match(/max-age=(\d+)/);
  const maxAgeSeconds = maxAgeMatch ? parseInt(maxAgeMatch[1], 10) : 3600;

  const data = await res.json();
  cachedKeys = data.keys;
  keysExpiry = now + (maxAgeSeconds * 1000);
  return cachedKeys;
}

function base64UrlDecode(str) {
  let base64 = str.replace(/-/g, "+").replace(/_/g, "/");
  while (base64.length % 4) base64 += "=";
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// Validar Firebase ID Token usando Web Crypto API
async function verifyFirebaseToken(authHeader, projectId) {
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    throw new Error("Formato de autorización inválido. Debe ser 'Bearer <token>'.");
  }

  const token = authHeader.substring(7).trim();
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("JWT malformado.");
  }

  const header = JSON.parse(new TextDecoder().decode(base64UrlDecode(parts[0])));
  const payload = JSON.parse(new TextDecoder().decode(base64UrlDecode(parts[1])));

  // 1. Validar expiración y emisión
  const nowSec = Math.floor(Date.now() / 1000);
  if (payload.exp && payload.exp < nowSec) {
    throw new Error("Token expirado.");
  }
  if (payload.iat && payload.iat > (nowSec + 300)) {
    throw new Error("Token emitido en el futuro.");
  }

  // 2. Validar Issuer y Audience
  const expectedIss = `https://securetoken.google.com/${projectId}`;
  if (payload.iss !== expectedIss) {
    throw new Error(`Issuer no coincide: ${payload.iss} vs ${expectedIss}`);
  }
  if (payload.aud !== projectId) {
    throw new Error(`Audience no coincide: ${payload.aud} vs ${projectId}`);
  }
  if (!payload.sub || typeof payload.sub !== "string" || payload.sub.length === 0) {
    throw new Error("Subject (UID) inválido.");
  }

  // 3. Validar firma criptográfica con Google JWKS
  const keys = await getGooglePublicKeys();
  const jwk = keys.find(k => k.kid === header.kid);
  if (!jwk) {
    throw new Error(`Clave pública no encontrada para kid: ${header.kid}`);
  }

  const cryptoKey = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );

  const dataToVerify = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const signature = base64UrlDecode(parts[2]);

  const isValid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    signature,
    dataToVerify
  );

  if (!isValid) {
    throw new Error("Firma de token inválida.");
  }

  return payload;
}

// Configuración de cabeceras CORS
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, x-custom-gemini-key",
  "Access-Control-Expose-Headers": "x-gemini-model, x-gemini-tokens, x-receipt-mode, x-receipt-image-kb",
};

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const projectId = env.FIREBASE_PROJECT_ID || "gastoscan-ai";
    const customKeyHeader = request.headers.get("x-custom-gemini-key");
    const isCustomKey = Boolean(customKeyHeader && customKeyHeader.trim().length > 10);
    const rawKey = isCustomKey ? customKeyHeader : env.GEMINI_API_KEY;
    const geminiKey = (rawKey || "").trim().replace(/[\r\n\t ]+/g, "");

    if (!geminiKey) {
      return new Response(JSON.stringify({ error: "GEMINI_API_KEY no configurada en los secretos de Cloudflare." }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // Endpoint de salud básico
    if (url.pathname === "/health" && request.method === "GET") {
      return new Response(JSON.stringify({
        status: "ok",
        models: FALLBACK_MODELS,
        timestamp: new Date().toISOString()
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // 1. Verificación de Autenticación
    let userPayload;
    try {
      const authHeader = request.headers.get("Authorization");
      userPayload = await verifyFirebaseToken(authHeader, projectId);
    } catch (authErr) {
      return new Response(JSON.stringify({ error: `No autenticado: ${authErr.message}` }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // 2. Rate Limiting por UID (si usa clave propia, límite ampliado a 60 rpm para prevención DoS)
    const uid = userPayload.sub;
    const rateLimitCap = isCustomKey ? 60 : 30;
    if (isRateLimited(uid, rateLimitCap)) {
      return new Response(JSON.stringify({ error: "Límite de solicitudes alcanzado. Espera un momento." }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // 3. Enrutamiento de Endpoints
    if (url.pathname === "/analyze-receipt" && request.method === "POST") {
      return handleAnalyzeReceipt(request, geminiKey, isCustomKey);
    } else if (url.pathname === "/chat-analyst" && request.method === "POST") {
      return handleChatAnalyst(request, geminiKey, isCustomKey);
    }

    return new Response(JSON.stringify({ error: "Endpoint no encontrado" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
};

// Controlador: Análisis de Facturas (OCR / Visión)
async function handleAnalyzeReceipt(request, geminiKey, isCustomKey = false) {
  try {
    const data = await request.json();
    const { imageBase64, ocrText, forceVision, shoppingList } = data;

    if (!imageBase64 && !ocrText) {
      return new Response(JSON.stringify({ error: "Falta la imagen base64 o el texto OCR." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    const isTextMode = Boolean(ocrText && ocrText.trim().length > 0 && !forceVision);
    let modelIndex = 0;

    const systemPrompt = `
Analiza la ${isTextMode ? "información textual extraída de la factura" : "imagen"} con máxima precisión. Si contiene MÚLTIPLES facturas, recibos o comprobantes de pago distintos, identifica y extrae cada uno por separado en una lista de facturas. Si contiene solo una factura, devuelve una lista con ese único elemento.

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

    const userParts = isTextMode
      ? [{ text: `${systemPrompt}\n\n=== TEXTO EXTRAÍDO DE LA FACTURA POR OCR LOCAL ===\n${ocrText}` }]
      : [
          { inline_data: { mime_type: "image/jpeg", data: imageBase64 } },
          { text: systemPrompt },
        ];

    const payload = {
      contents: [{ role: "user", parts: userParts }],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: "application/json",
      },
    };

    let response;
    let responseText = "";
    let bestErrorStatus = 500;
    let bestRetryAfter = null;
    let winningModel = FALLBACK_MODELS[0];

    for (let i = 0; i < FALLBACK_MODELS.length; i++) {
      const currentModel = FALLBACK_MODELS[modelIndex];
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${currentModel}:generateContent?key=${geminiKey}`;
      const attemptStart = Date.now();

      try {
        response = await fetch(url, {
          method: "POST",
          headers: { 
            "Content-Type": "application/json",
            "x-goog-api-key": geminiKey
          },
          body: JSON.stringify(payload),
          signal: AbortSignal.timeout(25000)
        });

        const latencyMs = Date.now() - attemptStart;
        responseText = await response.text();
        
        // Priorizar el error más informativo (429 tiene prioridad sobre 503, ignorando 404/410 de modelos retirados)
        if (response.status === 429) {
          bestErrorStatus = 429;
          bestRetryAfter = response.headers.get("Retry-After") || bestRetryAfter;
        } else if (response.status === 503 && bestErrorStatus !== 429) {
          bestErrorStatus = 503;
        } else if (bestErrorStatus === 500 && response.status !== 404 && response.status !== 410) {
          bestErrorStatus = response.status;
        }

        console.log(JSON.stringify({
          event: "gemini_receipt_attempt",
          model: currentModel,
          status: response.status,
          latencyMs,
          isTextMode,
          imageSizeChars: imageBase64 ? imageBase64.length : 0
        }));

        if (response.ok) {
          winningModel = currentModel;
          break;
        }

        if (isCustomKey && (response.status === 400 || response.status === 403)) {
          return new Response(JSON.stringify({
            error: "Tu API Key de Gemini personalizada tiene un error o no tiene permisos/cuota válida en Google AI Studio.",
            statusCode: response.status,
            isCustomKey: true
          }), {
            status: response.status,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
          });
        }

        if (response.status === 429 || response.status >= 500) {
          const delayMs = bestRetryAfter
            ? Math.min(parseInt(bestRetryAfter, 10) * 1000, 3000)
            : (400 + Math.floor(Math.random() * 400));
          await new Promise((resolve) => setTimeout(resolve, delayMs));
        }

        modelIndex++;
        if (modelIndex < FALLBACK_MODELS.length) {
          continue;
        } else {
          // Si fallaron todos, retornar el "mejor" error sin revelar detalles técnicos de los fallbacks fallidos
          let userFriendlyError = "Nuestros servidores están muy concurridos procesando facturas. Por favor, espera un momento y reintenta.";
          if (bestErrorStatus === 429) {
            userFriendlyError = isCustomKey
              ? "Tu API Key de Gemini personalizada alcanzó su límite de cuota (Rate Limit 429)."
              : "Límite de solicitudes procesadas. El servidor está pausando por seguridad. Reintenta en breves segundos.";
          }

          const httpStatusToReturn = bestErrorStatus === 429 ? 429 : 503;
          return new Response(JSON.stringify({
            error: userFriendlyError,
            statusCode: httpStatusToReturn,
            retryAfter: bestRetryAfter,
            isCustomKey: isCustomKey,
            details: "Todos los modelos de respaldo fallaron."
          }), {
            status: httpStatusToReturn,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
          });
        }
      } catch (netErr) {
        const latencyMs = Date.now() - attemptStart;
        console.log(JSON.stringify({
          event: "gemini_receipt_timeout_or_network",
          model: currentModel,
          latencyMs,
          error: netErr.message
        }));

        modelIndex++;
        if (modelIndex < FALLBACK_MODELS.length) {
          continue;
        }
        return new Response(JSON.stringify({
          error: "Tiempo de espera agotado al conectar con Gemini.",
          statusCode: 504
        }), {
          status: 504,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
    }

    const parsedData = JSON.parse(responseText);
    const candidates = parsedData.candidates || [];
    if (candidates.length === 0) {
      return new Response(JSON.stringify({ error: "Respuesta vacía de Gemini." }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    let rawText = candidates[0]?.content?.parts?.[0]?.text || "";
    rawText = rawText.replace(/^```json\s*/m, "").replace(/\s*```$/m, "").trim();
    const firstBrace = rawText.indexOf("{");
    const lastBrace = rawText.lastIndexOf("}");
    if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
      rawText = rawText.substring(firstBrace, lastBrace + 1);
    }

    const resultJson = JSON.parse(rawText);
    resultJson.modo_procesamiento = isTextMode ? "texto" : "vision";

    const usage = parsedData.usageMetadata || {};
    const totalTokens = usage.totalTokenCount || 0;

    const imageKb = imageBase64 ? Math.round((imageBase64.length * 0.75) / 1024) : 0;
    const textChars = ocrText ? ocrText.length : 0;
    const modeLabel = isTextMode ? `TEXTO_OCR (${textChars} caracteres)` : `VISION_MULTIMODAL (${imageKb} KB)`;

    console.log(`[RECEIPT] Factura procesada con éxito | Modo: ${modeLabel} | Modelo: ${winningModel} | Tokens: ${totalTokens}`);

    console.log(JSON.stringify({
      event: "gemini_receipt_success",
      model: winningModel,
      modo: isTextMode ? "texto" : "vision",
      imageSizeKB: imageKb,
      textLengthChars: textChars,
      totalTokens,
      promptTokens: usage.promptTokenCount || 0,
      candidatesTokens: usage.candidatesTokenCount || 0
    }));

    return new Response(JSON.stringify(resultJson), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
        "x-gemini-model": winningModel,
        "x-gemini-tokens": String(totalTokens),
        "x-receipt-mode": isTextMode ? "text" : "vision",
        "x-receipt-image-kb": String(imageKb)
      }
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: "Fallo al procesar la factura.", message: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
}

// Controlador: Chat y Asistente Financiero / Voz
async function handleChatAnalyst(request, geminiKey, isCustomKey = false) {
  try {
    const data = await request.json();
    const { messages, contextData } = data;

    if (!messages || !Array.isArray(messages)) {
      return new Response(JSON.stringify({ error: "Faltan los mensajes o formato inválido." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

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

    let response;
    let responseText = "";
    let bestErrorStatus = 500;
    let winningModel = FALLBACK_MODELS[0];

    for (let i = 0; i < FALLBACK_MODELS.length; i++) {
      const currentModel = FALLBACK_MODELS[modelIndex];
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${currentModel}:generateContent?key=${geminiKey}`;
      const attemptStart = Date.now();

      try {
        response = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
          signal: AbortSignal.timeout(20000)
        });

        const latencyMs = Date.now() - attemptStart;
        responseText = await response.text();

        if (response.status === 429) {
          bestErrorStatus = 429;
        } else if (response.status === 503 && bestErrorStatus !== 429) {
          bestErrorStatus = 503;
        } else if (bestErrorStatus === 500 && response.status !== 404 && response.status !== 410) {
          bestErrorStatus = response.status;
        }

        console.log(JSON.stringify({
          event: "gemini_chat_attempt",
          model: currentModel,
          status: response.status,
          latencyMs
        }));

        if (response.ok) {
          winningModel = currentModel;
          break;
        } else {
          if (isCustomKey && (response.status === 400 || response.status === 403)) {
            return new Response(JSON.stringify({
              error: "Tu API Key de Gemini personalizada tiene un error o no tiene permisos/cuota válida en Google AI Studio.",
              statusCode: response.status,
              isCustomKey: true
            }), {
              status: response.status,
              headers: { ...corsHeaders, "Content-Type": "application/json" }
            });
          }

          if (response.status === 429 || response.status >= 500) {
            const delayMs = 400 + Math.floor(Math.random() * 400);
            await new Promise((resolve) => setTimeout(resolve, delayMs));
          }
          modelIndex++;
          if (modelIndex < FALLBACK_MODELS.length) continue;
          
          let userFriendlyError = "Nuestros servidores están muy concurridos procesando información. Por favor, espera un momento y reintenta.";
          if (bestErrorStatus === 429) {
             userFriendlyError = isCustomKey
               ? "Tu API Key de Gemini personalizada alcanzó su límite de cuota (Rate Limit 429)."
               : "Límite de solicitudes procesadas. El servidor está pausando por seguridad. Reintenta en breves segundos.";
          }
          
          const httpStatusToReturn = bestErrorStatus === 429 ? 429 : 503;
          return new Response(JSON.stringify({
            error: userFriendlyError,
            statusCode: httpStatusToReturn,
            isCustomKey: isCustomKey,
            details: "Todos los modelos de respaldo fallaron."
          }), {
            status: httpStatusToReturn,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
          });
        }
      } catch (err) {
        const latencyMs = Date.now() - attemptStart;
        console.log(JSON.stringify({
          event: "gemini_chat_timeout_or_network",
          model: currentModel,
          latencyMs,
          error: err.message
        }));
        modelIndex++;
        if (modelIndex < FALLBACK_MODELS.length) continue;
        return new Response(JSON.stringify({
          error: "Fallo de conexión o tiempo agotado con Gemini.",
          statusCode: 504
        }), {
          status: 504,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
    }

    const responseData = JSON.parse(responseText);
    const candidates = responseData.candidates || [];
    if (candidates.length === 0) {
      return new Response(JSON.stringify({ error: "Respuesta vacía de Gemini." }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    const usage = responseData.usageMetadata || {};
    const totalTokens = usage.totalTokenCount || 0;

    console.log(JSON.stringify({
      event: "gemini_chat_success",
      model: winningModel,
      totalTokens,
      promptTokens: usage.promptTokenCount || 0,
      candidatesTokens: usage.candidatesTokenCount || 0
    }));

    const responseHeaders = {
      ...corsHeaders,
      "Content-Type": "application/json",
      "x-gemini-model": winningModel,
      "x-gemini-tokens": String(totalTokens)
    };

    const part = candidates[0]?.content?.parts?.[0];
    if (part?.functionCall) {
      return new Response(JSON.stringify({
        functionCall: {
          name: part.functionCall.name,
          args: part.functionCall.args
        }
      }), {
        status: 200,
        headers: responseHeaders
      });
    }

    return new Response(JSON.stringify({ text: part?.text || "" }), {
      status: 200,
      headers: responseHeaders
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: "Fallo al conectar con el asistente.", message: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
}
