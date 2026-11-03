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
        totalOriginal: 5000,
        totalUsd: 5000,
        totalUsdt: 5000,
        totalEur: 4500,
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
            precioUnitario: 120,
            total: 240,
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
      expect(payload['categoria'], equals('Alimentación'));

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
      expect(itemMap['precio_unitario'], equals(120));
      expect(itemMap['total'], equals(240));
    });

    test('toPayload includes eliminado_en when not null', () {
      final gasto = GastoModel(
        uuid: 'test-uuid-deleted',
        fecha: '2026-10-26',
        comercio: 'Farmatodo',
        moneda: 'USD',
        totalOriginal: 1000,
        totalUsd: 1000,
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

    test('toPayload omite campos opcionales null y no los envia como null en el mapa', () {
      final gasto = GastoModel(
        uuid: 'test-uuid-null-fields',
        fecha: '2026-10-26',
        comercio: 'Panadería Central',
        moneda: 'USD',
        totalOriginal: 2500,
        totalUsd: 2500,
        totalUsdt: null,
        totalEur: null,
        tasaCambio: 40.0,
        tasaUsdt: null,
        tasaEur: null,
        fuenteTasaCambio: null,
        fechaTasaCambio: null,
        categoria: 'Alimentación',
        creadoEn: '2026-10-26T10:00:00.000Z',
        actualizadoEn: null,
        eliminadoEn: null,
        ocrText: null,
        items: [],
      );

      final payload = GastoFirestoreMapper.toPayload(gasto);

      // Campos requeridos deben estar presentes
      expect(payload['uuid'], equals('test-uuid-null-fields'));
      expect(payload['fecha'], equals('2026-10-26'));
      expect(payload['comercio'], equals('Panadería Central'));
      expect(payload['moneda'], equals('USD'));
      expect(payload['total_original'], equals(2500));
      expect(payload['total_usd'], equals(2500));
      expect(payload['tasa_cambio'], equals(40.0));
      expect(payload['categoria'], equals('Alimentación'));
      expect(payload['creado_en'], equals('2026-10-26T10:00:00.000Z'));
      expect(payload['actualizado_en'], equals('2026-10-26T10:00:00.000Z'));
      expect(payload['items'], isEmpty);

      // Campos opcionales nulos DEBEN ser omitidos del mapa (no tener valor null)
      expect(payload.containsKey('total_usdt'), isFalse);
      expect(payload.containsKey('total_eur'), isFalse);
      expect(payload.containsKey('tasa_usdt'), isFalse);
      expect(payload.containsKey('tasa_eur'), isFalse);
      expect(payload.containsKey('fuente_tasa_cambio'), isFalse);
      expect(payload.containsKey('fecha_tasa_cambio'), isFalse);
      expect(payload.containsKey('ocr_text'), isFalse);
      expect(payload.containsKey('eliminado_en'), isFalse);
    });

    test('Conservacion de datos remotos no nulos ante simulacion de merge con campos locales nulos', () {
      final remoteFirestoreDoc = <String, dynamic>{
        'uuid': 'uuid-legacy-1',
        'fecha': '2026-10-20',
        'comercio': 'Automercados Plaza',
        'moneda': 'USD',
        'total_original': 5000,
        'total_usd': 5000,
        'total_usdt': 5000,
        'total_eur': 4500,
        'tasa_cambio': 40.0,
        'tasa_usdt': 40.0,
        'tasa_eur': 44.0,
        'fuente_tasa_cambio': 'dolarapi',
        'categoria': 'Alimentación',
        'creado_en': '2026-10-20T10:00:00.000Z',
        'actualizado_en': '2026-10-20T10:00:00.000Z',
        'items': [],
      };

      // Registro local con totalUsdt y tasaUsdt nulos (ej. deserializado con fromMap conservador)
      final localGasto = GastoModel(
        uuid: 'uuid-legacy-1',
        fecha: '2026-10-20',
        comercio: 'Automercados Plaza Editado',
        moneda: 'USD',
        totalOriginal: 5000,
        totalUsd: 5000,
        totalUsdt: null, // Nulo local
        tasaUsdt: null,  // Nulo local
        tasaCambio: 40.0,
        categoria: 'Alimentación',
        creadoEn: '2026-10-20T10:00:00.000Z',
        actualizadoEn: '2026-10-26T12:00:00.000Z',
      );

      final payload = GastoFirestoreMapper.toPayload(localGasto);

      // Simulación de SetOptions(merge: true) en Firestore:
      // Solo las claves presentes en payload sobrescriben el documento existente
      final mergedDoc = Map<String, dynamic>.from(remoteFirestoreDoc)..addAll(payload);

      // Los campos editados se actualizan
      expect(mergedDoc['comercio'], equals('Automercados Plaza Editado'));
      expect(mergedDoc['actualizado_en'], equals('2026-10-26T12:00:00.000Z'));

      // Los campos remotos no nulos NO fueron borrados ni sobrescritos con null
      expect(mergedDoc['total_usdt'], equals(5000));
      expect(mergedDoc['tasa_usdt'], equals(40.0));
      expect(mergedDoc['total_eur'], equals(4500));
      expect(mergedDoc['tasa_eur'], equals(44.0));
      expect(mergedDoc['fuente_tasa_cambio'], equals('dolarapi'));
    });

    test('fromPayload reconstructs GastoModel with normalized categories and clean items', () {
      final remoteData = {
        'uuid': 'remote-uuid-777',
        'fecha': '2026-10-26',
        'comercio': 'Unicasa',
        'moneda': 'VES',
        'total_original': 20000,
        'total_usd': 500,
        'total_usdt': 500,
        'total_eur': 450,
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
            'precio_unitario': 20000,
            'total': 20000,
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
