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

    test('Regresión Aceite de oliva / Leche Nativa / Crema Activa NO suprimen el renglón de IVA', () {
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
      expect(result.ivaModo, equals(IvaModo.renglonSeparado));
      expect(result.items.length, equals(4));
      expect(result.items.last.descripcion, equals('Impuesto IVA'));
      expect(result.items.last.total, equals(6400));
      // Categoría dominante: Alimentación (300 > 100)
      expect(result.items.last.categoria, equals('Alimentación'));
    });

    test('IVA explícito dentro de items más impuesto_iva en cabecera NO duplica el impuesto', () {
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

      expect(result.ivaModo, equals(IvaModo.renglonSeparado));
      expect(result.items.length, equals(2));
      expect(result.items.where((it) => ItemGastoModel.isIvaOnlyDescription(it.descripcion)).length, equals(1));
      expect(result.items[1].categoria, equals('Hogar'));
      expect(result.items[1].total, equals(4138));
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

    test('Líneas resumen (SUBTOTAL, BASE IMPONIBLE, EXENTO) coladas por el LLM se descartan', () {
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

      expect(result.items.length, equals(2));
      expect(result.items[0].descripcion, equals('Shampoo (G)'));
      expect(result.items[1].descripcion, equals('Impuesto IVA'));
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

    test('Round-trip idempotente toMap -> fromQueueMap preserva schema_v: 2, iva_modo y centavos exactos', () {
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
      expect(serialized1['iva_modo'], equals('renglonSeparado'));
      expect((serialized1['items'] as List).first['precio_unitario_cents'], equals(25862));
      expect((serialized1['items'] as List).first['total_cents'], equals(25862));

      final restored = GeminiExtractionResult.fromQueueMap(serialized1);
      final serialized2 = restored.toMap();

      expect(serialized2, equals(serialized1));
      expect(restored.ivaModo, equals(IvaModo.renglonSeparado));
      expect(restored.items.length, equals(2));
      expect(restored.items[0].descripcion, equals('Detergente (G)'));
      expect(restored.items[1].descripcion, equals('Impuesto IVA'));
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
      expect(results[0].ivaModo, equals(IvaModo.renglonSeparado));
      expect(results[0].items.length, equals(2));
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
}
