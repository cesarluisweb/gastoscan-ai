// Módulo puro del Asistente IA Financiero para el Panel Web de Rinde Más.
// Paridad matemática con lib/ui/screens/chat_screen.dart y lib/data/datasources/remote/gemini_service.dart.

import { computeMonthTotals, calculateSavingsHealth } from './expense-money.js';
import { clasificarCategoria, CATEGORIAS_OFICIALES } from './category-classifier.js';
import {
    isTaxItem,
    normalizeProductText,
    summarizeExpenseTaxContext,
    shelfPriceTaxFactor,
    formatCommerceDisplay,
    normalizeCommerce,
} from './price-comparator.js';
import { parseAmount } from './currency-calculator.js';

export const DEFAULT_GATEWAY_URL = 'https://rindemas-gateway.cesarluispuntocom.workers.dev';

export const INITIAL_CHAT_GREETING =
    '¡Hola! Puedo analizar tus gastos del mes, darte consejos para estirar tu presupuesto o preparar compras para registrarlas. ¿Por dónde empezamos?';

export const SHOPPING_LIST_WEB_NOTICE =
    'La Lista de Compras por ahora se guarda únicamente en tu teléfono dentro de la app móvil Rinde Más. Desde el panel web puedo ayudarte a analizar tus gastos, comparar precios y preparar compras para registrarlas.';

export const DEFAULT_CHAT_SUGGESTIONS = Object.freeze([
    {
        id: 'small_expenses',
        label: '¿Qué gastos pequeños están sumando más de lo que parece?',
        icon: '🔍',
    },
    {
        id: 'cut_expenses',
        label: '¿Qué gastos podría reducir sin afectar lo esencial?',
        icon: '✂️',
    },
    {
        id: 'price_increases',
        label: '¿Qué productos o gastos me han subido de precio?',
        icon: '📈',
    },
    {
        id: 'spending_days',
        label: '¿En qué días o momentos del mes suelo gastar más?',
        icon: '📅',
    },
    {
        id: 'top_budget_products',
        label: '¿Cuáles son los productos en los que más se me ha ido el presupuesto este mes?',
        icon: '🛒',
    },
]);

const SHOPPING_LIST_FUNCTION_NAMES = new Set([
    'agregar_items_lista_compras',
    'modificar_item_lista_compras',
    'eliminar_items_lista_compras',
    'marcar_items_lista_compras',
]);

/**
 * Devuelve la fecha de hoy en formato ISO YYYY-MM-DD en zona horaria America/Caracas (UTC-4).
 */
export function getVenezuelaTodayIso(now = new Date()) {
    try {
        return new Intl.DateTimeFormat('en-CA', {
            timeZone: 'America/Caracas',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
        }).format(now);
    } catch {
        // Fallback determinista UTC-4 si Intl timeZone no estuviera disponible
        const vetMs = now.getTime() - 4 * 60 * 60 * 1000;
        return new Date(vetMs).toISOString().slice(0, 10);
    }
}

/**
 * Deriva la fecha por defecto (YYYY-MM-DD) para el formulario de gasto según el mes visible
 * y el calendario real de Venezuela (America/Caracas), sin depender del huso horario del navegador.
 */
export function getDefaultExpenseDateForMonth({ selectedYear, selectedMonth, todayCaracasIso }) {
    const todayIso = todayCaracasIso || getVenezuelaTodayIso();
    const [todayY, todayM, todayD] = todayIso.split('-').map(Number);
    const year = Number(selectedYear) || todayY;
    const month = Number(selectedMonth) || todayM;

    const isCurrentMonth = year === todayY && month === todayM;
    const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
    const dayVal = isCurrentMonth ? todayD : Math.min(todayD, daysInMonth);

    return `${String(year).padStart(4, '0')}-${String(month).padStart(2, '0')}-${String(dayVal).padStart(2, '0')}`;
}

function formatUtcIsoDate(dateUtc) {
    const y = String(dateUtc.getUTCFullYear()).padStart(4, '0');
    const m = String(dateUtc.getUTCMonth() + 1).padStart(2, '0');
    const d = String(dateUtc.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function parseIsoToUtcDate(isoStr) {
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(isoStr || '').trim());
    if (!m) return null;
    const y = Number(m[1]);
    const mo = Number(m[2]);
    const d = Number(m[3]);
    if (y < 2000 || mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    const dt = new Date(Date.UTC(y, mo - 1, d));
    if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== mo - 1 || dt.getUTCDate() !== d) {
        return null;
    }
    return dt;
}

function subtractDaysIso(isoDate, days) {
    const dt = parseIsoToUtcDate(isoDate);
    if (!dt) return isoDate;
    dt.setUTCDate(dt.getUTCDate() - days);
    return formatUtcIsoDate(dt);
}

/**
 * Normaliza fechas provenientes de extracción IA: ISO ('2026-11-03') o formato
 * venezolano/latinoamericano ('03/11/2026', '03-11-26', '03.11.2026').
 * Port fiel de GeminiExtractionResult.parseExtractionDate.
 */
export function parseExtractionDate(raw, todayCaracasIso = getVenezuelaTodayIso()) {
    if (raw === null || raw === undefined) return todayCaracasIso;
    const str = String(raw).trim();
    if (!str) return todayCaracasIso;

    const isoMatch = /^(\d{4})-(\d{2})-(\d{2})/.exec(str);
    if (isoMatch) {
        const candidate = `${isoMatch[1]}-${isoMatch[2]}-${isoMatch[3]}`;
        if (parseIsoToUtcDate(candidate)) return candidate;
    }

    const dmyMatch = /^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})/.exec(str);
    if (dmyMatch) {
        const d = Number(dmyMatch[1]);
        const mo = Number(dmyMatch[2]);
        let y = Number(dmyMatch[3]);
        if (y < 100) y += 2000;
        const candidate = `${String(y).padStart(4, '0')}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
        if (parseIsoToUtcDate(candidate)) return candidate;
    }

    return todayCaracasIso;
}

/**
 * Resuelve de forma determinista la fecha de un gasto mencionado en el chat.
 * Port fiel de GeminiService.resolveSpokenExpenseDate (gemini_service.dart:306-378).
 */
export function resolveSpokenExpenseDate(spokenText, rawAiFecha, todayCaracasIso = getVenezuelaTodayIso()) {
    const todayIso = parseIsoToUtcDate(todayCaracasIso) ? todayCaracasIso : getVenezuelaTodayIso();
    const todayUtc = parseIsoToUtcDate(todayIso);
    const lower = String(spokenText || '').toLowerCase();

    if (/\b(antier|anteayer)\b/.test(lower)) {
        return subtractDaysIso(todayIso, 2);
    }
    if (/\b(ayer|anoche)\b/.test(lower)) {
        return subtractDaysIso(todayIso, 1);
    }

    const haceDiasMatch = /\bhace\s+(\d+|un|una|dos|tres|cuatro|cinco|seis|siete)\s+d[ií]as?\b/.exec(lower);
    if (haceDiasMatch) {
        const wordsToNum = {
            un: 1,
            una: 1,
            dos: 2,
            tres: 3,
            cuatro: 4,
            cinco: 5,
            seis: 6,
            siete: 7,
        };
        const rawToken = haceDiasMatch[1];
        const days = /^\d+$/.test(rawToken) ? Number(rawToken) : (wordsToNum[rawToken] || 0);
        if (days > 0) {
            return subtractDaysIso(todayIso, days);
        }
    }

    const hasCalendarRef =
        /\b(lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)\b/.test(lower) ||
        /\b(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)\b/.test(lower) ||
        /\b\d{1,2}[\/\-.]\d{1,2}(?:[\/\-.]\d{2,4})?\b/.test(lower) ||
        /\b\d{4}-\d{2}-\d{2}\b/.test(lower) ||
        /\bel\s+d[ií]a\s+\d{1,2}\b/.test(lower) ||
        /\bel\s+\d{1,2}\s+de\b/.test(lower);

    if (!hasCalendarRef) {
        return todayIso;
    }

    if (rawAiFecha === null || rawAiFecha === undefined || String(rawAiFecha).trim() === '') {
        return todayIso;
    }

    let parsedIso = parseExtractionDate(rawAiFecha, todayIso);
    const parsedUtc = parseIsoToUtcDate(parsedIso);
    if (!parsedUtc || !todayUtc) {
        return todayIso;
    }

    const hasExplicitFourDigitYear = /\b20\d{2}\b/.test(lower);
    if (!hasExplicitFourDigitYear && parsedUtc.getUTCFullYear() !== todayUtc.getUTCFullYear()) {
        const targetYear = todayUtc.getUTCFullYear();
        const targetMonth = parsedUtc.getUTCMonth() + 1;
        const maxDay = new Date(Date.UTC(targetYear, targetMonth, 0)).getUTCDate();
        const safeDay = Math.min(Math.max(1, parsedUtc.getUTCDate()), maxDay);
        parsedIso = `${String(targetYear).padStart(4, '0')}-${String(targetMonth).padStart(2, '0')}-${String(safeDay).padStart(2, '0')}`;
    }

    if (parsedIso > todayIso) {
        return todayIso;
    }
    return parsedIso;
}

/**
 * Normaliza un nombre de categoría al catálogo canónico de 10 categorías oficiales.
 */
export function normalizarCategoriaCanonica(cat) {
    if (!cat) return 'Otros';
    const trimmed = String(cat).trim();
    if (!trimmed) return 'Otros';

    const lower = trimmed.toLowerCase();
    const map = {
        alimentos: 'Alimentación',
        alimentacion: 'Alimentación',
        'alimentación': 'Alimentación',
        comida: 'Alimentación',
        salud: 'Salud',
        farmacia: 'Salud',
        medicina: 'Salud',
        higiene: 'Higiene',
        aseo: 'Higiene',
        'cuidado personal': 'Higiene',
        educacion: 'Educación',
        'educación': 'Educación',
        estudios: 'Educación',
        hogar: 'Hogar',
        casa: 'Hogar',
        servicios: 'Servicios',
        servicio: 'Servicios',
        transporte: 'Transporte',
        gasolina: 'Transporte',
        pasaje: 'Transporte',
        ropa: 'Ropa',
        vestimenta: 'Ropa',
        calzado: 'Ropa',
        zapatos: 'Ropa',
        entretenimiento: 'Entretenimiento',
        ocio: 'Entretenimiento',
        recreacion: 'Entretenimiento',
        'recreación': 'Entretenimiento',
        cine: 'Entretenimiento',
        salidas: 'Entretenimiento',
    };
    if (map[lower]) return map[lower];

    const exact = CATEGORIAS_OFICIALES.find((c) => c.toLowerCase() === lower);
    return exact || 'Otros';
}

/**
 * Normaliza sinónimos de moneda a 'USD' | 'VES' | 'EUR' | 'USDT'.
 */
export function normalizarMoneda(moneda, fallback = 'USD') {
    if (!moneda) return fallback;
    const trimmed = String(moneda).trim().toUpperCase();
    if (['VES', 'BS', 'BS.', 'BOLIVAR', 'BOLIVARES', 'BOLÍVAR', 'BOLÍVARES'].includes(trimmed)) return 'VES';
    if (['USD', 'DOLAR', 'DOLARES', 'DÓLAR', 'DÓLARES', '$'].includes(trimmed)) return 'USD';
    if (['EUR', 'EURO', 'EUROS', '€'].includes(trimmed)) return 'EUR';
    if (['USDT', 'TETHER'].includes(trimmed)) return 'USDT';
    if (['USD', 'VES', 'USDT', 'EUR'].includes(trimmed)) return trimmed;
    return fallback;
}

/**
 * Detecta la moneda explícita mencionada en texto en español venezolano.
 */
export function detectarMonedaDeTexto(texto, fallback = 'USD') {
    const lower = String(texto || '').toLowerCase();
    if (/\b(bol[ií]vares|bol[ií]var|bs\.?|ves)\b/i.test(lower)) return 'VES';
    if (/\b(d[oó]lares|d[oó]lar|usd)\b|\$/i.test(lower)) return 'USD';
    if (/\b(euros?|eur)\b|€/i.test(lower)) return 'EUR';
    if (/\b(usdt|tether)\b/i.test(lower)) return 'USDT';
    return fallback;
}

/**
 * Calcula la salud financiera y de ahorro estrictamente en la moneda del presupuesto
 * (paridad con GastoProvider.savingsSnapshot en lib/providers/gasto_provider.dart:156-181),
 * independientemente del lente visual seleccionado en el dashboard.
 */
export function buildSavingsHealthInBudgetCurrency({
    gastos = [],
    presupuesto = {},
    liveRates = {},
    selectedYear,
    selectedMonth,
    todayCaracasIso = getVenezuelaTodayIso(),
}) {
    const monthTotals = computeMonthTotals(gastos, liveRates);
    const monedaPresupuesto = normalizarMoneda(presupuesto?.moneda, 'USD');

    let gastoAcumulado;
    if (monedaPresupuesto === 'VES') {
        gastoAcumulado = monthTotals.sumVes;
    } else if (monedaPresupuesto === 'USDT') {
        gastoAcumulado = monthTotals.sumUsdt;
    } else if (monedaPresupuesto === 'EUR') {
        gastoAcumulado = monthTotals.sumEur;
    } else {
        gastoAcumulado = monthTotals.sumUsd;
    }

    const [todayY, todayM, todayD] = todayCaracasIso.split('-').map(Number);
    const year = Number(selectedYear) || todayY;
    const month = Number(selectedMonth) || todayM;
    const isCurrentMonth = year === todayY && month === todayM;
    const diasTotalesMes = new Date(Date.UTC(year, month, 0)).getUTCDate();
    const diaActual = isCurrentMonth ? todayD : diasTotalesMes;

    const snapshot = calculateSavingsHealth({
        presupuestoGeneral: Number(presupuesto?.general || 0),
        metaAhorro: Number(presupuesto?.meta_ahorro || 0),
        gastoAcumulado,
        diaActual,
        diasTotalesMes,
    });

    return {
        monthTotals,
        monedaPresupuesto,
        snapshot,
    };
}

const MIN_DAYS_FOR_RELIABLE_PROJECTION = 3;
const MIN_EXPENSES_FOR_RELIABLE_PROJECTION = 3;
const TRAILING_FISCAL_SUFFIX_RE = /(?:\s*\([GERgerExX]+\)|\s*-(?:G|E|R))\s*$/i;

function normalizeSelectorText(input) {
    const lower = String(input || '').trim().toLowerCase();
    if (!lower) return '';
    return lower
        .replace(/á/g, 'a')
        .replace(/é/g, 'e')
        .replace(/í/g, 'i')
        .replace(/ó/g, 'o')
        .replace(/ú/g, 'u')
        .replace(/ü/g, 'u')
        .replace(/ñ/g, 'n')
        .replace(/ç/g, 'c')
        .replace(/[^a-z0-9\s]+/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

const SELECTOR_SHOPPING_LIST_CUE = /\b(lista de compras|mi lista|a la lista|en la lista|de la lista|tengo que comprar|falta por comprar|pendiente en mi lista|pendientes en mi lista)\b/;
const SELECTOR_SHOPPING_LIST_VERB = /^(agrega|agregar|anota|anotar|pon|poner|quita|quitar|elimina|eliminar|borra|borrar|marca|marcar|tacha|tachar|cambia|cambiar|renombra|renombrar)\b/;
const SELECTOR_RECORD_EXPENSE_VERB = /\b(compre|gaste|pague|acabo de comprar|acabo de pagar|acabo de gastar|registra|registrar)\b/;
const SELECTOR_QUESTION_CUE = /^(cuanto|cuantos|cuanta|cuantas|que|cual|cuales|donde|como|cuando|por que|estoy|voy|me alcanza|he gastado|llevo)\b/;
const SELECTOR_DIRECT_LOOKUP = /^(cuanto|cuanta)\s+(gaste|he gastado|llevo gastado|llevo|pague|compre)\s+(en|de|por)\b/;
const SELECTOR_PREV_MONTH = /\b(mes pasado|mes anterior|meses anteriores|respecto al mes|frente al mes|comparar|comparativa|comparacion|evolucion|mas que antes|menos que antes|mas que el mes|menos que el mes|he gastado mas|gastando mas|gastando menos|aumentando|aumentado|suelo comprar cada mes|aun no he comprado)\b/;
const SELECTOR_PRICES = /\b(mas barato|mas barata|mas caro|mas cara|precio|precios|subido de precio|subieron de precio|subio de precio|aumento de precio|aumentaron de precio|donde comprar|donde me salio|donde consigo|mejor precio|mejores precios|comparador|inflacion|comercios|comercio mas barato|supermercado mas barato)\b/;
const SELECTOR_PRODUCT_PRICE_WORD = /\b(caro|cara|barato|barata|subio|bajo|comercio|tienda|donde|mejor)\b/;
const SELECTOR_ANT_EXPENSES = /\b(hormiga|gastos pequenos|gasto pequeno|compras pequenas|compra pequena|fuga|fugas|chucheria|chucherias|snack|snacks|menores a|pocos dolares|sumando mas de lo que parece|gastos chiquitos)\b/;
const SELECTOR_FULL_ANALYSIS = /\b(ahorrar|ahorro|reducir|recortar|presupuesto|ritmo|en que se me va|en que se me esta yendo|se me fue el dinero|alcanza|alcanzara|proyeccion|cierro el mes|cerrar el mes|resumen|diagnostico|consejo|consejos|recomendacion|recomendaciones|como voy|organizar mis gastos|planificar|planificacion|diciembre|fin de mes|dias o momentos del mes|suelo gastar mas|sin afectar lo esencial|compromet[a-z]*|estirar mi dinero|estirar el presupuesto)\b/;
const SELECTOR_SHORT_FOLLOWUP = /^(y\s+)?(por que|porque|dime mas|cuentame mas|explica|explicame|detalla|detallalo|cuales|cual|como asi|y eso|y el resto|mas detalle|a que se debe|donde|cuanto fue|que mas|y ahora)\b/;

function classifyNormalizedMessage(normalized, rawMessage, knownProductNames) {
    if (!normalized) {
        return {
            includeAntExpenses: false,
            includePrevMonthComparison: false,
            includePriceFindings: false,
            includeTemporalContext: true,
            includeTopComercios: false,
            intentGroup: 'neutral',
        };
    }

    const isQuestion = String(rawMessage || '').includes('?') || SELECTOR_QUESTION_CUE.test(normalized);
    const wantsPrevMonth = SELECTOR_PREV_MONTH.test(normalized);
    const mentionsKnownPrice = SELECTOR_PRODUCT_PRICE_WORD.test(normalized) && (knownProductNames || []).some((rawName) => {
        const normProd = normalizeSelectorText(rawName);
        return normProd.length >= 4 && normalized.includes(normProd);
    });
    const wantsPrices = SELECTOR_PRICES.test(normalized) || mentionsKnownPrice;
    const wantsAnt = SELECTOR_ANT_EXPENSES.test(normalized);
    const wantsFullAnalysis = SELECTOR_FULL_ANALYSIS.test(normalized);
    const hasAnalyticalCue = wantsPrevMonth || wantsPrices || wantsAnt || wantsFullAnalysis;

    if (!hasAnalyticalCue) {
        if (SELECTOR_SHOPPING_LIST_CUE.test(normalized) || SELECTOR_SHOPPING_LIST_VERB.test(normalized)) {
            return {
                includeAntExpenses: false,
                includePrevMonthComparison: false,
                includePriceFindings: false,
                includeTemporalContext: false,
                includeTopComercios: false,
                intentGroup: 'direct_or_action',
            };
        }
        if (SELECTOR_DIRECT_LOOKUP.test(normalized) || (!isQuestion && SELECTOR_RECORD_EXPENSE_VERB.test(normalized))) {
            return {
                includeAntExpenses: false,
                includePrevMonthComparison: false,
                includePriceFindings: false,
                includeTemporalContext: false,
                includeTopComercios: false,
                intentGroup: 'direct_or_action',
            };
        }
    }

    if (wantsFullAnalysis) {
        return {
            includeAntExpenses: true,
            includePrevMonthComparison: true,
            includePriceFindings: true,
            includeTemporalContext: true,
            includeTopComercios: true,
            intentGroup: 'analysis_or_budget',
        };
    }

    if (wantsPrevMonth || wantsPrices || wantsAnt) {
        let intentGroup = 'analysis_or_budget';
        if (wantsPrevMonth && !wantsPrices && !wantsAnt) intentGroup = 'prev_month';
        else if (wantsPrices && !wantsPrevMonth && !wantsAnt) intentGroup = 'prices';
        else if (wantsAnt && !wantsPrevMonth && !wantsPrices) intentGroup = 'ant_expenses';

        return {
            includeAntExpenses: wantsAnt,
            includePrevMonthComparison: wantsPrevMonth,
            includePriceFindings: wantsPrices,
            includeTemporalContext: wantsPrevMonth,
            includeTopComercios: wantsPrices,
            intentGroup,
        };
    }

    return {
        includeAntExpenses: false,
        includePrevMonthComparison: false,
        includePriceFindings: false,
        includeTemporalContext: true,
        includeTopComercios: false,
        intentGroup: 'neutral',
    };
}

/**
 * Selector determinista de señales para el Asistente IA (paridad 1:1 con ChatSignalSelector en Flutter).
 */
export function selectChatSignals({
    currentMessage = '',
    previousUserMessage = '',
    forceAllSignals = false,
    knownProductNames = [],
} = {}) {
    if (forceAllSignals) {
        return {
            includeAntExpenses: true,
            includePrevMonthComparison: true,
            includePriceFindings: true,
            includeTemporalContext: true,
            includeTopComercios: true,
            intentGroup: 'analysis_or_budget',
        };
    }

    const normalized = normalizeSelectorText(currentMessage);
    if (!normalized) {
        return {
            includeAntExpenses: false,
            includePrevMonthComparison: false,
            includePriceFindings: false,
            includeTemporalContext: true,
            includeTopComercios: false,
            intentGroup: 'neutral',
        };
    }

    if (previousUserMessage && String(previousUserMessage).trim()) {
        const wordCount = normalized.split(' ').length;
        if (wordCount <= 5 && SELECTOR_SHORT_FOLLOWUP.test(normalized)) {
            const prevSel = classifyNormalizedMessage(
                normalizeSelectorText(previousUserMessage),
                previousUserMessage,
                knownProductNames
            );
            return { ...prevSel, intentGroup: 'followup_inherited' };
        }
    }

    return classifyNormalizedMessage(normalized, currentMessage, knownProductNames);
}

/**
 * Construye el bloque `contexto_temporal` con guarda `proyeccion_confiable`
 * (paridad 1:1 con ChatContextBuilder.buildTemporalContext en Flutter).
 */
export function buildTemporalContext({
    selectedYear,
    selectedMonth,
    cantidadComprasMes,
    snapshot,
    monedaPresupuesto = 'USD',
    todayCaracasIso = getVenezuelaTodayIso(),
}) {
    const [todayY, todayM, todayD] = todayCaracasIso.split('-').map(Number);
    const year = Number(selectedYear) || todayY;
    const month = Number(selectedMonth) || todayM;
    const isCurrentMonth = year === todayY && month === todayM;
    const diasTotalesMes = new Date(Date.UTC(year, month, 0)).getUTCDate();
    const diasTranscurridos = isCurrentMonth
        ? Math.min(Math.max(1, todayD), diasTotalesMes)
        : diasTotalesMes;
    const diasRestantes = isCurrentMonth
        ? Math.max(0, diasTotalesMes - diasTranscurridos)
        : 0;
    const porcentajeMes = Math.min(
        100,
        Math.max(0, Math.round((diasTranscurridos / diasTotalesMes) * 100))
    );
    const gastoAcumulado = Number(snapshot?.gastoAcumulado || 0);
    const gastoDiarioRaw = diasTranscurridos > 0 ? gastoAcumulado / diasTranscurridos : 0;

    let motivoSinProyeccion = null;
    if (!isCurrentMonth) {
        motivoSinProyeccion = 'mes_cerrado';
    } else if (diasTranscurridos <= MIN_DAYS_FOR_RELIABLE_PROJECTION) {
        motivoSinProyeccion = 'inicio_de_mes';
    } else if (Number(cantidadComprasMes || 0) < MIN_EXPENSES_FOR_RELIABLE_PROJECTION) {
        motivoSinProyeccion = 'pocos_gastos';
    }

    const proyeccionConfiable = motivoSinProyeccion === null;
    const gastoProyectadoFinMes = proyeccionConfiable
        ? Number((gastoDiarioRaw * diasTotalesMes).toFixed(2))
        : null;

    return {
        fecha_hoy_ve: todayCaracasIso,
        periodo_consultado: `${String(year).padStart(4, '0')}-${String(month).padStart(2, '0')}`,
        es_mes_actual: isCurrentMonth,
        dias_transcurridos: diasTranscurridos,
        dias_totales_mes: diasTotalesMes,
        porcentaje_mes_transcurrido: porcentajeMes,
        dias_restantes_mes: diasRestantes,
        es_cierre_de_mes: isCurrentMonth && diasRestantes <= 3,
        cantidad_compras_mes: Number(cantidadComprasMes || 0),
        moneda_presupuesto: monedaPresupuesto,
        gasto_diario_promedio: Number(gastoDiarioRaw.toFixed(2)),
        proyeccion_confiable: proyeccionConfiable,
        gasto_proyectado_fin_mes: gastoProyectadoFinMes,
        motivo_sin_proyeccion: motivoSinProyeccion,
    };
}

/**
 * Construye el contexto JSON enviado a POST /chat-analyst.
 * Paridad matemática con ChatContextBuilder.buildSemanticChatContext (Etapa 0).
 */
export function buildSemanticChatContext({
    gastos = [],
    presupuesto = {},
    liveRates = {},
    selectedYear,
    selectedMonth,
    todayCaracasIso = getVenezuelaTodayIso(),
    currentMessage = null,
    previousUserMessage = '',
    selection = null,
}) {
    const list = Array.isArray(gastos) ? gastos.filter(Boolean) : [];
    const { monthTotals, monedaPresupuesto, snapshot } = buildSavingsHealthInBudgetCurrency({
        gastos: list,
        presupuesto,
        liveRates,
        selectedYear,
        selectedMonth,
        todayCaracasIso,
    });

    const temporalContext = buildTemporalContext({
        selectedYear,
        selectedMonth,
        cantidadComprasMes: list.length,
        snapshot,
        monedaPresupuesto,
        todayCaracasIso,
    });

    const tasaUsd = Number(liveRates?.usd || 0);
    const tasaEur = Number(liveRates?.eur || 0);
    const tasaUsdt = Number(liveRates?.usdt || 0);

    // 1. Totales acumulados por categoría en USD
    const totalesCategoriaRaw = {};
    for (const g of list) {
        const cat = normalizarCategoriaCanonica(g.categoria);
        const usd = Number(g.total_usd || 0) / 100.0;
        totalesCategoriaRaw[cat] = (totalesCategoriaRaw[cat] || 0) + usd;
    }
    const totalesCategoria = {};
    for (const [k, v] of Object.entries(totalesCategoriaRaw)) {
        totalesCategoria[k] = Number(v.toFixed(2));
    }

    // 2. Top 10 productos normalizados (AI-06) ordenados por impacto en USD (excluyendo impuestos)
    const productMap = new Map();
    const knownProductNames = [];
    for (const g of list) {
        const items = Array.isArray(g.items) ? g.items : [];
        const gTotalOrigCents = Number(g.total_original || 0);
        const gTotalUsdCents = Number(g.total_usd || 0);
        const taxCtx = summarizeExpenseTaxContext(items, { totalsInCents: true });

        for (const item of items) {
            const rawName = String(item?.descripcion || '').trim();
            if (!rawName || isTaxItem(rawName)) continue;

            knownProductNames.push(rawName);
            const norm = normalizeProductText(rawName);
            const key = norm || rawName.toLowerCase();
            const cleanedDisplay = rawName.replace(TRAILING_FISCAL_SUFFIX_RE, '').trim() || rawName;
            const existing = productMap.get(key) || {
                producto: cleanedDisplay,
                cantidad: 0,
                total_usd: 0,
                veces_comprado: 0,
            };

            const cant = Number(item.cantidad) || 1.0;
            const itemTotalCents = Number(item.total || 0);
            const hasBaseImponible =
                item?.base_imponible_original !== null &&
                item?.base_imponible_original !== undefined;
            const rawFactor = hasBaseImponible
                ? 1.0
                : shelfPriceTaxFactor({
                      descripcion: rawName,
                      taxCents: taxCtx.taxCents,
                      gravadoBaseCents: taxCtx.gravadoBaseCents,
                      gravadoItemCount: taxCtx.gravadoItemCount,
                      reducidoBaseCents: taxCtx.reducidoBaseCents,
                      reducidoItemCount: taxCtx.reducidoItemCount,
                  });
            const taxFactor = rawFactor === null ? 1.0 : rawFactor;
            const rawItemUsd = gTotalOrigCents > 0
                ? (itemTotalCents / gTotalOrigCents) * (gTotalUsdCents / 100.0)
                : itemTotalCents / 100.0;
            const itemUsd = rawItemUsd * taxFactor;

            existing.cantidad += cant;
            existing.total_usd += itemUsd;
            existing.veces_comprado += 1;
            productMap.set(key, existing);
        }
    }

    const top10Productos = Array.from(productMap.values())
        .sort((a, b) => (b.total_usd - a.total_usd) || (b.cantidad - a.cantidad))
        .slice(0, 10)
        .map((p) => ({
            producto: p.producto,
            cantidad: Number(p.cantidad.toFixed(1)),
            total_usd: Number(p.total_usd.toFixed(2)),
            veces_comprado: p.veces_comprado,
        }));

    // 2.1 Top 3 comercios del mes
    const comerciosMap = new Map();
    for (const g of list) {
        const comName = formatCommerceDisplay(g.comercio);
        const lower = comName.toLowerCase();
        if (!comName || lower === 'varios' || lower === 'otro comercio') continue;
        const normKey = normalizeCommerce(comName) || lower;
        const entry = comerciosMap.get(normKey) || { comercio: comName, visitas: 0, total_usd: 0 };
        entry.visitas += 1;
        entry.total_usd += Number(g.total_usd || 0) / 100.0;
        comerciosMap.set(normKey, entry);
    }
    const topComercios = Array.from(comerciosMap.values())
        .sort((a, b) => b.total_usd - a.total_usd)
        .slice(0, 3)
        .map((c) => ({
            comercio: c.comercio,
            visitas: c.visitas,
            total_usd: Number(c.total_usd.toFixed(2)),
        }));

    // 3. Últimas 5 compras del mes ordenadas por fecha descendente (comparador defensivo)
    const ultimasCompras = [...list]
        .sort((a, b) => String(b.fecha || '').localeCompare(String(a.fecha || '')))
        .slice(0, 5)
        .map((g) => ({
            fecha: String(g.fecha || ''),
            comercio: String(g.comercio || 'Compra general'),
            categoria: normalizarCategoriaCanonica(g.categoria),
            moneda: normalizarMoneda(g.moneda, 'USD'),
            monto_original: Number((Number(g.total_original || 0) / 100.0).toFixed(2)),
            total_usd: Number((Number(g.total_usd || 0) / 100.0).toFixed(2)),
            total_usdt: Number((Number(g.total_usdt ?? g.total_usd ?? 0) / 100.0).toFixed(2)),
        }));

    const { sumUsd, sumVes, sumUsdt } = monthTotals;

    const totalEurBcv = (tasaEur > 0 && sumVes > 0)
        ? Number((sumVes / tasaEur).toFixed(2))
        : (tasaEur > 0
            ? Number(((sumUsd * tasaUsd) / tasaEur).toFixed(2))
            : Number(sumUsd.toFixed(2)));

    const effectiveSelection = selection
        || (currentMessage !== null
            ? selectChatSignals({ currentMessage, previousUserMessage, knownProductNames })
            : { includeTemporalContext: true, includeTopComercios: true });

    const estadoMetaEfectivo = (!temporalContext.proyeccion_confiable && snapshot.status === 'enRiesgo')
        ? 'protegida'
        : snapshot.status;

    const contextMap = {
        fecha_hoy: todayCaracasIso,
        periodo_consultado: temporalContext.periodo_consultado,
        moneda_principal: monedaPresupuesto,
        tasa_bcv_usd: tasaUsd,
        tasa_bcv_eur: tasaEur,
        tasa_usdt: tasaUsdt,
        totales_categoria: totalesCategoria,
        top_productos_mes: top10Productos,
        ultimas_compras: ultimasCompras,
        total_usd: Number(sumUsd.toFixed(2)),
        total_usd_bcv: Number(sumUsd.toFixed(2)),
        total_usdt_p2p: Number(sumUsdt.toFixed(2)),
        total_eur_bcv: totalEurBcv,
        total_ves: Number(sumVes.toFixed(2)),
        presupuesto_general: Number(presupuesto?.general || 0),
        meta_ahorro: Number(presupuesto?.meta_ahorro || 0),
        limite_para_gastar: Number(snapshot.limiteParaGastar.toFixed(2)),
        gasto_proyectado_fin_mes: temporalContext.gasto_proyectado_fin_mes,
        estado_meta_ahorro: estadoMetaEfectivo,
        moneda_presupuesto: monedaPresupuesto,
        presupuestos_categoria: presupuesto?.categorias || {},
        lista_compras: null,
        lista_compras_disponible: false,
    };

    if (effectiveSelection.includeTemporalContext) {
        contextMap.contexto_temporal = temporalContext;
    }
    if (effectiveSelection.includeTopComercios && topComercios.length > 0) {
        contextMap.top_comercios = topComercios;
    }

    return contextMap;
}

/**
 * Detecta si la consulta o llamada de función corresponde a la Lista de Compras
 * (no disponible en web hasta el Bloque 2).
 */
export function isShoppingListQuery(userText = '', functionCallName = '') {
    if (functionCallName && SHOPPING_LIST_FUNCTION_NAMES.has(functionCallName)) {
        return true;
    }
    const lower = String(userText || '').toLowerCase();
    return /\blista\s+de\s+compras\b/.test(lower) ||
        /\b(agrega|anota|a[ñn]ade|pon|quita|elimina|borra|marca|tacha)\b.*\b(a\s+la\s+lista|en\s+la\s+lista|de\s+la\s+lista|por\s+comprar)\b/.test(lower) ||
        /\bqu[eé]\s+(tengo|hay)\s+en\s+(mi\s+)?lista\b/.test(lower);
}

function inferMetodoLiquidacion(monedaGasto, rawMethod, rawUserText) {
    const upperArg = rawMethod ? String(rawMethod).trim().toUpperCase() : '';
    let metodo = ['BS_BCV', 'BS_USDT', 'DIVISA'].includes(upperArg) ? upperArg : null;

    if (!metodo && (monedaGasto === 'USD' || monedaGasto === 'EUR')) {
        const textLower = String(rawUserText || '').toLowerCase();
        if (
            textLower.includes('bcv') ||
            textLower.includes('banco central') ||
            textLower.includes('oficial') ||
            textLower.includes('pago movil') ||
            textLower.includes('pago móvil') ||
            textLower.includes('punto') ||
            textLower.includes('debito') ||
            textLower.includes('débito') ||
            textLower.includes('biopago') ||
            textLower.includes('en bolivares') ||
            textLower.includes('en bolívares') ||
            textLower.includes('en bs')
        ) {
            metodo = 'BS_BCV';
        } else if (
            textLower.includes('paralelo') ||
            textLower.includes('usdt') ||
            textLower.includes('binance') ||
            textLower.includes('p2p')
        ) {
            metodo = 'BS_USDT';
        } else {
            metodo = 'DIVISA';
        }
    }

    // Regla estricta de negocio: EUR nunca se liquida a BS_USDT (review_expense_screen.dart:461-466)
    if (monedaGasto === 'EUR' && metodo === 'BS_USDT') {
        metodo = 'BS_BCV';
    }
    if (monedaGasto === 'VES' || monedaGasto === 'USDT') {
        metodo = null;
    }

    return metodo;
}

function mapSingleGastoToPrefill({ gastoData, rawUserText, liveRates, todayCaracasIso }) {
    const totalUsd = parseAmount(gastoData?.total_usd) ?? 0;
    const montoOriginalArg = parseAmount(gastoData?.monto_original) ?? 0;
    const comercioRaw = String(gastoData?.comercio || '').trim();
    const comercio = comercioRaw || 'General';
    const fecha = resolveSpokenExpenseDate(rawUserText, gastoData?.fecha, todayCaracasIso);
    const categoriaGasto = normalizarCategoriaCanonica(gastoData?.categoria || 'Otros');

    const monedaArg = String(gastoData?.moneda || '').trim();
    const monedaGasto = normalizarMoneda(
        monedaArg || null,
        detectarMonedaDeTexto(rawUserText, 'USD')
    );

    const rateUsd = Number(liveRates?.usd || 0);
    const rateEur = Number(liveRates?.eur || 0);
    const tasaChat = monedaGasto === 'EUR'
        ? (rateEur > 0 ? rateEur : (rateUsd > 0 ? rateUsd : 0))
        : (rateUsd > 0 ? rateUsd : 0);

    let totalOrigVal;
    if (monedaGasto === 'VES') {
        totalOrigVal = montoOriginalArg > 0
            ? montoOriginalArg
            : (totalUsd > 0 ? totalUsd * (tasaChat > 0 ? tasaChat : 1.0) : 0);
    } else {
        totalOrigVal = montoOriginalArg > 0 ? montoOriginalArg : totalUsd;
    }

    const rawItems = Array.isArray(gastoData?.items) ? gastoData.items : [];
    const items = rawItems
        .filter((it) => it && typeof it === 'object')
        .map((it) => {
            const desc = String(it.descripcion || '').trim() || 'Artículo';
            const cantRaw = parseAmount(it.cantidad);
            const cant = cantRaw !== null && cantRaw > 0 ? cantRaw : 1.0;

            const precioArg = parseAmount(it.precio_unitario);
            let precioUnit = precioArg !== null && precioArg >= 0 ? precioArg : null;
            if (precioUnit === null) {
                precioUnit = cant > 0 ? totalOrigVal / cant : totalOrigVal;
            }
            const itemTotal = precioUnit * cant;
            const precioFinal = cant > 0 ? itemTotal / cant : itemTotal;

            const catClasificada = clasificarCategoria(desc);
            const catItem = it.categoria
                ? normalizarCategoriaCanonica(it.categoria)
                : (catClasificada || categoriaGasto);

            return {
                descripcion: desc,
                cantidad: cant,
                precio: precioFinal.toFixed(2),
                total: itemTotal.toFixed(2),
                categoria: catItem,
                categoriaManual: false,
            };
        });

    if (items.length === 0) {
        items.push({
            descripcion: `Compra en ${comercio}`,
            cantidad: 1,
            precio: totalOrigVal.toFixed(2),
            total: totalOrigVal.toFixed(2),
            categoria: categoriaGasto,
            categoriaManual: false,
        });
    }

    const metodoLiquidacion = inferMetodoLiquidacion(
        monedaGasto,
        gastoData?.metodo_liquidacion ?? gastoData?.metodoLiquidacion,
        rawUserText
    );

    return {
        __isExpensePrefill: true,
        source: 'ai_chat',
        comercio,
        fecha,
        moneda: monedaGasto,
        categoria: categoriaGasto,
        totalOriginal: totalOrigVal,
        totalOriginalFixed: totalOrigVal.toFixed(2),
        metodoLiquidacion,
        tasaCambioDetectada: tasaChat > 0 ? tasaChat : null,
        tasaCobrada: null,
        rateOverride: null,
        customRateLocked: false,
        items,
    };
}

/**
 * Procesa una llamada `registrar_gasto` del Worker (simple o múltiples comercios en `args.gastos`).
 * Paridad con chat_screen.dart:602-689 (Criterios 4, 15 y 16).
 */
export function prepareChatExtractions({
    callArgs = {},
    rawUserText = '',
    liveRates = {},
    todayCaracasIso = getVenezuelaTodayIso(),
}) {
    const gastosList = Array.isArray(callArgs?.gastos)
        ? callArgs.gastos.filter((g) => g && typeof g === 'object')
        : [];

    if (gastosList.length > 0) {
        const prefills = gastosList.map((g) =>
            mapSingleGastoToPrefill({ gastoData: g, rawUserText, liveRates, todayCaracasIso })
        );
        return {
            type: 'extractions',
            prefills,
            clarificationText: null,
        };
    }

    const montoOriginal = parseAmount(callArgs?.monto_original) ?? 0;
    const totalUsd = parseAmount(callArgs?.total_usd) ?? 0;
    const hasExplicitPrice = montoOriginal > 0 || totalUsd > 0;
    const userLower = String(rawUserText || '').toLowerCase();
    const hasExplicitNumber = /\d+/.test(userLower);
    const hasExpenseKeyword =
        userLower.includes('gast') ||
        userLower.includes('compr') ||
        userLower.includes('pagu') ||
        userLower.includes('cost');

    if (!hasExplicitPrice || (!hasExplicitNumber && !hasExpenseKeyword)) {
        if (hasExpenseKeyword) {
            const comercio = String(callArgs?.comercio || '').trim();
            const items = Array.isArray(callArgs?.items) ? callArgs.items : [];
            const itemDesc = items.length > 0 && items[0]?.descripcion
                ? String(items[0].descripcion).trim()
                : 'tu compra';
            const comStr = comercio && comercio !== 'Varios' && comercio !== 'Compra general'
                ? ` en ${comercio}`
                : '';
            return {
                type: 'clarification',
                prefills: [],
                clarificationText: `Entendido, antes de registrar ${itemDesc}${comStr}, dime: ¿cuánto te costó en total?`,
            };
        }
        return {
            type: 'clarification',
            prefills: [],
            clarificationText: '¿Deseas agregarlo a tu lista de compras o registrarlo como un gasto realizado?',
        };
    }

    const prefill = mapSingleGastoToPrefill({
        gastoData: callArgs,
        rawUserText,
        liveRates,
        todayCaracasIso,
    });

    return {
        type: 'extractions',
        prefills: [prefill],
        clarificationText: null,
    };
}

/**
 * Crea la cola estructurada de extracciones con estados explícitos:
 * 'pending' | 'opened' | 'saved' | 'discarded' (Criterio 2 y 5).
 */
export function createExtractionQueue(prefills = [], batchId = 'batch') {
    const list = Array.isArray(prefills) ? prefills : [];
    const total = list.length;
    return list.map((prefill, idx) => ({
        id: `${batchId}_${idx + 1}`,
        index: idx + 1,
        total,
        status: 'pending',
        savedGastoId: null,
        prefill: {
            ...prefill,
            queueItemId: `${batchId}_${idx + 1}`,
        },
    }));
}

/**
 * Ejecuta una transición determinista sobre la cola de extracciones sin mutar el arreglo original.
 * Doble guarda (Criterio 2 / B2): 'close_without_save' SOLO afecta ítems en estado 'opened';
 * los ítems en 'saved' o 'discarded' permanecen inmutables.
 */
export function transitionExtractionItem(queue = [], itemId, action, payload = {}) {
    const current = Array.isArray(queue) ? queue : [];
    let nextQueue = current.map((item) => ({ ...item }));

    if (action === 'open') {
        nextQueue = nextQueue.map((item) => {
            if (item.id === itemId && (item.status === 'pending' || item.status === 'opened')) {
                return { ...item, status: 'opened' };
            }
            if (item.id !== itemId && item.status === 'opened') {
                return { ...item, status: 'pending' };
            }
            return item;
        });
    } else if (action === 'close_without_save') {
        nextQueue = nextQueue.map((item) => {
            if (item.id === itemId && item.status === 'opened') {
                return { ...item, status: 'pending' };
            }
            return item;
        });
    } else if (action === 'save') {
        nextQueue = nextQueue.map((item) => {
            if (item.id === itemId && item.status !== 'discarded') {
                return {
                    ...item,
                    status: 'saved',
                    savedGastoId: payload?.gastoId || item.savedGastoId || null,
                };
            }
            return item;
        });
    } else if (action === 'discard') {
        nextQueue = nextQueue.map((item) => {
            if (item.id === itemId && item.status !== 'saved') {
                return { ...item, status: 'discarded' };
            }
            return item;
        });
    }

    const nextPendingItem = nextQueue.find((item) => item.status === 'pending') || null;
    return { queue: nextQueue, nextPendingItem };
}

/**
 * Ventana deslizante de los últimos N mensajes en el contrato exacto que consume
 * workers/src/index.js:1003-1008 -> [{ role: 'user' | 'assistant', text: string }] (Criterio 3 / B3).
 */
export function sliceRecentChatMessages(messages = [], maxCount = 5) {
    const list = Array.isArray(messages) ? messages : [];
    const recent = list.length > maxCount ? list.slice(list.length - maxCount) : list;
    return recent.map((m) => ({
        role: m?.role === 'assistant' ? 'assistant' : 'user',
        text: String(m?.text ?? ''),
    }));
}

/**
 * Escapa caracteres peligrosos HTML para prevenir XSS.
 */
export function escapeHtml(str) {
    return String(str ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

/**
 * Formatea un mensaje de texto del asistente a HTML seguro:
 * 1. Escapa estrictamente todo HTML.
 * 2. Convierte únicamente **negrita** en <strong> y saltos de línea en <br>.
 */
export function formatAssistantMessageHtml(rawText) {
    const safe = escapeHtml(rawText);
    return safe
        .replace(/\*\*([^*\n]+)\*\*/g, '<strong class="font-bold text-slate-900">$1</strong>')
        .replace(/\n/g, '<br>');
}

/**
 * Traduce códigos HTTP del Worker o errores de red/timeout a mensajes amigables en español venezolano.
 */
export function mapChatHttpError(status, errorBody = null, { isAbort = false } = {}) {
    if (isAbort) {
        return 'El asistente tardó demasiado en responder (más de 45 s). Revisa tu conexión e intenta nuevamente.';
    }
    if (status === 401) {
        return 'Tu sesión ha caducado. Recarga la página o vuelve a iniciar sesión para usar el asistente.';
    }
    if (status === 413) {
        return 'La conversación excedió el tamaño permitido. Reinicia el chat para continuar.';
    }
    if (status === 429) {
        if (errorBody && errorBody.dailyLimitReached === true) {
            return (
                (typeof errorBody.error === 'string' && errorBody.error.trim()) ||
                'Has alcanzado el límite diario de 50 consultas compartidas entre la app móvil y el panel web. Tus consultas se renovarán automáticamente mañana.'
            );
        }
        return 'Estás enviando mensajes muy rápido. Espera unos segundos e intenta de nuevo.';
    }
    if (status === 504) {
        return 'El asistente no pudo conectarse a tiempo. Revisa tu conexión e intenta nuevamente.';
    }
    if (status === 502 || status === 503) {
        return 'El asistente está experimentando alta demanda en este momento. Intenta nuevamente en unos minutos.';
    }
    if (errorBody && typeof errorBody.error === 'string' && errorBody.error.trim()) {
        return errorBody.error.trim();
    }
    return `Error al comunicarse con el asistente (${status || 'red'}). Intenta nuevamente.`;
}
