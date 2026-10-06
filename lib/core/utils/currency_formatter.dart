import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String formatAmount(double amount, String currency) {
    final formatter = NumberFormat('#,##0.00', 'es_VE');
    final formattedNumber = formatter.format(amount);
    
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$ $formattedNumber';
      case 'VES':
        return 'Bs. $formattedNumber';
      case 'EUR':
        return '€ $formattedNumber';
      case 'USDT':
        return '$formattedNumber USDT';
      default:
        return '$currency $formattedNumber';
    }
  }

  static String formatUsd(double amount) {
    final formatter = NumberFormat('#,##0.00', 'es_VE');
    return '\$ ${formatter.format(amount)}';
  }

  static String formatVes(double amount) {
    final formatter = NumberFormat('#,##0.00', 'es_VE');
    return 'Bs. ${formatter.format(amount)}';
  }

  static String formatEur(double amount) {
    final formatter = NumberFormat('#,##0.00', 'es_VE');
    return '€ ${formatter.format(amount)}';
  }

  static String formatUsdt(double amount) {
    final formatter = NumberFormat('#,##0.00', 'es_VE');
    return '${formatter.format(amount)} USDT';
  }

  /// Formatea en la moneda preferida del usuario ('USD', 'VES', 'EUR', 'USDT').
  static String formatPreferido(
    double totalUsd,
    double? totalVes,
    double tasaCambio,
    String monedaPreferida, {
    double tasaEur = 0.0,
    double tasaUsdt = 0.0,
  }) {
    final double ves = (totalVes != null && totalVes > 0)
        ? totalVes
        : totalUsd * (tasaCambio > 0 ? tasaCambio : 1.0);

    switch (monedaPreferida.toUpperCase()) {
      case 'VES':
        return formatVes(ves);
      case 'EUR':
        // Sin tasa EUR no se inventa ratio (antes: tasaUsd * 1.08): se usa la
        // tasa USD como aproximación solo si existe; si no hay dato, la rama
        // neutra muestra el equivalente en USD.
        final double eurRate = tasaEur > 0 ? tasaEur : (tasaCambio > 0 ? tasaCambio : 0.0);
        return formatEur(eurRate > 0 ? ves / eurRate : totalUsd);
      case 'USDT':
        final double usdtRate = tasaUsdt > 0 ? tasaUsdt : (tasaCambio > 0 ? tasaCambio : 1.0);
        return formatUsdt(usdtRate > 0 ? ves / usdtRate : totalUsd);
      case 'USD':
      default:
        return formatUsd(totalUsd);
    }
  }

  /// Formatea en la moneda secundaria (Bolívares si es divisa, Dólares si es Bolívares).
  static String formatSecundario(
    double totalUsd,
    double? totalVes,
    double tasaCambio,
    String monedaPreferida,
  ) {
    if (monedaPreferida == 'VES') {
      return formatUsd(totalUsd);
    }
    final ves = (totalVes != null && totalVes > 0)
        ? totalVes
        : totalUsd * tasaCambio;
    return formatVes(ves);
  }

  /// Convierte un monto en USD a la moneda seleccionada.
  static double convertFromUsd(
    double amountUsd,
    String monedaPreferida,
    double tasaCambio, {
    double tasaEur = 0.0,
    double tasaUsdt = 0.0,
  }) {
    if (monedaPreferida == 'VES') {
      return amountUsd * (tasaCambio > 0 ? tasaCambio : 1.0);
    }
    if (monedaPreferida == 'EUR') {
      final ves = amountUsd * (tasaCambio > 0 ? tasaCambio : 1.0);
      // Sin tasa EUR no se inventa ratio: aproximación con tasa USD o neutro.
      final eurRate = tasaEur > 0 ? tasaEur : (tasaCambio > 0 ? tasaCambio : 0.0);
      return eurRate > 0 ? ves / eurRate : amountUsd;
    }
    if (monedaPreferida == 'USDT') {
      final ves = amountUsd * (tasaCambio > 0 ? tasaCambio : 1.0);
      final usdtRate = tasaUsdt > 0 ? tasaUsdt : (tasaCambio > 0 ? tasaCambio : 1.0);
      return usdtRate > 0 ? ves / usdtRate : amountUsd;
    }
    return amountUsd;
  }
}
