import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Rinde Más';

  // Categorías estándar (10 categorías canónicas oficiales)
  static const List<String> categorias = [
    'Alimentación',
    'Salud',
    'Higiene',
    'Educación',
    'Hogar',
    'Servicios',
    'Transporte',
    'Ropa',
    'Entretenimiento',
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
      case 'ropa':
      case 'vestimenta':
      case 'calzado':
      case 'zapatos':
        return 'Ropa';
      case 'entretenimiento':
      case 'ocio':
      case 'recreacion':
      case 'recreación':
      case 'cine':
      case 'salidas':
        return 'Entretenimiento';
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
      case 'Ropa':
        return Icons.checkroom_outlined;
      case 'Entretenimiento':
        return Icons.movie_outlined;
      case 'Otros':
      default:
        return Icons.more_horiz;
    }
  }

  /// Limpia sufijos de alícuotas fiscales como (G), (E), -G, -E al final de la descripción de un ítem.
  static String cleanItemDescription(String desc) {
    final cleaned = desc
        .replaceAll(RegExp(r'\s*\([GERgerExX]+\)\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-(G|E|R)\s*$', caseSensitive: false), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : desc.trim();
  }

  // Monedas soportadas
  static const List<String> monedas = ['USD', 'VES', 'USDT', 'EUR'];

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
  static const bool defaultGuardarFotos = true;
  // Último recurso cuando no hay caché ni red. NUNCA presentarlo como tasa
  // vigente: `SettingsProvider.tasasSonReferencia` lo señala en la UI.
  static const double defaultTasaCambio = 850.0;
  static const String defaultMoneda = 'USD';
  static const String defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  // Gateway Cloudflare Worker para Gemini
  static const String defaultGatewayUrl = String.fromEnvironment(
    'GATEWAY_BASE_URL',
    defaultValue: 'https://rindemas-gateway.cesarluispuntocom.workers.dev',
  );
  static const String prefGatewayUrl = 'gateway_api_url';

  // Límites temporales e históricos de tasas
  /// Fecha más antigua con registros continuos de tasas oficiales (DolarAPI / BCV).
  static final DateTime fechaMinimaHistoricoTasas = DateTime(2023, 1, 3);
  static const String fechaMinimaHistoricoTasasIso = '2023-01-03';

  // Notificaciones y Canales de Android
  static const int inactivityNotificationId = 1001;
  static const int pendingReviewNotificationId = 1002;
  static const int weekendReminderNotificationId = 1003;
  static const int broadcastNotificationId = 1004;

  static const String channelInactivityId = 'inactivity_reminders';
  static const String channelInactivityName = 'Recordatorios de Inactividad';
  static const String channelInactivityDesc =
      'Aviso suave tras 30 días sin registrar gastos para mantener tu presupuesto al día';

  static const String channelWeekendId = 'weekend_reminders';
  static const String channelWeekendName = 'Recordatorios de Compras';
  static const String channelWeekendDesc =
      'Avisos los sábados cada dos semanas para fotografiar facturas y comprobantes';

  static const String channelBroadcastId = 'broadcast_announcements';
  static const String channelBroadcastName = 'Avisos y Novedades';
  static const String channelBroadcastDesc =
      'Notificaciones sobre nuevas funciones y mejoras importantes de Rinde Más';

  static const String fcmTopicGeneral = 'anuncios_generales';

  // Claves de SharedPreferences para Notificaciones
  static const String prefRecordatorioFinDeSemana = 'recordatorio_fin_de_semana_activo';
  static const String prefAnunciosActivos = 'anuncios_notificaciones_activos';
  static const String prefIndiceMensajeRotativo = 'indice_mensaje_quincenal_rotativo';
  static const String prefCachedMensajesQuincenalesJson = 'cached_mensajes_quincenales_json';

  // Mensaje por defecto para inactividad (30 días)
  static const String defaultInactivityTitle = 'Tus cuentas al día';
  static const String defaultInactivityBody =
      'Ha pasado un mes desde tu último registro. Si tienes comprobantes acumulados, aquí estoy para ayudarte a ordenar tus números cuando quieras.';

  // Banco Base del Asistente IA para fin de semana (Offline / Fallback)
  static const List<Map<String, String>> defaultMensajesAsistenteQuincenal = [
    {
      'titulo': 'Mantén tu presupuesto al día',
      'cuerpo':
          'Aquí estoy para ayudarte: si hiciste compras hoy, tómale foto a los comprobantes y yo me encargo de ordenar los números.',
    },
    {
      'titulo': '¿Compras de fin de semana?',
      'cuerpo':
          'Pásame una foto de tus facturas de hoy antes de que se borre el papel térmico y extraigo los precios en segundos.',
    },
    {
      'titulo': 'Tus cuentas claras',
      'cuerpo':
          'Sube tus tickets del mercado o díctame tus gastos de hoy para cuadrar la quincena sin estrés.',
    },
    {
      'titulo': 'Que no se te acumulen los tickets',
      'cuerpo':
          'Una foto rápida a tus comprobantes de hoy y dejo tus gastos organizados por categoría de una vez.',
    },
  ];

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
