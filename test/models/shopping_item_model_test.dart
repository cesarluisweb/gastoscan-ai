import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/shopping_item_model.dart';

void main() {
  group('ShoppingItemModel Tests', () {
    test('instantiates with required name and default values', () {
      final item = ShoppingItemModel(
        name: 'Harina PAN',
        createdAt: '2026-09-29T10:00:00',
      );

      expect(item.id, isNull);
      expect(item.name, 'Harina PAN');
      expect(item.isPurchased, 0);
      expect(item.gastoId, isNull);
      expect(item.createdAt, '2026-09-29T10:00:00');
    });

    test('toMap and fromMap work correctly', () {
      final item = ShoppingItemModel(
        id: 42,
        name: 'Café',
        isPurchased: 1,
        gastoId: 7,
        createdAt: '2026-09-29T12:00:00',
      );

      final map = item.toMap();
      expect(map['id'], 42);
      expect(map['name'], 'Café');
      expect(map['is_purchased'], 1);
      expect(map['gasto_id'], 7);

      final restored = ShoppingItemModel.fromMap(map);
      expect(restored.id, 42);
      expect(restored.name, 'Café');
      expect(restored.isPurchased, 1);
      expect(restored.gastoId, 7);
    });

    test('copyWith updates fields appropriately', () {
      final item = ShoppingItemModel(
        id: 1,
        name: 'Leche',
        createdAt: '2026-09-29T10:00:00',
      );

      final updated = item.copyWith(
        name: 'Leche deslactosada',
        isPurchased: 1,
      );

      expect(updated.id, 1);
      expect(updated.name, 'Leche deslactosada');
      expect(updated.isPurchased, 1);
      expect(updated.createdAt, '2026-09-29T10:00:00');
    });
  });
}
