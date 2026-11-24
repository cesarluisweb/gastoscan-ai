import { test, describe } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";
import {
  DAILY_RATES_TOPIC,
  DAILY_RATES_CHANNEL_ID,
  DAILY_RATES_PAYLOAD,
  DAILY_RATES_DEDUPE_SCOPE,
  formatBsRate,
  formatVetShortDate,
  vetDayIso,
  buildDailyRatesMessage,
  parseServiceAccount,
  signServiceAccountJwt,
  sendDailyRatesPush,
} from "../src/daily_rates_push.js";

function createFakeD1ForPush() {
  const store = new Map();
  return {
    _store: store,
    prepare(sql) {
      return {
        bind(...params) {
          return {
            async first() {
              if (sql.trim().toUpperCase().startsWith("SELECT")) {
                const [day, scope] = params;
                const val = store.get(`${day}:${scope}`);
                return val !== undefined ? { count: val } : null;
              }
              if (sql.includes("ON CONFLICT") && sql.includes("RETURNING count")) {
                const [day, scope] = params;
                const key = `${day}:${scope}`;
                const next = (store.get(key) || 0) + 1;
                store.set(key, next);
                return { count: next };
              }
              throw new Error(`SQL inesperado en test: ${sql}`);
            },
          };
        },
      };
    },
  };
}

async function generateTestRsaServiceAccount() {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"]
  );

  const pkcs8 = await crypto.subtle.exportKey("pkcs8", keyPair.privateKey);
  const bytes = new Uint8Array(pkcs8);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  const b64 = btoa(binary);
  const lines = b64.match(/.{1,64}/g).join("\n");
  const pem = `-----BEGIN PRIVATE KEY-----\n${lines}\n-----END PRIVATE KEY-----\n`;

  return {
    publicKey: keyPair.publicKey,
    serviceAccountJson: JSON.stringify({
      type: "service_account",
      project_id: "gastoscan-ai",
      client_email: "fcm-sender@gastoscan-ai.iam.gserviceaccount.com",
      private_key: pem,
      token_uri: "https://oauth2.googleapis.com/token",
    }),
  };
}

function base64UrlToUint8Array(str) {
  const base64 = str.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (str.length % 4)) % 4);
  const binary = atob(base64);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

describe("Notificación diaria de tasa de cambio (Worker Cron + FCM HTTP v1)", () => {
  test("formatBsRate formatea tasas en estilo venezolano y descarta valores inválidos", () => {
    assert.equal(formatBsRate(245.3), "Bs. 245,30");
    assert.equal(formatBsRate(1245.5), "Bs. 1.245,50");
    assert.equal(formatBsRate(52.004), "Bs. 52,00");
    assert.equal(formatBsRate(0), null);
    assert.equal(formatBsRate(-10), null);
    assert.equal(formatBsRate(null), null);
    assert.equal(formatBsRate(NaN), null);
    assert.equal(formatBsRate("245.3"), null);
  });

  test("vetDayIso y formatVetShortDate usan hora de Venezuela (UTC-4)", () => {
    // 2026-11-24 12:30 UTC == Martes 24 Nov 08:30 VET
    const morningVet = new Date("2026-11-24T12:30:00Z");
    assert.equal(vetDayIso(morningVet), "2026-11-24");
    assert.equal(formatVetShortDate(morningVet), "Mar 24 Nov");

    // 2026-11-25 02:00 UTC == Martes 24 Nov 22:00 VET (no salta al miércoles UTC)
    const lateNightVet = new Date("2026-11-25T02:00:00Z");
    assert.equal(vetDayIso(lateNightVet), "2026-11-24");
    assert.equal(formatVetShortDate(lateNightVet), "Mar 24 Nov");
  });

  test("buildDailyRatesMessage construye payload FCM v1 con USD BCV en 1.ª línea, USDT P2P en 2.ª (sin EUR) y TTL de 8h", () => {
    const now = new Date("2026-11-24T12:30:00Z");
    const msg = buildDailyRatesMessage(
      { usd: 245.3, eur: 268.15, usdt: 279.4 },
      { now }
    );

    assert.ok(msg);
    assert.equal(msg.message.topic, DAILY_RATES_TOPIC);
    assert.equal(msg.message.notification.title, "Tasa de hoy · USD BCV Bs. 245,30");
    assert.equal(
      msg.message.notification.body,
      "USDT P2P Bs. 279,40 · Toca para calcular"
    );
    assert.equal(msg.message.notification.title.includes("EUR"), false);
    assert.equal(msg.message.notification.body.includes("EUR"), false);
    assert.equal(msg.message.notification.title.includes("Binance"), false);
    assert.equal(msg.message.notification.body.includes("Binance"), false);
    assert.equal(msg.message.notification.body.toLowerCase().includes("paralelo"), false);

    assert.equal(msg.message.data.payload, DAILY_RATES_PAYLOAD);
    assert.equal(msg.message.data.channel_id, DAILY_RATES_CHANNEL_ID);
    assert.equal(msg.message.data.day, "2026-11-24");
    assert.equal(msg.message.data.usd, "245.30");
    assert.equal(msg.message.data.usdt, "279.40");
    assert.equal(msg.message.data.eur, undefined);

    assert.equal(msg.message.android.ttl, "28800s");
    assert.equal(msg.message.android.collapse_key, DAILY_RATES_CHANNEL_ID);
    assert.equal(msg.message.android.notification.channel_id, DAILY_RATES_CHANNEL_ID);
    assert.equal(msg.message.android.notification.tag, DAILY_RATES_CHANNEL_ID);
    assert.equal(
      msg.message.android.notification.click_action,
      undefined,
      "No debe enviar click_action sin intent-filter en AndroidManifest"
    );
  });

  test("buildDailyRatesMessage tolera tasas parciales y retorna null si faltan USD y USDT", () => {
    const now = new Date("2026-11-24T12:30:00Z");

    const onlyUsd = buildDailyRatesMessage({ usd: 245.3, eur: 268.15, usdt: null }, { now });
    assert.ok(onlyUsd);
    assert.equal(onlyUsd.message.notification.title, "Tasa de hoy · USD BCV Bs. 245,30");
    assert.equal(onlyUsd.message.notification.body, "Toca para abrir la calculadora.");

    const onlyUsdt = buildDailyRatesMessage({ usd: null, eur: 268.15, usdt: 279.4 }, { now });
    assert.ok(onlyUsdt);
    assert.equal(onlyUsdt.message.notification.title, "Tasa de hoy · USDT P2P Bs. 279,40");
    assert.equal(onlyUsdt.message.notification.body, "Toca para abrir la calculadora.");

    const onlyEur = buildDailyRatesMessage({ usd: null, eur: 268.15, usdt: null }, { now });
    assert.equal(onlyEur, null);

    const empty = buildDailyRatesMessage({ usd: null, eur: 0, usdt: null }, { now });
    assert.equal(empty, null);
  });

  test("signServiceAccountJwt genera firma RS256 verificable con Web Crypto", async () => {
    const { publicKey, serviceAccountJson } = await generateTestRsaServiceAccount();
    const sa = parseServiceAccount(serviceAccountJson);
    const now = new Date("2026-11-24T12:30:00Z");

    const jwt = await signServiceAccountJwt({
      clientEmail: sa.clientEmail,
      privateKey: sa.privateKey,
      tokenUri: sa.tokenUri,
      now,
    });

    const parts = jwt.split(".");
    assert.equal(parts.length, 3);

    const header = JSON.parse(new TextDecoder().decode(base64UrlToUint8Array(parts[0])));
    const claims = JSON.parse(new TextDecoder().decode(base64UrlToUint8Array(parts[1])));
    assert.equal(header.alg, "RS256");
    assert.equal(claims.iss, "fcm-sender@gastoscan-ai.iam.gserviceaccount.com");
    assert.equal(claims.scope, "https://www.googleapis.com/auth/firebase.messaging");
    assert.equal(claims.exp - claims.iat, 3600);

    const signatureBytes = base64UrlToUint8Array(parts[2]);
    const valid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      publicKey,
      signatureBytes,
      new TextEncoder().encode(`${parts[0]}.${parts[1]}`)
    );
    assert.equal(valid, true);
  });

  test("sendDailyRatesPush omite envío limpio si falta FIREBASE_SERVICE_ACCOUNT_JSON", async () => {
    let ratesCalled = false;
    const result = await sendDailyRatesPush(
      { FIREBASE_PROJECT_ID: "gastoscan-ai" },
      {
        getRates: async () => {
          ratesCalled = true;
          return { usd: 245.3, eur: 268.15, usdt: 279.4 };
        },
        now: new Date("2026-11-24T12:30:00Z"),
      }
    );

    assert.equal(result.sent, false);
    assert.equal(result.skipped, true);
    assert.equal(result.reason, "missing_service_account_secret");
    assert.equal(ratesCalled, false);
  });

  test("sendDailyRatesPush envía a FCM HTTP v1, registra deduplicación en D1 y evita duplicados el mismo día", async () => {
    const { serviceAccountJson } = await generateTestRsaServiceAccount();
    const fakeDb = createFakeD1ForPush();
    const calls = [];

    const fakeFetch = async (url, options) => {
      calls.push({ url, options });
      if (url === "https://oauth2.googleapis.com/token") {
        return new Response(JSON.stringify({ access_token: "ya29.fake-access-token" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      if (url === "https://fcm.googleapis.com/v1/projects/gastoscan-ai/messages:send") {
        assert.equal(options.headers.Authorization, "Bearer ya29.fake-access-token");
        const sentBody = JSON.parse(options.body);
        assert.equal(sentBody.message.topic, DAILY_RATES_TOPIC);
        return new Response(JSON.stringify({ name: "projects/gastoscan-ai/messages/12345" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      throw new Error(`URL inesperada: ${url}`);
    };

    const env = {
      DB: fakeDb,
      FIREBASE_PROJECT_ID: "gastoscan-ai",
      FIREBASE_SERVICE_ACCOUNT_JSON: serviceAccountJson,
    };
    const now = new Date("2026-11-24T12:30:00Z");

    // Primer envío del día
    const first = await sendDailyRatesPush(env, {
      getRates: async () => ({ usd: 245.3, eur: 268.15, usdt: 279.4 }),
      fetchImpl: fakeFetch,
      now,
    });

    assert.equal(first.sent, true);
    assert.equal(first.messageName, "projects/gastoscan-ai/messages/12345");
    assert.equal(calls.length, 2);
    assert.equal(fakeDb._store.get(`2026-11-24:${DAILY_RATES_DEDUPE_SCOPE}`), 1);

    // Segundo disparo el mismo día -> omitido por deduplicación en D1
    const second = await sendDailyRatesPush(env, {
      getRates: async () => ({ usd: 245.3, eur: 268.15, usdt: 279.4 }),
      fetchImpl: fakeFetch,
      now: new Date("2026-11-24T13:00:00Z"),
    });

    assert.equal(second.sent, false);
    assert.equal(second.skipped, true);
    assert.equal(second.reason, "already_sent");
    assert.equal(calls.length, 2, "No debe volver a llamar OAuth2 ni FCM");
  });

  test("sendDailyRatesPush no marca como enviado en D1 si FCM devuelve error HTTP 500", async () => {
    const { serviceAccountJson } = await generateTestRsaServiceAccount();
    const fakeDb = createFakeD1ForPush();

    const failingFetch = async (url) => {
      if (url === "https://oauth2.googleapis.com/token") {
        return new Response(JSON.stringify({ access_token: "ya29.fake-access-token" }), { status: 200 });
      }
      return new Response(JSON.stringify({ error: { message: "Internal error" } }), { status: 500 });
    };

    const res = await sendDailyRatesPush(
      {
        DB: fakeDb,
        FIREBASE_PROJECT_ID: "gastoscan-ai",
        FIREBASE_SERVICE_ACCOUNT_JSON: serviceAccountJson,
      },
      {
        getRates: async () => ({ usd: 245.3, eur: 268.15, usdt: 279.4 }),
        fetchImpl: failingFetch,
        now: new Date("2026-11-24T12:30:00Z"),
      }
    );

    assert.equal(res.sent, false);
    assert.equal(res.reason, "fcm_http_error");
    assert.equal(res.status, 500);
    assert.equal(fakeDb._store.size, 0, "No debe registrar dedupe si FCM falló");
  });

  test("worker.scheduled delega el envío mediante ctx.waitUntil", async () => {
    let waitedPromise = null;
    const ctx = {
      waitUntil(promise) {
        waitedPromise = promise;
      },
    };

    await worker.scheduled(
      { scheduledTime: Date.parse("2026-11-24T12:30:00Z") },
      { FIREBASE_PROJECT_ID: "gastoscan-ai" },
      ctx
    );

    assert.ok(waitedPromise, "scheduled debe invocar ctx.waitUntil");
    await waitedPromise;
  });
});
