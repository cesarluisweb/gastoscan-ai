import test from 'node:test';
import assert from 'node:assert/strict';
import {
    computeExpenseTotals,
    computeItemCents,
    computeMonthTotals,
    calculateSavingsHealth,
    buildDuplicateExpensePrefill,
} from '../src/lib/expense-money.js';

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

test('Entrega 0: computeMonthTotals paridad exacta contra lógica inline de renderMetrics (10 gastos sintéticos mixtos)', () => {
    const liveRates = { usd: 50.0, eur: 54.0, usdt: 58.0 };

    // 10 gastos sintéticos cubriendo VES, USD directo, USD BCV, USD USDT, EUR directo, EUR BCV, USDT directo y docs legacy sin total_usdt/total_eur
    const gastos = [
        // 1. VES directo con todos los campos
        { moneda: 'VES', total_original: 50000, total_usd: 1000, total_usdt: 862, total_eur: 926, tasa_cambio: 50.0, tasa_usdt: 58.0, tasa_eur: 54.0 },
        // 2. USD directo con todos los campos
        { moneda: 'USD', total_original: 2500, total_usd: 2500, total_usdt: 2500, total_eur: 2315, tasa_cambio: 50.0, tasa_usdt: 58.0, tasa_eur: 54.0 },
        // 3. USD pagado en Bs a tasa BCV (moneda VES)
        { moneda: 'VES', total_original: 102000, total_usd: 2000, total_usdt: 1759, total_eur: 1889, tasa_cambio: 51.0, tasa_usdt: 58.0, tasa_eur: 54.0 },
        // 4. USD pagado en Bs a tasa P2P (moneda VES)
        { moneda: 'VES', total_original: 87000, total_usd: 1740, total_usdt: 1500, total_eur: 1611, tasa_cambio: 50.0, tasa_usdt: 58.0, tasa_eur: 54.0 },
        // 5. EUR directo
        { moneda: 'EUR', total_original: 1500, total_usd: 1620, total_usdt: 1620, total_eur: 1500, tasa_cambio: 50.0, tasa_eur: 54.0, tasa_usdt: 58.0 },
        // 6. USDT directo
        { moneda: 'USDT', total_original: 3000, total_usd: 3000, total_usdt: 3000, total_eur: 2778, tasa_cambio: 50.0, tasa_usdt: 58.0, tasa_eur: 54.0 },
        // 7. Legacy VES sin total_usdt ni total_eur (usa tasa_usdt/tasa_eur del doc)
        { moneda: 'VES', total_original: 116000, total_usd: 2320, tasa_cambio: 50.0, tasa_usdt: 58.0, tasa_eur: 54.0 },
        // 8. Legacy USD sin total_usdt ni total_eur (totalUsdt cae a totalUsd, totalEur cae a liveRates.eur)
        { moneda: 'USD', total_original: 1080, total_usd: 1080, tasa_cambio: 50.0 },
        // 9. Legacy EUR sin total_eur (cae a totalOrig) y sin total_usdt (usa liveRates.usdt)
        { moneda: 'EUR', total_original: 2000, total_usd: 2160, tasa_cambio: 50.0 },
        // 10. Legacy VES sin tasa_cambio propia (usa liveRates.usd)
        { moneda: 'VES', total_original: 25000, total_usd: 500, total_usdt: 431, total_eur: 463 },
    ];

    // Función de referencia literal del bloque inline original de panel.astro:1576-1617
    const legacyInlineTotals = (list, rates) => {
        let sumUsd = 0, sumVes = 0, sumUsdt = 0, sumEur = 0;
        list.forEach(g => {
            const totalUsd = (Number(g.total_usd || 0)) / 100.0;
            const totalOrig = (Number(g.total_original || 0)) / 100.0;
            const tasa = Number(g.tasa_cambio || 0) > 0 ? Number(g.tasa_cambio) : (rates.usd || 1.0);
            sumUsd += totalUsd;
            let totalUsdt = 0;
            if (g.total_usdt !== undefined && g.total_usdt !== null) {
                totalUsdt = (Number(g.total_usdt || 0)) / 100.0;
            } else if (g.moneda === 'USD') {
                totalUsdt = totalUsd;
            } else {
                const tUsdt = Number(g.tasa_usdt || 0) > 0 ? Number(g.tasa_usdt) : (Number(rates.usdt || 0) > 0 ? Number(rates.usdt) : 0);
                totalUsdt = tUsdt > 0 ? (totalOrig / tUsdt) : 0;
            }
            sumUsdt += totalUsdt;
            let totalEur = 0;
            if (g.total_eur !== undefined && g.total_eur !== null) {
                totalEur = (Number(g.total_eur || 0)) / 100.0;
            } else if (g.moneda === 'EUR') {
                totalEur = totalOrig;
            } else {
                const tEur = Number(g.tasa_eur || 0) > 0 ? Number(g.tasa_eur) : (Number(rates.eur || 0) > 0 ? Number(rates.eur) : 0);
                totalEur = tEur > 0 ? (g.moneda === 'VES' ? totalOrig / tEur : (totalUsd * (tasa > 0 ? tasa : 1.0)) / tEur) : 0;
            }
            sumEur += totalEur;
            if (g.moneda === 'VES') {
                sumVes += totalOrig;
            } else {
                sumVes += (totalUsd * (tasa > 0 ? tasa : 1.0));
            }
        });
        return { sumUsd, sumVes, sumUsdt, sumEur };
    };

    const actual = computeMonthTotals(gastos, liveRates);
    const expected = legacyInlineTotals(gastos, liveRates);

    assert.equal(actual.sumUsd, expected.sumUsd);
    assert.equal(actual.sumVes, expected.sumVes);
    assert.equal(actual.sumUsdt, expected.sumUsdt);
    assert.equal(actual.sumEur, expected.sumEur);

    // Verificación directa calculada a mano:
    // sumUsd = 10 + 25 + 20 + 17.40 + 16.20 + 30 + 23.20 + 10.80 + 21.60 + 5 = 179.20
    assert.ok(Math.abs(actual.sumUsd - 179.20) < 0.0001);
    // sumVes = (500 + 1020 + 870 + 1160 + 250) + (25 + 16.20 + 30 + 10.80 + 21.60)*50 = 3800 + 5180 = 8980.00
    assert.ok(Math.abs(actual.sumVes - 8980.00) < 0.0001);
});

test('Entrega 0: calculateSavingsHealth estados sinMeta, protegida, enRiesgo y comprometida', () => {
    const sinMeta = calculateSavingsHealth({
        presupuestoGeneral: 500,
        metaAhorro: 0,
        gastoAcumulado: 200,
        diaActual: 15,
        diasTotalesMes: 30,
    });
    assert.equal(sinMeta.status, 'sinMeta');
    assert.equal(sinMeta.limiteParaGastar, 500);

    const protegida = calculateSavingsHealth({
        presupuestoGeneral: 500,
        metaAhorro: 100,
        gastoAcumulado: 150,
        diaActual: 15,
        diasTotalesMes: 30,
    });
    assert.equal(protegida.status, 'protegida');
    assert.equal(protegida.limiteParaGastar, 400);
    assert.equal(protegida.gastoProyectadoFinDeMes, 300);

    const enRiesgo = calculateSavingsHealth({
        presupuestoGeneral: 500,
        metaAhorro: 100,
        gastoAcumulado: 250,
        diaActual: 15,
        diasTotalesMes: 30,
    });
    assert.equal(enRiesgo.status, 'enRiesgo');
    assert.ok(Math.abs(enRiesgo.gastoProyectadoFinDeMes - 500) < 0.0001);

    const comprometida = calculateSavingsHealth({
        presupuestoGeneral: 500,
        metaAhorro: 100,
        gastoAcumulado: 420,
        diaActual: 15,
        diasTotalesMes: 30,
    });
    assert.equal(comprometida.status, 'comprometida');
    assert.equal(comprometida.disponibleParaGastar, 0);
});

test('UX-21: buildDuplicateExpensePrefill USD DIVISA conserva monto USD y usa fecha de hoy', () => {
    const prefill = buildDuplicateExpensePrefill({
        comercio: 'Comisión App',
        fecha: '2026-11-03',
        moneda: 'USD',
        metodo_liquidacion: 'DIVISA',
        total_original: 250,
        total_usd: 250,
        tasa_cambio: 40.0,
        categoria: 'Servicios',
        items: [{ descripcion: 'Comisión', cantidad: 1, precio_unitario: 250, total: 250, categoria: 'Servicios' }],
    }, { todayCaracasIso: '2026-11-25' });

    assert.equal(prefill.__isExpensePrefill, true);
    assert.equal(prefill.isDuplicate, true);
    assert.equal(prefill.fecha, '2026-11-25');
    assert.equal(prefill.moneda, 'USD');
    assert.equal(prefill.metodoLiquidacion, 'DIVISA');
    assert.equal(prefill.totalOriginalFixed, '2.50');
    assert.equal(prefill.items[0].precio, '2.50');
    assert.equal(prefill.items[0].total, '2.50');
});

test('UX-21: buildDuplicateExpensePrefill USD indexado BS_BCV reconstruye monto e ítems en USD', () => {
    const prefill = buildDuplicateExpensePrefill({
        comercio: 'Supermercado',
        fecha: '2026-11-03',
        moneda: 'VES',
        total_original: 40000,
        total_usd: 1000,
        tasa_cambio: 40.0,
        fuente_tasa_cambio: 'BCV (Pago en Bs. indexado a USD)',
        items: [{ descripcion: 'Arroz', cantidad: 2, precio_unitario: 20000, total: 40000, categoria: 'Alimentación' }],
    }, { todayCaracasIso: '2026-11-25' });

    assert.equal(prefill.moneda, 'USD');
    assert.equal(prefill.metodoLiquidacion, 'BS_BCV');
    assert.equal(prefill.totalOriginalFixed, '10.00');
    assert.equal(prefill.items[0].precio, '5.00');
    assert.equal(prefill.items[0].total, '10.00');
});

test('UX-21: buildDuplicateExpensePrefill USD indexado BS_USDT reconstruye monto e ítems en USDT', () => {
    const prefill = buildDuplicateExpensePrefill({
        comercio: 'Tienda Tech',
        fecha: '2026-11-03',
        moneda: 'VES',
        total_original: 60000,
        total_usd: 1500,
        total_usdt: 1000,
        tasa_cambio: 40.0,
        tasa_usdt: 60.0,
        fuente_tasa_cambio: 'Binance P2P (Pago en Bs. indexado a USDT)',
        items: [{ descripcion: 'Cable', cantidad: 1, precio_unitario: 60000, total: 60000, categoria: 'Otros' }],
    }, { todayCaracasIso: '2026-11-25' });

    assert.equal(prefill.moneda, 'USD');
    assert.equal(prefill.metodoLiquidacion, 'BS_USDT');
    assert.equal(prefill.totalOriginalFixed, '10.00');
    assert.equal(prefill.items[0].total, '10.00');
});

test('UX-21: buildDuplicateExpensePrefill EUR indexado BS_BCV y bloqueo de BS_USDT en EUR', () => {
    const prefillIdx = buildDuplicateExpensePrefill({
        comercio: 'Farmacia',
        fecha: '2026-11-02',
        moneda: 'VES',
        total_original: 45000,
        total_eur: 1000,
        tasa_cambio: 45.0,
        fuente_tasa_cambio: 'BCV (Pago en Bs. indexado a EUR)',
        items: [{ descripcion: 'Vitamina', cantidad: 1, precio_unitario: 45000, total: 45000, categoria: 'Salud' }],
    }, { todayCaracasIso: '2026-11-25' });

    assert.equal(prefillIdx.moneda, 'EUR');
    assert.equal(prefillIdx.metodoLiquidacion, 'BS_BCV');
    assert.equal(prefillIdx.totalOriginalFixed, '10.00');
    assert.equal(prefillIdx.items[0].total, '10.00');

    const prefillGuard = buildDuplicateExpensePrefill({
        comercio: 'Prueba EUR',
        moneda: 'EUR',
        metodo_liquidacion: 'BS_USDT',
        total_original: 1200,
    }, { todayCaracasIso: '2026-11-25' });

    assert.equal(prefillGuard.moneda, 'EUR');
    assert.equal(prefillGuard.metodoLiquidacion, 'BS_BCV');
});

test('UX-21: buildDuplicateExpensePrefill VES puro conserva monto nominal en bolívares', () => {
    const prefill = buildDuplicateExpensePrefill({
        comercio: 'Pasaje',
        fecha: '2026-11-01',
        moneda: 'VES',
        total_original: 20000,
        total_usd: 500,
        tasa_cambio: 40.0,
        fuente_tasa_cambio: 'BCV',
        items: [{ descripcion: 'Pasaje', cantidad: 1, precio_unitario: 20000, total: 20000, categoria: 'Transporte' }],
    }, { todayCaracasIso: '2026-11-25' });

    assert.equal(prefill.moneda, 'VES');
    assert.equal(prefill.totalOriginalFixed, '200.00');
    assert.equal(prefill.items[0].total, '200.00');
});
