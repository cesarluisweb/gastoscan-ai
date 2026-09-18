import 'dart:math';

class UuidGenerator {
  static String generate() {
    final random = Random();
    final data = List<int>.generate(16, (_) => random.nextInt(256));
    data[6] = (data[6] & 0x0f) | 0x40; // Version 4
    data[8] = (data[8] & 0x3f) | 0x80; // Variant 1
    final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-${hex.sublist(10, 16).join()}';
  }
}
