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
