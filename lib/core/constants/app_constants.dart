import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Rinde Más';

  // Categorías estándar
  static const List<String> categorias = [
    'Alimentación',
    'Salud',
    'Higiene',
    'Educación',
    'Hogar',
    'Servicios',
    'Transporte',
    'Otros',
  ];

  /// Normaliza sinónimos y variaciones de nombres de categoría al catálogo estándar.
  static String normalizarCategoria(String? cat) {
    if (cat == null) return 'Otros';
    final trimmed = cat.trim();
    if (trimmed.isEmpty) return 'Otros';

    final lower = trimmed.toLowerCase();
    switch (lower) {
      case 'alimentos':
      case 'alimentacion':
      case 'alimentación':
      case 'comida':
        return 'Alimentación';
      case 'salud':
      case 'farmacia':
      case 'medicina':
        return 'Salud';
      case 'higiene':
      case 'aseo':
      case 'cuidado personal':
        return 'Higiene';
      case 'educacion':
      case 'educación':
      case 'estudios':
        return 'Educación';
      case 'hogar':
      case 'casa':
        return 'Hogar';
      case 'servicios':
      case 'servicio':
        return 'Servicios';
      case 'transporte':
      case 'gasolina':
      case 'pasaje':
        return 'Transporte';
      default:
        // Si coincide exactamente con alguna categoría registrada respetando mayúsculas/minúsculas
        for (final c in categorias) {
          if (c.toLowerCase() == lower) return c;
        }
        return 'Otros';
    }
  }

  /// Retorna el icono canónico oficial para una categoría dada.
  static IconData getCategoryIcon(String? cat) {
    final norm = normalizarCategoria(cat);
    switch (norm) {
      case 'Alimentación':
        return Icons.restaurant;
      case 'Educación':
        return Icons.school_outlined;
      case 'Salud':
        return Icons.favorite_border;
      case 'Hogar':
        return Icons.home_outlined;
      case 'Higiene':
        return Icons.clean_hands_outlined;
      case 'Servicios':
        return Icons.bolt;
      case 'Transporte':
        return Icons.directions_car_outlined;
      case 'Otros':
      default:
        return Icons.more_horiz;
    }
  }

  // Monedas soportadas
  static const List<String> monedas = ['USD', 'VES', 'EUR', 'USDT'];

  /// Normaliza representaciones y sinónimos de moneda al catálogo estándar ('USD', 'VES', 'EUR', 'USDT').
  static String normalizarMoneda(String? moneda, {String fallback = 'USD'}) {
    if (moneda == null) return fallback;
    final trimmed = moneda.trim().toUpperCase();
    if (trimmed == 'VES' || trimmed == 'BS' || trimmed == 'BS.' || trimmed == 'BOLIVAR' || trimmed == 'BOLIVARES' || trimmed == 'BOLÍVAR' || trimmed == 'BOLÍVARES') {
      return 'VES';
    }
    if (trimmed == 'USD' || trimmed == 'DOLAR' || trimmed == 'DOLARES' || trimmed == 'DÓLAR' || trimmed == 'DÓLARES' || trimmed == '\$') {
      return 'USD';
    }
    if (trimmed == 'EUR' || trimmed == 'EURO' || trimmed == 'EUROS' || trimmed == '€') {
      return 'EUR';
    }
    if (trimmed == 'USDT' || trimmed == 'TETHER') {
      return 'USDT';
    }
    if (monedas.contains(trimmed)) return trimmed;
    return fallback;
  }

  /// Detecta la moneda a partir de palabras clave o símbolos en texto dictado o escrito.
  static String detectarMonedaDeTexto(String texto, {String fallback = 'USD'}) {
    final lower = texto.toLowerCase();
    // Prioridad a bolívares si contiene referencias explícitas a la moneda venezolana
    if (RegExp(r'\b(bol[ií]vares|bol[ií]var|bs\.?|ves)\b', caseSensitive: false).hasMatch(lower)) {
      return 'VES';
    }
    // Dólares
    if (RegExp(r'\b(d[oó]lares|d[oó]lar|usd)\b|\$', caseSensitive: false).hasMatch(lower)) {
      return 'USD';
    }
    // Euros
    if (RegExp(r'\b(euros?|eur)\b|€', caseSensitive: false).hasMatch(lower)) {
      return 'EUR';
    }
    // USDT
    if (RegExp(r'\b(usdt|tether)\b', caseSensitive: false).hasMatch(lower)) {
      return 'USDT';
    }
    return fallback;
  }

  // Claves de SharedPreferences
  static const String prefApiKey = 'gemini_api_key';
  static const String prefGuardarFotos = 'guardar_fotos_local';
  static const String prefTasaCambio = 'tasa_cambio_ves_usd';
  static const String prefMonedaPrincipal = 'moneda_principal';
  static const String prefRecordatoriosActivos = 'recordatorios_activos';

  // Valores por defecto
  static const bool defaultGuardarFotos = false;
  // Último recurso cuando no hay caché ni red. NUNCA presentarlo como tasa
  // vigente: `SettingsProvider.tasasSonReferencia` lo señala en la UI.
  static const double defaultTasaCambio = 40.0;

  // Piso de verosimilitud de una tasa BCV vigente. Un valor por debajo de esto
  // es una semilla o un dato corrupto, jamás una tasa real del día: se descarta
  // para que la app no muestre una cifra falsa como si fuera la vigente.
  static const double tasaMinimaPlausible = 50.0;
  static const String defaultMoneda = 'USD';
  static const String defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  // Gateway Cloudflare Worker para Gemini
  static const String defaultGatewayUrl = String.fromEnvironment(
    'GATEWAY_BASE_URL',
    defaultValue: 'https://rindemas-gateway.cesarluispuntocom.workers.dev',
  );
  static const String prefGatewayUrl = 'gateway_api_url';

  // Soporte y Contacto
  static const String soporteWhatsAppNumero = '+58 414-8431543';
  static const String soporteWhatsAppUrl = 'https://wa.me/584148431543?text=Hola,%20tengo%20una%20consulta%20sobre%20Rinde%20M%C3%A1s';

  // Enlaces Oficiales Web y Donaciones
  static const String websiteUrl = 'https://rindemas.cesarluis.com';
  static const String donarUrl = 'https://rindemas.cesarluis.com/#donar';

  // Autenticación Google OAuth Web Client ID
  static const String googleWebClientId =
      '758679432067-p4lll1b5vfia32fndd68gjif6bmfmvel.apps.googleusercontent.com';
}
