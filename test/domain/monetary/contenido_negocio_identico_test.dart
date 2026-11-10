import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/domain/monetary/monetary_resolution.dart';

void main() {
  group('sonContenidoNegocioIdentico (E0-04 / Contrato v1.2 §4)', () {
    final gastoBase = GastoModel(
      id: 1,
      uuid: 'uuid-test-01',
      fecha: '2026-11-10',
      comercio: 'Automercado San José',
      moneda: 'USD',
      totalOriginal: 2500,
      totalUsd: 2500,
      totalUsdt: 2500,
      totalEur: 2300,
      tasaCambio: 45.0,
      tasaUsdt: 45.0,
      tasaEur: 49.0,
      fuenteTasaCambio: 'bcv',
      fechaTasaCambio: '2026-11-10',
      categoria: 'Alimentos',
      rutaFotoLocal: '/storage/foto1.jpg',
      creadoEn: '2026-11-10T08:00:00Z',
      actualizadoEn: '2026-11-10T08:00:00Z',
      eliminadoEn: null,
      firestoreId: 'fs-01',
      synced: 0,
      ocrText: 'Texto 1',
      items: [
        ItemGastoModel(
          descripcion: 'Harina PAN',
          cantidad: 2.0,
          precioUnitario: 100,
          total: 200,
          categoria: 'Alimentos',
        ),
      ],
    );

    test('1. Dos gastos idénticos en negocio pero con diferente synced y fotos retornan true', () {
      final gastoRemoto = gastoBase.copyWith(
        id: 99,
        synced: 1,
        firestoreId: 'fs-remoto-distinto',
        rutaFotoLocal: '/otra/ruta/en/otro/telefono.jpg',
        ocrText: 'Texto remoto diferente',
        creadoEn: '2026-11-10T09:00:00Z',
        actualizadoEn: '2026-11-10T09:00:00Z',
      );

      expect(sonContenidoNegocioIdentico(gastoBase, gastoRemoto), isTrue);
    });

    test('2. Diferencia en totalOriginal retorna false', () {
      final modificado = gastoBase.copyWith(totalOriginal: 2600);
      expect(sonContenidoNegocioIdentico(gastoBase, modificado), isFalse);
    });

    test('3. Diferencia en moneda retorna false', () {
      final modificado = gastoBase.copyWith(moneda: 'VES');
      expect(sonContenidoNegocioIdentico(gastoBase, modificado), isFalse);
    });

    test('4. Diferencia en tasaCambio retorna false', () {
      final modificado = gastoBase.copyWith(tasaCambio: 46.0);
      expect(sonContenidoNegocioIdentico(gastoBase, modificado), isFalse);
    });

    test('5. Diferencia en eliminadoEn retorna false', () {
      final modificado = gastoBase.copyWith(eliminadoEn: '2026-11-10T12:00:00Z');
      expect(sonContenidoNegocioIdentico(gastoBase, modificado), isFalse);
    });

    test('6. Diferencia en cantidad o precio de ítems retorna false', () {
      final modificado = gastoBase.copyWith(
        items: [
          ItemGastoModel(
            descripcion: 'Harina PAN',
            cantidad: 3.0, // Cambió de 2.0 a 3.0
            precioUnitario: 100,
            total: 300,
            categoria: 'Alimentos',
          ),
        ],
      );
      expect(sonContenidoNegocioIdentico(gastoBase, modificado), isFalse);
    });

    test('7. Cantidad diferente de ítems retorna false', () {
      final modificado = gastoBase.copyWith(
        items: [
          ...gastoBase.items,
          ItemGastoModel(
            descripcion: 'Arroz',
            cantidad: 1.0,
            precioUnitario: 100,
            total: 100,
            categoria: 'Alimentos',
          ),
        ],
      );
      expect(sonContenidoNegocioIdentico(gastoBase, modificado), isFalse);
    });

    test('8. Mayúsculas y espacios en comercio o categoría son normalizados', () {
      final modificado = gastoBase.copyWith(
        comercio: '  AUTOMERCADO SAN JOSÉ  ',
        categoria: ' ALIMENTOS ',
      );
      expect(sonContenidoNegocioIdentico(gastoBase, modificado), isTrue);
    });
  });
}
