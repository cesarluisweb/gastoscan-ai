import 'package:flutter/material.dart';

class AppColors {
  // Fondos Oscuros Minimalistas
  static const Color background = Color(0xFF0F172A); // Slate 900
  static const Color surface = Color(0xFF1E293B);    // Slate 800
  static const Color card = Color(0xFF1E293B);
  static const Color cardLighter = Color(0xFF334155); // Slate 700

  // Colores de Acento (Fintech / Éxito)
  static const Color primary = Color(0xFF10B981);     // Esmeralda vibrante
  static const Color primaryLight = Color(0xFF34D399);
  static const Color primaryDark = Color(0xFF059669);
  static const Color secondary = Color(0xFF06B6D4);   // Cyan
  
  // Alertas y Estados
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Textos y Bordes
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFF334155);
  static const Color divider = Color(0xFF1E293B);

  // Paleta de Categorías para Gráficos
  static const Map<String, Color> categoryColors = {
    'Alimentación': Color(0xFF10B981), // Verde
    'Salud': Color(0xFFEF4444),        // Rojo
    'Educación': Color(0xFF3B82F6),    // Azul
    'Hogar': Color(0xFFF59E0B),        // Ámbar
    'Servicios': Color(0xFF8B5CF6),    // Púrpura
    'Transporte': Color(0xFF06B6D4),  // Cyan
    'Otros': Color(0xFF64748B),        // Gris
  };
}
