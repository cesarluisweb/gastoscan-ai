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
      totalOriginal: 1000,
      totalUsd: 1000,
      tasaCambio: 40.0,
      categoria: 'Otros',
      creadoEn: '2026-10-26T10:00:00.000Z',
      actualizadoEn: '2026-10-26T10:00:00.000Z',
      synced: 1,
    );

    test('1. Local null, remote active -> crearLocalDesdeRemoto', () {
      final remote = gastoBase.copyWith(firestoreId: 'doc-1');
      final action = resolverConflicto(null, remote);
      expect(action, equals(AccionReconciliacion.crearLocalDesdeRemoto));
    });

    test('2. Local null, remote deleted -> descartarRemotoBorrado', () {
      final remote = gastoBase.copyWith(
        firestoreId: 'doc-1',
        eliminadoEn: '2026-10-26T11:00:00.000Z',
      );
      final action = resolverConflicto(null, remote);
      expect(action, equals(AccionReconciliacion.descartarRemotoBorrado));
    });

    test('3. Local active with pending changes (synced=0), remote null -> subirLocalANube', () {
      final local = gastoBase.copyWith(id: 1, synced: 0);
      final action = resolverConflicto(local, null);
      expect(action, equals(AccionReconciliacion.subirLocalANube));
    });

    test('4. Local active synced (synced=1), remote null -> mantenerLocal', () {
      final local = gastoBase.copyWith(id: 1, synced: 1);
      final action = resolverConflicto(local, null);
      expect(action, equals(AccionReconciliacion.mantenerLocal));
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
      expect(action, equals(AccionReconciliacion.eliminarLocalFisico));
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
      expect(action, equals(AccionReconciliacion.subirLocalANube));
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
      expect(action, equals(AccionReconciliacion.eliminarLocalFisico));
    });

    test('8. Both active, remote newer -> actualizarLocalDesdeRemoto', () {
      final local = gastoBase.copyWith(
        id: 1,
        actualizadoEn: '2026-10-26T10:00:00.000Z',
      );
      final remote = gastoBase.copyWith(
        firestoreId: 'doc-1',
        actualizadoEn: '2026-10-26T10:05:00.000Z',
      );
      final action = resolverConflicto(local, remote);
      expect(action, equals(AccionReconciliacion.actualizarLocalDesdeRemoto));
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
      expect(action, equals(AccionReconciliacion.subirLocalANube));
    });

    test('10. Both active, identical timestamps, synced=1 -> mantenerLocal', () {
      final local = gastoBase.copyWith(
        id: 1,
        actualizadoEn: '2026-10-26T10:00:00.000Z',
        synced: 1,
      );
      final remote = gastoBase.copyWith(
        firestoreId: 'doc-1',
        actualizadoEn: '2026-10-26T10:00:00.000Z',
      );
      final action = resolverConflicto(local, remote);
      expect(action, equals(AccionReconciliacion.mantenerLocal));
    });
  });
}
