// Servicio determinista y local para clasificar descripciones en las 10 categorías oficiales de Rinde Más.
// Port 100% fiel de lib/services/category_classifier_service.dart

export const CATEGORIAS_OFICIALES = [
    'Alimentación',
    'Salud',
    'Higiene',
    'Transporte',
    'Servicios',
    'Hogar',
    'Educación',
    'Ropa',
    'Entretenimiento',
    'Otros',
];

const AMBIGUOS = new Set([
    'aceite',
    'gas',
    'bateria',
    'pilas',
    'crema',
    'pasta',
    'papel',
    'corte',
    'taller',
    'bar',
    'agua',
]);

const FRASES_COMPUESTAS = {
    // Transporte vs Alimentación / Hogar
    'aceite de motor': 'Transporte',
    'aceite motor': 'Transporte',
    'aceite para motor': 'Transporte',
    'cambio de aceite': 'Transporte',
    'bateria de carro': 'Transporte',
    'bateria de auto': 'Transporte',
    'bateria carro': 'Transporte',
    'bateria vehiculo': 'Transporte',
    'gas vehicular': 'Transporte',
    'viaje en ridery': 'Transporte',
    'viaje en yummy': 'Transporte',
    'viaje en taxi': 'Transporte',

    // Alimentación
    'aceite de maiz': 'Alimentación',
    'aceite maiz': 'Alimentación',
    'aceite de oliva': 'Alimentación',
    'aceite oliva': 'Alimentación',
    'aceite de girasol': 'Alimentación',
    'aceite girasol': 'Alimentación',
    'aceite vegetal': 'Alimentación',
    'crema de leche': 'Alimentación',
    'pasta de tomate': 'Alimentación',
    'pasta alimenticia': 'Alimentación',
    'agua mineral': 'Alimentación',
    'botellon de agua': 'Alimentación',
    'botella de agua': 'Alimentación',
    'corte de carne': 'Alimentación',
    'perro caliente': 'Alimentación',
    'perros calientes': 'Alimentación',
    'comida rapida': 'Alimentación',

    // Higiene
    'crema dental': 'Higiene',
    'pasta dental': 'Higiene',
    'crema de dientes': 'Higiene',
    'crema corporal': 'Higiene',
    'crema para la piel': 'Higiene',
    'papel higienico': 'Higiene',
    'papel sanitario': 'Higiene',
    'toallas sanitarias': 'Higiene',
    'toalla sanitaria': 'Higiene',
    'toallitas humedas': 'Higiene',
    'corte de cabello': 'Higiene',
    'corte de pelo': 'Higiene',
    'corte y secado': 'Higiene',
    'jabon de bano': 'Higiene',
    'jabon corporal': 'Higiene',
    'jabon liquido': 'Higiene',
    'cuidado personal': 'Higiene',
    'aseo personal': 'Higiene',
    'enjuague bucal': 'Higiene',
    'cepillo de dientes': 'Higiene',
    'cepillo dental': 'Higiene',

    // Hogar
    'papel toalla': 'Hogar',
    'toalla de cocina': 'Hogar',
    'papel aluminio': 'Hogar',
    'jabon en polvo': 'Hogar',
    'jabon de lavar': 'Hogar',
    'jabon para platos': 'Hogar',
    'jabon lavaplatos': 'Hogar',
    'articulos de limpieza': 'Hogar',
    'bolsa de basura': 'Hogar',
    'bolsas de basura': 'Hogar',

    // Educación
    'papel bond': 'Educación',
    'utiles escolares': 'Educación',
    'articulos de oficina': 'Educación',

    // Servicios
    'gas domestico': 'Servicios',
    'bombona de gas': 'Servicios',
    'gas por tuberia': 'Servicios',
    'pago de agua': 'Servicios',
    'servicio de agua': 'Servicios',
    'servicio de luz': 'Servicios',
    'servicio de gas': 'Servicios',
    'recarga de saldo': 'Servicios',
    'recarga telefonica': 'Servicios',
    'recarga digitel': 'Servicios',
    'recarga movistar': 'Servicios',
    'recarga movilnet': 'Servicios',

    // Ropa
    'ropa interior': 'Ropa',
    'traje de bano': 'Ropa',

    // Entretenimiento
    'almuerzo en restaurante': 'Entretenimiento',
    'cena en restaurante': 'Entretenimiento',
    'salida a restaurante': 'Entretenimiento',
};

const CATALOGO = {
    'Alimentación': [
        'queso', 'carne', 'pollo', 'pan', 'leche', 'huevos', 'huevo', 'cafe',
        'arroz', 'harina', 'comida', 'verduras', 'verdura', 'frutas', 'fruta',
        'pasta', 'jamon', 'charcuteria', 'mercado', 'supermercado', 'abasto',
        'empanada', 'arepa', 'almuerzo', 'cena', 'desayuno', 'pizza', 'hamburguesa',
        'pescado', 'atun', 'sardina', 'mortadela', 'salchicha', 'mantequilla',
        'margarina', 'azucar', 'sal', 'mayonesa', 'salsa', 'vinagre', 'tomate',
        'cebolla', 'papa', 'platano', 'cambur', 'manzana', 'aguacate', 'ajo',
        'pimenton', 'zanahoria', 'refresco', 'malta', 'cerveza', 'sopa', 'postre',
        'helado', 'jugo', 'bodega', 'bodegon', 'viveres', 'sandwich', 'tostada',
        'cachapa', 'tequeno', 'galletas', 'galleta', 'dulce', 'chocolate', 'torta',
        'pastel', 'pina', 'lechuga', 'pepino', 'repollo', 'caraotas', 'frijoles',
        'lentejas', 'avena', 'cereal', 'maizena', 'maicena', 'yuca', 'ocumo', 'name',
    ],
    'Salud': [
        'medicina', 'pastilla', 'pastillas', 'jarabe', 'dolor', 'farmacia', 'remedio',
        'salud', 'tableta', 'tabletas', 'capsula', 'capsulas', 'ampolla', 'gotas',
        'inyeccion', 'antibiotico', 'analgesico', 'acetaminofen', 'paracetamol',
        'ibuprofeno', 'aspirina', 'losartan', 'amoxicilina', 'omeprazol', 'antialergico',
        'vitamina', 'vitaminas', 'consulta', 'medico', 'doctora', 'odontologo',
        'dentista', 'oculista', 'oftalmologo', 'psicologo', 'clinica', 'hospital',
        'laboratorio', 'ecografia', 'vacuna', 'termometro', 'curitas', 'gasas',
        'vendas', 'alcohol', 'tensiometro', 'inhalador', 'suero', 'pediatra',
    ],
    'Higiene': [
        'jabon', 'champu', 'shampoo', 'acondicionador', 'desodorante', 'aseo',
        'higiene', 'afeitadora', 'hojilla', 'toallas', 'toalla', 'tampones',
        'perfume', 'colonia', 'locion', 'dentifrico', 'enjuague', 'cepillo',
        'peluqueria', 'barberia', 'manicura', 'pedicura', 'tinte', 'maquillaje',
        'afeitado', 'bloqueador', 'bronceador', 'acetona', 'talco',
    ],
    'Transporte': [
        'gasolina', 'gasoil', 'diesel', 'pasaje', 'taxi', 'transporte', 'camioneta',
        'camionetica', 'metro', 'metrobus', 'autobus', 'bus', 'ridery', 'yummy',
        'peaje', 'estacionamiento', 'parking', 'carrera', 'repuesto', 'caucho',
        'llanta', 'tripay', 'frenos', 'autolavado', 'mecanico', 'alineacion',
        'balanceo', 'lubricante', 'amortiguador', 'pastillasfreno',
    ],
    'Servicios': [
        'luz', 'cantv', 'internet', 'servicio', 'saldo', 'recarga', 'corpoelec',
        'hidrocapital', 'electricidad', 'movistar', 'digitel', 'movilnet', 'simpletv',
        'netuno', 'thundernet', 'inter', 'airtek', 'wifi', 'fibra', 'cable',
        'condominio', 'aseo', 'bombona', 'streaming', 'directv',
    ],
    'Hogar': [
        'bombillo', 'detergente', 'cloro', 'reparacion', 'hogar', 'lavaplatos',
        'desengrasante', 'coleto', 'mopa', 'escoba', 'bolsa', 'bolsas', 'tornillo',
        'ferreteria', 'plomero', 'cerradura', 'candado', 'llave', 'sabana', 'sabanas',
        'almohada', 'cobija', 'cortina', 'vaso', 'vasos', 'plato', 'platos', 'sarten',
        'olla', 'ollas', 'mueble', 'cubiertos', 'pintura', 'cemento', 'enchufe',
        'cableado', 'desinfectante',
    ],
    'Educación': [
        'cuaderno', 'utiles', 'libro', 'libros', 'colegio', 'escuela', 'educacion',
        'universidad', 'liceo', 'matricula', 'mensualidad', 'inscripcion', 'curso',
        'taller', 'diplomado', 'clase', 'clases', 'libreta', 'lapiz', 'boligrafo',
        'colores', 'borrador', 'sacapuntas', 'resma', 'morral', 'uniforme', 'regla',
        'tijera', 'cartulina',
    ],
    'Ropa': [
        'ropa', 'pantalon', 'camisa', 'zapatos', 'medias', 'franela', 'chemise',
        'blusa', 'short', 'bermuda', 'vestido', 'falda', 'chaqueta', 'sueter',
        'abrigo', 'calzado', 'zapatillas', 'tenis', 'sandalias', 'cholas', 'botas',
        'tacones', 'correa', 'cinturon', 'cartera', 'billetera', 'boxer', 'sosten',
        'panty', 'interiores', 'calcetines', 'pijama', 'jeans', 'jean',
    ],
    'Entretenimiento': [
        'cine', 'salida', 'restaurante', 'chucheria', 'chuchería', 'fiesta',
        'pelicula', 'peliculas', 'teatro', 'concierto', 'entrada', 'entradas',
        'discoteca', 'parque', 'juego', 'juegos', 'videojuegos', 'playstation',
        'nintendo', 'xbox', 'netflix', 'spotify', 'disney', 'paseo', 'viaje',
        'posada', 'hotel', 'club', 'licor', 'ron', 'whisky', 'vodka', 'evento',
        'snack', 'piscina', 'playa',
    ],
};

export function normalizar(texto) {
    if (!texto) return '';
    let s = String(texto).toLowerCase();
    s = s
        .replace(/[áàäâ]/g, 'a')
        .replace(/[éèëê]/g, 'e')
        .replace(/[íìïî]/g, 'i')
        .replace(/[óòöô]/g, 'o')
        .replace(/[úùüû]/g, 'u')
        .replace(/ñ/g, 'n')
        .replace(/ç/g, 'c');
    s = s.replace(/[^a-z0-9\s]/g, ' ');
    return s.replace(/\s+/g, ' ').trim();
}

const INDICE = (() => {
    const map = {};
    for (const [cat, palabras] of Object.entries(CATALOGO)) {
        for (const p of palabras) {
            const norm = normalizar(p);
            if (norm) {
                map[norm] = cat;
            }
        }
    }
    return map;
})();

export function clasificarCategoria(concepto) {
    if (!concepto) return null;
    const clean = normalizar(concepto);
    if (clean.length < 3) return null;

    // 1. Frases compuestas con límites de palabra
    for (const [frase, cat] of Object.entries(FRASES_COMPUESTAS)) {
        const escaped = frase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const re = new RegExp(`\\b${escaped}\\b`);
        if (re.test(clean)) {
            return cat;
        }
    }

    // 2. Tokenizar
    const tokens = clean.split(/\s+/).filter(t => t.length > 0);
    if (tokens.length === 0) return null;

    // 3. Término ambiguo aislado
    if (tokens.length === 1 && AMBIGUOS.has(tokens[0])) {
        return null;
    }

    // 4. Token por token
    for (const token of tokens) {
        if (token.length < 3) continue;
        if (AMBIGUOS.has(token)) continue;

        const cat = INDICE[token];
        if (cat && CATEGORIAS_OFICIALES.includes(cat)) {
            return cat;
        }
    }

    return null;
}

export function isTaxDescription(desc) {
    const clean = normalizar(desc || '');
    return clean === 'impuesto iva' ||
        clean.startsWith('impuesto iva ') ||
        clean === 'iva 16' ||
        clean === 'iva' ||
        clean === 'iva 16 porciento';
}

export function sincronizarCategoriaImpuestos(items) {
    if (!Array.isArray(items) || items.length === 0) return items;

    // Calcular categoría dominante de los productos que no sean impuesto
    const catTotals = {};
    for (const it of items) {
        if (!isTaxDescription(it.descripcion)) {
            const cat = it.categoria || 'Otros';
            catTotals[cat] = (catTotals[cat] || 0) + (Number(it.total) || 0);
        }
    }

    let dominantCat = 'Otros';
    const entries = Object.entries(catTotals);
    if (entries.length > 0) {
        dominantCat = entries.reduce((a, b) => (b[1] > a[1] ? b : a))[0] || 'Otros';
    }

    return items.map(it => {
        if (isTaxDescription(it.descripcion) && (!it.origenCategoria || it.origenCategoria === 'auto' || it.categoria === 'Otros')) {
            return { ...it, categoria: dominantCat };
        }
        return it;
    });
}
