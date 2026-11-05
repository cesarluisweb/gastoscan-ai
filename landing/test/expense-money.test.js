import test from 'node:test';
import assert from 'node:assert/strict';
import { computeExpenseTotals, computeItemCents } from '../src/lib/expense-money.js';

// Tasas canónicas de referencia para las pruebas
const RATES = {
    tasaUsd: 36.50,
    tasaEur: 39.80,
    tasaUsdt: 42.10,
};

test('C1: VES 1.234,56 @ BCV 36,50', () => {
    const res = computeExpenseTotals({
        moneda: 'VES',
        monto: 1234.56,
        ...RATES,
    });

    assert.equal(res.moneda, 'VES');
    assert.equal(res.total_original, 123456); // Bs. 1.234,56
    assert.equal(res.total_usd, 3382);       // $33,82
    assert.equal(res.total_eur, 3102);       // €31,02
    assert.equal(res.total_usdt, 2932);      // 29,32 USDT
    assert.equal(res.tasa_cambio, 36.50);
    assert.equal(res.tasa_eur, 39.80);
    assert.equal(res.tasa_usdt, 42.10);
    assert.equal(res.fuente_tasa_cambio, 'BCV');
});

test('C2: USD 20, Bs. 740,00 @ efectiva 37,00 (en Bs. a tasa BCV)', () => {
    const res = computeExpenseTotals({
        moneda: 'USD',
        monto: 20.00,
        metodoLiquidacion: 'BS_BCV',
        bolivaresManuales: 740.00,
        ...RATES,
    });

    assert.equal(res.moneda, 'VES');
    assert.equal(res.total_original, 74000); // Bs. 740,00
    assert.equal(res.total_usd, 2000);       // $20,00 exacto
    assert.equal(res.total_eur, 1859);       // €18,59
    assert.equal(res.total_usdt, 1758);      // 17,58 USDT
    assert.equal(res.tasa_cambio, 37.00);    // Tasa efectiva cobrada en caja
    assert.equal(res.tasa_eur, 39.80);
    assert.equal(res.tasa_usdt, 42.10);
    assert.equal(res.fuente_tasa_cambio, 'BCV (Pago en Bs. indexado a USD)');
});

test('C3: USD 15, Bs. 631,50 @ P2P 42,10 (en Bs. a tasa P2P)', () => {
    const res = computeExpenseTotals({
        moneda: 'USD',
        monto: 15.00,
        metodoLiquidacion: 'BS_USDT',
        tasaCobrada: 42.10,
        ...RATES,
    });

    assert.equal(res.moneda, 'VES');
    assert.equal(res.total_original, 63150); // Bs. 631,50
    assert.equal(res.total_usd, 1730);       // $17,30 (dividido por USD BCV 36,50)
    assert.equal(res.total_eur, 1587);       // €15,87
    assert.equal(res.total_usdt, 1500);      // 15,00 USDT
    assert.equal(res.tasa_cambio, 36.50);    // USD BCV de referencia
    assert.equal(res.tasa_usdt, 42.10);      // Tasa USDT P2P aplicada
    assert.equal(res.tasa_eur, 39.80);
    assert.equal(res.fuente_tasa_cambio, 'Binance P2P (Pago en Bs. indexado a USDT)');
});

test('C4: EUR 10, Bs. 398,00 @ EUR 39,80 (en Bs. a tasa BCV)', () => {
    const res = computeExpenseTotals({
        moneda: 'EUR',
        monto: 10.00,
        metodoLiquidacion: 'BS_BCV',
        tasaCobrada: 39.80,
        ...RATES,
    });

    assert.equal(res.moneda, 'VES');
    assert.equal(res.total_original, 39800); // Bs. 398,00
    assert.equal(res.total_usd, 1090);       // $10,90
    assert.equal(res.total_eur, 1000);       // €10,00
    assert.equal(res.total_usdt, 945);       // 9,45 USDT
    assert.equal(res.tasa_cambio, 39.80);    // Tasa EUR aplicada
    assert.equal(res.tasa_eur, 39.80);
    assert.equal(res.tasa_usdt, 42.10);
    assert.equal(res.fuente_tasa_cambio, 'BCV (Pago en Bs. indexado a EUR)');
});

test('C5: EUR 25 divisa directa', () => {
    const res = computeExpenseTotals({
        moneda: 'EUR',
        monto: 25.00,
        metodoLiquidacion: 'DIVISA',
        ...RATES,
    });

    assert.equal(res.moneda, 'EUR');
    assert.equal(res.total_original, 2500); // € 25,00
    assert.equal(res.total_eur, 2500);      // € 25,00
    assert.equal(res.total_usd, 2726);      // $ 27,26
    assert.equal(res.total_usdt, 2726);     // 27,26 USDT
    assert.equal(res.tasa_cambio, 36.50);   // USD BCV de referencia
    assert.equal(res.tasa_eur, 39.80);      // EUR BCV
    assert.equal(res.fuente_tasa_cambio, 'Euro BCV (Bs. 39.80)');
});

test('C6: Preservación estricta de centavos en ítems sin modificar', () => {
    const itemOriginal = {
        cantidad: 2,
        precio: 5.00,
        total: 10.00,
        origBsTotal: 36521,   // Centavos exactos almacenados originalmente
        origBsPrecio: 18260,  // Centavos exactos almacenados originalmente
        initRate: 36.521,
        initCant: 2,
        initPrecio: 5.00,
    };

    // Al reabrir sin cambios en cant ni precio
    const centsSinCambios = computeItemCents(itemOriginal, 36.521);
    assert.equal(centsSinCambios.total, 36521);
    assert.equal(centsSinCambios.precio_unitario, 18260);

    // Si el usuario modifica la cantidad a 3
    const itemModificado = { ...itemOriginal, cantidad: 3 };
    const centsModificado = computeItemCents(itemModificado, 36.521);
    assert.equal(centsModificado.precio_unitario, Math.round(5.00 * 36.521 * 100)); // 18261
    assert.equal(centsModificado.total, Math.round(3 * 5.00 * 36.521 * 100));       // 54782
});
