import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/utils/image_hash_service.dart';

void main() {
  group('ImageHashService - SHA-256 (OCR-01)', () {
    test('calcula hash de cadena vacia segun estandar FIPS 180-4', () {
      final hash = ImageHashService.computeSha256([]);
      expect(hash, equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
    });

    test('calcula hash de "abc"', () {
      final bytes = utf8.encode('abc');
      final hash = ImageHashService.computeSha256(bytes);
      expect(hash, equals('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'));
    });

    test('calcula hash de mensaje largo de 56 bytes (1 bloque con padding multi-bloque)', () {
      final bytes = utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq');
      final hash = ImageHashService.computeSha256(bytes);
      expect(hash, equals('248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1'));
    });

    test('calcula hash identico para archivos con el mismo contenido', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final file1 = File('${tempDir.path}/img1.jpg');
      final file2 = File('${tempDir.path}/img2.jpg');
      final dummyBytes = List.generate(500, (i) => i % 256);

      await file1.writeAsBytes(dummyBytes);
      await file2.writeAsBytes(dummyBytes);

      final hash1 = await ImageHashService.computeFileSha256(file1);
      final hash2 = await ImageHashService.computeFileSha256(file2);

      expect(hash1, equals(hash2));

      tempDir.deleteSync(recursive: true);
    });
  });
}
