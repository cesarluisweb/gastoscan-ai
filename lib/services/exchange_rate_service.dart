import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExchangeRateService {
  static const String _dolarApiOficial = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const String _dolarApiParalelo = 'https://ve.dolarapi.com/v1/dolares/paralelo';

  /// Obtiene la tasa de cambio del día de forma automática
  /// tipo: 'oficial' (BCV por defecto) o 'paralelo'
  static Future<double> getTodayRate({String tipo = 'oficial'}) async {
    try {
      final url = Uri.parse(tipo == 'paralelo' ? _dolarApiParalelo : _dolarApiOficial);
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final promedio = (data['promedio'] as num?)?.toDouble();
        if (promedio != null && promedio > 0) {
          // Guardar en caché local para cuando no haya internet
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('cached_exchange_rate', promedio);
          await prefs.setString('cached_exchange_rate_date', DateTime.now().toIso8601String());
          return promedio;
        }
      }
    } catch (_) {
      // Fallback a la tasa guardada en caché si falla la red
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('cached_exchange_rate') ?? 40.0;
  }
}
