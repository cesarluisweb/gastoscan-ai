// Módulo puro del Comparador de Precios v2 para Rinde Más (Panel Web Astro).
// Paridad 1:1 con lib/data/datasources/local/database_helper.dart y lib/ui/screens/review_expense_screen.dart.

const GENERIC_COMMERCE_PLACEHOLDERS = new Set([
    'compra general',
    'otro comercio',
    'comercio no especificado',
    'comercio desconocido',
    'comercio',
    'varios',
    'gasto general',
    'sin comercio',
    'sin nombre',
]);

const COMMERCE_NOISE_TOKENS = new Set([
    'ca',
    'sa',
    'srl',
    'rl',
    'cc',
    'compania',
    'anonima',
    'sociedad',
    'rif',
    'sucursal',
    'suc',
    'centro',
    'comercial',
    'inversiones',
    'inv',
    'distribuidora',
    'dist',
    'corporacion',
    'corp',
]);

const TAX_KEYWORDS = ['iva', 'iva 16', 'iva 8', 'iva g', 'iva r', 'impuesto', 'tax'];

/**
 * Normaliza la descripción de un producto para su comparación exacta:
 * elimina sufijos fiscales (E)/(G), pasa a minúsculas, mapea diacríticos y limpia signos.
 */
export function normalizeProductText(text) {
    if (!text) return '';
    return String(text)
        .replace(/\s*\([GERgerExX]+\)\s*$/i, '')
        .replace(/\s*-(G|E|R)\s*$/i, '')
        .toLowerCase()
        .replace(/á/g, 'a')
        .replace(/é/g, 'e')
        .replace(/í/g, 'i')
        .replace(/ó/g, 'o')
        .replace(/ú/g, 'u')
        .replace(/ü/g, 'u')
        .replace(/ñ/g, 'n')
        .replace(/ç/g, 'c')
        .replace(/[^\w\s]/g, '')
        .replace(/\s+/g, ' ')
        .trim();
}

/**
 * Determina si una descripción corresponde a un renglón de impuesto (IVA).
 */
export function isTaxItem(descripcion) {
    const clean = normalizeProductText(descripcion);
    if (!clean) return false;
    return TAX_KEYWORDS.some(
        (kw) =>
            clean === kw ||
            clean.startsWith(`${kw} `) ||
            clean.includes('iva 16') ||
            clean.includes('iva 8')
    );
}

/**
 * Normaliza el nombre de un comercio para comparaciones deterministas:
 * minúsculas, sin acentos, sin RIF y sin sufijos societarios o de centro comercial (C.A., S.A., C.C.).
 */
export function normalizeCommerce(text) {
    if (!text) return '';
    const clean = String(text)
        .toLowerCase()
        .replace(/á/g, 'a')
        .replace(/é/g, 'e')
        .replace(/í/g, 'i')
        .replace(/ó/g, 'o')
        .replace(/ú/g, 'u')
        .replace(/ü/g, 'u')
        .replace(/ñ/g, 'n')
        .replace(/ç/g, 'c')
        .replace(/['’]s\b/g, '')
        .replace(/\b(?:rif\s*)?[jvgpe]\s*[-.]?\s*\d{5,10}(?:[-.]?\d)?\b/g, ' ')
        .replace(/\bc\s*\.\s*a\s*\.?(?=\s|$|,)/g, ' ')
        .replace(/\bs\s*\.\s*a\s*\.?(?=\s|$|,)/g, ' ')
        .replace(/\bs\s*\.\s*r\s*\.\s*l\s*\.?(?=\s|$|,)/g, ' ')
        .replace(/\br\s*\.\s*l\s*\.?(?=\s|$|,)/g, ' ')
        .replace(/\bc\s*\.\s*c\s*\.?(?=\s|$|,)/g, ' ')
        .replace(/[^\w\s]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();

    if (!clean || GENERIC_COMMERCE_PLACEHOLDERS.has(clean)) {
        return '';
    }

    const words = clean
        .split(' ')
        .filter((w) => w.length > 0)
        .map((w) => {
            if (w === 'automercados') return 'automercado';
            if (w === 'supermercados') return 'supermercado';
            if (w === 'hipermercados') return 'hipermercado';
            if (w === 'farmacias') return 'farmacia';
            if (w === 'plazas') return 'plaza';
            return w;
        });

    const filtered = words.filter((w) => !COMMERCE_NOISE_TOKENS.has(w));
    const result = (filtered.length > 0 ? filtered : words).join(' ').trim();
    if (GENERIC_COMMERCE_PLACEHOLDERS.has(result)) return '';
    return result;
}

/**
 * Formatea el nombre del comercio para mostrarlo limpio en la interfaz (sin RIF ni sufijos fiscales).
 */
export function formatCommerceDisplay(text) {
    if (!text) return 'Otro comercio';
    let clean = String(text)
        .replace(/\b(?:RIF\s*[:.]?\s*)?[JVGPEjvgpe]\s*[-.]?\s*\d{5,10}(?:[-.]?\d)?\b/g, '')
        .replace(/,?\s*\b(?:C\.?\s*A\.?|S\.?\s*A\.?|S\.?\s*R\.?\s*L\.?|R\.?\s*L\.?|C\.?\s*C\.?)\s*$/i, '')
        .replace(/\s+/g, ' ')
        .trim();

    if (!clean || GENERIC_COMMERCE_PLACEHOLDERS.has(clean.toLowerCase())) {
        return 'Otro comercio';
    }

    const hasLetters = /[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]/.test(clean);
    const isAllUpper = hasLetters && clean === clean.toUpperCase();
    const isAllLower = hasLetters && clean === clean.toLowerCase();
    if (isAllUpper || isAllLower) {
        clean = clean
            .split(' ')
            .map((word) => {
                if (!word) return word;
                const lower = word.toLowerCase();
                return lower.charAt(0).toUpperCase() + lower.slice(1);
            })
            .join(' ');
    }
    return clean;
}

/**
 * Calcula los días calendario entre una fecha ISO (yyyy-MM-dd) y la fecha de referencia.
 */
export function daysBetweenIsoAndReference(fechaIso, referenceDate = new Date()) {
    if (!fechaIso) return null;
    const raw = String(fechaIso).trim().slice(0, 10);
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(raw);
    if (!match) return null;
    const y = Number(match[1]);
    const m = Number(match[2]) - 1;
    const d = Number(match[3]);
    const parsedUtc = Date.UTC(y, m, d);

    let refUtc;
    if (typeof referenceDate === 'string') {
        const refMatch = /^(\d{4})-(\d{2})-(\d{2})/.exec(referenceDate.trim());
        if (refMatch) {
            refUtc = Date.UTC(Number(refMatch[1]), Number(refMatch[2]) - 1, Number(refMatch[3]));
        } else {
            const dt = new Date(referenceDate);
            refUtc = Date.UTC(dt.getFullYear(), dt.getMonth(), dt.getDate());
        }
    } else {
        const dt = referenceDate instanceof Date ? referenceDate : new Date();
        refUtc = Date.UTC(dt.getFullYear(), dt.getMonth(), dt.getDate());
    }

    return Math.round((refUtc - parsedUtc) / 86400000);
}

/**
 * Formatea una fecha ISO (yyyy-MM-dd) como etiqueta relativa en español:
 * `hoy`, `ayer`, `hace N días`, `hace N semanas`, `hace N meses`.
 */
export function formatRelativePriceDate(fechaIso, referenceDate = new Date()) {
    const days = daysBetweenIsoAndReference(fechaIso, referenceDate);
    if (days === null || days <= 0) return 'hoy';
    if (days === 1) return 'ayer';
    if (days < 7) return `hace ${days} días`;
    if (days < 30) {
        const weeks = Math.floor(days / 7);
        return weeks <= 1 ? 'hace 1 semana' : `hace ${weeks} semanas`;
    }
    const months = Math.floor(days / 30);
    return months <= 1 ? 'hace 1 mes' : `hace ${months} meses`;
}

/**
 * Extrae el precio unitario equivalente en USD para un ítem de un gasto almacenado en Firestore/SQLite.
 */
export function computeItemUnitPriceUsd(item, gasto) {
    const moneda = gasto?.moneda || 'USD';
    const tasaRow = Number(gasto?.tasa_cambio) || 1.0;
    const totalOrig = Number(gasto?.total_original) || 0;
    const totalUsd = Number(gasto?.total_usd) || 0;
    const cant = Number(item?.cantidad) > 0 ? Number(item.cantidad) : 1.0;
    const totalItem = Number(item?.total) || 0;
    const precioUnitItem = Number(item?.precio_unitario) || 0;

    let unitPriceInCurrency;
    if (totalItem > 0 && cant > 0) {
        unitPriceInCurrency = (totalItem / 100.0) / cant;
    } else {
        unitPriceInCurrency = precioUnitItem / 100.0;
    }

    let tasa = tasaRow > 0 ? tasaRow : 1.0;
    if (tasa === 1.0 && totalOrig > 0 && totalUsd > 0 && totalOrig / totalUsd > 2.0) {
        tasa = totalOrig / totalUsd;
    }

    let prevUsd = unitPriceInCurrency;
    if (moneda === 'VES') {
        prevUsd = unitPriceInCurrency / tasa;
    } else if (totalUsd > 0 && unitPriceInCurrency > (totalUsd / 100.0) * 2.0 && tasa > 1.0) {
        prevUsd = unitPriceInCurrency / tasa;
    }
    return prevUsd;
}

/**
 *Construye el mapa de historial de precios (`Map<descripcionNorm, PriceHistory>`) a partir de una lista de gastos.
 */
export function findPriceHistoryFromGastos(
    gastos,
    descripcionesNormalizadas,
    {
        excludeGastoId = null,
        comercioActual = '',
        diasVentana = 60,
        referenceDate = new Date(),
    } = {}
) {
    const validDescs = new Set();
    for (const raw of descripcionesNormalizadas || []) {
        const norm = normalizeProductText(raw);
        if (norm.length > 2 && !isTaxItem(norm)) {
            validDescs.add(norm);
        }
    }
    if (validDescs.size === 0 || !Array.isArray(gastos) || gastos.length === 0) {
        return {};
    }

    const comercioActualNorm = normalizeCommerce(comercioActual);
    const sortedGastos = [...gastos]
        .filter((g) => g && !g.eliminado_en && (excludeGastoId === null || String(g.id) !== String(excludeGastoId)))
        .sort((a, b) => String(b.fecha || '').localeCompare(String(a.fecha || '')));

    const grouped = new Map();
    let inspectedItems = 0;

    for (const g of sortedGastos) {
        const fechaStr = String(g.fecha || '').slice(0, 10);
        const ageDays = daysBetweenIsoAndReference(fechaStr, referenceDate);
        if (ageDays === null || ageDays > diasVentana) continue;

        const items = Array.isArray(g.items) ? g.items : [];
        for (const it of items) {
            if (inspectedItems >= 600) break;
            const prevDesc = String(it?.descripcion || '');
            if (isTaxItem(prevDesc)) continue;

            const normDesc = it?.descripcion_norm
                ? String(it.descripcion_norm)
                : normalizeProductText(prevDesc);
            if (!validDescs.has(normDesc)) continue;

            const prevUsd = computeItemUnitPriceUsd(it, g);
            if (!(prevUsd > 0)) continue;

            inspectedItems += 1;
            const rawComercio = g.comercio || 'Otro comercio';
            const ref = {
                precioUsd: prevUsd,
                fecha: fechaStr,
                comercio: formatCommerceDisplay(rawComercio),
                comercioNorm: normalizeCommerce(rawComercio),
                cantidad: Number(it?.cantidad) > 0 ? Number(it.cantidad) : 1.0,
                gastoId: g.id ?? null,
            };

            if (!grouped.has(normDesc)) {
                grouped.set(normDesc, []);
            }
            grouped.get(normDesc).push(ref);
        }
        if (inspectedItems >= 600) break;
    }

    const output = {};
    for (const [descNorm, refs] of grouped.entries()) {
        if (refs.length === 0) continue;

        let mismoComercio = null;
        if (comercioActualNorm) {
            mismoComercio = refs.find((r) => r.comercioNorm === comercioActualNorm) || null;
        }

        const refsVigentes = refs.filter((r) => {
            const d = daysBetweenIsoAndReference(r.fecha, referenceDate);
            return d !== null && d >= 0 && d <= 30;
        });
        const poolMejor = refsVigentes.length > 0 ? refsVigentes : refs;
        let mejorPrecio = poolMejor[0];
        for (let i = 1; i < poolMejor.length; i++) {
            if (poolMejor[i].precioUsd < mejorPrecio.precioUsd) {
                mejorPrecio = poolMejor[i];
            }
        }

        output[descNorm] = {
            descripcionNorm: descNorm,
            registros: refs.length,
            mismoComercio,
            mejorPrecio,
            entradas: refs,
        };
    }

    return output;
}

/**
 * Evalúa la línea única de comparación de precios según la prioridad canónica:
 * 1. Mismo comercio (0 a 30 días) -> veredicto del comercio (umbral ±5%).
 * 2. Sin coincidencia en el comercio (0 a 30 días) -> mejor precio del mercado (0 a 30 días, umbral ±5%).
 * 3. Cualquier dato entre 31 y 60 días -> línea gris de referencia sin porcentaje.
 * 4. Más de 60 días o sin datos -> null.
 *
 * @returns {{ text: string, tone: 'error' | 'good' | 'muted' } | null}
 */
export function evaluatePriceComparison({
    currentUnitUsd,
    history,
    comercioActual = '',
    referenceDate = new Date(),
}) {
    if (!history) return null;

    const entries = Array.isArray(history.entradas) ? history.entradas : [];
    const normCom = normalizeCommerce(comercioActual);

    let mismoComercioRef = null;
    if (normCom) {
        if (entries.length > 0) {
            mismoComercioRef = entries.find((e) => e.comercioNorm === normCom) || null;
        } else if (
            history.mismoComercio &&
            (!history.mismoComercio.comercioNorm || history.mismoComercio.comercioNorm === normCom)
        ) {
            mismoComercioRef = history.mismoComercio;
        }
    } else if (history.mismoComercio && entries.length === 0) {
        mismoComercioRef = history.mismoComercio;
    }

    const mismoAge = mismoComercioRef
        ? daysBetweenIsoAndReference(mismoComercioRef.fecha, referenceDate)
        : null;

    // Prioridad 1: Mismo comercio (0 a 30 días)
    if (
        mismoComercioRef &&
        mismoComercioRef.precioUsd > 0 &&
        mismoAge !== null &&
        mismoAge >= 0 &&
        mismoAge <= 30
    ) {
        if (!(currentUnitUsd > 0)) return null;
        const prevUsd = mismoComercioRef.precioUsd;
        const comercioDisplay = formatCommerceDisplay(mismoComercioRef.comercio);
        const relDate = formatRelativePriceDate(mismoComercioRef.fecha, referenceDate);
        if (currentUnitUsd > prevUsd * 1.05) {
            const diff = Math.round((currentUnitUsd / prevUsd - 1) * 100);
            return {
                text: `🔺 Está ${diff}% más caro por unidad en ${comercioDisplay} (${relDate})`,
                tone: 'error',
            };
        }
        if (currentUnitUsd < prevUsd * 0.95) {
            const diff = Math.round((1 - currentUnitUsd / prevUsd) * 100);
            return {
                text: `🟢 Te salió un ${diff}% más económico por unidad en ${comercioDisplay} (${relDate})`,
                tone: 'good',
            };
        }
        return null;
    }

    // Prioridad 2: Mejor precio del mercado (0 a 30 días)
    let mejorReciente = null;
    for (const ref of entries) {
        const age = daysBetweenIsoAndReference(ref.fecha, referenceDate);
        if (age !== null && age >= 0 && age <= 30 && ref.precioUsd > 0) {
            if (!mejorReciente || ref.precioUsd < mejorReciente.precioUsd) {
                mejorReciente = ref;
            }
        }
    }
    if (!mejorReciente && history.mejorPrecio && history.mejorPrecio.precioUsd > 0) {
        const age = daysBetweenIsoAndReference(history.mejorPrecio.fecha, referenceDate);
        if (age !== null && age >= 0 && age <= 30) {
            mejorReciente = history.mejorPrecio;
        }
    }

    if (mejorReciente) {
        if (!(currentUnitUsd > 0)) return null;
        const prevUsd = mejorReciente.precioUsd;
        const comercioDisplay = formatCommerceDisplay(mejorReciente.comercio);
        const relDate = formatRelativePriceDate(mejorReciente.fecha, referenceDate);
        if (currentUnitUsd > prevUsd * 1.05) {
            const diff = Math.round((currentUnitUsd / prevUsd - 1) * 100);
            return {
                text: `🔺 Está ${diff}% más caro por unidad que en ${comercioDisplay} (${relDate})`,
                tone: 'error',
            };
        }
        if (currentUnitUsd < prevUsd * 0.95) {
            const diff = Math.round((1 - currentUnitUsd / prevUsd) * 100);
            return {
                text: `🟢 Te salió un ${diff}% más económico por unidad que en ${comercioDisplay} (${relDate})`,
                tone: 'good',
            };
        }
        return null;
    }

    // Prioridad 3: Cualquier dato entre 31 y 60 días -> línea gris de referencia sin porcentaje
    let oldRef = null;
    if (mismoComercioRef && mismoAge !== null && mismoAge >= 31 && mismoAge <= 60) {
        oldRef = mismoComercioRef;
    } else if (history.mejorPrecio) {
        const age = daysBetweenIsoAndReference(history.mejorPrecio.fecha, referenceDate);
        if (age !== null && age >= 31 && age <= 60) {
            oldRef = history.mejorPrecio;
        }
    }
    if (!oldRef) {
        for (const ref of entries) {
            const age = daysBetweenIsoAndReference(ref.fecha, referenceDate);
            if (age !== null && age >= 31 && age <= 60 && ref.precioUsd > 0) {
                oldRef = ref;
                break;
            }
        }
    }

    if (oldRef) {
        const prevUsd = oldRef.precioUsd;
        const comercioDisplay = formatCommerceDisplay(oldRef.comercio);
        const relDate = formatRelativePriceDate(oldRef.fecha, referenceDate);
        return {
            text: `Referencia: $${prevUsd.toFixed(2)}/ud en ${comercioDisplay} (${relDate})`,
            tone: 'muted',
        };
    }

    return null;
}
