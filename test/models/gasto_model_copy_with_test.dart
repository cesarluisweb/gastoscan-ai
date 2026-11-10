import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';

void main() {
  group('GastoModel.copyWith - Limpieza Nullable (S3.2)', () {
    final modeloOriginal = GastoModel(
      id: 1,
      uuid: 'uuid-123',
      fecha: '2026-11-10',
      comercio: 'Automercado',
      moneda: 'USD',
      totalOriginal: 5000,
      totalUsd: 5000,
      totalUsdt: 5000,
      totalEur: 4500,
      tasaCambio: 45.0,
      tasaUsdt: 45.5,
      tasaEur: 50.0,
      fuenteTasaCambio: 'bcv',
      fechaTasaCambio: '2026-11-10',
      categoria: 'Alimentos',
      rutaFotoLocal: '/storage/emulated/0/foto.jpg',
      creadoEn: '2026-11-10T10:00:00Z',
      actualizadoEn: '2026-11-10T10:00:00Z',
      eliminadoEn: '2026-11-10T11:00:00Z',
      firestoreId: 'fs-123',
      synced: 1,
      ocrText: 'Factura #001',
    );

    test('1. copyWith sin argumentos preserva todos los valores intactos', () {
      final copia = modeloOriginal.copyWith();
      expect(copia.id, equals(1));
      expect(copia.uuid, equals('uuid-123'));
      expect(copia.totalUsdt, equals(5000));
      expect(copia.totalEur, equals(4500));
      expect(copia.tasaUsdt, equals(45.5));
      expect(copia.tasaEur, equals(50.0));
      expect(copia.fuenteTasaCambio, equals('bcv'));
      expect(copia.fechaTasaCambio, equals('2026-11-10'));
      expect(copia.rutaFotoLocal, equals('/storage/emulated/0/foto.jpg'));
      expect(copia.eliminadoEn, equals('2026-11-10T11:00:00Z'));
      expect(copia.firestoreId, equals('fs-123'));
      expect(copia.ocrText, equals('Factura #001'));
    });

    test('2. copyWith con totalEur: null y tasaEur: null limpia los campos nulos', () {
      final copia = modeloOriginal.copyWith(
        totalEur: null,
        tasaEur: null,
      );
      expect(copia.totalEur, isNull);
      expect(copia.tasaEur, isNull);
      // Los demás campos no afectados se conservan
      expect(copia.totalUsdt, equals(5000));
      expect(copia.tasaUsdt, equals(45.5));
    });

    test('3. copyWith con eliminadoEn: null reactiva un gasto en soft delete', () {
      final reactivado = modeloOriginal.copyWith(eliminadoEn: null);
      expect(reactivado.eliminadoEn, isNull);
      expect(reactivado.id, equals(1));
    });

    test('4. copyWith con rutaFotoLocal: null desvincula la foto', () {
      final sinFoto = modeloOriginal.copyWith(rutaFotoLocal: null);
      expect(sinFoto.rutaFotoLocal, isNull);
      expect(sinFoto.comercio, equals('Automercado'));
    });

    test('5. copyWith actualiza valores no nulos correctamente', () {
      final actualizado = modeloOriginal.copyWith(
        totalOriginal: 6000,
        totalUsd: 6000,
        totalUsdt: 6000,
        totalEur: 5500,
        tasaCambio: 46.0,
        tasaUsdt: 46.5,
        tasaEur: 51.0,
        comercio: 'Farmacia',
        categoria: 'Salud',
        synced: 0,
      );
      expect(actualizado.totalOriginal, equals(6000));
      expect(actualizado.totalUsd, equals(6000));
      expect(actualizado.totalUsdt, equals(6000));
      expect(actualizado.totalEur, equals(5500));
      expect(actualizado.tasaCambio, equals(46.0));
      expect(actualizado.tasaUsdt, equals(46.5));
      expect(actualizado.tasaEur, equals(51.0));
      expect(actualizado.comercio, equals('Farmacia'));
      expect(actualizado.categoria, equals('Salud'));
      expect(actualizado.synced, equals(0));
    });

    test('6. sinFoto() invoca limpiamente la desvinculación de foto', () {
      final sinFoto = modeloOriginal.sinFoto();
      expect(sinFoto.rutaFotoLocal, isNull);
      expect(sinFoto.totalOriginal, equals(5000));
    });
  });
}
