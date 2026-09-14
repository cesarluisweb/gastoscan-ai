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
}
