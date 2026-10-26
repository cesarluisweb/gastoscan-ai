import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gasto_firestore_mapper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';

void main() {
  group('GastoFirestoreMapper Tests', () {
    test('toPayload strips local-only fields, normalizes categories, and handles items', () {
      final gasto = GastoModel(
        id: 42,
        uuid: 'test-uuid-123',
        fecha: '2026-10-26',
        comercio: 'Automercados Plaza',
        moneda: 'USD',
        totalOriginal: 50.0,
        totalUsd: 50.0,
        totalUsdt: 50.0,
        totalEur: 45.0,
        tasaCambio: 40.0,
        tasaUsdt: 40.0,
        tasaEur: 44.0,
        categoria: 'comida', // lower-case, should normalize to 'Comida'
        rutaFotoLocal: '/data/user/0/photos/receipt.jpg',
        creadoEn: '2026-10-26T10:00:00.000Z',
        actualizadoEn: null,
        eliminadoEn: null,
        firestoreId: 'remote-id-999',
        synced: 0,
        ocrText: 'Harina PAN 1kg 1.20',
        items: [
          ItemGastoModel(
            id: 101,
            gastoId: 42,
            descripcion: 'Harina PAN 1kg',
            cantidad: 2.0,
            precioUnitario: 1.20,
            total: 2.40,
            categoria: 'supermercado', // should normalize to 'Comida' or canonical
          ),
        ],
      );

      final payload = GastoFirestoreMapper.toPayload(gasto);

      // Local fields must NOT be present
      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('synced'), isFalse);
      expect(payload.containsKey('firestore_id'), isFalse);
      expect(payload.containsKey('ruta_foto_local'), isFalse);

      // null eliminado_en must be omitted
      expect(payload.containsKey('eliminado_en'), isFalse);

      // Category normalized
      expect(payload['categoria'], equals('Comida'));

      // actualizado_en falls back to creado_en when null
      expect(payload['actualizado_en'], equals('2026-10-26T10:00:00.000Z'));

      // Items array verified
      final items = payload['items'] as List<dynamic>;
      expect(items.length, equals(1));
      final itemMap = items[0] as Map<String, dynamic>;
      expect(itemMap.containsKey('id'), isFalse);
      expect(itemMap.containsKey('gasto_id'), isFalse);
      expect(itemMap['descripcion'], equals('Harina PAN 1kg'));
      expect(itemMap['cantidad'], equals(2.0));
      expect(itemMap['precio_unitario'], equals(1.20));
      expect(itemMap['total'], equals(2.40));
    });

    test('toPayload includes eliminado_en when not null', () {
      final gasto = GastoModel(
        uuid: 'test-uuid-deleted',
        fecha: '2026-10-26',
        comercio: 'Farmatodo',
        moneda: 'USD',
        totalOriginal: 10.0,
        totalUsd: 10.0,
        tasaCambio: 40.0,
        categoria: 'Salud',
        creadoEn: '2026-10-26T10:00:00.000Z',
        actualizadoEn: '2026-10-26T11:00:00.000Z',
        eliminadoEn: '2026-10-26T11:00:00.000Z',
      );

      final payload = GastoFirestoreMapper.toPayload(gasto);
      expect(payload['eliminado_en'], equals('2026-10-26T11:00:00.000Z'));
      expect(payload['actualizado_en'], equals('2026-10-26T11:00:00.000Z'));
    });

    test('fromPayload reconstructs GastoModel with normalized categories and clean items', () {
      final remoteData = {
        'uuid': 'remote-uuid-777',
        'fecha': '2026-10-26',
        'comercio': 'Unicasa',
        'moneda': 'VES',
        'total_original': 200.0,
        'total_usd': 5.0,
        'total_usdt': 5.0,
        'total_eur': 4.5,
        'tasa_cambio': 40.0,
        'tasa_usdt': 40.0,
        'tasa_eur': 44.4,
        'categoria': 'servicios',
        'creado_en': '2026-10-26T08:00:00.000Z',
        'actualizado_en': '2026-10-26T09:00:00.000Z',
        'items': [
          {
            'descripcion': 'Pago de Luz',
            'cantidad': 1,
            'precio_unitario': 200.0,
            'total': 200.0,
            'categoria': 'servicios',
          }
        ],
      };

      final gasto = GastoFirestoreMapper.fromPayload(remoteData, 'remote-doc-id-123');

      expect(gasto.uuid, equals('remote-doc-id-123'));
      expect(gasto.firestoreId, equals('remote-doc-id-123'));
      expect(gasto.synced, equals(1));
      expect(gasto.categoria, equals('Servicios'));
      expect(gasto.items.length, equals(1));
      expect(gasto.items[0].id, isNull);
      expect(gasto.items[0].gastoId, isNull);
      expect(gasto.items[0].descripcion, equals('Pago de Luz'));
      expect(gasto.items[0].categoria, equals('Servicios'));
    });
  });
}
