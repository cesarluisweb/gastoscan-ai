import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/services/export_service.dart';

void main() {
  group('ExportService CSV Injection Prevention Tests', () {
    test('sanitizeCsvCell neutralizes formula prefixes (=, +, -, @, tab, cr)', () {
      expect(ExportService.sanitizeCsvCell('=SUM(A1:A10)'), equals("'=SUM(A1:A10)"));
      expect(ExportService.sanitizeCsvCell('+123456'), equals("'+123456"));
      expect(ExportService.sanitizeCsvCell('-Descuento'), equals("'-Descuento"));
      expect(ExportService.sanitizeCsvCell('@tienda_oficial'), equals("'@tienda_oficial"));
      expect(ExportService.sanitizeCsvCell('  =HYPERLINK("http://evil")'), equals("'  =HYPERLINK(\"http://evil\")"));
      expect(ExportService.sanitizeCsvCell('\t=CMD()'), equals("'\t=CMD()"));
      expect(ExportService.sanitizeCsvCell('\r+CMD()'), equals("'\r+CMD()"));
    });

    test('sanitizeCsvCell preserves safe strings and empty values unchanged', () {
      expect(ExportService.sanitizeCsvCell(''), equals(''));
      expect(ExportService.sanitizeCsvCell('Automercado Plaza'), equals('Automercado Plaza'));
      expect(ExportService.sanitizeCsvCell('2026-10-23'), equals('2026-10-23'));
      expect(ExportService.sanitizeCsvCell('Harina PAN 1kg'), equals('Harina PAN 1kg'));
    });

    test('generateCsvData neutralizes dangerous comercio and item descriptions', () {
      final gastos = [
        GastoModel(
          id: 1,
          uuid: 'gasto-csv-1',
          fecha: '2026-10-23',
          comercio: '=CMD|\' /C calc\'!A0',
          moneda: 'USD',
          totalOriginal: 1500,
          totalUsd: 1500,
          categoria: 'Alimentación',
          creadoEn: '2026-10-23T10:00:00Z',
          items: [
            ItemGastoModel(
              descripcion: '+Producto malicioso',
              cantidad: 1.0,
              precioUnitario: 1500,
              total: 1500,
              categoria: 'Alimentación',
            ),
          ],
        ),
        GastoModel(
          id: 2,
          uuid: 'gasto-csv-2',
          fecha: '2026-10-23',
          comercio: '-Comercio con guion',
          moneda: 'VES',
          totalOriginal: 50000,
          totalUsd: 1000,
          categoria: '@CategoriaInyectada',
          creadoEn: '2026-10-23T11:00:00Z',
          items: [],
        ),
      ];

      final csv = ExportService.generateCsvData(gastos);

      expect(csv, contains("'=CMD|"));
      expect(csv, contains("'+Producto malicioso"));
      expect(csv, contains("'-Comercio con guion"));
      expect(csv, contains("'@CategoriaInyectada"));
    });
  });
}
