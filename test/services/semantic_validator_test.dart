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

    test('no duplica impuestoIva si la lista items ya incluye el renglón de IVA', () {
      // Compra de 100 con 16 de IVA ya incluido en items: total 116
      final factura = GeminiExtractionResult(
        comercio: 'Farmatodo',
        fecha: '2026-10-23',
        moneda: 'USD',
        totalOriginal: 116.0,
        impuestoIva: 16.0,
        items: [
          ItemGastoModel(
            descripcion: 'Medicamentos',
            cantidad: 1.0,
            precioUnitario: 10000,
            total: 10000, // 100.00
            categoria: 'Salud',
          ),
          ItemGastoModel(
            descripcion: 'Impuesto IVA',
            cantidad: 1.0,
            precioUnitario: 1600,
            total: 1600, // 16.00
            categoria: 'Salud',
          ),
        ],
      );

      final result = validator.validate([factura]);
      expect(result.isValid, isTrue);
    });

    test('no suma impuestoIva dos veces cuando ivaModo es imputado (fallaría si se reintroduce el bug)', () {
      // Con tolerancia 5% (maxAllowedDiff = 5.80 < 16.0), sumar impuestoIva dos veces daría 132 vs 116 -> inválido.
      const strictValidator = SemanticValidator(tolerancePercentage: 0.05);
      final factura = GeminiExtractionResult(
        comercio: 'Farmatodo',
        fecha: '2026-11-20',
        moneda: 'VES',
        totalOriginal: 116.0,
        impuestoIva: 16.0,
        ivaModo: IvaModo.imputado,
        items: [
          ItemGastoModel(
            descripcion: 'Detergente',
            cantidad: 1.0,
            precioUnitario: 11600,
            total: 11600,
            categoria: 'Hogar',
          ),
        ],
      );

      final result = strictValidator.validate([factura]);
      expect(result.isValid, isTrue);

      // Negativo: en modo imputado, si itemsSum=100 vs total=116, NO debe sumar impuestoIva para enmascararlo.
      final facturaIncompleta = GeminiExtractionResult(
        comercio: 'Farmatodo',
        fecha: '2026-11-20',
        moneda: 'VES',
        totalOriginal: 116.0,
        impuestoIva: 16.0,
        ivaModo: IvaModo.imputado,
        items: [
          ItemGastoModel(
            descripcion: 'Detergente',
            cantidad: 1.0,
            precioUnitario: 10000,
            total: 10000,
            categoria: 'Hogar',
          ),
        ],
      );
      expect(strictValidator.validate([facturaIncompleta]).isValid, isFalse);
    });

    test('no suma impuestoIva dos veces cuando ivaModo es yaIncluido', () {
      const strictValidator = SemanticValidator(tolerancePercentage: 0.05);
      final factura = GeminiExtractionResult(
        comercio: 'Bodegon',
        fecha: '2026-11-20',
        moneda: 'VES',
        totalOriginal: 116.0,
        impuestoIva: 16.0,
        ivaModo: IvaModo.yaIncluido,
        items: [
          ItemGastoModel(
            descripcion: 'Aceite de oliva',
            cantidad: 1.0,
            precioUnitario: 11600,
            total: 11600,
            categoria: 'Alimentación',
          ),
        ],
      );

      final result = strictValidator.validate([factura]);
      expect(result.isValid, isTrue);
    });

    test('Aceite de oliva con ivaModo noInformado e impuestoIva > 0 NO se confunde con renglón de IVA', () {
      // Con tolerancia 5% (maxAllowedDiff = 5.80 < 16.0), si "Aceite de oliva" disparara contains('iva'),
      // no sumaría los 16.0 de impuestoIva (itemsSum=100 vs total=116 -> diff=16 > 5.80 -> FALLARÍA).
      const strictValidator = SemanticValidator(tolerancePercentage: 0.05);
      final factura = GeminiExtractionResult(
        comercio: 'Automercado Plaza',
        fecha: '2026-11-20',
        moneda: 'VES',
        totalOriginal: 116.0,
        impuestoIva: 16.0,
        ivaModo: IvaModo.noInformado,
        items: [
          ItemGastoModel(
            descripcion: 'Aceite de oliva',
            cantidad: 1.0,
            precioUnitario: 10000,
            total: 10000,
            categoria: 'Alimentación',
          ),
        ],
      );

      final result = strictValidator.validate([factura]);
      expect(result.isValid, isTrue);
    });

    test('IGTF en items sin renglón IVA no impide contabilizar impuestoIva en modo noInformado', () {
      const strictValidator = SemanticValidator(tolerancePercentage: 0.05);
      final factura = GeminiExtractionResult(
        comercio: 'Restaurante',
        fecha: '2026-11-20',
        moneda: 'USD',
        totalOriginal: 119.48,
        impuestoIva: 16.0,
        ivaModo: IvaModo.noInformado,
        items: [
          ItemGastoModel(
            descripcion: 'Almuerzo',
            cantidad: 1.0,
            precioUnitario: 10000,
            total: 10000,
            categoria: 'Alimentación',
          ),
          ItemGastoModel(
            descripcion: 'IGTF 3%',
            cantidad: 1.0,
            precioUnitario: 348,
            total: 348,
            categoria: 'Alimentación',
          ),
        ],
      );

      final result = strictValidator.validate([factura]);
      expect(result.isValid, isTrue);
    });
  });
}
