import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gemini_extraction_result.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';

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

    test('Caso G ([F1-C04]): Preserva Higiene, Ropa, Entretenimiento, moneda USDT e imputa 16% cuando toda la factura calza al 16%', () {
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
      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items.length, equals(2));
      expect(result.items[0].categoria, equals('Higiene'));
      expect(result.items[0].total, equals(812)); // 7.00 * 1.16 = 8.12
      expect(result.items[0].baseImponibleOriginal, equals(700));
      expect(result.items[1].categoria, equals('Alimentación'));
      expect(result.items[1].total, equals(348)); // 3.00 * 1.16 = 3.48
      expect(result.items[1].baseImponibleOriginal, equals(300));
      expect(result.items.fold<int>(0, (s, it) => s + it.total), equals(1160));
    });

    test('Caso G-Fallback: Factura mixta ambigua sin (E)/(G) conserva Impuesto IVA en categoría dominante', () {
      // 7.00 + 3.00 = 10.00 pero IVA = 1.12 (solo 7.00 era gravado) sin etiquetas E/G -> no adivina
      final json = {
        'comercio': 'Farmatodo',
        'fecha': '2026-10-20',
        'moneda': 'USDT',
        'total_original': 11.12,
        'impuesto_iva': 1.12,
        'items': [
          {'descripcion': 'Champú', 'cantidad': 1, 'precio_unitario': 7.00, 'total': 7.00, 'categoria': 'Higiene'},
          {'descripcion': 'Galletas', 'cantidad': 1, 'precio_unitario': 3.00, 'total': 3.00, 'categoria': 'Alimentación'},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.ivaModo, equals(IvaModo.renglonSeparado));
      expect(result.items.length, equals(3));
      expect(result.items[2].descripcion, equals('Impuesto IVA'));
      // Categoría dominante es Higiene (7.00 > 3.00), no 'Otros'
      expect(result.items[2].categoria, equals('Higiene'));
      expect(result.items[2].totalDisplay, equals(1.12));
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

  group('AI-06 Push 1 - Clasificación estricta, IvaModo, schema_v y fromQueueMap', () {
    test('ItemGastoModel.toMap conserva exactamente las 7 columnas de SQLite items_gasto', () {
      final item = ItemGastoModel(
        id: 1,
        gastoId: 10,
        descripcion: 'Harina PAN',
        cantidad: 2.0,
        precioUnitario: 150,
        total: 300,
        categoria: 'Alimentación',
      );
      final map = item.toMap();
      expect(
        map.keys.toSet(),
        equals({'id', 'gasto_id', 'descripcion', 'cantidad', 'precio_unitario', 'total', 'categoria'}),
      );
    });

    test('Regresión Aceite de oliva / Leche Nativa / Crema Activa NO se confunden con IVA e imputan 16% exacto', () {
      final json = {
        'comercio': 'Automercado Plaza',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 464.00,
        'impuesto_iva': 64.00,
        'items': [
          {'descripcion': 'Aceite de oliva 500ml', 'cantidad': 1, 'precio_unitario': 200.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Leche Nativa 1L', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Crema Activa Corporal', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Higiene', 'alicuota_fiscal': 'G'},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(ItemGastoModel.isTaxDescription('Aceite de oliva 500ml'), isFalse);
      expect(ItemGastoModel.isTaxDescription('Leche Nativa 1L'), isFalse);
      expect(ItemGastoModel.isTaxDescription('Crema Activa Corporal'), isFalse);
      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items.length, equals(3));
      expect(result.items[0].descripcion, equals('Aceite de oliva 500ml'));
      expect(result.items[0].total, equals(23200));
      expect(result.items[0].baseImponibleOriginal, equals(20000));
      expect(result.items[1].total, equals(11600));
      expect(result.items[2].total, equals(11600));
      expect(result.items.fold<int>(0, (s, it) => s + it.total), equals(46400));
    });

    test('IVA explícito dentro de items más impuesto_iva en cabecera NO duplica el impuesto e imputa 16%', () {
      final json = {
        'comercio': 'Farmatodo',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 300.00,
        'impuesto_iva': 41.38,
        'items': [
          {'descripcion': 'Detergente', 'cantidad': 1, 'precio_unitario': 258.62, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
          {'descripcion': 'IVA 16%', 'cantidad': 1, 'precio_unitario': 41.38, 'categoria': 'Otros'},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items.length, equals(1));
      expect(result.items[0].descripcion, equals('Detergente'));
      expect(result.items[0].total, equals(30000));
      expect(result.items[0].precioUnitario, equals(30000));
      expect(result.items[0].baseImponibleOriginal, equals(25862));
      expect(result.items[0].tasaIvaPct, equals(16));
    });

    test('IVA explícito dentro de items que discrepa del header impuesto_iva marca requiereRevision', () {
      final json = {
        'comercio': 'Farmatodo',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 300.00,
        'impuesto_iva': 50.00,
        'items': [
          {'descripcion': 'Detergente', 'cantidad': 1, 'precio_unitario': 258.62, 'categoria': 'Hogar'},
          {'descripcion': 'IVA 16%', 'cantidad': 1, 'precio_unitario': 41.38, 'categoria': 'Otros'},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);
      expect(result.ivaModo, equals(IvaModo.requiereRevision));
    });

    test('Líneas resumen (SUBTOTAL, BASE IMPONIBLE, EXENTO) coladas por el LLM se descartan antes de imputar IVA', () {
      final json = {
        'comercio': 'Supermercado',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 116.00,
        'impuesto_iva': 16.00,
        'items': [
          {'descripcion': 'Shampoo', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Higiene', 'alicuota_fiscal': 'G'},
          {'descripcion': 'SUBTOTAL', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Otros'},
          {'descripcion': 'BASE IMPONIBLE', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Otros'},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);

      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items.length, equals(1));
      expect(result.items[0].descripcion, equals('Shampoo'));
      expect(result.items[0].total, equals(11600));
      expect(result.items[0].baseImponibleOriginal, equals(10000));
    });

    test('Detecta descuentos negativos, descuentos por texto, IGTF y servicio como hasSpecialLines', () {
      expect(
        GeminiExtractionResult.classifyRawLine(
          descripcion: 'Descuento promocional',
          rawUnitPrice: -5.0,
          rawTotal: -5.0,
        ),
        equals(TipoLineaExtraccion.descuento),
      );
      expect(
        GeminiExtractionResult.classifyRawLine(
          descripcion: 'BONIFICACION CLIENTE',
          rawUnitPrice: 5.0,
          rawTotal: 5.0,
        ),
        equals(TipoLineaExtraccion.descuento),
      );
      expect(
        GeminiExtractionResult.classifyRawLine(
          descripcion: 'IGTF 3%',
          rawUnitPrice: 0.90,
          rawTotal: 0.90,
        ),
        equals(TipoLineaExtraccion.igtf),
      );
      expect(
        GeminiExtractionResult.classifyRawLine(
          descripcion: 'Servicio 10%',
          rawUnitPrice: 10.0,
          rawTotal: 10.0,
        ),
        equals(TipoLineaExtraccion.servicio),
      );

      final jsonConDescuento = {
        'comercio': 'Tienda',
        'fecha': '2026-11-20',
        'moneda': 'USD',
        'total_original': 20.00,
        'impuesto_iva': 0.0,
        'items': [
          {'descripcion': 'Camisa', 'cantidad': 1, 'precio_unitario': 25.00, 'categoria': 'Ropa'},
          {'descripcion': 'Descuento', 'cantidad': 1, 'precio_unitario': -5.00, 'categoria': 'Ropa'},
        ],
      };

      final result = GeminiExtractionResult.fromJson(jsonConDescuento);
      expect(result.hasSpecialLines, isTrue);
      expect(result.ivaModo, equals(IvaModo.sinIvaDeclarado));
    });

    test('Diferencia sinIvaDeclarado (impuesto_iva: 0) de noInformado (campo ausente)', () {
      final sinIva = GeminiExtractionResult.fromJson({
        'comercio': 'Abasto',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 50.0,
        'impuesto_iva': 0.0,
        'items': [
          {'descripcion': 'Harina PAN', 'cantidad': 1, 'precio_unitario': 50.0},
        ],
      });
      final noInformado = GeminiExtractionResult.fromJson({
        'comercio': 'Abasto',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 50.0,
        'items': [
          {'descripcion': 'Harina PAN', 'cantidad': 1, 'precio_unitario': 50.0},
        ],
      });

      expect(sinIva.ivaModo, equals(IvaModo.sinIvaDeclarado));
      expect(noInformado.ivaModo, equals(IvaModo.noInformado));
    });

    test('IGTF en items NO suprime la creación de Impuesto IVA cuando impuesto_iva > 0', () {
      final json = {
        'comercio': 'Restaurante',
        'fecha': '2026-11-20',
        'moneda': 'USD',
        'total_original': 119.48,
        'impuesto_iva': 16.00,
        'items': [
          {'descripcion': 'Almuerzo', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Alimentación'},
          {'descripcion': 'IGTF 3%', 'cantidad': 1, 'precio_unitario': 3.48, 'categoria': 'Otros'},
        ],
      };

      final result = GeminiExtractionResult.fromJson(json);
      expect(result.hasSpecialLines, isTrue);
      expect(result.ivaModo, equals(IvaModo.renglonSeparado));
      expect(result.items.any((it) => it.descripcion == 'Impuesto IVA' && it.total == 1600), isTrue);
      expect(result.items.any((it) => it.descripcion == 'IGTF 3%' && it.categoria == 'Alimentación'), isTrue);
    });

    test('Round-trip idempotente toMap -> fromQueueMap preserva schema_v: 2, iva_modo, baseImponibleOriginal y centavos exactos', () {
      final initial = GeminiExtractionResult.fromJson({
        'comercio': 'Farmatodo',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 300.00,
        'impuesto_iva': 41.38,
        'items': [
          {'descripcion': 'Detergente', 'cantidad': 1, 'precio_unitario': 258.62, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
        ],
      });

      final serialized1 = initial.toMap();
      expect(serialized1['schema_v'], equals(2));
      expect(serialized1['iva_modo'], equals('imputado'));
      expect((serialized1['items'] as List).first['precio_unitario_cents'], equals(30000));
      expect((serialized1['items'] as List).first['total_cents'], equals(30000));
      expect((serialized1['items'] as List).first['base_imponible_original_cents'], equals(25862));
      expect((serialized1['items'] as List).first['tasa_iva_pct'], equals(16));

      final restored = GeminiExtractionResult.fromQueueMap(serialized1);
      final serialized2 = restored.toMap();

      expect(serialized2, equals(serialized1));
      expect(restored.ivaModo, equals(IvaModo.imputado));
      expect(restored.items.length, equals(1));
      expect(restored.items[0].descripcion, equals('Detergente'));
      expect(restored.items[0].precioUnitario, equals(30000));
      expect(restored.items[0].baseImponibleOriginal, equals(25862));
      expect(restored.items[0].tasaIvaPct, equals(16));
    });

    test('Fixture legado de scan_queue (sin schema_v ni iva_modo) se restaura intacto sin re-ejecutar heurísticas', () {
      // JSON real equivalente al formato producido antes de AI-06 (schema_v ausente)
      final legacyQueueMap = <String, dynamic>{
        'comercio': 'Automercado Plaza',
        'fecha': '2026-11-18',
        'moneda': 'VES',
        'total_original': 300.0,
        'impuesto_iva': 41.38,
        'tasa_cambio': 45.2,
        'items': [
          {
            'descripcion': 'Detergente Liquido (G)',
            'cantidad': 1.0,
            'precio_unitario': 258.62,
            'total': 258.62,
            'categoria': 'Hogar',
          },
          {
            'descripcion': 'Impuesto IVA',
            'cantidad': 1.0,
            'precio_unitario': 41.38,
            'total': 41.38,
            'categoria': 'Hogar',
          },
        ],
        'items_comprados_ids': <int>[],
        'metodo_liquidacion': null,
      };

      final restored = GeminiExtractionResult.fromQueueMap(legacyQueueMap);

      expect(restored.schemaVersion, equals(1));
      expect(restored.ivaModo, equals(IvaModo.renglonSeparado));
      expect(restored.items.length, equals(2));
      expect(restored.items[0].descripcion, equals('Detergente Liquido (G)'));
      expect(restored.items[0].precioUnitario, equals(25862));
      expect(restored.items[1].descripcion, equals('Impuesto IVA'));
      expect(restored.items[1].total, equals(4138));
    });

    test('fromQueueMap con registro legado donde total != suma NO altera decimales ni inyecta IVA extra', () {
      final legacyNoIvaLine = <String, dynamic>{
        'comercio': 'Bodega',
        'fecha': '2026-11-18',
        'moneda': 'USD',
        'total_original': 15.0,
        'impuesto_iva': 2.0,
        'items': [
          {
            'descripcion': 'Aceite de oliva',
            'cantidad': 1.0,
            'precio_unitario': 15.0,
            'total': 15.0,
            'categoria': 'Alimentación',
          },
        ],
      };

      final restored = GeminiExtractionResult.fromQueueMap(legacyNoIvaLine);

      expect(restored.schemaVersion, equals(1));
      expect(restored.ivaModo, equals(IvaModo.yaIncluido));
      expect(restored.items.length, equals(1));
      expect(restored.items[0].descripcion, equals('Aceite de oliva'));
      expect(restored.items[0].total, equals(1500));
    });

    test('listFromJson procesa múltiples facturas en una misma foto preservando IvaModo por factura', () {
      final multiJson = {
        'facturas': [
          {
            'comercio': 'Farmatodo',
            'fecha': '2026-11-20',
            'moneda': 'VES',
            'total_original': 116.00,
            'impuesto_iva': 16.00,
            'items': [
              {'descripcion': 'Aceite de oliva', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'G'},
            ],
          },
          {
            'comercio': 'Panadería',
            'fecha': '2026-11-20',
            'moneda': 'VES',
            'total_original': 50.00,
            'impuesto_iva': 0.00,
            'items': [
              {'descripcion': 'Pan Canilla', 'cantidad': 2, 'precio_unitario': 25.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
            ],
          },
        ],
      };

      final results = GeminiExtractionResult.listFromJson(multiJson);
      expect(results.length, equals(2));
      expect(results[0].ivaModo, equals(IvaModo.imputado));
      expect(results[0].items.length, equals(1));
      expect(results[0].items[0].descripcion, equals('Aceite de oliva'));
      expect(results[0].items[0].total, equals(11600));
      expect(results[1].ivaModo, equals(IvaModo.sinIvaDeclarado));
      expect(results[1].items.length, equals(1));
    });

    test('Clasificadores de ItemGastoModel evitan falsos positivos y negativos en facturas reales VE', () {
      // Variantes reales de IVA e IGTF -> true
      expect(ItemGastoModel.isIvaOnlyDescription('IVA-16%'), isTrue);
      expect(ItemGastoModel.isIvaOnlyDescription('IVA/16%'), isTrue);
      expect(ItemGastoModel.isIvaOnlyDescription('Impuesto (IVA)'), isTrue);
      expect(ItemGastoModel.isIvaOnlyDescription('Impuesto al IVA'), isTrue);
      expect(ItemGastoModel.isIvaOnlyDescription('Monto IVA'), isTrue);
      expect(ItemGastoModel.isTaxDescription('IGTF-3%'), isTrue);
      expect(ItemGastoModel.isTaxDescription('Cargo IGTF 3%'), isTrue);
      expect(ItemGastoModel.isTaxDescription('3% IGTF'), isTrue);

      // Productos compuestos y marcas -> NO son impuestos ni descuentos ni servicio
      expect(ItemGastoModel.isTaxDescription('Combo con IVA 16%'), isFalse);
      expect(ItemGastoModel.isTaxDescription('Envío + IVA 16%'), isFalse);
      expect(ItemGastoModel.isServiceOrTipDescription('Servicio técnico'), isFalse);
      expect(ItemGastoModel.isServiceOrTipDescription('Servicio de internet'), isFalse);
      expect(ItemGastoModel.isServiceOrTipDescription('Cubierto de plástico'), isFalse);
      expect(ItemGastoModel.isServiceOrTipDescription('Tip Top Galletas'), isFalse);
      expect(ItemGastoModel.isDiscountDescription('Pack Ahorro Pañales'), isFalse);
      expect(ItemGastoModel.isDiscountDescription('Combo Promo 2x1'), isFalse);
      expect(ItemGastoModel.isDiscountDescription('Shampoo Promoción'), isFalse);

      // Servicio y propina reales -> true
      expect(ItemGastoModel.isServiceOrTipDescription('Servicio 10%'), isTrue);
      expect(ItemGastoModel.isServiceOrTipDescription('10% Servicio'), isTrue);
      expect(ItemGastoModel.isServiceOrTipDescription('Cargo por servicio'), isTrue);
      expect(ItemGastoModel.isServiceOrTipDescription('Propina'), isTrue);
      expect(ItemGastoModel.isServiceOrTipDescription('Cubiertos'), isTrue);
    });

    test('fromQueueJson degrada limpiamente ante null, cadena vacía, JSON corrupto o no-Map', () {
      expect(GeminiExtractionResult.fromQueueJson(null).comercio, equals('Comercio no especificado'));
      expect(GeminiExtractionResult.fromQueueJson('').comercio, equals('Comercio no especificado'));
      expect(GeminiExtractionResult.fromQueueJson('{corrupto').comercio, equals('Comercio no especificado'));
      expect(GeminiExtractionResult.fromQueueJson('[]').comercio, equals('Comercio no especificado'));
      expect(GeminiExtractionResult.fromQueueJson('null').comercio, equals('Comercio no especificado'));
      expect(GeminiExtractionResult.fromQueueJson(12345).comercio, equals('Comercio no especificado'));

      // También tolera id/gasto_id como String y cents negativos corruptos sin lanzar TypeError
      final corruptedMap = GeminiExtractionResult.fromQueueJson({
        'comercio': 'Bodega',
        'total_original': 10.0,
        'items': [
          {
            'id': 'no_es_num',
            'gasto_id': 'tampoco',
            'descripcion': 'Agua',
            'cantidad': 1,
            'precio_unitario_cents': -500,
            'total_cents': -500,
          },
        ],
      });
      expect(corruptedMap.items.first.id, isNull);
      expect(corruptedMap.items.first.gastoId, isNull);
      expect(corruptedMap.items.first.precioUnitario, equals(0));
      expect(corruptedMap.items.first.total, equals(0));
    });

    test('Renglón IVA 16% con monto 0 cuando header impuesto_iva > 0 marca requiereRevision', () {
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Farmatodo',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 116.00,
        'impuesto_iva': 16.00,
        'items': [
          {'descripcion': 'Jabón', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Higiene'},
          {'descripcion': 'IVA 16%', 'cantidad': 1, 'precio_unitario': 0.00, 'categoria': 'Otros'},
        ],
      });
      expect(result.ivaModo, equals(IvaModo.requiereRevision));
    });
  });

  group('AI-06 Push 2 - Imputación por Mayor Resto, Decimales, YaIncluido y Casos Borde', () {
    test('Factura mixta (E) + (G): imputa 16% solo a (G), deja (E) intacto y limpia sufijos', () {
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Automercado Plaza',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 410.00,
        'impuesto_iva': 41.38,
        'items': [
          {'descripcion': 'Harina PAN 1kg', 'cantidad': 1, 'precio_unitario': 110.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Detergente Líquido', 'cantidad': 1, 'precio_unitario': 258.62, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
        ],
      });

      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items.length, equals(2));
      expect(result.items[0].descripcion, equals('Harina PAN 1kg'));
      expect(result.items[0].total, equals(11000));
      expect(result.items[0].baseImponibleOriginal, isNull);
      expect(result.items[0].tasaIvaPct, equals(0));

      expect(result.items[1].descripcion, equals('Detergente Líquido'));
      expect(result.items[1].total, equals(30000));
      expect(result.items[1].precioUnitario, equals(30000));
      expect(result.items[1].baseImponibleOriginal, equals(25862));
      expect(result.items[1].tasaIvaPct, equals(16));
      expect(result.items.fold<int>(0, (s, it) => s + it.total), equals(41000));
    });

    test('Mayor Resto con cantidad = 3 (Bs. 1.08 base): total=3.76 exacto, precioUnitario=1.25 sin distorsión', () {
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Abasto',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 3.76,
        'impuesto_iva': 0.52,
        'items': [
          {'descripcion': 'Galleta', 'cantidad': 3, 'precio_unitario': 1.08, 'categoria': 'Alimentación', 'alicuota_fiscal': 'G'},
        ],
      });

      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items.length, equals(1));
      expect(result.items[0].precioUnitario, equals(125)); // round(108 * 1.16) = 125
      expect(result.items[0].total, equals(376)); // 324 + 52 = 376 exacto
      expect(result.items[0].baseImponibleOriginal, equals(108));
      expect(result.items[0].tasaIvaPct, equals(16));
    });

    test('Mayor Resto con múltiples productos gravados: suma de totales == total_original al centavo', () {
      // 3 productos idénticos de base 1.01 -> total base 3.03; IVA 16% = 0.4848 -> 0.48; total = 3.51
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Farmatodo',
        'fecha': '2026-11-20',
        'moneda': 'USD',
        'total_original': 3.51,
        'impuesto_iva': 0.48,
        'items': [
          {'descripcion': 'Item A', 'cantidad': 1, 'precio_unitario': 1.01, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Item B', 'cantidad': 1, 'precio_unitario': 1.01, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Item C', 'cantidad': 1, 'precio_unitario': 1.01, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
        ],
      });

      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items.fold<int>(0, (s, it) => s + it.total), equals(351));
    });

    test('Caso 24 unidades (guardia con tolerancia por cantidad) + recálculo sin perder precisión', () {
      // 24 x 0.45 = 10.80 base; IVA 16% = 1.73; Total = 12.53
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Mayorista',
        'fecha': '2026-11-20',
        'moneda': 'USD',
        'total_original': 12.53,
        'impuesto_iva': 1.73,
        'items': [
          {'descripcion': 'Agua Mineral', 'cantidad': 24, 'precio_unitario': 0.45, 'categoria': 'Alimentación', 'alicuota_fiscal': 'G'},
        ],
      });

      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items[0].total, equals(1253));
      expect(result.items[0].precioUnitario, equals(52)); // round(45 * 1.16) = 52
      expect(result.items[0].baseImponibleOriginal, equals(45));
    });

    test('Decimales omitidos antes de imputar IVA: 1156 -> 11.56 y luego imputa IVA 1.85', () {
      // Exento 10.00 + Gravado 11.56 (leído 1156) + IVA 1.85 = Total 23.41
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Supermercado',
        'fecha': '2026-11-20',
        'moneda': 'USD',
        'total_original': 23.41,
        'impuesto_iva': 1.85,
        'items': [
          {'descripcion': 'Harina', 'cantidad': 1, 'precio_unitario': 10.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Jabón', 'cantidad': 1, 'precio_unitario': 1156, 'categoria': 'Higiene', 'alicuota_fiscal': 'G'},
        ],
      });

      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items.length, equals(2));
      expect(result.items[0].total, equals(1000));
      expect(result.items[1].baseImponibleOriginal, equals(1156));
      expect(result.items[1].total, equals(1341)); // 1156 + 185 = 1341
      expect(result.items.fold<int>(0, (s, it) => s + it.total), equals(2341));
    });

    test('Guardia IVA ya incluido en líneas: NO aplica doble IVA ni agrega Impuesto IVA ni baseImponibleOriginal', () {
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Nota de Entrega',
        'fecha': '2026-11-20',
        'moneda': 'USD',
        'total_original': 3.00,
        'impuesto_iva': 0.41,
        'items': [
          {'descripcion': 'Detergente', 'cantidad': 1, 'precio_unitario': 3.00, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
        ],
      });

      expect(result.ivaModo, equals(IvaModo.yaIncluido));
      expect(result.items.length, equals(1));
      expect(result.items[0].descripcion, equals('Detergente'));
      expect(result.items[0].total, equals(300));
      expect(result.items[0].baseImponibleOriginal, isNull);
      expect(result.items[0].tasaIvaPct, equals(0));
    });

    test('Alícuota reducida (R = 8%) combinada con (G = 16%) imputa cada tasa exacta', () {
      // G=100.00 (IVA 16.00) + R=50.00 (IVA 4.00) = 150.00 base + 20.00 IVA = 170.00
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Supermercado',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 170.00,
        'impuesto_iva': 20.00,
        'items': [
          {'descripcion': 'Detergente', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Carne Especial', 'cantidad': 1, 'precio_unitario': 50.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'R'},
        ],
      });

      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items[0].total, equals(11600));
      expect(result.items[0].tasaIvaPct, equals(16));
      expect(result.items[1].total, equals(5400));
      expect(result.items[1].tasaIvaPct, equals(8));
      expect(result.items[1].baseImponibleOriginal, equals(5000));
    });

    test('Restaurante con Servicio 10% + IVA 16% NO reparte IVA sobre el servicio (fallback seguro)', () {
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Restaurante',
        'fecha': '2026-11-20',
        'moneda': 'USD',
        'total_original': 126.00,
        'impuesto_iva': 16.00,
        'items': [
          {'descripcion': 'Almuerzo', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Alimentación'},
          {'descripcion': 'Servicio 10%', 'cantidad': 1, 'precio_unitario': 10.00, 'categoria': 'Alimentación'},
        ],
      });

      expect(result.hasSpecialLines, isTrue);
      expect(result.ivaModo, equals(IvaModo.renglonSeparado));
      expect(result.items.length, equals(3));
      expect(result.items.last.descripcion, equals('Impuesto IVA'));
    });

    test('Tolerancia fiscal estricta rechaza mezcla G(16%) + R(8%) sin etiqueta R (contraejemplo 1000 + 100, IVA 168)', () {
      // Base G=1000 (IVA 160) + producto sin etiqueta=100 (IVA 8) -> IVA=168;
      // 16% de 1000 = 160 (diff 8 > tol) y 16% de 1100 = 176 (diff 8 > tol) -> fallback seguro
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Tienda',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 1268.00,
        'impuesto_iva': 168.00,
        'items': [
          {'descripcion': 'Producto G', 'cantidad': 1, 'precio_unitario': 1000.00, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Producto R sin etiqueta', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Hogar'},
        ],
      });

      expect(result.ivaModo, equals(IvaModo.renglonSeparado));
      expect(result.items.any((it) => it.descripcion == 'Impuesto IVA'), isTrue);
    });

    test('ItemGastoModel.copyWith con clearBaseImponibleOriginal limpia realmente la base y la tasa', () {
      final item = ItemGastoModel(
        descripcion: 'Detergente',
        cantidad: 1,
        precioUnitario: 30000,
        total: 30000,
        baseImponibleOriginal: 25862,
        tasaIvaPct: 16,
      );

      final preserved = item.copyWith(descripcion: 'Detergente 1L');
      expect(preserved.baseImponibleOriginal, equals(25862));
      expect(preserved.tasaIvaPct, equals(16));

      final cleared = item.copyWith(precioUnitario: 31000, total: 31000, clearBaseImponibleOriginal: true);
      expect(cleared.baseImponibleOriginal, isNull);
      expect(cleared.tasaIvaPct, equals(0));
    });

    test('Regresión: total_original inflado x100 con impuesto_iva 16% (11600 vs 100+16) se corrige e imputa', () {
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Farmatodo',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 11600, // omitió decimales (real 116.00)
        'impuesto_iva': 16.00,
        'items': [
          {'descripcion': 'Champú', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Higiene', 'alicuota_fiscal': 'G'},
        ],
      });

      expect(result.totalOriginal, closeTo(116.00, 0.001));
      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items.length, equals(1));
      expect(result.items[0].total, equals(11600));
      expect(result.items[0].baseImponibleOriginal, equals(10000));
    });

    test('BigInt en repartirIvaMayorResto evita overflow de 64 bits con montos altos en bolívares (Bs. 25.000.000)', () {
      // Base 25.000.000,00 Bs = 2.500.000.000 centavos; IVA 16% = 4.000.000,00 Bs = 400.000.000 centavos
      // Sin BigInt, 4e8 * (2.5e9 * 16) = 1.6e19 > 2^63 - 1 (9.22e18) desbordaría a negativo.
      final shares = GeminiExtractionResult.repartirIvaMayorResto(
        [2500000000, 500000000],
        [16, 16],
        480000000,
      );

      expect(shares[0], equals(400000000));
      expect(shares[1], equals(80000000));
      expect(shares[0] + shares[1], equals(480000000));
    });

    test('Ítem promocional de Bs. 0 marcado (G) no genera baseImponibleOriginal artificial', () {
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Supermercado',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 116.00,
        'impuesto_iva': 16.00,
        'items': [
          {'descripcion': 'Detergente', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Muestra gratis', 'cantidad': 1, 'precio_unitario': 0.00, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
        ],
      });

      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items[0].baseImponibleOriginal, equals(10000));
      expect(result.items[1].baseImponibleOriginal, isNull);
      expect(result.items[1].tasaIvaPct, equals(0));
    });

    test('Round-trip toMap -> fromQueueMap preserva base_total_original_cents con cantidad decimal 0.31', () {
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Supermercado',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 93.00,
        'impuesto_iva': 12.83,
        'items': [
          {'descripcion': 'Detergente a granel', 'cantidad': 0.31, 'precio_unitario': 258.62, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
        ],
      });

      expect(result.ivaModo, equals(IvaModo.imputado));
      expect(result.items[0].baseImponibleOriginal, equals(25862));
      expect(result.items[0].baseTotalOriginal, equals(8017));
      expect(result.items[0].total, equals(9300));

      final restored = GeminiExtractionResult.fromQueueMap(result.toMap());
      expect(restored.items[0].baseImponibleOriginal, equals(25862));
      expect(restored.items[0].baseTotalOriginal, equals(8017));
      expect(restored.items[0].total, equals(9300));
    });

    test('Rama 3 (renglonSeparado por error OCR) conserva tasaIvaPct en memoria sin setear baseImponibleOriginal', () {
      final result = GeminiExtractionResult.fromJson({
        'comercio': 'Automercado',
        'fecha': '2026-11-20',
        'moneda': 'VES',
        'total_original': 410.00,
        'impuesto_iva': 41.38,
        'items': [
          {'descripcion': 'Jabón', 'cantidad': 1, 'precio_unitario': 100.00, 'categoria': 'Hogar', 'alicuota_fiscal': 'G'},
          {'descripcion': 'Detergente', 'cantidad': 1, 'precio_unitario': 158.62, 'categoria': 'Hogar', 'alicuota_fiscal': 'E'},
          {'descripcion': 'Harina PAN', 'cantidad': 1, 'precio_unitario': 110.00, 'categoria': 'Alimentación', 'alicuota_fiscal': 'E'},
        ],
      });

      expect(result.ivaModo, equals(IvaModo.renglonSeparado));
      expect(result.items[0].tasaIvaPct, equals(16));
      expect(result.items[0].baseImponibleOriginal, isNull);
      expect(result.items[1].tasaIvaPct, equals(0));
      expect(result.items.last.descripcion, equals('Impuesto IVA'));
    });
  });
}
