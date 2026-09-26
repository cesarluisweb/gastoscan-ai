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

  /// Formatea en la moneda preferida del usuario ('USD' o 'VES').
  static String formatPreferido(
    double totalUsd,
    double? totalVes,
    double tasaCambio,
    String monedaPreferida,
  ) {
    if (monedaPreferida == 'VES') {
      final ves = (totalVes != null && totalVes > 0)
          ? totalVes
          : totalUsd * tasaCambio;
      return formatVes(ves);
    }
    return formatUsd(totalUsd);
  }

  /// Formatea en la moneda secundaria (opuesta a la preferida).
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

  /// Convierte un monto en USD a la moneda preferida.
  static double convertFromUsd(
    double amountUsd,
    String monedaPreferida,
    double tasaCambio,
  ) {
    if (monedaPreferida == 'VES') {
      return amountUsd * tasaCambio;
    }
    return amountUsd;
  }
}
