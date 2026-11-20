// Módulo puro de cálculos monetarios y conversiones de gastos para Rinde Más.
// Paridad 100% matemática con lib/ui/screens/review_expense_screen.dart y dinero-datos.md

/**
 * Computa todos los campos monetarios de un gasto para persistir en Firestore y reportar.
 *
 * @param {Object} params
 * @param {string} params.moneda - Moneda seleccionada: 'USD' | 'VES' | 'EUR' | 'USDT'
 * @param {number} params.monto - Monto nominal total en la moneda seleccionada
 * @param {string|null} [params.metodoLiquidacion] - 'DIVISA' | 'BS_BCV' | 'BS_USDT'
 * @param {number} params.tasaUsd - Tasa USD BCV de referencia (> 0)
 * @param {number} params.tasaEur - Tasa EUR BCV de referencia (> 0)
 * @param {number} params.tasaUsdt - Tasa USDT P2P de referencia (> 0)
 * @param {number|null} [params.tasaCobrada] - Tasa personalizada cobrada en caja
 * @param {number|null} [params.bolivaresManuales] - Bolívares finales pagados en tarjeta/punto
 *
 * @returns {Object} Totales en céntimos, tasas aplicadas y metadatos canónicos
 */
export function computeExpenseTotals({
    moneda,
    monto,
    metodoLiquidacion = null,
    tasaUsd = 1.0,
    tasaEur = 1.0,
    tasaUsdt = 1.0,
    tasaCobrada = null,
    bolivaresManuales = null,
}) {
    const totalOrig = Number(monto || 0);
    const refUsd = Number(tasaUsd) > 0 ? Number(tasaUsd) : 1.0;
    const refEur = Number(tasaEur) > 0 ? Number(tasaEur) : refUsd;
    const refUsdt = Number(tasaUsdt) > 0 ? Number(tasaUsdt) : refUsd;

    let monedaFinal = moneda;
    let totalOriginalCentavos = Math.round(totalOrig * 100);
    let totalUsdCentavos = 0;
    let totalUsdtCentavos = 0;
    let totalEurCentavos = 0;
    let tasaCambio = refUsd;
    let tasaEurGuardada = refEur;
    let tasaUsdtGuardada = refUsdt;
    let fuenteFinal = 'BCV';
    let metodoLiqFinal = (moneda === 'USD' || moneda === 'EUR') ? (metodoLiquidacion || 'DIVISA') : null;
    let ratioConversionItems = 1.0;

    if (moneda === 'VES') {
        totalUsdCentavos = Math.round((totalOrig / refUsd) * 100);
        totalEurCentavos = Math.round((totalOrig / refEur) * 100);
        totalUsdtCentavos = Math.round((totalOrig / refUsdt) * 100);
        tasaCambio = refUsd;
        tasaEurGuardada = refEur;
        tasaUsdtGuardada = refUsdt;
        fuenteFinal = 'BCV';
        metodoLiqFinal = null;
    } else if ((moneda === 'USD' || moneda === 'EUR') && metodoLiquidacion === 'BS_BCV') {
        monedaFinal = 'VES';
        const tasaBase = (Number(tasaCobrada) > 0)
            ? Number(tasaCobrada)
            : (moneda === 'EUR' ? refEur : refUsd);

        let totalVes = (Number(bolivaresManuales) > 0)
            ? Number(bolivaresManuales)
            : (totalOrig * tasaBase);

        totalOriginalCentavos = Math.round(totalVes * 100);

        if (moneda === 'EUR') {
            // EUR liquidado en Bs a tasa BCV
            const effectiveEurRate = (Number(bolivaresManuales) > 0 && totalOrig > 0)
                ? (totalVes / totalOrig)
                : tasaBase;
            tasaCambio = effectiveEurRate;
            tasaEurGuardada = effectiveEurRate;
            totalUsdCentavos = Math.round((totalVes / refUsd) * 100);
            totalEurCentavos = Math.round((totalVes / effectiveEurRate) * 100);
            totalUsdtCentavos = Math.round((totalVes / refUsdt) * 100);
            fuenteFinal = 'BCV (Pago en Bs. indexado a EUR)';
        } else {
            // USD liquidado en Bs a tasa BCV
            const effectiveUsdRate = (Number(bolivaresManuales) > 0 && totalOrig > 0)
                ? (totalVes / totalOrig)
                : tasaBase;
            tasaCambio = effectiveUsdRate;
            totalUsdCentavos = Math.round((totalVes / effectiveUsdRate) * 100);
            totalEurCentavos = Math.round((totalVes / refEur) * 100);
            totalUsdtCentavos = Math.round((totalVes / refUsdt) * 100);
            fuenteFinal = 'BCV (Pago en Bs. indexado a USD)';
        }

        ratioConversionItems = totalOrig > 0 ? (totalVes / totalOrig) : tasaBase;
    } else if (moneda === 'USD' && metodoLiquidacion === 'BS_USDT') {
        monedaFinal = 'VES';
        const tasaUsdtEfectiva = (Number(tasaCobrada) > 0) ? Number(tasaCobrada) : refUsdt;
        let totalVes = (Number(bolivaresManuales) > 0)
            ? Number(bolivaresManuales)
            : (totalOrig * tasaUsdtEfectiva);

        totalOriginalCentavos = Math.round(totalVes * 100);
        // Paridad estricta móvil: total_usd divide por la tasa USD BCV de referencia
        totalUsdCentavos = Math.round((totalVes / refUsd) * 100);
        totalEurCentavos = Math.round((totalVes / refEur) * 100);
        totalUsdtCentavos = Math.round((totalVes / tasaUsdtEfectiva) * 100);

        tasaCambio = refUsd;
        tasaUsdtGuardada = tasaUsdtEfectiva;
        tasaEurGuardada = refEur;
        fuenteFinal = 'Binance P2P (Pago en Bs. indexado a USDT)';
        ratioConversionItems = totalOrig > 0 ? (totalVes / totalOrig) : tasaUsdtEfectiva;
    } else if (moneda === 'EUR') {
        // EUR Divisa Directa
        const eurRate = (Number(tasaCobrada) > 0) ? Number(tasaCobrada) : refEur;
        const totalVesEquiv = totalOrig * eurRate;
        totalOriginalCentavos = Math.round(totalOrig * 100);
        totalEurCentavos = Math.round(totalOrig * 100);
        totalUsdCentavos = Math.round((totalVesEquiv / refUsd) * 100);
        totalUsdtCentavos = totalUsdCentavos;
        tasaCambio = refUsd;
        tasaEurGuardada = eurRate;
        tasaUsdtGuardada = refUsdt;
        fuenteFinal = `Euro BCV (Bs. ${eurRate.toFixed(2)})`;
    } else if (moneda === 'USDT') {
        totalOriginalCentavos = Math.round(totalOrig * 100);
        totalUsdCentavos = Math.round(totalOrig * 100);
        totalUsdtCentavos = Math.round(totalOrig * 100);
        const totalVesEquiv = totalOrig * refUsd;
        totalEurCentavos = Math.round((totalVesEquiv / refEur) * 100);
        tasaCambio = refUsd;
        tasaUsdtGuardada = refUsdt;
        tasaEurGuardada = refEur;
        fuenteFinal = 'Binance P2P';
        metodoLiqFinal = null;
    } else {
        // USD Divisa Directa
        totalOriginalCentavos = Math.round(totalOrig * 100);
        totalUsdCentavos = Math.round(totalOrig * 100);
        totalUsdtCentavos = Math.round(totalOrig * 100);
        const totalVesEquiv = totalOrig * refUsd;
        totalEurCentavos = Math.round((totalVesEquiv / refEur) * 100);
        tasaCambio = refUsd;
        tasaEurGuardada = refEur;
        tasaUsdtGuardada = refUsdt;
        fuenteFinal = 'Divisa Directa';
    }

    return {
        moneda: monedaFinal,
        total_original: totalOriginalCentavos,
        total_usd: totalUsdCentavos,
        total_usdt: totalUsdtCentavos,
        total_eur: totalEurCentavos,
        tasa_cambio: tasaCambio,
        tasa_usdt: tasaUsdtGuardada,
        tasa_eur: tasaEurGuardada,
        metodo_liquidacion: metodoLiqFinal,
        fuente_tasa_cambio: fuenteFinal,
        ratioConversionItems,
    };
}

/**
 * Calcula los centavos unitario y total para un ítem, respetando la preservación de centavos sin redondeo flotante.
 */
export function computeItemCents(item, ratioConversion = 1.0) {
    const cant = Number(item.cantidad) || 1;
    const precio = Number(item.precio) || 0;
    const nominalTotal = (item.initCant !== undefined && item.initPrecio !== undefined && cant === item.initCant && precio === item.initPrecio && item.total !== undefined)
        ? (Number(item.total) || (cant * precio))
        : (cant * precio);

    const isUnchangedIndexed = (
        item.origBsTotal !== null &&
        item.origBsTotal !== undefined &&
        item.origBsPrecio !== null &&
        item.origBsPrecio !== undefined &&
        item.initRate !== null &&
        item.initRate !== undefined &&
        Math.abs(ratioConversion - item.initRate) < 0.0001 &&
        cant === item.initCant &&
        precio === item.initPrecio
    );

    if (isUnchangedIndexed) {
        return {
            precio_unitario: item.origBsPrecio,
            total: item.origBsTotal,
        };
    }

    const finalPrice = Math.round(precio * ratioConversion * 100);
    const finalTotal = Math.round(nominalTotal * ratioConversion * 100);

    return {
        precio_unitario: finalPrice,
        total: finalTotal,
    };
}

/**
 * Acumula los totales mensuales en las 4 divisas (USD BCV, VES, USDT P2P, EUR BCV)
 * respetando la inmutabilidad del bolívar en gastos VES y los fallbacks de tasas.
 * Fuente única compartida entre renderMetrics (panel.astro) y buildSemanticChatContext (ai-assistant.js).
 *
 * @param {Array<Object>} gastos - Lista de documentos de gasto activos del mes
 * @param {Object} liveRates - Tasas de referencia vigentes { usd, eur, usdt }
 * @returns {{ sumUsd: number, sumVes: number, sumUsdt: number, sumEur: number }}
 */
export function computeMonthTotals(gastos = [], liveRates = {}) {
    let sumUsd = 0;
    let sumVes = 0;
    let sumUsdt = 0;
    let sumEur = 0;

    const list = Array.isArray(gastos) ? gastos : [];
    const liveUsd = Number(liveRates?.usd || 0);
    const liveEur = Number(liveRates?.eur || 0);
    const liveUsdt = Number(liveRates?.usdt || 0);

    for (const g of list) {
        if (!g) continue;
        const totalUsd = Number(g.total_usd || 0) / 100.0;
        const totalOrig = Number(g.total_original || 0) / 100.0;
        const tasa = Number(g.tasa_cambio || 0) > 0 ? Number(g.tasa_cambio) : (liveUsd || 1.0);

        sumUsd += totalUsd;

        let totalUsdt = 0;
        if (g.total_usdt !== undefined && g.total_usdt !== null) {
            totalUsdt = Number(g.total_usdt || 0) / 100.0;
        } else if (g.moneda === 'USD') {
            totalUsdt = totalUsd;
        } else {
            const tUsdt = Number(g.tasa_usdt || 0) > 0 ? Number(g.tasa_usdt) : (liveUsdt > 0 ? liveUsdt : 0);
            totalUsdt = tUsdt > 0 ? (totalOrig / tUsdt) : 0;
        }
        sumUsdt += totalUsdt;

        let totalEur = 0;
        if (g.total_eur !== undefined && g.total_eur !== null) {
            totalEur = Number(g.total_eur || 0) / 100.0;
        } else if (g.moneda === 'EUR') {
            totalEur = totalOrig;
        } else {
            const tEur = Number(g.tasa_eur || 0) > 0 ? Number(g.tasa_eur) : (liveEur > 0 ? liveEur : 0);
            totalEur = tEur > 0
                ? (g.moneda === 'VES' ? totalOrig / tEur : (totalUsd * (tasa > 0 ? tasa : 1.0)) / tEur)
                : 0;
        }
        sumEur += totalEur;

        if (g.moneda === 'VES') {
            // Inmutabilidad del bolívar: los gastos en VES suman su monto original
            sumVes += totalOrig;
        } else {
            // Gastos en divisas (USD, EUR, USDT) se convierten determinísticamente con su tasa
            sumVes += totalUsd * (tasa > 0 ? tasa : 1.0);
        }
    }

    return { sumUsd, sumVes, sumUsdt, sumEur };
}

/**
 * Calculadora de Salud Financiera y Ahorro (Paridad exacta con SavingsHealthCalculator en Flutter).
 */
export function calculateSavingsHealth({
    presupuestoGeneral,
    metaAhorro,
    gastoAcumulado,
    diaActual,
    diasTotalesMes,
    diasGracia = 3,
}) {
    const gen = Math.max(0, Number(presupuestoGeneral) || 0);
    const metaClamped = Math.max(0, Math.min(Number(metaAhorro) || 0, gen));
    const limite = Math.max(0, gen - metaClamped);
    const gasto = Math.max(0, Number(gastoAcumulado) || 0);
    const disponible = Math.max(0, limite - gasto);

    const totalDias = diasTotalesMes > 0 ? diasTotalesMes : 30;
    const diasValidos = Math.max(1, Math.min(diaActual, totalDias));

    const gastoDiario = diasValidos > 0 ? (gasto / diasValidos) : 0;
    const gastoProyectado = gastoDiario * totalDias;

    let status = 'sinMeta';
    if (metaClamped <= 0) {
        status = 'sinMeta';
    } else if (gasto > limite) {
        status = 'comprometida';
    } else if (diasValidos <= diasGracia) {
        status = 'protegida';
    } else if (gastoProyectado > limite) {
        status = 'enRiesgo';
    } else {
        status = 'protegida';
    }

    return {
        presupuestoGeneral: gen,
        metaAhorro: metaClamped,
        limiteParaGastar: limite,
        gastoAcumulado: gasto,
        disponibleParaGastar: disponible,
        diasTranscurridos: diasValidos,
        diasTotalesMes: totalDias,
        gastoDiarioPromedio: gastoDiario,
        gastoProyectadoFinDeMes: gastoProyectado,
        status,
    };
}
