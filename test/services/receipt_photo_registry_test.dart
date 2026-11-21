import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/repositories/gasto_repository.dart';
import 'package:gastoscan_ai/services/receipt_photo_registry.dart';

class _InMemoryPhotoRepository extends Fake implements GastoRepository {
  final List<GastoModel> gastos;
  final Map<int, String> updatedPaths = {};

  _InMemoryPhotoRepository(this.gastos);

  @override
  Future<List<GastoModel>> obtenerGastos() async => List.from(gastos);

  @override
  Future<int> actualizarRutaFotoLocal(int gastoId, String rutaFotoLocal) async {
    updatedPaths[gastoId] = rutaFotoLocal;
    final idx = gastos.indexWhere((g) => g.id == gastoId);
    if (idx != -1) {
      gastos[idx] = gastos[idx].copyWith(rutaFotoLocal: rutaFotoLocal);
      return 1;
    }
    return 0;
  }
}

GastoModel _buildGasto({
  required int id,
  required String uuid,
  required String creadoEn,
  String? actualizadoEn,
  String? rutaFotoLocal,
}) {
  return GastoModel(
    id: id,
    uuid: uuid,
    fecha: '2026-11-21',
    comercio: 'Farmatodo',
    moneda: 'USD',
    totalOriginal: 1200,
    totalUsd: 1200,
    tasaCambio: 880.0,
    categoria: 'Salud',
    rutaFotoLocal: rutaFotoLocal,
    creadoEn: creadoEn,
    actualizadoEn: actualizadoEn,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ReceiptPhotoRegistry', () {
    late Directory tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('receipt_registry_test_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('Paso 1: restaura rutaFotoLocal por uuid tras cierre de sesion y reconexion', () async {
      final photoFile = File('${tempDir.path}/recibo_1763700000000.jpg')..writeAsBytesSync([1, 2, 3]);
      final prefs = await SharedPreferences.getInstance();

      // Antes de cerrar sesion se registra el mapa uuid -> ruta
      await ReceiptPhotoRegistry.registerBatch(
        {'uuid-1': photoFile.path},
        prefsOverride: prefs,
      );

      // Tras volver a iniciar sesion, Firestore descarga el gasto sin rutaFotoLocal
      final repo = _InMemoryPhotoRepository([
        _buildGasto(
          id: 10,
          uuid: 'uuid-1',
          creadoEn: '2026-11-10T10:00:00.000',
          rutaFotoLocal: null,
        ),
      ]);

      final recovered = await ReceiptPhotoRegistry.reconcileMissingPhotos(
        repository: repo,
        appDirOverride: tempDir,
        prefsOverride: prefs,
      );

      expect(recovered, 1);
      expect(repo.updatedPaths[10], photoFile.path);
      expect(repo.gastos.first.rutaFotoLocal, photoFile.path);
    });

    test('Paso 2: auto-recupera archivos huerfanos recibo_<ms>.jpg por creado_en y actualizado_en', () async {
      final t1 = DateTime(2026, 11, 18, 14, 30, 0);
      final t2 = DateTime(2026, 11, 19, 9, 15, 0);
      final t2Updated = DateTime(2026, 11, 20, 16, 45, 0);
      final tUnrelated = DateTime(2026, 11, 1, 8, 0, 0);

      // Archivo guardado 400 ms antes de creado_en del gasto 1
      final file1 = File('${tempDir.path}/recibo_${t1.millisecondsSinceEpoch - 400}.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      // Archivo adjuntado al editar gasto 2 (300 ms antes de actualizado_en)
      final file2 = File('${tempDir.path}/recibo_${t2Updated.millisecondsSinceEpoch - 300}.png')
        ..writeAsBytesSync([4, 5, 6]);
      // Archivo sin gasto cercano (no debe vincularse)
      File('${tempDir.path}/recibo_${tUnrelated.millisecondsSinceEpoch}.jpg')
        ..writeAsBytesSync([7, 8, 9]);

      final prefs = await SharedPreferences.getInstance();
      final repo = _InMemoryPhotoRepository([
        _buildGasto(
          id: 1,
          uuid: 'uuid-orphan-1',
          creadoEn: t1.toIso8601String(),
          rutaFotoLocal: null,
        ),
        _buildGasto(
          id: 2,
          uuid: 'uuid-orphan-2',
          creadoEn: t2.toIso8601String(),
          actualizadoEn: t2Updated.toIso8601String(),
          rutaFotoLocal: null,
        ),
      ]);

      final recovered = await ReceiptPhotoRegistry.reconcileMissingPhotos(
        repository: repo,
        appDirOverride: tempDir,
        prefsOverride: prefs,
      );

      expect(recovered, 2);
      expect(repo.updatedPaths[1], file1.path);
      expect(repo.updatedPaths[2], file2.path);

      // Debe haber persistido ambos en SharedPreferences para futuras sesiones
      final saved = await ReceiptPhotoRegistry.loadMap(prefsOverride: prefs);
      expect(saved['uuid-orphan-1'], file1.path);
      expect(saved['uuid-orphan-2'], file2.path);
    });

    test('Privacidad: no reasigna por timestamp un comprobante mapeado a otro uuid', () async {
      final t1 = DateTime(2026, 11, 20, 12, 0, 0);
      final fileUserA = File('${tempDir.path}/recibo_${t1.millisecondsSinceEpoch - 200}.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      final prefs = await SharedPreferences.getInstance();

      await ReceiptPhotoRegistry.register('uuid-user-A', fileUserA.path, prefsOverride: prefs);

      final repoUserB = _InMemoryPhotoRepository([
        _buildGasto(
          id: 50,
          uuid: 'uuid-user-B',
          creadoEn: t1.toIso8601String(),
          rutaFotoLocal: null,
        ),
      ]);

      final recovered = await ReceiptPhotoRegistry.reconcileMissingPhotos(
        repository: repoUserB,
        appDirOverride: tempDir,
        prefsOverride: prefs,
      );

      expect(recovered, 0);
      expect(repoUserB.updatedPaths, isEmpty);
    });

    test('DatabaseHelper.reemplazarDatosLocales preserva ruta_foto_local por uuid', () async {
      final dbDir = Directory.systemTemp.createTempSync('replace_photo_preserve_');
      final dbPath = '${dbDir.path}/test_replace_photos.db';
      Database? db;
      try {
        db = await DatabaseHelper.openTestDatabase(
          factory: databaseFactoryFfi,
          path: dbPath,
        );
        final dbHelper = DatabaseHelper.instance;
        final localGasto = _buildGasto(
          id: 1,
          uuid: 'uuid-keep-photo',
          creadoEn: '2026-11-20T10:00:00.000',
          rutaFotoLocal: '/app_flutter/recibo_999.jpg',
        );
        await dbHelper.insertGasto(localGasto, []);

        // Simular reemplazo atomico con gastos descargados de Firestore (rutaFotoLocal == null)
        final remoteGasto = _buildGasto(
          id: 1,
          uuid: 'uuid-keep-photo',
          creadoEn: '2026-11-20T10:00:00.000',
          rutaFotoLocal: null,
        );
        await dbHelper.reemplazarDatosLocales(
          gastos: [remoteGasto],
          presupuestos: const [],
        );

        final after = await dbHelper.getAllGastos();
        expect(after, hasLength(1));
        expect(after.first.uuid, 'uuid-keep-photo');
        expect(after.first.rutaFotoLocal, '/app_flutter/recibo_999.jpg');
      } finally {
        await db?.close();
        DatabaseHelper.resetTestDatabase();
        try {
          dbDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });
  });
}
