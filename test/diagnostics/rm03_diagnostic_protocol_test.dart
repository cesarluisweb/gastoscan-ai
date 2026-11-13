import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/domain/diagnostics/rm03_copy_strategy.dart';
import 'package:gastoscan_ai/domain/diagnostics/rm03_diagnostic_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory workDir;

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('rm03_diag_test_');
  });

  tearDown(() async {
    if (await workDir.exists()) {
      await workDir.delete(recursive: true);
    }
  });

  Future<String> createFixtureDb({
    String fileName = 'fixture.db',
    Future<void> Function(Database db)? seed,
  }) async {
    final dbPath = p.join(workDir.path, fileName);
    final db = await DatabaseHelper.openTestDatabase(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
    if (seed != null) {
      await seed(db);
    }
    await db.close();
    return dbPath;
  }

  Rm03CopyStrategy ffiCopyStrategy({
    void Function(String)? onTempDirCreated,
    void Function(String)? onTempDirDeleted,
  }) {
    return FileRm03CopyStrategy(
      openReadOnly: (path) => databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      ),
      onTempDirCreated: onTempDirCreated,
      onTempDirDeleted: onTempDirDeleted,
    );
  }

  Future<void> insertRawGasto(
    Database db, {
    required String uuid,
    String fecha = '2026-11-10',
    String comercio = 'Comercio Prueba',
    String moneda = 'VES',
    int totalOriginal = 10000,
    int totalUsd = 200,
    int? totalUsdt = 200,
    int? totalEur = 180,
    double? tasaCambio = 50.0,
    double? tasaUsdt = 51.0,
    double? tasaEur = 55.0,
    String? fuenteTasa = 'BCV',
    String? fechaTasa = '2026-11-10',
    String? eliminadoEn,
    String? ocrText,
    String? rutaFotoLocal,
  }) async {
    await db.insert('gastos', {
      'uuid': uuid,
      'fecha': fecha,
      'comercio': comercio,
      'moneda': moneda,
      'total_original': totalOriginal,
      'total_usd': totalUsd,
      'total_usdt': totalUsdt,
      'total_eur': totalEur,
      'tasa_cambio': tasaCambio,
      'tasa_usdt': tasaUsdt,
      'tasa_eur': tasaEur,
      'fuente_tasa_cambio': fuenteTasa,
      'fecha_tasa_cambio': fechaTasa,
      'categoria': 'Alimentación',
      'ruta_foto_local': rutaFotoLocal,
      'creado_en': '2026-11-10T10:00:00Z',
      'actualizado_en': '2026-11-10T10:00:00Z',
      'eliminado_en': eliminadoEn,
      'items': '[]',
      'synced': 0,
      'ocr_text': ocrText,
    });
  }

  group('E0-05b: Protocolo de diagnóstico read-only Q01..Q20', () {
    test('T1 & T2: Ejecuta Q01..Q20 con conteos exactos y clases D/S/V/N', () async {
      final dbPath = await createFixtureDb(seed: (db) async {
        // Fila 1 (Q01: negativo, Q04: tasa 1.0, Q02: USD roto)
        await insertRawGasto(
          db,
          uuid: 'u-q01',
          moneda: 'USD',
          totalOriginal: -500,
          totalUsd: 100,
          tasaCambio: 1.0,
        );
        // Fila 2 (Q03: total_original 0 con equivalencia != 0, Q05: tasa NULL)
        await insertRawGasto(
          db,
          uuid: 'u-q03',
          moneda: 'VES',
          totalOriginal: 0,
          totalUsd: 500,
          totalUsdt: 0,
          totalEur: 0,
          tasaCambio: null,
        );
        // Fila 3 (Q06: VES con total_usd > 0 y tasa 0, Q05: CERO)
        await insertRawGasto(
          db,
          uuid: 'u-q06',
          moneda: 'VES',
          totalOriginal: 5000,
          totalUsd: 100,
          tasaCambio: 0.0,
        );
        // Fila 4 (Q18: etiqueta no ISO 'Hoy', Q19: fuente vacía, Q20: 850.0)
        await insertRawGasto(
          db,
          uuid: 'u-q18',
          moneda: 'VES',
          totalOriginal: 85000,
          totalUsd: 100,
          tasaCambio: 850.0,
          fuenteTasa: '',
          fechaTasa: 'Hoy',
        );
        // Fila 5 y 6 (Q17: UUID duplicado)
        await insertRawGasto(db, uuid: 'u-dup', tasaCambio: 50.0);
        await insertRawGasto(db, uuid: 'u-dup', tasaCambio: 50.0);
        // Fila 7 (soft-deleted: debe ser ignorada por todas las consultas)
        await insertRawGasto(
          db,
          uuid: 'u-deleted',
          totalOriginal: -999,
          tasaCambio: 1.0,
          eliminadoEn: '2026-11-11T00:00:00Z',
        );
      });

      final protocol = Rm03DiagnosticProtocol(
        copyStrategy: ffiCopyStrategy(),
        saltGenerator: () => 'fixed-test-salt',
      );
      final report = await protocol.runOnFile(dbPath);

      expect(report.readOnlyVerified, isTrue);
      expect(report.schemaVersion, equals(19));
      expect(report.results.length, equals(21)); // Q01..Q09, Q10a, Q10b, Q11..Q20

      expect(report.byCode('Q01')?.affectedCount, equals(1));
      expect(report.byCode('Q01')?.clase, equals('D'));
      expect(report.byCode('Q02')?.affectedCount, equals(1));
      expect(report.byCode('Q03')?.affectedCount, equals(1));
      expect(report.byCode('Q04')?.affectedCount, equals(1));
      expect(report.byCode('Q05')?.affectedCount, equals(2));
      expect(report.byCode('Q05')?.breakdown, equals({'NULL': 1, 'CERO': 1}));
      expect(report.byCode('Q06')?.affectedCount, equals(2));
      expect(report.byCode('Q17')?.affectedCount, equals(1));
      expect(report.byCode('Q18')?.breakdown['ETIQUETA_NO_ISO'], equals(1));
      expect(report.byCode('Q19')?.affectedCount, equals(1));
      expect(report.byCode('Q20')?.clase, equals('indicio'));
      expect(report.byCode('Q20')?.breakdown['tasa_cambio|850.0'], equals(1));
    });

    test('T3: Guard SQL rechaza UPDATE, DELETE, INSERT y VACUUM', () {
      expect(
        () => Rm03DiagnosticProtocol.assertReadOnlySql('UPDATE gastos SET synced = 1;'),
        throwsA(isA<Rm03DiagnosticSecurityException>()),
      );
      expect(
        () => Rm03DiagnosticProtocol.assertReadOnlySql('DELETE FROM gastos;'),
        throwsA(isA<Rm03DiagnosticSecurityException>()),
      );
      expect(
        () => Rm03DiagnosticProtocol.assertReadOnlySql('INSERT INTO gastos VALUES (1);'),
        throwsA(isA<Rm03DiagnosticSecurityException>()),
      );
      expect(
        () => Rm03DiagnosticProtocol.assertReadOnlySql('VACUUM;'),
        throwsA(isA<Rm03DiagnosticSecurityException>()),
      );
      expect(
        () => Rm03DiagnosticProtocol.assertReadOnlySql('SELECT COUNT(*) FROM gastos;'),
        returnsNormally,
      );
    });

    test('T4: El archivo de origen permanece intacto byte a byte', () async {
      final dbPath = await createFixtureDb(seed: (db) async {
        await insertRawGasto(db, uuid: 'u-intact');
      });
      final bytesBefore = await File(dbPath).readAsBytes();

      final protocol = Rm03DiagnosticProtocol(copyStrategy: ffiCopyStrategy());
      await protocol.runOnFile(dbPath);

      final bytesAfter = await File(dbPath).readAsBytes();
      expect(bytesAfter, equals(bytesBefore));
    });

    test('T5: La copia temporal se borra al terminar y también ante excepción', () async {
      final createdDirs = <String>[];
      final deletedDirs = <String>[];
      final dbPath = await createFixtureDb();

      final strategy = ffiCopyStrategy(
        onTempDirCreated: createdDirs.add,
        onTempDirDeleted: deletedDirs.add,
      );

      final protocol = Rm03DiagnosticProtocol(copyStrategy: strategy);
      await protocol.runOnFile(dbPath);

      expect(createdDirs.length, equals(1));
      expect(deletedDirs, equals(createdDirs));
      expect(Directory(createdDirs.first).existsSync(), isFalse);

      // Caso con excepción dentro de la acción
      await expectLater(
        () => strategy.withReadOnlyCopy(dbPath, (_) async {
          throw StateError('Fallo simulado');
        }),
        throwsStateError,
      );
      expect(createdDirs.length, equals(2));
      expect(deletedDirs.length, equals(2));
      expect(Directory(createdDirs.last).existsSync(), isFalse);
    });

    test('T6: El JSON serializado no contiene PII ni UUID en texto claro', () async {
      const secretComercio = 'Bodegón Don Pepito PII';
      const secretOcr = 'RIF J-12345678-9 FACTURA CONFIDENCIAL';
      const secretPhoto = '/data/user/0/app/recibo_secreto.jpg';
      const rawUuid = 'uuid-super-secreto-998877';

      final dbPath = await createFixtureDb(seed: (db) async {
        await insertRawGasto(
          db,
          uuid: rawUuid,
          comercio: secretComercio,
          ocrText: secretOcr,
          rutaFotoLocal: secretPhoto,
          tasaCambio: 1.0,
        );
      });

      final protocol = Rm03DiagnosticProtocol(copyStrategy: ffiCopyStrategy());
      final report = await protocol.runOnFile(dbPath);
      final jsonText = jsonEncode(report.toJson());

      expect(jsonText, isNot(contains(secretComercio)));
      expect(jsonText, isNot(contains(secretOcr)));
      expect(jsonText, isNot(contains(secretPhoto)));
      expect(jsonText, isNot(contains(rawUuid)));
      expect(report.byCode('Q04')?.sampleHashes, hasLength(1));
      expect(report.byCode('Q04')?.sampleHashes.first.length, equals(64));
    });

    test('T7: Dos ejecuciones producen el mismo reporte (salvo executedAtIso y hashes con sal distinta)', () async {
      final dbPath = await createFixtureDb(seed: (db) async {
        await insertRawGasto(db, uuid: 'u-det', tasaCambio: 1.0);
      });

      final protocol = Rm03DiagnosticProtocol(
        copyStrategy: ffiCopyStrategy(),
        saltGenerator: () => 'same-salt',
        now: () => DateTime.utc(2026, 11, 13, 12, 0, 0),
      );

      final r1 = await protocol.runOnFile(dbPath);
      final r2 = await protocol.runOnFile(dbPath);
      expect(jsonEncode(r1.toJson()), equals(jsonEncode(r2.toJson())));
    });

    test('T8: Base vacía produce reporte válido con ceros', () async {
      final dbPath = await createFixtureDb();
      final protocol = Rm03DiagnosticProtocol(copyStrategy: ffiCopyStrategy());
      final report = await protocol.runOnFile(dbPath);

      expect(report.readOnlyVerified, isTrue);
      for (final item in report.results) {
        expect(item.totalEvaluated, equals(0));
        expect(item.affectedCount, equals(0));
      }
    });

    test('T9: Archivo inexistente o corrupto lanza error tipado sin reporte parcial', () async {
      final protocol = Rm03DiagnosticProtocol(copyStrategy: ffiCopyStrategy());

      await expectLater(
        () => protocol.runOnFile(p.join(workDir.path, 'no_existe.db')),
        throwsA(isA<Rm03DiagnosticIoException>()),
      );

      final corruptPath = p.join(workDir.path, 'corrupto.db');
      await File(corruptPath).writeAsString('esto no es un archivo sqlite');
      await expectLater(
        () => protocol.runOnFile(corruptPath),
        throwsA(isA<Exception>()),
      );
    });

    test('T10 & C3: Reporta schemaVersion real y falla cerrado si faltan columnas normativas', () async {
      final dbPath = await createFixtureDb();
      final protocol = Rm03DiagnosticProtocol(copyStrategy: ffiCopyStrategy());
      final report = await protocol.runOnFile(dbPath);
      expect(report.schemaVersion, equals(19));

      // Base incompleta sin columnas requeridas por Q1..Q19
      final incompletePath = p.join(workDir.path, 'legacy_v1.db');
      final legacyDb = await databaseFactoryFfi.openDatabase(incompletePath);
      await legacyDb.execute('PRAGMA user_version = 1;');
      await legacyDb.execute('CREATE TABLE gastos (id INTEGER PRIMARY KEY, uuid TEXT);');
      await legacyDb.close();

      await expectLater(
        () => protocol.runOnFile(incompletePath),
        throwsA(isA<Rm03DiagnosticSchemaException>()),
      );
    });
  });
}
