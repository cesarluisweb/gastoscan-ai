import test from 'node:test';
import assert from 'node:assert/strict';
import {
    RATE_TYPES,
    parseAmount,
    parsePositiveAmount,
    resolveActiveCalculatorRate,
    convertFromDivisa,
    convertFromVes,
    buildSimultaneousComparison,
    buildCalculatorExpensePrefill,
} from '../src/lib/currency-calculator.js';

const LIVE_RATES = { usd: 50.0, eur: 54.5, usdt: 58.0 };

test('parseAmount y parsePositiveAmount soportan formato venezolano, internacional y negativos', () => {
    assert.equal(parseAmount('1.234,56'), 1234.56);
    assert.equal(parseAmount('1,234.56'), 1234.56);
    assert.equal(parseAmount('1234,56'), 1234.56);
    assert.equal(parseAmount('1234.56'), 1234.56);
    assert.equal(parseAmount('1.250.000'), 1250000);
    assert.equal(parseAmount('1,250,000'), 1250000);
    assert.equal(parseAmount('-50'), -50);
    assert.equal(parseAmount('-12,50'), -12.5);
    assert.equal(parseAmount(''), null);
    assert.equal(parseAmount('   '), null);
    assert.equal(parseAmount(null), null);
    assert.equal(parseAmount(NaN), null);

    assert.equal(parsePositiveAmount('-50'), null);
    assert.equal(parsePositiveAmount('0'), null);
    assert.equal(parsePositiveAmount('12,50'), 12.5);
});

test('resolveActiveCalculatorRate selecciona tasas oficiales y tasa personalizada > 1.0', () => {
    assert.deepEqual(
        resolveActiveCalculatorRate({ tipoTasa: RATE_TYPES.DOLAR_BCV, rates: LIVE_RATES }),
        { rate: 50.0, currency: 'USD' }
    );
    assert.deepEqual(
        resolveActiveCalculatorRate({ tipoTasa: RATE_TYPES.EURO_BCV, rates: LIVE_RATES }),
        { rate: 54.5, currency: 'EUR' }
    );
    assert.deepEqual(
        resolveActiveCalculatorRate({ tipoTasa: RATE_TYPES.USDT_P2P, rates: LIVE_RATES }),
        { rate: 58.0, currency: 'USDT' }
    );
    assert.deepEqual(
        resolveActiveCalculatorRate({
            tipoTasa: RATE_TYPES.CUSTOM,
            selectedCurrency: 'EUR',
            rates: LIVE_RATES,
            customRate: '61,25',
        }),
        { rate: 61.25, currency: 'EUR' }
    );
    // Tasa inválida <= 1.0 retorna 0
    assert.deepEqual(
        resolveActiveCalculatorRate({
            tipoTasa: RATE_TYPES.CUSTOM,
            selectedCurrency: 'USD',
            rates: LIVE_RATES,
            customRate: '1',
        }),
        { rate: 0, currency: 'USD' }
    );
});

test('convertFromDivisa y convertFromVes convierten bidireccionalmente aceptando coma', () => {
    assert.equal(convertFromDivisa('12,50', 50.0), '625.00');
    assert.equal(convertFromVes('1.000,00', 50.0), '20.00');
    assert.equal(convertFromDivisa('10', 1.0), '');
    assert.equal(convertFromVes('-500', 50.0), '');
    assert.equal(convertFromDivisa('', 50.0), '');
});

test('buildSimultaneousComparison calcula las 3 filas y brecha USDT vs Dólar BCV', () => {
    const compDefault = buildSimultaneousComparison({
        rawDivisa: '',
        rates: LIVE_RATES,
        selectedTipoTasa: RATE_TYPES.DOLAR_BCV,
    });
    assert.equal(compDefault.montoBase, 1.0);
    // (58 - 50) / 50 * 100 = +16.0%
    assert.ok(Math.abs(compDefault.brechaUsdtBcv - 16.0) < 0.0001);
    assert.equal(compDefault.rows[0].totalBs, 50.0);
    assert.equal(compDefault.rows[0].isHighlighted, true);
    assert.equal(compDefault.rows[1].totalBs, 54.5);
    assert.equal(compDefault.rows[2].totalBs, 58.0);

    const compMonto = buildSimultaneousComparison({
        rawDivisa: '20,00',
        rates: LIVE_RATES,
        selectedTipoTasa: RATE_TYPES.EURO_BCV,
    });
    assert.equal(compMonto.montoBase, 20.0);
    assert.equal(compMonto.rows[1].isHighlighted, true);
    assert.equal(compMonto.rows[1].totalBs, 1090.0);
});

test('buildCalculatorExpensePrefill paridad móvil en USD/EUR/USDT/VES y B4 Personalizada con DIVISA + rateOverride', () => {
    // 1. Dólar BCV -> DIVISA en USD, ítem con precio/total con punto decimal
    const usdRes = buildCalculatorExpensePrefill({
        isVesOnTop: false,
        rawDivisa: '12,50',
        rawVes: '625,00',
        tipoTasa: RATE_TYPES.DOLAR_BCV,
        selectedCurrency: 'USD',
        rates: LIVE_RATES,
        defaultFechaIso: '2026-11-20',
    });
    assert.equal(usdRes.ok, true);
    assert.equal(usdRes.prefill.__isExpensePrefill, true);
    assert.equal(usdRes.prefill.moneda, 'USD');
    assert.equal(usdRes.prefill.metodoLiquidacion, 'DIVISA');
    assert.equal(usdRes.prefill.totalOriginalFixed, '12.50');
    assert.equal(usdRes.prefill.items[0].precio, '12.50');
    assert.equal(usdRes.prefill.items[0].total, '12.50');

    // 2. USDT P2P -> moneda USDT nativa (metodoLiquidacion null)
    const usdtRes = buildCalculatorExpensePrefill({
        isVesOnTop: false,
        rawDivisa: '30',
        rawVes: '1740',
        tipoTasa: RATE_TYPES.USDT_P2P,
        selectedCurrency: 'USDT',
        rates: LIVE_RATES,
        defaultFechaIso: '2026-11-20',
    });
    assert.equal(usdtRes.ok, true);
    assert.equal(usdtRes.prefill.moneda, 'USDT');
    assert.equal(usdtRes.prefill.metodoLiquidacion, null);

    // 3. Bolívares arriba (isVesOnTop = true) -> moneda VES
    const vesRes = buildCalculatorExpensePrefill({
        isVesOnTop: true,
        rawDivisa: '10',
        rawVes: '500,50',
        tipoTasa: RATE_TYPES.DOLAR_BCV,
        selectedCurrency: 'USD',
        rates: LIVE_RATES,
        defaultFechaIso: '2026-11-20',
    });
    assert.equal(vesRes.ok, true);
    assert.equal(vesRes.prefill.moneda, 'VES');
    assert.equal(vesRes.prefill.metodoLiquidacion, null);
    assert.equal(vesRes.prefill.totalOriginalFixed, '500.50');

    // 4. B4: Personalizada -> mantiene DIVISA y moneda original + rateOverride sin convertir a VES
    const customRes = buildCalculatorExpensePrefill({
        isVesOnTop: false,
        rawDivisa: '15,00',
        rawVes: '900,00',
        tipoTasa: RATE_TYPES.CUSTOM,
        selectedCurrency: 'USD',
        rates: LIVE_RATES,
        customRate: '60,00',
        defaultFechaIso: '2026-11-20',
    });
    assert.equal(customRes.ok, true);
    assert.equal(customRes.prefill.moneda, 'USD');
    assert.equal(customRes.prefill.metodoLiquidacion, 'DIVISA');
    assert.equal(customRes.prefill.tasaCobrada, 60.0);
    assert.deepEqual(customRes.prefill.rateOverride, { currency: 'USD', rate: 60.0 });
    assert.equal(customRes.prefill.customRateLocked, true);

    // 5. Sin montos válidos falla limpiamente
    const emptyRes = buildCalculatorExpensePrefill({
        isVesOnTop: false,
        rawDivisa: '',
        rawVes: '',
        rates: LIVE_RATES,
    });
    assert.equal(emptyRes.ok, false);
    assert.equal(emptyRes.prefill, null);
});
