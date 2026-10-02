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
  static const List<String> monedas = ['USD', 'VES'];

  // Claves de SharedPreferences
  static const String prefApiKey = 'gemini_api_key';
  static const String prefGuardarFotos = 'guardar_fotos_local';
  static const String prefTasaCambio = 'tasa_cambio_ves_usd';
  static const String prefMonedaPrincipal = 'moneda_principal';
  static const String prefRecordatoriosActivos = 'recordatorios_activos';

  // Valores por defecto
  static const bool defaultGuardarFotos = false;
  static const double defaultTasaCambio = 40.0;
  static const String defaultMoneda = 'USD';
  static const String defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  // Soporte y Contacto
  static const String soporteWhatsAppNumero = '+58 414-8431543';
  static const String soporteWhatsAppUrl = 'https://wa.me/584148431543?text=Hola,%20tengo%20una%20consulta%20sobre%20Rinde%20M%C3%A1s';
}
