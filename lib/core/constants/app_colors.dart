import 'package:flutter/material.dart';

class AppColors {
  // Fondos Claros
  static const Color background = Color(0xFFF9FAFB); // Gris súper claro
  static const Color surface = Color(0xFFFFFFFF);    // Blanco
  static const Color card = Color(0xFFFFFFFF);       // Blanco
  static const Color cardLighter = Color(0xFFF3F4F6); // Gris claro

  // Colores de Acento (Rinde Más - Amarillo Asistente IA)
  static const Color primary = Color(0xFFFEF08A);     // Amarillo del Asistente IA
  static const Color primaryLight = Color(0xFFFEF08A); // Tailwind Yellow 200
  static const Color primaryDark = Color(0xFFFACC15); // Amarillo oscuro reservado para bordes/iconos en fondo blanco
  static const Color secondary = Color(0xFF0F172A);   // Azul oscuro casi negro
  
  // Alertas y Estados
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Textos y Bordes
  static const Color textPrimary = Color(0xFF111827); // Negro/Gris muy oscuro
  static const Color textSecondary = Color(0xFF6B7280); // Gris medio
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // Paleta de Categoría Gráficos (Paleta armónica independiente de semáforos)
  static const Map<String, Color> categoryColors = {
    'Alimentación': Color(0xFF0D9488), // Teal elegante
    'Educación': Color(0xFF4F46E5),    // Índigo moderno
    'Salud': Color(0xFFE11D48),        // Frambuesa / Rose cálido
    'Hogar': Color(0xFFD97706),        // Ámbar tostado
    'Higiene': Color(0xFF06B6D4),      // Cyan fresco
    'Servicios': Color(0xFF7C3AED),    // Violeta balanceado
    'Transporte': Color(0xFF2563EB),   // Azul cobalto
    'Otros': Color(0xFF64748B),        // Gris pizarra
  };
}
