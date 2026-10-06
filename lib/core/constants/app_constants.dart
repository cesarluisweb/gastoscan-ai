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

  // Monedas soportadas
  static const List<String> monedas = ['USD', 'VES', 'EUR', 'USDT'];

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
}
