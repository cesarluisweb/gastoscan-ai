import '../core/constants/app_constants.dart';

/// Servicio local, determinista y 100% offline para clasificar descripciones
/// de compras y servicios en una de las 10 categorías canónicas oficiales de Rinde Más.
class CategoryClassifierService {
  CategoryClassifierService._();

  /// Términos ambiguos que por sí solos no deben forzar una categoría a menos
  /// que formen parte de una frase compuesta explícita (ej. "aceite motor" vs "aceite maíz").
  static const Set<String> _ambiguos = {
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
  };

  /// Frases compuestas con prioridad absoluta sobre palabras individuales.
  /// Se evalúan sobre el texto normalizado antes de consultar tokens aislados.
  static final Map<String, String> _frasesCompuestas = {
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

  /// Catálogo temático curado por categoría canónica oficial.
  static const Map<String, List<String>> _catalogo = {
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

  /// Índice invertido lazy: término -> categoría canónica.
  static final Map<String, String> _indice = _construirIndice();

  static Map<String, String> _construirIndice() {
    final Map<String, String> map = {};
    for (final entry in _catalogo.entries) {
      final categoria = entry.key;
      for (final palabra in entry.value) {
        final norm = normalizar(palabra);
        if (norm.isNotEmpty) {
          map[norm] = categoria;
        }
      }
    }
    return map;
  }

  /// Normaliza una cadena de texto para su comparación semántica:
  /// 1. Mapeo estricto de diacríticos y acentos antes de sanitizar caracteres.
  /// 2. Eliminación de signos de puntuación y caracteres especiales no alfanuméricos.
  /// 3. Conversión a minúsculas y normalización de espacios en blanco.
  static String normalizar(String texto) {
    if (texto.isEmpty) return '';
    var s = texto.toLowerCase();

    // 1. Mapeo de diacríticos y caracteres latinos
    s = s
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ç', 'c');

    // 2. Sanitizar: caracteres no alfanuméricos pasan a ser espacios
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    // 3. Colapsar espacios y recortar
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Clasifica un concepto o descripción en una de las 10 categorías canónicas oficiales.
  /// Retorna la categoría si hay coincidencia de alta certeza, o `null` si es desconocido o ambiguo.
  static String? clasificar(String? concepto) {
    if (concepto == null) return null;
    final clean = normalizar(concepto);
    if (clean.length < 3) return null;

    // 1. Evaluación de frases compuestas prioritarias con límites de palabra
    for (final entry in _frasesCompuestas.entries) {
      final frase = entry.key;
      final pattern = RegExp(r'\b' + RegExp.escape(frase) + r'\b');
      if (pattern.hasMatch(clean)) {
        return entry.value;
      }
    }

    // 2. Tokenizar por palabras
    final tokens = clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;

    // 3. Si el texto se compone exclusivamente de un término ambiguo aislado, no forzar categoría
    if (tokens.length == 1 && _ambiguos.contains(tokens.first)) {
      return null;
    }

    // 4. Evaluar token por token
    for (final token in tokens) {
      if (token.length < 3) continue;
      if (_ambiguos.contains(token)) continue; // Omitir términos ambiguos sueltos

      final categoriaEncontrada = _indice[token];
      if (categoriaEncontrada != null && AppConstants.categorias.contains(categoriaEncontrada)) {
        return categoriaEncontrada;
      }
    }

    return null;
  }
}
