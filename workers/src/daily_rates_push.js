/**
 * Envío programado (lunes a viernes, 8:30 AM VET / 12:30 UTC) de la tasa de cambio
 * diaria vía Firebase Cloud Messaging (HTTP v1) al tema `tasa_diaria`.
 *
 * Usa Web Crypto nativo (`crypto.subtle`) para firmar el JWT OAuth2 de la cuenta de
 * servicio de Google sin dependencias externas ni plan pago de Firebase.
 */

export const DAILY_RATES_TOPIC = "tasa_diaria";
export const DAILY_RATES_CHANNEL_ID = "daily_rates";
export const DAILY_RATES_PAYLOAD = "daily_rates";
export const DAILY_RATES_TTL_SECONDS = 28800; // 8 horas: expira si el teléfono pasó el día sin red
export const DAILY_RATES_DEDUPE_SCOPE = "push:daily_rates";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const GOOGLE_TOKEN_URI = "https://oauth2.googleapis.com/token";
const VET_OFFSET_MS = 4 * 60 * 60 * 1000;

const DIAS_CORTO = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"];
const MESES_CORTO = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];

export function isValidRate(value) {
  return typeof value === "number" && Number.isFinite(value) && value > 0 && value < 1e9;
}

/**
 * Formatea un monto de tasa en estilo venezolano: `Bs. 245,30` o `Bs. 1.245,50`.
 */
export function formatBsRate(value) {
  if (!isValidRate(value)) return null;
  const fixed = value.toFixed(2);
  const [intPart, decPart] = fixed.split(".");
  const withThousands = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  return `Bs. ${withThousands},${decPart}`;
}

/**
 * Retorna la fecha YYYY-MM-DD en hora oficial de Venezuela (UTC-4).
 */
export function vetDayIso(date = new Date()) {
  return new Date(date.getTime() - VET_OFFSET_MS).toISOString().slice(0, 10);
}

/**
 * Retorna fecha corta legible en hora VE (ej. "Mar 24 Nov").
 */
export function formatVetShortDate(date = new Date()) {
  const vet = new Date(date.getTime() - VET_OFFSET_MS);
  const dia = DIAS_CORTO[vet.getUTCDay()];
  const num = vet.getUTCDate();
  const mes = MESES_CORTO[vet.getUTCMonth()];
  return `${dia} ${num} ${mes}`;
}

/**
 * Construye el payload completo para FCM HTTP v1 respetando la terminología oficial
 * (`USD BCV`, `EUR BCV`, `USDT P2P`). Retorna `null` si no hay ninguna tasa válida.
 */
export function buildDailyRatesMessage(rates, { now = new Date(), topic = DAILY_RATES_TOPIC } = {}) {
  if (!rates || typeof rates !== "object") return null;

  const segments = [];
  const data = {
    payload: DAILY_RATES_PAYLOAD,
    type: DAILY_RATES_PAYLOAD,
    channel_id: DAILY_RATES_CHANNEL_ID,
    day: vetDayIso(now),
  };

  const usdText = formatBsRate(rates.usd);
  if (usdText) {
    segments.push(`USD BCV: ${usdText}`);
    data.usd = rates.usd.toFixed(2);
  }

  const eurText = formatBsRate(rates.eur);
  if (eurText) {
    segments.push(`EUR BCV: ${eurText}`);
    data.eur = rates.eur.toFixed(2);
  }

  const usdtText = formatBsRate(rates.usdt);
  if (usdtText) {
    segments.push(`USDT P2P: ${usdtText}`);
    data.usdt = rates.usdt.toFixed(2);
  }

  if (segments.length === 0) {
    return null;
  }

  const title = `Tasa de hoy · ${formatVetShortDate(now)}`;
  const body = `${segments.join(" · ")}. Toca para calcular.`;
  const apnsExpiration = String(Math.floor(now.getTime() / 1000) + DAILY_RATES_TTL_SECONDS);

  return {
    message: {
      topic,
      notification: {
        title,
        body,
      },
      data,
      android: {
        priority: "NORMAL",
        ttl: `${DAILY_RATES_TTL_SECONDS}s`,
        collapse_key: DAILY_RATES_CHANNEL_ID,
        notification: {
          channel_id: DAILY_RATES_CHANNEL_ID,
          tag: DAILY_RATES_CHANNEL_ID,
        },
      },
      apns: {
        headers: {
          "apns-expiration": apnsExpiration,
          "apns-collapse-id": DAILY_RATES_CHANNEL_ID,
        },
      },
    },
  };
}

export function base64UrlEncode(input) {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function pemToDerBytes(pem) {
  const normalized = String(pem).replace(/\\n/g, "\n");
  const base64 = normalized
    .replace(/-----BEGIN [A-Z ]+-----/g, "")
    .replace(/-----END [A-Z ]+-----/g, "")
    .replace(/\s+/g, "");

  if (!base64) {
    throw new Error("Clave privada PEM vacía o inválida.");
  }

  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export function parseServiceAccount(rawSecret) {
  if (typeof rawSecret !== "string" || rawSecret.trim().length === 0) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON no configurado.");
  }

  let parsed;
  try {
    parsed = JSON.parse(rawSecret);
  } catch (_) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON no es un JSON válido.");
  }

  const clientEmail = typeof parsed.client_email === "string" ? parsed.client_email.trim() : "";
  const privateKey = typeof parsed.private_key === "string" ? parsed.private_key.replace(/\\n/g, "\n").trim() : "";
  const projectId = typeof parsed.project_id === "string" ? parsed.project_id.trim() : "";
  const tokenUri = typeof parsed.token_uri === "string" && parsed.token_uri.trim().length > 0
    ? parsed.token_uri.trim()
    : GOOGLE_TOKEN_URI;

  if (!clientEmail || !privateKey || !privateKey.includes("PRIVATE KEY")) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON incompleto (falta client_email o private_key).");
  }

  return { clientEmail, privateKey, projectId, tokenUri };
}

export async function signServiceAccountJwt({
  clientEmail,
  privateKey,
  tokenUri = GOOGLE_TOKEN_URI,
  now = new Date(),
}) {
  const nowSec = Math.floor(now.getTime() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64UrlEncode(JSON.stringify({
    iss: clientEmail,
    scope: FCM_SCOPE,
    aud: tokenUri,
    iat: nowSec,
    exp: nowSec + 3600,
  }));

  const signingInput = `${header}.${claims}`;
  const derBytes = pemToDerBytes(privateKey);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    derBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;
}

export async function fetchGoogleAccessToken(
  serviceAccount,
  { fetchImpl = fetch, now = new Date(), timeoutMs = 10000 } = {}
) {
  const tokenUri = serviceAccount.tokenUri || GOOGLE_TOKEN_URI;
  const assertion = await signServiceAccountJwt({
    clientEmail: serviceAccount.clientEmail,
    privateKey: serviceAccount.privateKey,
    tokenUri,
    now,
  });

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const body = new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }).toString();

    const response = await fetchImpl(tokenUri, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
      signal: controller.signal,
    });

    const text = await response.text();
    if (!response.ok) {
      throw new Error(`OAuth2 token error (${response.status}): ${text.slice(0, 200)}`);
    }

    const json = JSON.parse(text);
    if (!json || typeof json.access_token !== "string" || !json.access_token) {
      throw new Error("Respuesta OAuth2 sin access_token.");
    }
    return json.access_token;
  } finally {
    clearTimeout(timer);
  }
}

export async function wasDailyRatesPushSent(db, day) {
  if (!db || typeof db.prepare !== "function") return false;
  try {
    const row = await db
      .prepare("SELECT count FROM usage WHERE day = ? AND scope = ?")
      .bind(day, DAILY_RATES_DEDUPE_SCOPE)
      .first();
    const count = row ? (row.count ?? row.COUNT ?? 0) : 0;
    return count > 0;
  } catch (err) {
    console.warn(JSON.stringify({
      event: "daily_rates_dedupe_read_error",
      day,
      error: String(err && err.message ? err.message : err),
    }));
    return false;
  }
}

export async function markDailyRatesPushSent(db, day) {
  if (!db || typeof db.prepare !== "function") return;
  try {
    await db
      .prepare(
        "INSERT INTO usage (day, scope, count) VALUES (?, ?, 1) ON CONFLICT(day, scope) DO UPDATE SET count = count + 1 RETURNING count"
      )
      .bind(day, DAILY_RATES_DEDUPE_SCOPE)
      .first();
  } catch (err) {
    console.warn(JSON.stringify({
      event: "daily_rates_dedupe_write_error",
      day,
      error: String(err && err.message ? err.message : err),
    }));
  }
}

/**
 * Ejecuta el ciclo completo del envío diario de tasa de cambio por FCM HTTP v1.
 */
export async function sendDailyRatesPush(
  env,
  {
    getRates,
    fetchImpl = fetch,
    now = new Date(),
    topic = DAILY_RATES_TOPIC,
    force = false,
    timeoutMs = 10000,
  } = {}
) {
  const day = vetDayIso(now);

  if (!env || !env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    console.warn(JSON.stringify({
      event: "daily_rates_push_skipped",
      reason: "missing_service_account_secret",
      day,
    }));
    return { sent: false, skipped: true, reason: "missing_service_account_secret", day };
  }

  let serviceAccount;
  try {
    serviceAccount = parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  } catch (err) {
    console.error(JSON.stringify({
      event: "daily_rates_push_error",
      reason: "invalid_service_account",
      day,
      error: String(err && err.message ? err.message : err),
    }));
    return { sent: false, skipped: false, reason: "invalid_service_account", day };
  }

  if (!force && await wasDailyRatesPushSent(env.DB, day)) {
    console.log(JSON.stringify({
      event: "daily_rates_push_skipped",
      reason: "already_sent",
      day,
    }));
    return { sent: false, skipped: true, reason: "already_sent", day };
  }

  if (typeof getRates !== "function") {
    throw new Error("sendDailyRatesPush requiere getRates.");
  }

  const rates = await getRates();
  const payload = buildDailyRatesMessage(rates, { now, topic });
  if (!payload) {
    console.warn(JSON.stringify({
      event: "daily_rates_push_skipped",
      reason: "no_rates_available",
      day,
    }));
    return { sent: false, skipped: true, reason: "no_rates_available", day };
  }

  const projectId = serviceAccount.projectId || env.FIREBASE_PROJECT_ID || "gastoscan-ai";
  const accessToken = await fetchGoogleAccessToken(serviceAccount, { fetchImpl, now, timeoutMs });
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(fcmUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    const text = await response.text();
    if (!response.ok) {
      const errorSnippet = text.slice(0, 300);
      console.error(JSON.stringify({
        event: "daily_rates_push_error",
        reason: "fcm_http_error",
        day,
        status: response.status,
        error: errorSnippet,
      }));
      return {
        sent: false,
        skipped: false,
        reason: "fcm_http_error",
        status: response.status,
        error: errorSnippet,
        day,
      };
    }

    let messageName = null;
    try {
      const parsed = JSON.parse(text);
      messageName = parsed && parsed.name ? parsed.name : null;
    } catch (_) {
      messageName = null;
    }

    await markDailyRatesPushSent(env.DB, day);

    console.log(JSON.stringify({
      event: "daily_rates_push_sent",
      day,
      topic,
      messageName,
      usd: rates.usd ?? null,
      eur: rates.eur ?? null,
      usdt: rates.usdt ?? null,
    }));

    return {
      sent: true,
      skipped: false,
      day,
      topic,
      messageName,
      title: payload.message.notification.title,
      body: payload.message.notification.body,
    };
  } finally {
    clearTimeout(timer);
  }
}
