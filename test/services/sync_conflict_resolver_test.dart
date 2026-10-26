import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/services/sync_conflict_resolver.dart';

void main() {
  group('SyncConflictResolver Tests ("Borrado Gana" Policy)', () {
    final gastoBase = GastoModel(
      uuid: 'uuid-1',
      fecha: '2026-10-26',
      comercio: 'Comercio A',
      moneda: 'USD',
      totalOriginal: 10.0,
      totalUsd: 10.0,
      tasaCambio: 40.0,
      categoria: 'Otros',
      creadoEn: '2026-10-26T10:00:00.000Z',
      actualizadoEn: '2026-10-26T10:00:00.000Z',
    );

    test('1. Local null, remote active -> descargarRemotoALocal', () {
      final remote = gastoBase.copyWith(firestoreId: 'doc-1');
      final action = resolverConflicto(null, remote);
      expect(action, equals(ResolucionConflicto.descargarRemotoALocal));
    });

    test('2. Local null, remote deleted -> nada', () {
      final remote = gastoBase.copyWith(
        firestoreId: 'doc-1',
        eliminadoEn: '2026-10-26T11:00:00.000Z',
      );
      final action = resolverConflicto(null, remote);
      expect(action, equals(ResolucionConflicto.nada));
    });

    test('3. Local active, remote null -> subirLocalANube', () {
      final local = gastoBase.copyWith(id: 1);
      final action = resolverConflicto(local, null);
      expect(action, equals(ResolucionConflicto.subirLocalANube));
    });

    test('4. Local deleted, remote null (ghost delete) -> eliminarLocalFisico', () {
      final local = gastoBase.copyWith(
        id: 1,
        eliminadoEn: '2026-10-26T11:00:00.000Z',
      );
      final action = resolverConflicto(local, null);
      expect(action, equals(ResolucionConflicto.eliminarLocalFisico));
    });

    test('5. Remote deleted, local active (Delete Wins!) -> eliminarLocalFisico', () {
      final local = gastoBase.copyWith(
        id: 1,
        actualizadoEn: '2026-10-26T12:00:00.000Z', // Even if local updated later!
      );
      final remote = gastoBase.copyWith(
        firestoreId: 'doc-1',
        eliminadoEn: '2026-10-26T11:00:00.000Z',
      );
      final action = resolverConflicto(local, remote);
      expect(action, equals(ResolucionConflicto.eliminarLocalFisico));
    });

    test('6. Remote active, local deleted (Delete Wins!) -> subirLocalANube', () {
      final local = gastoBase.copyWith(
        id: 1,
        eliminadoEn: '2026-10-26T11:00:00.000Z',
      );
      final remote = gastoBase.copyWith(
        firestoreId: 'doc-1',
        actualizadoEn: '2026-10-26T12:00:00.000Z', // Even if remote updated later!
      );
      final action = resolverConflicto(local, remote);
      expect(action, equals(ResolucionConflicto.subirLocalANube));
    });

    test('7. Both deleted -> eliminarLocalFisico', () {
      final local = gastoBase.copyWith(
        id: 1,
        eliminadoEn: '2026-10-26T11:00:00.000Z',
      );
      final remote = gastoBase.copyWith(
        firestoreId: 'doc-1',
        eliminadoEn: '2026-10-26T11:00:00.000Z',
      );
      final action = resolverConflicto(local, remote);
      expect(action, equals(ResolucionConflicto.eliminarLocalFisico));
    });

    test('8. Both active, remote newer -> descargarRemotoALocal', () {
      final local = gastoBase.copyWith(
        id: 1,
        actualizadoEn: '2026-10-26T10:00:00.000Z',
      );
      final remote = gastoBase.copyWith(
        firestoreId: 'doc-1',
        actualizadoEn: '2026-10-26T10:05:00.000Z',
      );
      final action = resolverConflicto(local, remote);
      expect(action, equals(ResolucionConflicto.descargarRemotoALocal));
    });

    test('9. Both active, local newer -> subirLocalANube', () {
      final local = gastoBase.copyWith(
        id: 1,
        actualizadoEn: '2026-10-26T10:10:00.000Z',
      );
      final remote = gastoBase.copyWith(
        firestoreId: 'doc-1',
        actualizadoEn: '2026-10-26T10:05:00.000Z',
      );
      final action = resolverConflicto(local, remote);
      expect(action, equals(ResolucionConflicto.subirLocalANube));
    });

    test('10. Both active, identical timestamps -> nada', () {
      final local = gastoBase.copyWith(
        id: 1,
        actualizadoEn: '2026-10-26T10:00:00.000Z',
      );
      final remote = gastoBase.copyWith(
        firestoreId: 'doc-1',
        actualizadoEn: '2026-10-26T10:00:00.000Z',
      );
      final action = resolverConflicto(local, remote);
      expect(action, equals(ResolucionConflicto.nada));
    });
  });
}
