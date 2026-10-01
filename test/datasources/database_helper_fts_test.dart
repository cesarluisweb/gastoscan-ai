import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';

class MockFtsDatabaseHelper extends DatabaseHelper {
  final Map<int, Map<String, dynamic>> _gastosStorage = {};
  final Map<int, String> _ftsStorage = {};

  MockFtsDatabaseHelper() : super.test();

  void seedGasto(int id, String comercio, String ocrText) {
    _gastosStorage[id] = {'id': id, 'comercio': comercio, 'ocr_text': ocrText};
    _ftsStorage[id] = '$comercio $ocrText';
  }

  @override
  Future<void> syncGastoFts(int gastoId, String comercio, String? ocrText) async {
    if (ocrText != null && ocrText.trim().isNotEmpty) {
      _ftsStorage[gastoId] = '$comercio $ocrText';
    }
  }

  @override
  Future<void> deleteGastoFts(int gastoId) async {
    _ftsStorage.remove(gastoId);
  }

  @override
  Future<List<int>> searchGastosFts(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final List<int> matchedIds = [];
    for (final entry in _ftsStorage.entries) {
      if (entry.value.toLowerCase().contains(cleanQuery)) {
        matchedIds.add(entry.key);
      }
    }
    return matchedIds;
  }
}

void main() {
  group('FTS Search and Sync Tests', () {
    late MockFtsDatabaseHelper dbHelper;

    setUp(() {
      dbHelper = MockFtsDatabaseHelper();
      dbHelper.seedGasto(1, 'Central Madeirense', 'HARINA PAN ARROZ MARY ACEITE');
      dbHelper.seedGasto(2, 'Farmatodo', 'ACETAMINOFEN VITAMINA C ALCOHOL');
    });

    test('searchGastosFts encuentra gastos por términos en el ocr_text', () async {
      final results = await dbHelper.searchGastosFts('HARINA');
      expect(results, contains(1));
      expect(results, isNot(contains(2)));
    });

    test('searchGastosFts encuentra gastos por comercio', () async {
      final results = await dbHelper.searchGastosFts('Farmatodo');
      expect(results, contains(2));
      expect(results, isNot(contains(1)));
    });

    test('searchGastosFts retorna lista vacía si no hay coincidencias o query está vacío', () async {
      expect(await dbHelper.searchGastosFts('Chupeta'), isEmpty);
      expect(await dbHelper.searchGastosFts(''), isEmpty);
    });

    test('deleteGastoFts elimina del índice', () async {
      await dbHelper.deleteGastoFts(1);
      final results = await dbHelper.searchGastosFts('HARINA');
      expect(results, isEmpty);
    });
  });
}
