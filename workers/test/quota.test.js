import { test, describe } from "node:test";
import assert from "node:assert/strict";
import worker, {
  checkDailyQuota,
  incrementUsage,
  DAILY_UID_LIMIT,
  DAILY_GLOBAL_LIMIT,
  quotaDayFor
} from "../src/index.js";

// Implementación en memoria del binding D1 de Cloudflare para pruebas sin red
function createFakeD1() {
  const store = new Map();

  return {
    _store: store,
    prepare(sql) {
      assert.ok(
        typeof sql === "string" && sql.includes("ON CONFLICT") && sql.includes("RETURNING count"),
        `SQL no válido o sin cláusula ON CONFLICT / RETURNING count: ${sql}`
      );
      return {
        bind(...params) {
          return {
            async first() {
              const [day, scope] = params;
              const key = `${day}:${scope}`;
              const current = store.get(key) || 0;
              const next = current + 1;
              store.set(key, next);
              return { count: next };
            }
          };
        }
      };
    }
  };
}

describe("A1a — Control de Cuota y Rate Limiting Persistente con Cloudflare D1", () => {
  test("persiste el contador entre isolates simulados compartiendo env.DB", async () => {
    const fakeDb = createFakeD1();
    const day = "2026-11-10";
    const scope = "uid:usuario_compartido";

    // Simula Isolate 1 en región Miami
    const isolate1Env = { DB: fakeDb };
    const count1 = await incrementUsage(isolate1Env.DB, day, scope);
    assert.equal(count1, 1, "Isolate 1 debe inicializar el contador en 1");

    // Simula Isolate 2 en región Frankfurt accediendo a la misma base de datos
    const isolate2Env = { DB: fakeDb };
    const count2 = await incrementUsage(isolate2Env.DB, day, scope);
    assert.equal(count2, 2, "Isolate 2 debe ver el incremento persistido y retornar 2");

    // Simula Isolate 3 en región San Pablo
    const isolate3Env = { DB: fakeDb };
    const count3 = await incrementUsage(isolate3Env.DB, day, scope);
    assert.equal(count3, 3, "Isolate 3 debe retornar 3");
  });

  test("bloquea con 429 al superar el límite de 50 peticiones/día por UID", async () => {
    const fakeDb = createFakeD1();
    const env = { DB: fakeDb };
    const uid = "user_test_limit";

    // Consumir 50 peticiones permitidas
    for (let i = 1; i <= DAILY_UID_LIMIT; i++) {
      const result = await checkDailyQuota(env, uid, false);
      assert.equal(result.allowed, true, `Petición ${i} debe permitirse`);
      assert.equal(result.quotaMode, "d1");
    }

    // Petición 51 debe ser bloqueada
    const blocked = await checkDailyQuota(env, uid, false);
    assert.equal(blocked.allowed, false);
    assert.equal(blocked.statusCode, 429);
    assert.match(blocked.error, /límite diario de seguridad/);
  });

  test("bloquea con 429 al superar el tope global diario de 20.000", async () => {
    const fakeDb = createFakeD1();
    const today = quotaDayFor();
    // Simular que el contador global ya alcanzó el tope
    fakeDb._store.set(`${today}:global`, DAILY_GLOBAL_LIMIT);

    const env = { DB: fakeDb };
    const result = await checkDailyQuota(env, "usuario_cualquiera", false);

    assert.equal(result.allowed, false);
    assert.equal(result.statusCode, 429);
    assert.match(result.error, /límite diario de capacidad del servidor compartido/);
  });

  test("las peticiones con API key propia (BYOK) no consumen cuota compartida", async () => {
    const fakeDb = createFakeD1();
    const today = quotaDayFor();
    // Límite global y de usuario agotados
    fakeDb._store.set(`${today}:global`, DAILY_GLOBAL_LIMIT + 10);
    fakeDb._store.set(`${today}:uid:user_byok`, DAILY_UID_LIMIT + 10);

    const env = { DB: fakeDb };
    const result = await checkDailyQuota(env, "user_byok", true);

    assert.equal(result.allowed, true, "BYOK no debe ser bloqueado por cuotas compartidas");
  });

  test("aplica fail-closed con 503 si env.DB no está definido", async () => {
    const envSinDb = {};
    const uid = "user_memory_fallback";

    const result = await checkDailyQuota(envSinDb, uid, false);
    assert.equal(result.allowed, false);
    assert.equal(result.statusCode, 503);
    assert.equal(result.quotaMode, "memory");
  });

  test("aplica fail-closed con 503 ante fallo en base de datos D1", async () => {
    const brokenDb = {
      prepare() {
        throw new Error("D1 connection lost");
      }
    };
    const env = { DB: brokenDb };
    const result = await checkDailyQuota(env, "user_fail_closed", false);

    assert.equal(result.allowed, false, "Debe rechazar la llamada a Gemini si la DB falla");
    assert.equal(result.statusCode, 503);
  });

  // --- TESTS NUEVOS ESPECIFICADOS ---

  test("T1: autenticación antes de cuota (fetch-level)", async () => {
    const fakeDb = createFakeD1();
    const env = {
      GEMINI_API_KEY: "dummy_key",
      DB: fakeDb,
      FIREBASE_PROJECT_ID: "gastoscan-ai"
    };
    const req = new Request("https://rindemas-gateway.workers.dev/analyze-receipt", {
      method: "POST",
      headers: {
        "Authorization": "Bearer basura",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ ocrText: "test" })
    });

    const response = await worker.fetch(req, env, {});
    assert.equal(response.status, 401, "Debe retornar 401 si el token es inválido");
    assert.equal(fakeDb._store.size, 0, "No debe escribir en D1 si la autenticación falla");
  });

  test("T2: BYOK no escribe en D1", async () => {
    const fakeDb = createFakeD1();
    const env = { DB: fakeDb };
    const uid = "user_byok_clean";

    const result = await checkDailyQuota(env, uid, true);
    assert.equal(result.allowed, true);
    assert.equal(fakeDb._store.size, 0, "No debe registrar ninguna entrada en D1 para BYOK");
  });

  test("T3: peticiones bloqueadas por UID no consumen el global", async () => {
    const fakeDb = createFakeD1();
    const env = { DB: fakeDb };
    const uid = "user_t3_uid";
    const today = quotaDayFor();

    // Consumir las 50 peticiones del usuario
    for (let i = 0; i < DAILY_UID_LIMIT; i++) {
      const res = await checkDailyQuota(env, uid, false);
      assert.equal(res.allowed, true);
    }

    const globalCountBefore = fakeDb._store.get(`${today}:global`);
    assert.equal(globalCountBefore, DAILY_UID_LIMIT, "El global debe tener 50 tras 50 peticiones exitosas");

    // Petición 51 (bloqueada por superar el límite individual)
    const blockedRes = await checkDailyQuota(env, uid, false);
    assert.equal(blockedRes.allowed, false);
    assert.equal(blockedRes.statusCode, 429);

    const globalCountAfter = fakeDb._store.get(`${today}:global`);
    assert.equal(
      globalCountAfter,
      globalCountBefore,
      "El contador global NO debe haber aumentado tras la petición 51 bloqueada"
    );
  });

  test("T4: fake D1 valida que el SQL contenga ON CONFLICT y RETURNING count", async () => {
    const fakeDb = createFakeD1();

    // Comprobar que prepare no arroja error con el SQL oficial
    assert.doesNotThrow(() => {
      fakeDb.prepare(
        "INSERT INTO usage (day, scope, count) VALUES (?, ?, 1) ON CONFLICT(day, scope) DO UPDATE SET count = count + 1 RETURNING count"
      );
    });

    // Comprobar que prepare rechaza consultas que omitan cláusulas críticas
    assert.throws(() => {
      fakeDb.prepare("SELECT * FROM usage WHERE day = ?");
    }, /ON CONFLICT/);

    assert.throws(() => {
      fakeDb.prepare("INSERT INTO usage (day, scope, count) VALUES (?, ?, 1) ON CONFLICT(day, scope) DO UPDATE SET count = count + 1");
    }, /RETURNING count/);
  });

  test("calcula el corte de cuota en hora de Venezuela (UTC-4)", () => {
    assert.equal(quotaDayFor(new Date("2026-11-11T02:00:00Z")), "2026-11-10"); // 22:00 VET del día 10
    assert.equal(quotaDayFor(new Date("2026-11-10T12:00:00Z")), "2026-11-10");
  });

  test("la respuesta 401 no filtra internos", async () => {
    const fakeDb = createFakeD1();
    const env = {
      GEMINI_API_KEY: "dummy_key",
      DB: fakeDb,
      FIREBASE_PROJECT_ID: "gastoscan-ai"
    };
    const req = new Request("https://rindemas-gateway.workers.dev/analyze-receipt", {
      method: "POST",
      headers: {
        "Authorization": "Bearer basura",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ ocrText: "test" })
    });

    const response = await worker.fetch(req, env, {});
    assert.equal(response.status, 401);
    const bodyText = await response.text();
    assert.equal(bodyText.includes("JWT"), false, "No debe filtrar 'JWT'");
    assert.equal(bodyText.includes("kid"), false, "No debe filtrar 'kid'");
    assert.equal(bodyText.includes("Issuer"), false, "No debe filtrar 'Issuer'");
    assert.equal(bodyText.includes("gastoscan"), false, "No debe filtrar 'gastoscan'");
    const json = JSON.parse(bodyText);
    assert.equal(json.error, "No autenticado.");
  });

  test("incrementUsage lanza error si recibe un db inválido", async () => {
    await assert.rejects(
      async () => {
        await incrementUsage(null, "2026-11-10", "global");
      },
      {
        name: "Error",
        message: "DB de cuotas no disponible"
      }
    );
  });
});
