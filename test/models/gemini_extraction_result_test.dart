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

    test('Caso G ([F1-C04]): Preserva Higiene, Ropa, Entretenimiento, moneda USDT y asigna categoría dominante a Impuesto IVA', () {
      final json = {
        'comercio': 'Farmatodo',
        'fecha': '2026-10-20',
        'moneda': 'USDT',
        'total_original': 11.60,
        'impuesto_iva': 1.60,
        'items': [
          {'descripcion': 'Champú', 'cantidad': 1, 'precio_unitario': 7.00, 'total': 7.00, 'categoria': 'Higiene'},
          {'descripcion': 'Galletas', 'cantidad': 1, 'precio_unitario': 3.00, 'total': 3.00, 'categoria': 'Alimentación'},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.moneda, equals('USDT'));
      expect(result.items.length, equals(3));
      expect(result.items[0].categoria, equals('Higiene'));
      expect(result.items[1].categoria, equals('Alimentación'));
      expect(result.items[2].descripcion, equals('Impuesto IVA'));
      // Categoría dominante es Higiene (7.00 > 3.00), no 'Otros'
      expect(result.items[2].categoria, equals('Higiene'));
      expect(result.items[2].totalDisplay, equals(1.60));
    });

    test('Caso H (Residual Match): Ítem 1156 se corrige a 11.56 al calzar con total impreso 36.56', () {
      final json = {
        'comercio': 'Supermercado Central',
        'fecha': '2026-10-23',
        'moneda': 'USD',
        'total_original': 36.56,
        'items': [
          {'descripcion': 'Queso', 'cantidad': 1, 'precio_unitario': 12.50, 'total': 12.50},
          {'descripcion': 'Jamón', 'cantidad': 1, 'precio_unitario': 8.40, 'total': 8.40},
          {'descripcion': 'Mantequilla', 'cantidad': 1, 'precio_unitario': 1156, 'total': 1156}, // Perdió decimal (11.56)
          {'descripcion': 'Pan', 'cantidad': 1, 'precio_unitario': 4.10, 'total': 4.10},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.totalOriginal, equals(36.56));
      expect(result.items[2].precioUnitarioDisplay, equals(11.56));
      expect(result.items[2].totalDisplay, equals(11.56));
    });

    test('Caso I (Consenso de Decimales y Outlier): Ítem 1156 se corrige y desinfla total_original inflado por IA', () {
      final json = {
        'comercio': 'Supermercado Central',
        'fecha': '2026-10-23',
        'moneda': 'USD',
        'total_original': 1181.00, // La IA sumó 12.50 + 8.40 + 1156 + 4.10
        'items': [
          {'descripcion': 'Queso', 'cantidad': 1, 'precio_unitario': 12.50, 'total': 12.50},
          {'descripcion': 'Jamón', 'cantidad': 1, 'precio_unitario': 8.40, 'total': 8.40},
          {'descripcion': 'Mantequilla', 'cantidad': 1, 'precio_unitario': 1156, 'total': 1156},
          {'descripcion': 'Pan', 'cantidad': 1, 'precio_unitario': 4.10, 'total': 4.10},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.items[2].precioUnitarioDisplay, equals(11.56));
      expect(result.items[2].totalDisplay, equals(11.56));
      expect(result.totalOriginal, closeTo(36.56, 0.01));
    });

    test('Caso J (Preservar precio entero legítimo): Compra con decimales y un ítem entero de 10.00', () {
      final json = {
        'comercio': 'Ferretería',
        'fecha': '2026-10-23',
        'moneda': 'USD',
        'total_original': 35.00,
        'items': [
          {'descripcion': 'Tornillos', 'cantidad': 1, 'precio_unitario': 12.50, 'total': 12.50},
          {'descripcion': 'Pega', 'cantidad': 1, 'precio_unitario': 8.40, 'total': 8.40},
          {'descripcion': 'Herramienta', 'cantidad': 1, 'precio_unitario': 10.00, 'total': 10.00},
          {'descripcion': 'Lija', 'cantidad': 1, 'precio_unitario': 4.10, 'total': 4.10},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.totalOriginal, equals(35.00));
      expect(result.items[2].precioUnitarioDisplay, equals(10.00));
      expect(result.items[2].totalDisplay, equals(10.00));
    });

    test('Caso K (Preservar compra en Bolívares con enteros legítimos)', () {
      final json = {
        'comercio': 'Carnicería',
        'fecha': '2026-10-23',
        'moneda': 'VES',
        'total_original': 1350.00,
        'items': [
          {'descripcion': 'Pan', 'cantidad': 1, 'precio_unitario': 150.00, 'total': 150.00},
          {'descripcion': 'Carne', 'cantidad': 1, 'precio_unitario': 1200.00, 'total': 1200.00},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.totalOriginal, equals(1350.00));
      expect(result.items[1].precioUnitarioDisplay, equals(1200.00));
    });

    test('Serialización toMap y fromJson preserva montos e ítems sin descalces (Round-trip)', () {
      final initialJson = {
        'comercio': 'Supermercado Central',
        'fecha': '2026-10-28',
        'moneda': 'USD',
        'total_original': 15.50,
        'impuesto_iva': 0.0,
        'items': [
          {'descripcion': 'Harina Pan', 'cantidad': 2, 'precio_unitario': 1.50, 'total': 3.00, 'categoria': 'Alimentos'},
          {'descripcion': 'Queso Paisa', 'cantidad': 1, 'precio_unitario': 12.50, 'total': 12.50, 'categoria': 'Alimentos'},
        ],
      };

      final result1 = GeminiExtractionResult.fromJson(initialJson);
      final mapped = result1.toMap();
      final result2 = GeminiExtractionResult.fromJson(mapped);

      expect(result2.comercio, equals('Supermercado Central'));
      expect(result2.totalOriginal, equals(15.50));
      expect(result2.items.length, equals(2));
      expect(result2.items[0].precioUnitarioDisplay, equals(1.50));
      expect(result2.items[0].totalDisplay, equals(3.00));
      expect(result2.items[1].precioUnitarioDisplay, equals(12.50));
      expect(result2.items[1].totalDisplay, equals(12.50));
    });

    test('Fallback cuando comercio es nulo o vacío es "Comercio no especificado"', () {
      final json = {
        'fecha': '2026-10-28',
        'moneda': 'USD',
        'total_original': 10.0,
      };

      final result = GeminiExtractionResult.fromJson(json);
      expect(result.comercio, equals('Comercio no especificado'));
    });
  });

  group('GeminiExtractionResult - Normalización de fechas (parseExtractionDate)', () {
    test('Formato ISO YYYY-MM-DD se preserva exactamente', () {
      expect(
        GeminiExtractionResult.parseExtractionDate('2026-11-03'),
        equals('2026-11-03'),
      );
    });

    test('Formato ISO con timestamp o sufijo T se normaliza a YYYY-MM-DD', () {
      expect(
        GeminiExtractionResult.parseExtractionDate('2026-11-03T14:30:00Z'),
        equals('2026-11-03'),
      );
    });

    test('Formato venezolano DD/MM/YYYY ambiguo (03/11/2026) se normaliza a 2026-11-03 (3 de noviembre)', () {
      expect(
        GeminiExtractionResult.parseExtractionDate('03/11/2026'),
        equals('2026-11-03'),
      );
    });

    test('Formato con guiones DD-MM-YYYY (03-11-2026) se normaliza a 2026-11-03', () {
      expect(
        GeminiExtractionResult.parseExtractionDate('03-11-2026'),
        equals('2026-11-03'),
      );
    });

    test('Formato con puntos DD.MM.YYYY (03.11.2026) se normaliza a 2026-11-03', () {
      expect(
        GeminiExtractionResult.parseExtractionDate('03.11.2026'),
        equals('2026-11-03'),
      );
    });

    test('Día de un solo dígito (3/11/2026) se rellena con cero a 2026-11-03', () {
      expect(
        GeminiExtractionResult.parseExtractionDate('3/11/2026'),
        equals('2026-11-03'),
      );
    });

    test('Año de dos dígitos (03/11/26) se expande al siglo 2000 (2026-11-03)', () {
      expect(
        GeminiExtractionResult.parseExtractionDate('03/11/26'),
        equals('2026-11-03'),
      );
    });

    test('Factura procesada con json fecha 03/11/2026 se extrae como 2026-11-03 en fromJson', () {
      final json = {
        'comercio': 'Automercado',
        'fecha': '03/11/2026',
        'moneda': 'USD',
        'total_original': 12.50,
        'items': [
          {'descripcion': 'Queso', 'cantidad': 1, 'precio_unitario': 12.50, 'total': 12.50},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);
      expect(result.fecha, equals('2026-11-03'));
    });

    test('Valor nulo o vacío cae en la fecha de hoy en formato ISO YYYY-MM-DD', () {
      final todayIso = DateTime.now().toIso8601String().substring(0, 10);
      expect(GeminiExtractionResult.parseExtractionDate(null), equals(todayIso));
      expect(GeminiExtractionResult.parseExtractionDate(''), equals(todayIso));
      expect(GeminiExtractionResult.parseExtractionDate('   '), equals(todayIso));
    });
  });

  group('GeminiExtractionResult - Integridad y saneamiento de datos IA (C2)', () {
    test('1. precio_unitario negativo (-50) se sanea a 0 y total 0', () {
      final json = {
        'facturas': [
          {
            'comercio': 'Tienda Test',
            'fecha': '2026-11-10',
            'moneda': 'USD',
            'total_original': 0.0,
            'items': [
              {'descripcion': 'Producto', 'cantidad': 1, 'precio_unitario': -50.0},
            ],
          }
        ]
      };

      final results = GeminiExtractionResult.listFromJson(json);
      expect(results.first.items.first.precioUnitario, equals(0));
      expect(results.first.items.first.total, equals(0));
    });

    test('2. total_original negativo (-100) se sanea a 0', () {
      final json = {
        'facturas': [
          {
            'comercio': 'Tienda Test',
            'fecha': '2026-11-10',
            'moneda': 'USD',
            'total_original': -100.0,
            'items': <dynamic>[],
          }
        ]
      };

      final results = GeminiExtractionResult.listFromJson(json);
      expect(results.first.totalOriginal, equals(0.0));
    });

    test('3. cantidad desproporcionada (1000000000000) se trunca a 10000 sin excepción', () {
      final json = {
        'facturas': [
          {
            'comercio': 'Tienda Test',
            'fecha': '2026-11-10',
            'moneda': 'USD',
            'total_original': 100.0,
            'items': [
              {'descripcion': 'Arroz', 'cantidad': 1000000000000, 'precio_unitario': 10.0},
            ],
          }
        ]
      };

      final results = GeminiExtractionResult.listFromJson(json);
      expect(results.first.items.first.cantidad, equals(10000.0));
    });

    test('4. precio_unitario enorme (1e300) sin excepción y total <= 100000000000 (centavos)', () {
      final json = {
        'facturas': [
          {
            'comercio': 'Tienda Test',
            'fecha': '2026-11-10',
            'moneda': 'USD',
            'total_original': 100.0,
            'items': [
              {'descripcion': 'Oro', 'cantidad': 1, 'precio_unitario': 1e300},
            ],
          }
        ]
      };

      final results = GeminiExtractionResult.listFromJson(json);
      expect(results.first.items.first.precioUnitario, lessThanOrEqualTo(100000000000));
      expect(results.first.items.first.total, lessThanOrEqualTo(100000000000));
    });

    test('5. precio_unitario no numérico ("abc") se sanea a 0', () {
      final json = {
        'facturas': [
          {
            'comercio': 'Tienda Test',
            'fecha': '2026-11-10',
            'moneda': 'USD',
            'total_original': 0.0,
            'items': [
              {'descripcion': 'Algo', 'cantidad': 1, 'precio_unitario': 'abc'},
            ],
          }
        ]
      };

      final results = GeminiExtractionResult.listFromJson(json);
      expect(results.first.items.first.precioUnitario, equals(0));
      expect(results.first.items.first.total, equals(0));
    });
  });
}
