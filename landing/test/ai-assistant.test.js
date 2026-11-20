import test from 'node:test';
import assert from 'node:assert/strict';
import {
    DEFAULT_CHAT_SUGGESTIONS,
    getVenezuelaTodayIso,
    getDefaultExpenseDateForMonth,
    parseExtractionDate,
    resolveSpokenExpenseDate,
    buildSavingsHealthInBudgetCurrency,
    buildSemanticChatContext,
    isShoppingListQuery,
    prepareChatExtractions,
    createExtractionQueue,
    transitionExtractionItem,
    sliceRecentChatMessages,
    escapeHtml,
    formatAssistantMessageHtml,
    mapChatHttpError,
} from '../src/lib/ai-assistant.js';

const LIVE_RATES = { usd: 50.0, eur: 54.0, usdt: 58.0 };

test('getVenezuelaTodayIso y getDefaultExpenseDateForMonth usan calendario VET (UTC-4)', () => {
    // 2026-11-21T01:30:00Z en UTC ya es 21 de noviembre, pero en Caracas (UTC-4) es 20 de noviembre 21:30
    const lateEveningUtc = new Date('2026-11-21T01:30:00.000Z');
    assert.equal(getVenezuelaTodayIso(lateEveningUtc), '2026-11-20');

    // Mes actual devuelve hoy; febrero acota día 31 al 28
    assert.equal(
        getDefaultExpenseDateForMonth({ selectedYear: 2026, selectedMonth: 11, todayCaracasIso: '2026-11-20' }),
        '2026-11-20'
    );
    assert.equal(
        getDefaultExpenseDateForMonth({ selectedYear: 2026, selectedMonth: 2, todayCaracasIso: '2026-03-31' }),
        '2026-02-28'
    );
});

test('parseExtractionDate y resolveSpokenExpenseDate resuelven ayer, antier, hace X días, DD/MM/YYYY y neutralizan futuro', () => {
    const today = '2026-11-20';
    assert.equal(parseExtractionDate('03/11/2026', today), '2026-11-03');
    assert.equal(parseExtractionDate('03-11-26', today), '2026-11-03');
    assert.equal(parseExtractionDate('2026-11-03', today), '2026-11-03');

    assert.equal(resolveSpokenExpenseDate('Ayer compré pan en 5$', '2026-10-01', today), '2026-11-19');
    assert.equal(resolveSpokenExpenseDate('Antier pagué el agua', '2026-11-20', today), '2026-11-18');
    assert.equal(resolveSpokenExpenseDate('Hace 3 días gasté 10$', '2026-11-20', today), '2026-11-17');
    assert.equal(resolveSpokenExpenseDate('Hace dos días compré café', '2026-11-20', today), '2026-11-18');
    // Sin referencia temporal -> siempre hoy (neutraliza alucinación del modelo)
    assert.equal(resolveSpokenExpenseDate('Compré queso en 8$', '2025-04-12', today), '2026-11-20');
    // Referencia de calendario sin año explícito -> fuerza año actual
    assert.equal(resolveSpokenExpenseDate('El 5 de noviembre gasté 20$', '2025-11-05', today), '2026-11-05');
    // Fecha futura -> bloqueada y devuelta como hoy
    assert.equal(resolveSpokenExpenseDate('El 25 de noviembre compré harina', '2026-11-25', today), '2026-11-20');
});

test('buildSemanticChatContext calcula salud en moneda del presupuesto (VES) y excluye impuestos con isTaxItem', () => {
    const gastos = [
        {
            fecha: '2026-11-10',
            comercio: 'Excelsior Gama',
            categoria: 'Alimentación',
            moneda: 'VES',
            total_original: 100000, // Bs. 1.000,00
            total_usd: 2000,        // $20,00
            total_usdt: 1724,       // 17,24 USDT
            tasa_cambio: 50.0,
            tasa_usdt: 58.0,
            tasa_eur: 54.0,
            items: [
                { descripcion: 'Harina PAN', cantidad: 2, total: 50000 },
                { descripcion: 'IVA 16%', cantidad: 1, total: 16000 },
                { descripcion: 'IVA 8%', cantidad: 1, total: 8000 },
                { descripcion: 'Impuesto', cantidad: 1, total: 5000 },
                { descripcion: 'Tax', cantidad: 1, total: 5000 },
                { descripcion: 'Queso blanco', cantidad: 1, total: 16000 },
            ],
        },
        {
            // Documento sin fecha (comprueba comparador defensivo en ultimas_compras)
            comercio: 'Farmatodo',
            categoria: 'Salud',
            moneda: 'USD',
            total_original: 1000, // $10,00
            total_usd: 1000,
            total_usdt: 1000,
            tasa_cambio: 50.0,
            items: [{ descripcion: 'Acetaminofen', cantidad: 1, total: 1000 }],
        },
    ];

    const presupuesto = {
        general: 5000,     // Bs. 5.000
        meta_ahorro: 1000, // Bs. 1.000 -> límite = Bs. 4.000
        moneda: 'VES',
        categorias: { Alimentación: 3000 },
    };

    // Aunque el usuario esté mirando el lente USD en el panel, la salud de ahorro DEBE ir en VES
    const { snapshot } = buildSavingsHealthInBudgetCurrency({
        gastos,
        presupuesto,
        liveRates: LIVE_RATES,
        selectedYear: 2026,
        selectedMonth: 11,
        todayCaracasIso: '2026-11-15',
    });
    assert.equal(snapshot.limiteParaGastar, 4000);
    // sumVes = 1000 (VES) + 10 * 50 (USD) = 1500 Bs -> proyectado a 30 días desde día 15 = 3000 Bs
    assert.equal(snapshot.gastoAcumulado, 1500);
    assert.equal(snapshot.gastoProyectadoFinDeMes, 3000);
    assert.equal(snapshot.status, 'protegida');

    const ctx = buildSemanticChatContext({
        gastos,
        presupuesto,
        liveRates: LIVE_RATES,
        selectedYear: 2026,
        selectedMonth: 11,
        todayCaracasIso: '2026-11-15',
    });

    assert.equal(ctx.moneda_principal, 'VES');
    assert.equal(ctx.moneda_presupuesto, 'VES');
    assert.equal(ctx.total_usd, 30);
    assert.equal(ctx.total_usd_bcv, 30);
    assert.equal(ctx.total_ves, 1500);
    assert.equal(ctx.limite_para_gastar, 4000);
    assert.equal(ctx.gasto_proyectado_fin_mes, 3000);
    assert.equal(ctx.lista_compras, null);
    assert.equal(ctx.lista_compras_disponible, false);

    // Verificar exclusión de IVA 16%, IVA 8%, Impuesto y Tax en top_productos_mes
    const nombresTop = ctx.top_productos_mes.map((p) => p.producto);
    assert.deepEqual(nombresTop, ['Harina PAN', 'Queso blanco', 'Acetaminofen']);
    // Verificar prorrateo USD de Harina PAN: (50000 / 100000) * 20 = $10.00
    assert.equal(ctx.top_productos_mes[0].total_usd, 10);
    // Verificar 7 campos exactos en ultimas_compras
    assert.deepEqual(Object.keys(ctx.ultimas_compras[0]), [
        'fecha',
        'comercio',
        'categoria',
        'moneda',
        'monto_original',
        'total_usd',
        'total_usdt',
    ]);
});

test('isShoppingListQuery NO intercepta ninguno de los 5 chips de sugerencias web, pero sí intercepta lista de compras', () => {
    assert.equal(DEFAULT_CHAT_SUGGESTIONS.length, 5);
    for (const s of DEFAULT_CHAT_SUGGESTIONS) {
        assert.equal(
            isShoppingListQuery(s.label),
            false,
            `El chip "${s.label}" no debe activar el aviso de lista de compras`
        );
    }
    assert.equal(isShoppingListQuery('Anota leche en mi lista de compras'), true);
    assert.equal(isShoppingListQuery('¿Qué tengo en mi lista?'), true);
    assert.equal(isShoppingListQuery('cualquier texto', 'agregar_items_lista_compras'), true);
});

test('prepareChatExtractions: EUR + BS_USDT fuerza BS_BCV y usa tasa EUR, inferencia de método, repregunta y múltiples comercios', () => {
    const today = '2026-11-20';

    // 1. I1: EUR con BS_USDT -> fuerza BS_BCV y usa liveRates.eur (54.0)
    const eurRes = prepareChatExtractions({
        callArgs: {
            comercio: 'Zara',
            moneda: 'EUR',
            monto_original: 40,
            total_usd: 43.2,
            metodo_liquidacion: 'BS_USDT',
            categoria: 'Ropa',
            items: [{ descripcion: 'Camisa blanca', cantidad: 2, precio_unitario: 20 }],
        },
        rawUserText: 'Pagué 40 euros en Zara a paralelo',
        liveRates: LIVE_RATES,
        todayCaracasIso: today,
    });
    assert.equal(eurRes.type, 'extractions');
    assert.equal(eurRes.prefills[0].moneda, 'EUR');
    assert.equal(eurRes.prefills[0].metodoLiquidacion, 'BS_BCV');
    assert.equal(eurRes.prefills[0].tasaCambioDetectada, 54.0);
    assert.equal(eurRes.prefills[0].items[0].precio, '20.00');
    assert.equal(eurRes.prefills[0].items[0].total, '40.00');

    // 2. I5: Inferencia de método desde texto ("pago móvil" -> BS_BCV) y clasificación automática de ítem
    const pagoMovilRes = prepareChatExtractions({
        callArgs: {
            comercio: 'Farmatodo',
            moneda: 'USD',
            monto_original: 12,
            total_usd: 12,
            categoria: 'Otros',
            items: [{ descripcion: 'Acetaminofen 500mg', cantidad: 1, precio_unitario: 12 }],
        },
        rawUserText: 'Gasté 12 dólares en Farmatodo por pago móvil',
        liveRates: LIVE_RATES,
        todayCaracasIso: today,
    });
    assert.equal(pagoMovilRes.prefills[0].metodoLiquidacion, 'BS_BCV');
    assert.equal(pagoMovilRes.prefills[0].items[0].categoria, 'Salud');

    // 3. I5: Repregunta cuando falta precio en compra pasada
    const noPriceRes = prepareChatExtractions({
        callArgs: {
            comercio: 'New Market',
            monto_original: 0,
            total_usd: 0,
            items: [{ descripcion: 'Queso', cantidad: 1 }],
        },
        rawUserText: 'Compré queso en New Market',
        liveRates: LIVE_RATES,
        todayCaracasIso: today,
    });
    assert.equal(noPriceRes.type, 'clarification');
    assert.match(noPriceRes.clarificationText, /cuánto te costó en total/i);

    // 4. I5: Múltiples comercios en args.gastos (3 compras)
    const multiRes = prepareChatExtractions({
        callArgs: {
            gastos: [
                { comercio: 'Farmatodo', moneda: 'USD', monto_original: 10, categoria: 'Salud', items: [{ descripcion: 'Ibuprofeno', cantidad: 1, precio_unitario: 10 }] },
                { comercio: 'Panadería', moneda: 'VES', monto_original: 250, categoria: 'Alimentación', items: [{ descripcion: 'Pan campesino', cantidad: 2, precio_unitario: 125 }] },
                { comercio: 'Estación de Servicio', moneda: 'USD', monto_original: 15, categoria: 'Transporte', items: [{ descripcion: 'Gasolina', cantidad: 1, precio_unitario: 15 }] },
            ],
        },
        rawUserText: 'Ayer compré en Farmatodo, Panadería y gasolina',
        liveRates: LIVE_RATES,
        todayCaracasIso: today,
    });
    assert.equal(multiRes.type, 'extractions');
    assert.equal(multiRes.prefills.length, 3);
    assert.equal(multiRes.prefills[0].fecha, '2026-11-19');
    assert.equal(multiRes.prefills[1].moneda, 'VES');
    assert.equal(multiRes.prefills[1].items[0].precio, '125.00');
    assert.equal(multiRes.prefills[1].items[0].total, '250.00');
});

test('B2: Máquina de estados de cola de compras distingue save de close_without_save, guardar 2 de 3 y descartar 1 de 2', () => {
    const prefills = [
        { __isExpensePrefill: true, comercio: 'Comercio 1', totalOriginalFixed: '10.00' },
        { __isExpensePrefill: true, comercio: 'Comercio 2', totalOriginalFixed: '20.00' },
        { __isExpensePrefill: true, comercio: 'Comercio 3', totalOriginalFixed: '30.00' },
    ];
    let queue = createExtractionQueue(prefills, 'msg1');
    assert.equal(queue.length, 3);
    assert.equal(queue[0].status, 'pending');

    // Abrir la compra 2 de 3 y guardarla
    ({ queue } = transitionExtractionItem(queue, 'msg1_2', 'open'));
    assert.equal(queue[1].status, 'opened');

    let nextPendingItem;
    ({ queue, nextPendingItem } = transitionExtractionItem(queue, 'msg1_2', 'save', { gastoId: 'g-2' }));
    assert.equal(queue[1].status, 'saved');
    assert.equal(queue[1].savedGastoId, 'g-2');
    assert.equal(nextPendingItem.id, 'msg1_1');

    // Doble guarda B2: cerrar el modal después de guardar NO debe revertir 'saved' a 'pending'
    ({ queue } = transitionExtractionItem(queue, 'msg1_2', 'close_without_save'));
    assert.equal(queue[1].status, 'saved');

    // Abrir la compra 1 y cerrarla sin guardar -> vuelve a 'pending'
    ({ queue } = transitionExtractionItem(queue, 'msg1_1', 'open'));
    assert.equal(queue[0].status, 'opened');
    ({ queue } = transitionExtractionItem(queue, 'msg1_1', 'close_without_save'));
    assert.equal(queue[0].status, 'pending');

    // Descartar la compra 1 -> pasa a 'discarded' y sugiere la compra 3
    ({ queue, nextPendingItem } = transitionExtractionItem(queue, 'msg1_1', 'discard'));
    assert.equal(queue[0].status, 'discarded');
    assert.equal(nextPendingItem.id, 'msg1_3');
});

test('B3: sliceRecentChatMessages conserva contrato exacto { role: user|assistant, text } para el Worker', () => {
    const history = [
        { role: 'assistant', text: 'Hola', extraField: 'ignore' },
        { role: 'user', text: 'Uno' },
        { role: 'assistant', text: 'Dos' },
        { role: 'user', text: 'Tres' },
        { role: 'assistant', text: 'Cuatro' },
        { role: 'user', text: 'Cinco' },
    ];
    const sliced = sliceRecentChatMessages(history, 5);
    assert.equal(sliced.length, 5);
    assert.deepEqual(Object.keys(sliced[0]), ['role', 'text']);
    assert.equal(sliced[0].role, 'user');
    assert.equal(sliced[0].text, 'Uno');
    assert.equal(sliced[1].role, 'assistant');
    assert.equal(sliced[1].text, 'Dos');
    assert.equal('content' in sliced[1], false);
});

test('Seguridad XSS en texto del asistente, comercio e ítems y mapeo de errores HTTP', () => {
    const xssPayload = '<script>alert(1)</script>**Seguro**<img src=x onerror=alert(2)>';
    const html = formatAssistantMessageHtml(xssPayload);
    assert.equal(html.includes('<script>'), false);
    assert.equal(html.includes('<img'), false);
    assert.equal(html.includes('&lt;script&gt;'), true);
    assert.equal(html.includes('<strong class="font-bold text-slate-900">Seguro</strong>'), true);

    assert.equal(escapeHtml('Farmatodo <img onerror=1>'), 'Farmatodo &lt;img onerror=1&gt;');

    // Errores HTTP: 401, 413, 429 diario vs ráfaga, 502/503, 504 y timeout
    assert.match(mapChatHttpError(401), /sesión/i);
    assert.match(mapChatHttpError(413), /tamaño/i);
    assert.match(
        mapChatHttpError(429, { dailyLimitReached: true }),
        /50 consultas compartidas/i
    );
    assert.match(
        mapChatHttpError(429, { dailyLimitReached: false }),
        /muy rápido/i
    );
    assert.match(mapChatHttpError(503), /alta demanda/i);
    assert.match(mapChatHttpError(504), /conexión/i);
    assert.match(mapChatHttpError(0, null, { isAbort: true }), /45 s/i);
});
