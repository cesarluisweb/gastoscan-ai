# -*- coding: utf-8 -*-
with open("lib/core/constants/app_constants.dart", "w", encoding="utf-8") as f:
    f.write("""class AppConstants {
  static const String appName = 'GastoScan AI';

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
  static const List<String> monedas = ['USD', 'VES', 'EUR'];

  // Claves de SharedPreferences
  static const String prefApiKey = 'gemini_api_key';
  static const String prefGuardarFotos = 'guardar_fotos_local';
  static const String prefTasaCambio = 'tasa_cambio_ves_usd';
  static const String prefMonedaPrincipal = 'moneda_principal';

  // Valores por defecto
  static const bool defaultGuardarFotos = false;
  static const double defaultTasaCambio = 40.0;
  static const String defaultMoneda = 'USD';
  static const String defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
}
""")
