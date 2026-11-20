// Módulo puro de la Calculadora Cambiaria y parser de montos para Rinde Más (Web).
// Paridad 1:1 con lib/core/utils/amount_parser.dart y lib/ui/screens/currency_calculator_screen.dart.

export const RATE_TYPES = Object.freeze({
    DOLAR_BCV: 'dolarBcv',
    EURO_BCV: 'euroBcv',
    USDT_P2P: 'usdtBinance',
    CUSTOM: 'personalizada',
});

/**
 * Parsea montos con formato venezolano ("1.234,56"), internacional ("1,234.56")
 * y decimales simples ("1234,56", "1234.56").
 * Port fiel de lib/core/utils/amount_parser.dart -> tryParseAmount.
 *
 * @param {unknown} value
 * @param {{ isPrice?: boolean }} [options]
 * @returns {number | null}
 */
export function parseAmount(value, { isPrice = false } = {}) {
    if (value === null || value === undefined) return null;

    if (typeof value === 'number') {
        if (!Number.isFinite(value)) return null;
        return value;
    }

    let s = String(value).trim();
    if (!s) return null;

    let negative = false;
    if (s.startsWith('-')) {
        negative = true;
        s = s.slice(1).trim();
    } else if (s.startsWith('+')) {
        s = s.slice(1).trim();
    }
    if (!s) return null;

    let parsed = Number.NaN;
    if (s.includes('.') || s.includes(',')) {
        s = s.replace(/[^\d.,]/g, '');
        if (!s) return null;

        if (s.includes(',') && s.includes('.')) {
            if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
                s = s.replace(/\./g, '').replace(/,/g, '.');
            } else {
                s = s.replace(/,/g, '');
            }
        } else {
            const dotCount = (s.match(/\./g) || []).length;
            const commaCount = (s.match(/,/g) || []).length;
            if (dotCount > 1) {
                // Múltiples puntos sin coma: separadores de miles (ej. 1.250.000)
                s = s.replace(/\./g, '');
            } else if (commaCount > 1) {
                // Múltiples comas sin punto: separadores de miles (ej. 1,250,000)
                s = s.replace(/,/g, '');
            } else {
                s = s.replace(/,/g, '.');
            }
        }
        parsed = Number(s);
    } else {
        s = s.replace(/[^\d]/g, '');
        if (!s) return null;
        if (isPrice) {
            if (s.length <= 2) {
                s = s.padStart(3, '0');
            }
            const len = s.length;
            parsed = Number(`${s.slice(0, len - 2)}.${s.slice(len - 2)}`);
        } else {
            parsed = Number(s);
        }
    }

    if (!Number.isFinite(parsed)) return null;
    return negative ? -parsed : parsed;
}

/**
 * Parsea un monto que debe ser estrictamente mayor a cero (> 0).
 *
 * @param {unknown} value
 * @param {{ isPrice?: boolean }} [options]
 * @returns {number | null}
 */
export function parsePositiveAmount(value, options = {}) {
    const parsed = parseAmount(value, options);
    if (parsed === null || parsed <= 0) return null;
    return parsed;
}

/**
 * Resuelve la tasa activa y la divisa correspondiente para la Calculadora Cambiaria.
 * Exige estrictamente tasa > 1.0 (paridad con CurrencyCalculatorScreen._obtenerTasaActiva).
 *
 * @param {{ tipoTasa: string, selectedCurrency?: string, rates?: { usd?: number, eur?: number, usdt?: number }, customRate?: unknown }} params
 * @returns {{ rate: number, currency: string }}
 */
export function resolveActiveCalculatorRate({
    tipoTasa = RATE_TYPES.DOLAR_BCV,
    selectedCurrency = 'USD',
    rates = {},
    customRate = 0,
}) {
    const usd = Number(rates?.usd || 0);
    const eur = Number(rates?.eur || 0);
    const usdt = Number(rates?.usdt || 0);
    const custom = parsePositiveAmount(customRate) ?? 0;

    if (tipoTasa === RATE_TYPES.EURO_BCV) {
        return { rate: eur > 1.0 ? eur : 0.0, currency: 'EUR' };
    }
    if (tipoTasa === RATE_TYPES.USDT_P2P) {
        return { rate: usdt > 1.0 ? usdt : 0.0, currency: 'USDT' };
    }
    if (tipoTasa === RATE_TYPES.CUSTOM) {
        const cur = ['USD', 'EUR', 'USDT'].includes(selectedCurrency) ? selectedCurrency : 'USD';
        return { rate: custom > 1.0 ? custom : 0.0, currency: cur };
    }
    return { rate: usd > 1.0 ? usd : 0.0, currency: 'USD' };
}

/**
 * Convierte un monto en divisa a Bolívares usando la tasa activa (> 1.0).
 * Devuelve string con 2 decimales (punto decimal) o '' si es inválido.
 */
export function convertFromDivisa(rawDivisa, activeRate) {
    const montoDivisa = parsePositiveAmount(rawDivisa);
    const tasa = Number(activeRate || 0);
    if (montoDivisa === null || tasa <= 1.0) return '';
    return (montoDivisa * tasa).toFixed(2);
}

/**
 * Convierte un monto en Bolívares a divisa usando la tasa activa (> 1.0).
 * Devuelve string con 2 decimales (punto decimal) o '' si es inválido.
 */
export function convertFromVes(rawVes, activeRate) {
    const montoVes = parsePositiveAmount(rawVes);
    const tasa = Number(activeRate || 0);
    if (montoVes === null || tasa <= 1.0) return '';
    return (montoVes / tasa).toFixed(2);
}

/**
 * Construye el cuadro comparativo simultáneo (Dólar BCV, Euro BCV, USDT P2P) y la brecha USDT vs BCV.
 * Paridad con CurrencyCalculatorScreen (currency_calculator_screen.dart:289-306 y 566-625).
 */
export function buildSimultaneousComparison({
    rawDivisa,
    rates = {},
    selectedTipoTasa = RATE_TYPES.DOLAR_BCV,
}) {
    const parsedDivisa = parsePositiveAmount(rawDivisa);
    const montoBase = parsedDivisa !== null ? parsedDivisa : 1.0;

    const tasaUsd = Number(rates?.usd || 0) > 1.0 ? Number(rates.usd) : 0.0;
    const tasaEur = Number(rates?.eur || 0) > 1.0 ? Number(rates.eur) : 0.0;
    const tasaUsdt = Number(rates?.usdt || 0) > 1.0 ? Number(rates.usdt) : 0.0;

    const brechaUsdtBcv = (tasaUsd > 1.0 && tasaUsdt > 1.0)
        ? ((tasaUsdt - tasaUsd) / tasaUsd) * 100
        : null;

    return {
        montoBase,
        brechaUsdtBcv,
        rows: [
            {
                id: RATE_TYPES.DOLAR_BCV,
                title: 'Dólar BCV',
                rate: tasaUsd,
                totalBs: tasaUsd > 1.0 ? montoBase * tasaUsd : null,
                isHighlighted: selectedTipoTasa === RATE_TYPES.DOLAR_BCV,
            },
            {
                id: RATE_TYPES.EURO_BCV,
                title: 'Euro BCV',
                rate: tasaEur,
                totalBs: tasaEur > 1.0 ? montoBase * tasaEur : null,
                isHighlighted: selectedTipoTasa === RATE_TYPES.EURO_BCV,
            },
            {
                id: RATE_TYPES.USDT_P2P,
                title: 'USDT P2P',
                rate: tasaUsdt,
                totalBs: tasaUsdt > 1.0 ? montoBase * tasaUsdt : null,
                isHighlighted: selectedTipoTasa === RATE_TYPES.USDT_P2P,
            },
        ],
    };
}

/**
 * Prepara el objeto prefill para abrir #modal-expense desde la Calculadora Cambiaria.
 * Paridad 1:1 con CurrencyCalculatorScreen._registrarComoGasto y ReviewExpenseScreen (Criterio 9, 14 y 15):
 * - Si isVesOnTop === true -> moneda = 'VES', metodoLiquidacion = null.
 * - Si isVesOnTop === false -> moneda = selectedCurrency ('USD' | 'EUR' | 'USDT'),
 *   metodoLiquidacion = 'DIVISA' para USD/EUR, null para USDT.
 * - Si tipoTasa === 'personalizada' y tasa > 1.0 -> conserva DIVISA sin cambiar moneda,
 *   enviando rateOverride: { currency, rate } y tasaCobrada: rate para que openExpenseModal
 *   aplique la tasa manual sobre activeRates sin tocar officialRates.
 */
export function buildCalculatorExpensePrefill({
    isVesOnTop = false,
    rawDivisa = '',
    rawVes = '',
    tipoTasa = RATE_TYPES.DOLAR_BCV,
    selectedCurrency = 'USD',
    rates = {},
    customRate = 0,
    defaultFechaIso = '',
}) {
    const { rate: activeRate, currency } = resolveActiveCalculatorRate({
        tipoTasa,
        selectedCurrency,
        rates,
        customRate,
    });

    const montoVes = parsePositiveAmount(rawVes);
    const montoDivisa = parsePositiveAmount(rawDivisa);

    if (montoVes === null && montoDivisa === null) {
        return {
            ok: false,
            error: 'Ingresa un monto válido para registrar el gasto.',
            prefill: null,
        };
    }

    const needsConversion = isVesOnTop ? montoVes === null : montoDivisa === null;
    if (needsConversion && activeRate <= 1.0) {
        return {
            ok: false,
            error: 'Ingresa o actualiza una tasa válida para convertir este monto.',
            prefill: null,
        };
    }

    let totalFinal;
    let monedaFinal;
    if (isVesOnTop) {
        totalFinal = montoVes !== null ? montoVes : montoDivisa * activeRate;
        monedaFinal = 'VES';
    } else {
        totalFinal = montoDivisa !== null ? montoDivisa : montoVes / activeRate;
        monedaFinal = currency;
    }

    const totalFixed = totalFinal.toFixed(2);
    const isCustom = tipoTasa === RATE_TYPES.CUSTOM && activeRate > 1.0;
    const metodoLiquidacion = (!isVesOnTop && (monedaFinal === 'USD' || monedaFinal === 'EUR'))
        ? 'DIVISA'
        : null;

    const prefill = {
        __isExpensePrefill: true,
        source: 'calculator',
        comercio: '',
        fecha: defaultFechaIso || '',
        moneda: monedaFinal,
        totalOriginal: totalFinal,
        totalOriginalFixed: totalFixed,
        metodoLiquidacion,
        tasaCambioDetectada: activeRate > 1.0 ? activeRate : null,
        tasaCobrada: isCustom ? activeRate : null,
        rateOverride: isCustom ? { currency, rate: activeRate } : null,
        customRateLocked: isCustom,
        items: [
            {
                descripcion: 'Gasto calculado',
                cantidad: 1,
                precio: totalFixed,
                total: totalFixed,
                categoria: 'Otros',
                categoriaManual: false,
            },
        ],
    };

    return { ok: true, error: null, prefill };
}
