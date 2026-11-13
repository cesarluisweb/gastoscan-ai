import test from 'node:test';
import assert from 'node:assert/strict';
import {
    normalizeProductText,
    normalizeCommerce,
    formatCommerceDisplay,
    isTaxItem,
    formatRelativePriceDate,
    findPriceHistoryFromGastos,
    evaluatePriceComparison,
} from '../src/lib/price-comparator.js';

const REF_DATE = '2026-11-13';

test('Normalización de producto y comercio en paridad con Flutter', () => {
    assert.equal(normalizeProductText('Café Molido Gourmet (E)'), 'cafe molido gourmet');
    assert.equal(normalizeProductText('Pañales Etapa 3!'), 'panales etapa 3');
    assert.equal(isTaxItem('Impuesto IVA'), true);
    assert.equal(isTaxItem('IVA 16%'), true);
    assert.equal(isTaxItem('Harina PAN'), false);

    assert.equal(normalizeCommerce('FARMATODO, C.A. J-00020200-1'), 'farmatodo');
    assert.equal(normalizeCommerce('Farmatodo C.C.'), 'farmatodo');
    assert.equal(normalizeCommerce("Automercados Plaza's, C.A."), 'automercado plaza');
    assert.equal(normalizeCommerce('Compra general'), '');
    assert.equal(formatCommerceDisplay('FARMATODO, C.A. J-00020200-1'), 'Farmatodo');
});

test('Etiquetas de fecha relativa: hoy, ayer, días, semanas y meses', () => {
    assert.equal(formatRelativePriceDate('2026-11-13', REF_DATE), 'hoy');
    assert.equal(formatRelativePriceDate('2026-11-12', REF_DATE), 'ayer');
    assert.equal(formatRelativePriceDate('2026-11-08', REF_DATE), 'hace 5 días');
    assert.equal(formatRelativePriceDate('2026-10-30', REF_DATE), 'hace 2 semanas');
    assert.equal(formatRelativePriceDate('2026-10-09', REF_DATE), 'hace 1 mes');
    assert.equal(formatRelativePriceDate('2026-09-14', REF_DATE), 'hace 2 meses');
});

test('Prioridad de comercio vs mejor precio del mercado y ventana 30/31/60/61 días', () => {
    const gastos = [
        {
            id: 'g1',
            fecha: '2026-10-24', // 20 días
            comercio: 'Excelsior Gama, C.A.',
            moneda: 'USD',
            total_original: 220,
            total_usd: 220,
            tasa_cambio: 50,
            items: [{ descripcion: 'Harina PAN 1kg', cantidad: 1, precio_unitario: 220, total: 220 }],
        },
        {
            id: 'g2',
            fecha: '2026-11-01', // 12 días (mejor precio)
            comercio: 'Central Madeirense C.C.',
            moneda: 'USD',
            total_original: 180,
            total_usd: 180,
            tasa_cambio: 50,
            items: [{ descripcion: 'Harina Pan 1kg (E)', cantidad: 1, precio_unitario: 180, total: 180 }],
        },
        {
            id: 'g3',
            fecha: '2026-11-08', // 5 días (mismo comercio)
            comercio: 'FARMATODO, C.A.',
            moneda: 'USD',
            total_original: 200,
            total_usd: 200,
            tasa_cambio: 50,
            items: [{ descripcion: 'HARINA PAN 1KG', cantidad: 1, precio_unitario: 200, total: 200 }],
        },
        {
            id: 'g4',
            fecha: '2026-10-04', // 40 días (entre 31 y 60 días)
            comercio: 'Unicasa',
            moneda: 'USD',
            total_original: 350,
            total_usd: 350,
            tasa_cambio: 50,
            items: [{ descripcion: 'Aceite Vegetal', cantidad: 1, precio_unitario: 350, total: 350 }],
        },
        {
            id: 'g5',
            fecha: '2026-09-12', // 62 días (fuera de ventana)
            comercio: 'Tienda Vieja',
            moneda: 'USD',
            total_original: 100,
            total_usd: 100,
            tasa_cambio: 50,
            items: [{ descripcion: 'Azúcar Refinada', cantidad: 1, precio_unitario: 100, total: 100 }],
        },
    ];

    const historyMap = findPriceHistoryFromGastos(
        gastos,
        ['Harina PAN 1kg', 'Aceite Vegetal', 'Azúcar Refinada'],
        { comercioActual: 'Farmatodo C.C.', referenceDate: REF_DATE }
    );

    // 1. Azúcar Refinada (>60 días) no entra
    assert.equal(historyMap['azucar refinada'], undefined);

    // 2. Harina PAN en el mismo comercio (Farmatodo: $2.00 hace 5 días) -> hoy $2.40 (+20%)
    const verdictSame = evaluatePriceComparison({
        currentUnitUsd: 2.40,
        history: historyMap['harina pan 1kg'],
        comercioActual: 'Farmatodo',
        referenceDate: REF_DATE,
    });
    assert.deepEqual(verdictSame, {
        text: '🔺 Está 20% más caro por unidad en Farmatodo (hace 5 días)',
        tone: 'error',
    });

    // 3. Harina PAN en otro comercio (Plazas) -> compara con mejor precio ($1.80 en Central Madeirense hace 1 semana)
    const verdictMarket = evaluatePriceComparison({
        currentUnitUsd: 1.44,
        history: historyMap['harina pan 1kg'],
        comercioActual: 'Automercado Plaza',
        referenceDate: REF_DATE,
    });
    assert.deepEqual(verdictMarket, {
        text: '🟢 Te salió un 20% más económico por unidad que en Central Madeirense (hace 1 semana)',
        tone: 'good',
    });

    // 4. Silencio bajo 5% ($2.04 vs $2.00 = +2%)
    const verdictSilent = evaluatePriceComparison({
        currentUnitUsd: 2.04,
        history: historyMap['harina pan 1kg'],
        comercioActual: 'Farmatodo',
        referenceDate: REF_DATE,
    });
    assert.equal(verdictSilent, null);

    // 5. Referencia entre 31 y 60 días (Aceite Vegetal: hace 40 días -> sin porcentaje)
    const verdictOld = evaluatePriceComparison({
        currentUnitUsd: 5.00,
        history: historyMap['aceite vegetal'],
        comercioActual: 'Farmatodo',
        referenceDate: REF_DATE,
    });
    assert.deepEqual(verdictOld, {
        text: 'Referencia: $3.50/ud en Unicasa (hace 1 mes)',
        tone: 'muted',
    });
});
