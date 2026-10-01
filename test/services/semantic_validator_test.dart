import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gemini_extraction_result.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/services/semantic_validator.dart';

void main() {
  group('SemanticValidator Tests', () {
    const validator = SemanticValidator(tolerancePercentage: 0.15);

    test('retorna inválido si la lista de facturas está vacía', () {
      final result = validator.validate([]);
      expect(result.isValid, isFalse);
      expect(result.reason, contains('no devolvió ninguna factura'));
    });

    test('retorna inválido si no tiene comercio ni total válido', () {
      final factura = GeminiExtractionResult(
        comercio: '',
        fecha: '2026-10-01',
        moneda: 'VES',
        totalOriginal: 0.0,
        impuestoIva: 0.0,
        items: [],
      );

      final result = validator.validate([factura]);
      expect(result.isValid, isFalse);
      expect(result.reason, contains('no tiene comercio ni total válidos'));
    });

    test('retorna válido si tiene comercio y total válido coherente con ítems', () {
      final factura = GeminiExtractionResult(
        comercio: 'Automercados Plaza',
        fecha: '2026-10-01',
        moneda: 'VES',
        totalOriginal: 100.0,
        impuestoIva: 0.0,
        items: [
          ItemGastoModel(
            descripcion: 'Harina PAN',
            cantidad: 2.0,
            precioUnitario: 2500, // $25.00
            total: 5000, // $50.00
            categoria: 'Alimentación',
          ),
          ItemGastoModel(
            descripcion: 'Arroz Mary',
            cantidad: 2.0,
            precioUnitario: 2500,
            total: 5000,
            categoria: 'Alimentación',
          ),
        ],
      );

      final result = validator.validate([factura]);
      expect(result.isValid, isTrue);
      expect(result.reason, isNull);
    });

    test('acepta discrepancia pequeña dentro del porcentaje de tolerancia (15%)', () {
      // Total 100, suma de ítems 90 (diferencia 10, que es 10% <= 15%)
      final factura = GeminiExtractionResult(
        comercio: 'Central Madeirense',
        fecha: '2026-10-01',
        moneda: 'USD',
        totalOriginal: 100.0,
        impuestoIva: 0.0,
        items: [
          ItemGastoModel(
            descripcion: 'Café',
            cantidad: 1.0,
            precioUnitario: 9000,
            total: 9000, // $90.00
            categoria: 'Alimentación',
          ),
        ],
      );

      final result = validator.validate([factura]);
      expect(result.isValid, isTrue);
    });

    test('rechaza discrepancia grave superior al porcentaje de tolerancia (>15%)', () {
      // Total 100, suma de ítems 50 (diferencia 50, que es 50% > 15%)
      final factura = GeminiExtractionResult(
        comercio: 'Automercado',
        fecha: '2026-10-01',
        moneda: 'USD',
        totalOriginal: 100.0,
        impuestoIva: 0.0,
        items: [
          ItemGastoModel(
            descripcion: 'Producto A',
            cantidad: 1.0,
            precioUnitario: 5000,
            total: 5000, // $50.00
            categoria: 'Alimentación',
          ),
        ],
      );

      final result = validator.validate([factura]);
      expect(result.isValid, isFalse);
      expect(result.reason, contains('Discrepancia'));
    });
  });
}
