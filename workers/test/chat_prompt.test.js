import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { buildChatSystemPrompt } from "../src/index.js";

describe("AI-11 Etapa 0 — Prompt de /chat-analyst por modo", () => {
  test("chat normal incluye reglas de contexto temporal, proyeccion_confiable y cero ruido puntual", () => {
    const prompt = buildChatSystemPrompt({
      modo: undefined,
      contextData: {
        fecha_hoy: "2026-11-21",
        periodo_consultado: "2026-11",
        moneda_principal: "USD",
        gasto_proyectado_fin_mes: null,
        contexto_temporal: {
          proyeccion_confiable: false,
          motivo_sin_proyeccion: "inicio_de_mes"
        }
      },
      defaultMoneda: "USD",
      fechaReferenciaHoy: "2026-11-21"
    });

    assert.match(prompt, /REGLAS DE CONTEXTO TEMPORAL Y SEÑALES/);
    assert.match(prompt, /proyeccion_confiable/);
    assert.match(prompt, /comparativa_mes_anterior/);
    assert.match(prompt, /consulta puntual/);
    assert.match(prompt, /NUNCA afirmes ni recomiendes/);
    assert.match(prompt, /periodo_consultado/);
  });

  test("modo dictado_gasto NO incorpora reglas de chat ni contexto temporal (0 tokens extra)", () => {
    const prompt = buildChatSystemPrompt({
      modo: "dictado_gasto",
      contextData: { fecha_hoy: "2026-11-21", moneda_principal: "VES" },
      defaultMoneda: "VES",
      fechaReferenciaHoy: "2026-11-21"
    });

    assert.equal(prompt.includes("REGLAS DE CONTEXTO TEMPORAL Y SEÑALES"), false);
    assert.equal(prompt.includes("proyeccion_confiable"), false);
    assert.match(prompt, /registrar_gasto/);
    assert.match(prompt, /2026-11-21/);
  });

  test("modo insight_inicio conserva su contrato JSON estricto y regla de disciplina sutil", () => {
    const prompt = buildChatSystemPrompt({
      modo: "insight_inicio",
      contextData: { fecha_hoy: "2026-11-21", cantidad_compras_mes: 5 },
      defaultMoneda: "USD",
      fechaReferenciaHoy: "2026-11-21"
    });

    assert.equal(prompt.includes("REGLAS DE CONTEXTO TEMPORAL Y SEÑALES"), false);
    assert.match(prompt, /Disciplina sutil/);
    assert.match(prompt, /campo único "consejo"/);
  });

  test("fallback de fechaReferenciaHoy resuelve fecha ISO YYYY-MM-DD (UTC-4) sin lanzar ReferenceError", () => {
    const prompt = buildChatSystemPrompt({
      modo: "dictado_gasto",
      contextData: {}
    });

    assert.match(prompt, /La fecha de hoy es estrictamente "\d{4}-\d{2}-\d{2}"/);
  });
});
