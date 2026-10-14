import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/utils/uuid_generator.dart';

void main() {
  group('UuidGenerator RFC 4122 v4 tests', () {
    test('generates valid UUID v4 string format', () {
      final uuid = UuidGenerator.generate();
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

      expect(uuid.length, 36);
      expect(uuidRegex.hasMatch(uuid), isTrue, reason: 'UUID $uuid must match RFC 4122 v4 format');
    });

    test('generates unique UUIDs consecutively', () {
      final generated = <String>{};
      for (int i = 0; i < 100; i++) {
        final uuid = UuidGenerator.generate();
        expect(generated.contains(uuid), isFalse, reason: 'Duplicate UUID generated: $uuid');
        generated.add(uuid);
      }
      expect(generated.length, 100);
    });
  });
}
