import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gemini_extraction_result.dart';

void main() {
  group('GeminiExtractionResult - Corrección matemática de decimales', () {
    test('Caso A: total_original omitió decimales (5612 vs ítems 56.12)', () {
      final json = {
        'comercio': 'Farmatodo',
        'fecha': '2026-10-19',
        'moneda': 'USD',
        'total_original': 5612, // 100x mayor
        'items': [
          {'descripcion': 'Champú', 'cantidad': 1, 'precio_unitario': 30.00, 'total': 30.00},
          {'descripcion': 'Jabón', 'cantidad': 1, 'precio_unitario': 26.12, 'total': 26.12},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.totalOriginal, equals(56.12));
      expect(result.items[0].precioUnitarioDisplay, equals(30.00));
      expect(result.items[1].precioUnitarioDisplay, equals(26.12));
    });

    test('Caso B: Ítems omitieron decimales colectivamente (3000 y 2612 vs total 56.12)', () {
      final json = {
        'comercio': 'Automercado Plaza',
        'fecha': '2026-10-19',
        'moneda': 'USD',
        'total_original': 56.12,
        'items': [
          {'descripcion': 'Harina Pan', 'cantidad': 1, 'precio_unitario': 3000, 'total': 3000},
          {'descripcion': 'Arroz', 'cantidad': 1, 'precio_unitario': 2612, 'total': 2612},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.totalOriginal, equals(56.12));
      expect(result.items[0].precioUnitarioDisplay, equals(30.00));
      expect(result.items[1].precioUnitarioDisplay, equals(26.12));
    });

    test('Caso C: Un solo ítem omitió decimales y superaba el total general', () {
      final json = {
        'comercio': 'Supermercado',
        'fecha': '2026-10-19',
        'moneda': 'USD',
        'total_original': 95.00,
        'items': [
          {'descripcion': 'Harina Pan', 'cantidad': 1, 'precio_unitario': 4500, 'total': 4500}, // Omitió decimal (45.00)
          {'descripcion': 'Carne', 'cantidad': 1, 'precio_unitario': 50.00, 'total': 50.00},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.totalOriginal, equals(95.00));
      expect(result.items[0].precioUnitarioDisplay, equals(45.00));
      expect(result.items[1].precioUnitarioDisplay, equals(50.00));
    });

    test('Caso D: Factura con decimales correctos no se altera', () {
      final json = {
        'comercio': 'Panadería',
        'fecha': '2026-10-19',
        'moneda': 'VES',
        'total_original': 45.50,
        'items': [
          {'descripcion': 'Pan Canilla', 'cantidad': 2, 'precio_unitario': 22.75, 'total': 45.50},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.totalOriginal, equals(45.50));
      expect(result.items[0].precioUnitarioDisplay, equals(22.75));
      expect(result.items[0].totalDisplay, equals(45.50));
    });

    test('Caso E: Único ítem con decimal omitido contra total correcto', () {
      final json = {
        'comercio': 'Estación de Servicio',
        'fecha': '2026-10-19',
        'moneda': 'USD',
        'total_original': 15.00,
        'items': [
          {'descripcion': 'Gasolina', 'cantidad': 1, 'precio_unitario': 1500, 'total': 1500},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.totalOriginal, equals(15.00));
      expect(result.items[0].precioUnitarioDisplay, equals(15.00));
      expect(result.items[0].totalDisplay, equals(15.00));
    });

    test('Caso F: Total omitió decimal contra único ítem correcto', () {
      final json = {
        'comercio': 'Estación de Servicio',
        'fecha': '2026-10-19',
        'moneda': 'USD',
        'total_original': 1500,
        'items': [
          {'descripcion': 'Gasolina', 'cantidad': 1, 'precio_unitario': 15.00, 'total': 15.00},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.totalOriginal, equals(15.00));
      expect(result.items[0].precioUnitarioDisplay, equals(15.00));
      expect(result.items[0].totalDisplay, equals(15.00));
    });
  });
}
