/// Parsea montos con formato venezolano o internacional.
///
/// Acepta miles con punto y decimal con coma ("1.234,56"), formato
/// internacional ("1,234.56") y decimales simples ("1234,56", "1234.56").
///
/// Devuelve `null` si el texto no está vacío pero no es un monto válido.
/// El texto vacío también da `null`: el llamador decide el fallback con `??`.
///
/// `isPrice: true` conserva la regla histórica para OCR (cadenas de solo
/// dígitos toman los 2 últimos como decimales: "1500" -> 15.00).
/// En formularios usar `isPrice: false`: un "1500" tipeado son 1500, no 15.00.
double? tryParseAmount(dynamic value, {bool isPrice = false}) {
  if (value == null) return null;

  String s = value.toString().trim();
  if (s.isEmpty) return null;

  // Conservar el signo para no convertir "-50" en 50 en silencio.
  bool negative = false;
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1).trim();
  } else if (s.startsWith('+')) {
    s = s.substring(1).trim();
  }
  if (s.isEmpty) return null;

  double? parsed;
  if (s.contains('.') || s.contains(',')) {
    s = s.replaceAll(RegExp(r'[^\d.,]'), '');
    if (s.contains(',') && s.contains('.')) {
      if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else {
      s = s.replaceAll(',', '.');
    }
    parsed = double.tryParse(s);
  } else {
    s = s.replaceAll(RegExp(r'[^\d]'), '');
    if (s.isEmpty) return null;
    if (isPrice) {
      if (s.length <= 2) {
        s = s.padLeft(3, '0');
      }
      final length = s.length;
      parsed = double.tryParse('${s.substring(0, length - 2)}.${s.substring(length - 2)}');
    } else {
      parsed = double.tryParse(s);
    }
  }

  if (parsed == null) return null;
  return negative ? -parsed : parsed;
}
