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

// Rate limiting diario en memoria por UID (50 peticiones/día por usuario en cuota compartida)
const dailyRateLimitMap = new Map();

function isDailyLimitExceeded(uid, limit = 50) {
  const todayKey = new Date().toISOString().slice(0, 10);
  const userKey = `${uid}:${todayKey}`;
  const count = (dailyRateLimitMap.get(userKey) || 0) + 1;
  dailyRateLimitMap.set(userKey, count);

  // Limpieza periódica de días anteriores si el mapa crece
  if (dailyRateLimitMap.size > 5000) {
    for (const key of dailyRateLimitMap.keys()) {
      if (!key.endsWith(todayKey)) {
        dailyRateLimitMap.delete(key);
      }
    }
  }

  return count > limit;
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

// --- Endpoint público de tasas de cambio (/tasas) -------------------------
// Agrega BCV + Yadio + espejo jsDelivr desde la salida de Cloudflare, que no
// depende del ISP del teléfono. Devuelve null en las monedas que no se pudieron
// resolver para que el cliente decida fuente por fuente.
const TASAS_MEMO_TTL_MS = 5 * 60 * 1000;
let tasasMemo = { at: 0, body: null };

async function fetchJson(url, timeoutMs = 6000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: { Accept: "application/json" },
    });
    if (!res.ok) return null;
    return await res.json();
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

function positive(value) {
  const n = typeof value === "number" ? value : parseFloat(value);
  return Number.isFinite(n) && n > 0 ? n : null;
}

function pick(...candidatos) {
  for (const c of candidatos) {
    const n = positive(c);
    if (n !== null) return n;
  }
  return null;
}

async function agregarTasas() {
  const [oficial, euros, paralelo, yadio, usdMirror, eurMirror] = await Promise.all([
    fetchJson("https://ve.dolarapi.com/v1/dolares/oficial"),
    fetchJson("https://ve.dolarapi.com/v1/euros/oficial"),
    fetchJson("https://ve.dolarapi.com/v1/dolares/paralelo"),
    fetchJson("https://api.yadio.io/json"),
    fetchJson("https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json"),
    fetchJson("https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json"),
  ]);

  const yadioUsd = yadio && yadio.USD && yadio.USD.other ? yadio.USD.other : {};

  return {
    usd: pick(
      oficial && oficial.promedio,
      yadioUsd.official && yadioUsd.official.rate,
      usdMirror && usdMirror.usd && usdMirror.usd.ves
    ),
    eur: pick(
      euros && euros.promedio,
      eurMirror && eurMirror.eur && eurMirror.eur.ves
    ),
    usdt: pick(
      yadioUsd.p2p_usdt && yadioUsd.p2p_usdt.rate,
      paralelo && paralelo.promedio
    ),
    fecha: new Date().toISOString(),
  };
}

function jsonTasas(body, origen) {
  return new Response(JSON.stringify({ ...body, origen }), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=300",
    },
  });
}

async function handleTasas() {
  const now = Date.now();
  if (tasasMemo.body && now - tasasMemo.at < TASAS_MEMO_TTL_MS) {
    return jsonTasas(tasasMemo.body, "cache");
  }

  const body = await agregarTasas();
  if (body.usd == null && body.eur == null && body.usdt == null) {
    // 503 (no 200 vacío) para que el cliente caiga a sus fuentes directas.
    return new Response(JSON.stringify({ error: "Sin tasas disponibles." }), {
      status: 503,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  tasasMemo = { at: now, body };
  return jsonTasas(body, "directa");
}

const MAX_RECEIPT_BODY_BYTES = 8 * 1024 * 1024; // 8 MB máx para imagen base64
const MAX_CHAT_BODY_BYTES = 512 * 1024; // 512 KB máx para chat

async function readJsonBodyWithLimit(request, maxBytes) {
  const contentLength = parseInt(request.headers.get("content-length") || "0", 10);
  if (Number.isFinite(contentLength) && contentLength > maxBytes) {
    const err = new Error("El tamaño de la solicitud excede el límite permitido.");
    err.statusCode = 413;
    throw err;
  }
  const rawBody = await request.text();
  if (rawBody.length > maxBytes) {
    const err = new Error("El tamaño de la solicitud excede el límite permitido.");
    err.statusCode = 413;
    throw err;
  }
  return JSON.parse(rawBody);
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    // Tasas de cambio BCV: dato público y SIN autenticación. Va antes de la
    // comprobación de GEMINI_API_KEY y del bloqueo de login, porque la app
    // necesita leer la tasa vigente aunque no haya sesión ni IA configurada.
    if (url.pathname === "/tasas" && request.method === "GET") {
      const clientIp = request.headers.get("CF-Connecting-IP") || request.headers.get("x-forwarded-for") || "anon_ip";
      if (isRateLimited(`tasas:${clientIp}`, 60, 60000)) {
        return new Response(JSON.stringify({ error: "Demasiadas consultas de tasas. Intenta en un minuto." }), {
          status: 429,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
      return handleTasas();
    }

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

    // 2.1 Límite diario de seguridad invisible (50 peticiones/día para cuota compartida)
    if (!isCustomKey && isDailyLimitExceeded(uid, 50)) {
      return new Response(JSON.stringify({
        error: "¡Le sacaste el jugo a Rinde Más hoy! 🚀 Has alcanzado el límite diario de seguridad en nuestros servidores compartidos. Tus consultas se renovarán automáticamente mañana. Si la app te ayuda a rendir tu dinero, puedes apoyarnos en Más > Apoyar el proyecto ☕.",
        statusCode: 429,
        dailyLimitReached: true
      }), {
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
    const data = await readJsonBodyWithLimit(request, MAX_RECEIPT_BODY_BYTES);
    const { imageBase64, ocrText, forceVision, shoppingList } = data;

    if (!imageBase64 && !ocrText) {
      return new Response(JSON.stringify({ error: "Falta la imagen base64 o el texto OCR." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    if (ocrText && typeof ocrText === "string" && ocrText.length > 100000) {
      return new Response(JSON.stringify({ error: "El texto OCR excede el tamaño máximo permitido." }), {
        status: 413,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    if (imageBase64 && typeof imageBase64 === "string" && imageBase64.length > MAX_RECEIPT_BODY_BYTES) {
      return new Response(JSON.stringify({ error: "La imagen excede el tamaño máximo permitido." }), {
        status: 413,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    const isTextMode = Boolean(ocrText && ocrText.trim().length > 0 && !forceVision);
    let modelIndex = 0;

    const systemPrompt = `
Analiza la ${isTextMode ? "información textual extraída de la factura" : "imagen"} con máxima precisión. Si contiene MÚLTIPLES facturas, recibos o comprobantes de pago distintos, identifica y extrae cada uno por separado en una lista de facturas. Si contiene solo una factura, devuelve una lista con ese único elemento.

Reglas estrictas para los productos de cada factura:
1. "descripcion": Transcribe el nombre legible, claro y completo del producto. Si el texto en la factura viene abreviado o cortado por la impresora térmica (por ejemplo "TOLLAS" -> "Toallas Húmedas", "ARRZ SUP" -> "Arroz Superior"), interpreta el contexto comercial y coloca un nombre descriptivo, limpio y bien escrito en español. No dejes caracteres truncados o incomprensibles.
2. Decimales y Céntimos: Extrae con exactitud los montos numéricos usando SIEMPRE el PUNTO (.) como separador decimal. NUNCA devuelvas precios en céntimos enteros sin punto decimal (ej. si la factura fiscal o impresora térmica imprime 1250, 12,50, 1156 o 11,56, DEBES interpretarlo y extraerlo como 12.50 u 11.56, NO como 1250 u 1156). Todo precio debe tener sus decimales correspondientes. Extrae "total_original" leyendo con fidelidad el TOTAL impreso al pie de la factura (no inventes el total sumando ítems a ciegas). Si un ítem se leyó sin punto decimal haciendo que la suma supere al TOTAL impreso, corrige los decimales de ese ítem para que cuadre con el total.
3. Moneda Unificada: Todos los precios extraídos (ítems y total_original) DEBEN estar estrictamente en la misma moneda. Si los ítems están detallados en Bolívares (VES), extrae el total_original en Bolívares (ignorando el total Ref en USD) y coloca "moneda": "VES".
4. "categoria": Asigna a cada ítem individual una de las categorías válidas ("Alimentación", "Salud", "Higiene", "Educación", "Hogar", "Servicios", "Transporte", "Ropa", "Entretenimiento", "Otros") según el tipo de producto.
5. "impuesto_iva" y marcadores fiscales: En facturas fiscales venezolanas, los ítems suelen marcarse al final como (E) Exento o (G) Gravado al 16% (o alícuotas reducidas). En cada ítem, extrae "alicuota_fiscal": "E" para exento, o "G" para gravado. En el campo general "impuesto_iva", extrae el monto total del IVA liquidado (suele decir "Total IVA", "IVA 16%", "Impuesto"). Si toda la factura es exenta o no tiene IVA desglosado, coloca 0.00.

Devuelve EXCLUSIVAMENTE un objeto JSON válido con la siguiente estructura, sin texto adicional ni bloques markdown:
{
  "facturas": [
    {
      "comercio": "Nombre del establecimiento o persona receptora",
      "fecha": "YYYY-MM-DD",
      "moneda": "VES" | "USD" | "EUR" | "USDT",
      "total_original": 0.00,
      "tasa_cambio": 0.00,
      "impuesto_iva": 0.00,
      "metodo_liquidacion": "BS_BCV" | "BS_USDT" | "DIVISA" | null,
      "items": [
        {
          "descripcion": "Nombre claro y completo del producto",
          "cantidad": 1.0,
          "precio_unitario": 0.00,
          "total": 0.00,
          "categoria": "Alimentación" | "Salud" | "Higiene" | "Educación" | "Hogar" | "Servicios" | "Transporte" | "Ropa" | "Entretenimiento" | "Otros",
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
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${currentModel}:generateContent`;
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
    const statusCode = err && err.statusCode === 413 ? 413 : 500;
    return new Response(JSON.stringify({ error: statusCode === 413 ? err.message : "Fallo al procesar la factura.", message: err.message }), {
      status: statusCode,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
}

// Controlador: Chat y Asistente Financiero / Voz
async function handleChatAnalyst(request, geminiKey, isCustomKey = false) {
  try {
    const data = await readJsonBodyWithLimit(request, MAX_CHAT_BODY_BYTES);
    const { messages, contextData, modo } = data;
    const isDictadoGasto = modo === "dictado_gasto";
    const defaultMoneda = (contextData && contextData.moneda_principal) ? contextData.moneda_principal : "USD";

    if (!messages || !Array.isArray(messages)) {
      return new Response(JSON.stringify({ error: "Faltan los mensajes o formato inválido." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    if (messages.length > 50) {
      return new Response(JSON.stringify({ error: "El historial de mensajes excede el límite permitido." }), {
        status: 413,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    let modelIndex = 0;

    let systemPrompt;
    if (isDictadoGasto) {
      systemPrompt = `Eres un extractor experto de gastos estructurados para la app Rinde Más en Venezuela.
Tu ÚNICA tarea es extraer con total fidelidad los datos de las compras o gastos dictados por el usuario y llamar obligatoriamente a la función "registrar_gasto".

REGLAS DE EXTRACCIÓN DE PRODUCTOS (ESTRICTO):
1. Limpieza de descripción: El campo "descripcion" de cada ítem debe contener ÚNICAMENTE el nombre limpio del producto (ejemplo: "Queso", "Harina pan", "Café", "Papas"). Queda estrictamente PROHIBIDO incluir frases como "Compré", "Gasté en", "Pagué por", cantidades ("5 kg"), unidades ("litros") o nombres de comercios ("en New Market") en la descripción.
2. Cantidades y Unidades: El campo "cantidad" debe ser un número decimal. Si el usuario dictó gramos o fracciones coloquiales de peso/volumen, DEBES convertirlos a decimales de kilogramo o litro:
   - "500 gramos" o "medio kilo" -> cantidad: 0.5
   - "250 gramos" o "un cuarto de kilo" -> cantidad: 0.25
   - "750 gramos" o "tres cuartos de kilo" -> cantidad: 0.75
   - "kilo y medio" -> cantidad: 1.5
   - "5 kg" o "5 kilos" -> cantidad: 5.0
   - Si no mencionó cantidad ni peso, usa cantidad: 1.0.
3. Precios y Subtotales:
   - Si el usuario dice el precio total pagado por una fracción o cantidad (ej. "medio kilo de jamón por 4 dólares"), el "precio_unitario" es el precio POR KILO o por unidad: monto / cantidad (4.00 / 0.5 = 8.00). Así, cantidad * precio_unitario da exactamente los 4.00 dólares.
   - Si dice "3 harinas en 4 dólares", el subtotal del renglón es 4 y precio_unitario = 4 / 3 = 1.33.
   - Si el usuario NO mencionó precio o monto para un producto (ej. "Compré 5 kg de queso en New Market"): DEBES colocar precio_unitario = 0 y monto_original = 0 (o total_usd = 0). NUNCA inventes un precio ni asumas la cantidad o el peso como si fuera dinero.
4. Categorización Canónica:
   - Asigna a cada ítem y al gasto general una de las 10 categorías canónicas oficiales: "Alimentación", "Salud", "Higiene", "Educación", "Hogar", "Servicios", "Transporte", "Ropa", "Entretenimiento", "Otros".
   - Por ejemplo: queso, carne, pollo, pan, leche, comida, víveres -> "Alimentación"; medicinas, pastillas -> "Salud"; champú, jabón -> "Higiene"; pasaje, gasolina -> "Transporte".
5. Moneda y Liquidación:
   - Si el usuario menciona explícitamente "bolívares" o "Bs", moneda = "VES".
   - Si menciona "dólares", "$", "USD", moneda = "USD".
   - Si menciona "euros" o "€", moneda = "EUR".
   - Si menciona "USDT", moneda = "USDT".
   - Si NO menciona ninguna moneda, usa por defecto "${defaultMoneda}".
   - Si la moneda es USD o EUR: si pagó a paralelo/USDT/p2p usa metodo_liquidacion = "BS_USDT"; si pagó en efectivo/Zelle/divisa directa usa "DIVISA"; en cualquier otro caso (pago móvil, punto, BCV o sin especificar) usa "BS_BCV".
6. Comercio:
   - Extrae el nombre del establecimiento (ej. "New Market", "Farmatodo"). Si no mencionó comercio, usa "Varios".
7. Múltiples Comercios:
   - Si el dictado incluye compras en comercios distintos (ej. "compré medicinas en Farmatodo y luego comida en Central Madeirense"), desglosa cada comercio independiente en el array "gastos".
`;
    } else {
      systemPrompt = `Eres un asistente financiero y de compras experto y amigable para un usuario en Venezuela dentro de la app Rinde Más.
Tu objetivo es analizar los gastos mensuales del usuario, responder sus dudas con base en los datos proporcionados y gestionar su lista de compras.
Da respuestas cortas, directas y prácticas en español venezolano natural.
Evita usar saludos largos o excesos de formalidad, ve directo al grano.

REGLAS FISCALES Y DE GASTOS HORMIGA (ESTRICTO):
- En Venezuela, el IVA (Impuesto al Valor Agregado del 16%) y otros tributos fiscales son costos obligatorios por ley y están incluidos o agregados forzosamente en las compras comerciales.
- NUNCA consideres el IVA, impuestos o retenciones fiscales como un producto, un gasto hormiga, una fuga de dinero o un gasto prescindible.
- Si el usuario pregunta por gastos pequeños, fugas de dinero o gastos hormiga a recortar, enfócate EXCLUSIVAMENTE en consumos discrecionales (chucherías, snacks, café de la calle, delivery, salidas imprevistas, suscripciones o compras no planificadas). NUNCA sugieras recortar, evitar o controlar el IVA ni impuestos obligatorios.

REGLA DE DESAMBIGUACIÓN (ESTRICTA Y OBLIGATORIA):
- NUNCA inventes precios o montos si el usuario no los mencionó explícitamente.
- Si el usuario dice claramente que ya gastó, compró o pagó algo Y menciona montos/precios o un comercio (ej. "gasté 10$ en el mercado", "pagué 200 bolívares de pasaje", "compré queso en New Market"): regístralo como gasto con la función "registrar_gasto". Si no mencionó precio, pon precio_unitario = 0 y monto_original = 0.
- Si el usuario dice claramente que lo anote en la "lista de compras", "tengo que comprar", "para comprar" o similar, usa las funciones de lista de compras ("agregar_items_lista_compras", etc.).
- Si el usuario NO menciona un monto ni precio ni comercio y la frase es ambigua (ejemplos: "anota una harina pan", "anota un champú", "agrega café", "pon 2 leches", "guarda champú"): TIENES ESTRICTAMENTE PROHIBIDO LLAMAR A registrar_gasto O INVENTAR UN PRECIO. En este caso NO EJECUTES NINGUNA FUNCIÓN y responde EXACTAMENTE con este texto:
"¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?"

REGLAS PARA LISTA DE COMPRAS:
- Si el usuario pide agregar uno o varios productos a la lista de compras, invoca "agregar_items_lista_compras".
- Si pide cambiar o renombrar un producto existente, invoca "modificar_item_lista_compras".
- Si pide eliminar o quitar productos de la lista, invoca "eliminar_items_lista_compras".
- Si pide marcar productos como comprados o pendientes, invoca "marcar_items_lista_compras".
- Si pregunta qué tiene en su lista de compras, responde directamente listando los productos de su lista actual.

Regla para registrar gastos por voz:
- Identifica la moneda en que el usuario realizó la compra: "VES" (si menciona bolívares, bs, o montos en moneda nacional), "USD" (si menciona dólares, $, verdes), "EUR" (si menciona euros, €) o "USDT".
- PRIORIDAD INMUTABLE DEL BOLÍVAR: Si el usuario menciona un monto explícito en Bolívares (ej. "Pagué 4.000 Bs por gasolina; eran unos 20 dólares"), el dato original obligatorio e inmutable es 4.000 VES (moneda = "VES", monto_original = 4000); el monto en USD es solo contexto y NUNCA debe sobreescribir los 4.000 Bs.
- Si no menciona ninguna moneda, usa por defecto "${defaultMoneda}".
- Si la compra es en "USD" (o "EUR"), identifica cómo liquidó o pagó el usuario e incluye "metodo_liquidacion":
  * "BS_BCV": Si pagó en bolívares a tasa oficial BCV, banco central, tasa oficial, pago móvil, tarjeta de débito, biopago, punto de venta, o si menciona un gasto en dólares en Venezuela sin especificar efectivo ni tasa paralela (por defecto "BS_BCV").
  * "BS_USDT": Si cobraron en bolívares calculados a tasa paralelo, USDT, Binance o P2P.
  * "DIVISA": Si pagó directamente en dólares/divisas (efectivo, billetes, Zelle, Wally, Zinli, Binance Pay, suscripción digital).
- Si el usuario dicta directamente en bolívares (ej. "4000 bolívares"), mantén "moneda": "VES".
- En "monto_original" envía el monto numérico exacto en la moneda indicada (ej. si dice "1500 bolívares", monto_original: 1500, moneda: "VES").
- Cantidades y Subtotales: Si el usuario dice "3 harinas en 4 dólares", el total de esa compra es 4 dólares y el precio_unitario es 4 / 3 = 1.33 (el monto mencionado por el usuario es el subtotal del renglón, no el precio unitario). Si dice "medio kilo de jamón en 4$", cantidad = 0.5 y precio_unitario = 8.00 (4 / 0.5).
- Decimales exactos: Usa siempre punto decimal en los montos (ej. 11.56 y nunca 1156). Si el usuario dice "11 con 56" o "11 y medio", interpreta 11.56 o 11.50.
- En "total_usd" envía el equivalente estimado en dólares (si fue en bolívares, puedes dividirlo por la tasa BCV aproximada del contexto o enviarlo igual para que el cliente lo convierta). Si no se mencionó precio, usa 0.
- Si el usuario te dicta registrar un gasto con precios en múltiples monedas mezcladas, unifica todos los precios a una sola moneda antes de llamar a registrar_gasto.
- Si el usuario menciona o dicta compras realizadas en MÚLTIPLES comercios, establecimientos o lugares distintos (ejemplo: "compré en la farmacia tal cosa en tanto y compré en el supermercado tal cosa en tanto"): DEBES desglosar cada compra por separado en el array "gastos". Cada elemento en "gastos" debe contener su propio comercio, fecha, moneda, monto_original, total_usd, metodo_liquidacion (si aplica), categoría adecuada e items.
- Si el usuario menciona múltiples productos dentro del MISMO comercio o compra general, regístralo como un solo gasto con los productos en "items".

Aquí están los datos financieros del usuario en formato JSON (resumen mensual compacto, totales por categoría en 'totales_categoria', productos más comprados en 'top_productos_mes', compras recientes en 'ultimas_compras', presupuesto y lista de compras):
${JSON.stringify(contextData)}

Contexto de Lentes Financieros del usuario:
- 'total_usd_bcv': Total gastado del mes evaluado al lente comercial de tasa oficial BCV.
- 'total_usdt_p2p': Total gastado del mes evaluado al costo de reposición a tasa USDT P2P (Binance).
- 'total_eur_bcv': Total gastado en euros evaluado a tasa oficial BCV.
- 'total_ves': Total acumulado en bolívares.
Nota de análisis cambiario: La diferencia entre total_usd_bcv y total_usdt_p2p en pagos en bolívares refleja cuánto rindió el dinero del usuario pagando a tasa oficial BCV en comparación con la tasa P2P. Explícalo con naturalidad si el usuario consulta sobre comparativas o ahorro entre divisas.
`;
    }

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

    const registrarGastoDeclaration = {
      name: "registrar_gasto",
      description: "Registra uno o varios gastos en la app. Si incluye compras en múltiples lugares o comercios distintos (ej. farmacia y supermercado), desglosa cada compra en el array 'gastos'.",
      parameters: {
        type: "object",
        properties: {
          comercio: { type: "string", description: "Nombre del local o 'Varios' si no se especifica." },
          fecha: { type: "string", description: "Fecha en formato YYYY-MM-DD. Usa la fecha actual si no dice otra." },
          moneda: { type: "string", description: "Moneda de la compra: VES, USD, EUR o USDT. Si no se especificó divisa, usa '" + defaultMoneda + "'." },
          monto_original: { type: "number", description: "Monto total pagado en la moneda original (o 0 si no se mencionó precio)." },
          total_usd: { type: "number", description: "Monto total estimado en dólares (o 0 si no se mencionó precio)." },
          metodo_liquidacion: {
            type: "string",
            enum: ["BS_BCV", "BS_USDT", "DIVISA"],
            description: "Para compras en USD o EUR: 'BS_BCV' si pagó en bolívares a tasa oficial/BCV/pago móvil/punto; 'BS_USDT' si cobraron a tasa paralelo/USDT; 'DIVISA' si pagó en efectivo/Zelle/divisa directa."
          },
          categoria: { type: "string", description: "Una de: Alimentación, Salud, Higiene, Educación, Hogar, Servicios, Transporte, Ropa, Entretenimiento, Otros." },
          items: {
            type: "array",
            description: "Lista de productos comprados y sus precios en la moneda original.",
            items: {
              type: "object",
              properties: {
                descripcion: { type: "string", description: "Nombre limpio del producto (ej. 'Queso', 'Harina pan', 'Café', 'Carne'), sin incluir cantidades, unidades ni verbos como 'compré' o 'gasté'." },
                cantidad: { type: "number", description: "Cantidad numérica. Si se dictaron gramos o fracciones de kilo/litro, conviértelo a decimales de kilogramo/litro (ej. '500 gramos' o 'medio kilo' -> 0.5, '250 gramos' o 'un cuarto' -> 0.25, 'kilo y medio' -> 1.5). Si no se dijo cantidad, usa 1.0." },
                precio_unitario: { type: "number", description: "Precio unitario o precio por kilo/litro si se compró por peso o volumen: monto_pagado / cantidad. Si no se mencionó precio, usa 0." }
              },
              required: ["descripcion", "cantidad"]
            }
          },
          gastos: {
            type: "array",
            description: "Lista de compras o gastos independientes si el usuario dictó compras en múltiples lugares o comercios distintos (ej. farmacia y supermercado). Cada objeto representa una compra completa.",
            items: {
              type: "object",
              properties: {
                comercio: { type: "string", description: "Nombre del establecimiento de esta compra." },
                fecha: { type: "string", description: "Fecha en formato YYYY-MM-DD." },
                moneda: { type: "string", description: "Moneda de esta compra: VES, USD, EUR o USDT." },
                monto_original: { type: "number", description: "Monto total pagado en la moneda de esta compra (o 0 si no se mencionó)." },
                total_usd: { type: "number", description: "Monto total estimado en USD (o 0 si no se mencionó)." },
                metodo_liquidacion: {
                  type: "string",
                  enum: ["BS_BCV", "BS_USDT", "DIVISA"],
                  description: "Método de liquidación si la compra fue en USD o EUR: 'BS_BCV', 'BS_USDT' o 'DIVISA'."
                },
                categoria: { type: "string", description: "Una de: Alimentación, Salud, Higiene, Educación, Hogar, Servicios, Transporte, Ropa, Entretenimiento, Otros." },
                items: {
                  type: "array",
                  description: "Lista de productos comprados en este establecimiento.",
                  items: {
                    type: "object",
                    properties: {
                      descripcion: { type: "string", description: "Nombre limpio del producto sin verbos, cantidades ni unidades." },
                      cantidad: { type: "number", description: "Cantidad numérica en unidades, kg o litros." },
                      precio_unitario: { type: "number", description: "Precio unitario o por kilo/litro (monto_pagado / cantidad). Si no se mencionó, usa 0." }
                    },
                    required: ["descripcion", "cantidad"]
                  }
                }
              },
              required: ["comercio", "fecha", "categoria", "items"]
            }
          }
        },
        required: ["comercio", "fecha", "categoria", "items"]
      }
    };

    const payload = {
      contents: geminiMessages,
      tools: [
        {
          functionDeclarations: isDictadoGasto
            ? [registrarGastoDeclaration]
            : [
                registrarGastoDeclaration,
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
      ...(isDictadoGasto ? {
        toolConfig: {
          functionCallingConfig: {
            mode: "ANY",
            allowedFunctionNames: ["registrar_gasto"]
          }
        }
      } : {}),
      generationConfig: {
        temperature: isDictadoGasto ? 0.1 : 0.5,
      },
    };

    let response;
    let responseText = "";
    let bestErrorStatus = 500;
    let winningModel = FALLBACK_MODELS[0];

    for (let i = 0; i < FALLBACK_MODELS.length; i++) {
      const currentModel = FALLBACK_MODELS[modelIndex];
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${currentModel}:generateContent`;
      const attemptStart = Date.now();

      try {
        response = await fetch(url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": geminiKey
          },
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
    const statusCode = error && error.statusCode === 413 ? 413 : 500;
    return new Response(JSON.stringify({ error: statusCode === 413 ? error.message : "Fallo al conectar con el asistente.", message: error.message }), {
      status: statusCode,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
}
