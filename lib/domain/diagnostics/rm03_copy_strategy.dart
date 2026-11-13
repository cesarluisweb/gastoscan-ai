import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Excepción tipada para fallos al preparar o abrir la copia de solo lectura.
class Rm03DiagnosticIoException implements Exception {
  final String message;
  const Rm03DiagnosticIoException(this.message);

  @override
  String toString() => 'Rm03DiagnosticIoException: $message';
}

/// Contrato de aislamiento para ejecutar diagnósticos sobre una copia temporal
/// sin tocar jamás la base de datos de origen.
abstract class Rm03CopyStrategy {
  Future<T> withReadOnlyCopy<T>(
    String sourceDbPath,
    Future<T> Function(Database db) action,
  );
}

/// Implementación por defecto basada en archivo temporal + apertura read-only.
///
/// Copia el archivo `.db` y sus acompañantes `-wal` / `-shm` si existen (para
/// evitar estados inconsistentes en modo WAL) a un directorio temporal único,
/// abre la copia con `readOnly: true` y elimina el directorio en `finally`.
class FileRm03CopyStrategy implements Rm03CopyStrategy {
  final Future<Database> Function(String path) _openReadOnly;
  final void Function(String tempDirPath)? onTempDirCreated;
  final void Function(String tempDirPath)? onTempDirDeleted;

  FileRm03CopyStrategy({
    Future<Database> Function(String path)? openReadOnly,
    this.onTempDirCreated,
    this.onTempDirDeleted,
  }) : _openReadOnly = openReadOnly ?? _defaultOpenReadOnly;

  static Future<Database> _defaultOpenReadOnly(String path) {
    return openDatabase(
      path,
      readOnly: true,
      singleInstance: false,
    );
  }

  @override
  Future<T> withReadOnlyCopy<T>(
    String sourceDbPath,
    Future<T> Function(Database db) action,
  ) async {
    if (sourceDbPath.trim().isEmpty) {
      throw const Rm03DiagnosticIoException('La ruta de base de datos está vacía.');
    }

    final sourceFile = File(sourceDbPath);
    if (!await sourceFile.exists()) {
      throw Rm03DiagnosticIoException(
        'No existe el archivo SQLite de origen: $sourceDbPath',
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('rm03_diag_');
    onTempDirCreated?.call(tempDir.path);
    Database? db;

    try {
      final baseName = p.basename(sourceDbPath);
      final destPath = p.join(tempDir.path, baseName);
      await sourceFile.copy(destPath);

      for (final suffix in const ['-wal', '-shm']) {
        final sidecar = File('$sourceDbPath$suffix');
        if (await sidecar.exists()) {
          await sidecar.copy('$destPath$suffix');
        }
      }

      try {
        db = await _openReadOnly(destPath);
      } catch (e) {
        throw Rm03DiagnosticIoException(
          'No se pudo abrir la copia temporal en solo lectura: $e',
        );
      }

      return await action(db);
    } finally {
      if (db != null) {
        try {
          await db.close();
        } catch (_) {
          // Ignorar errores al cerrar la copia temporal durante la limpieza.
        }
      }
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
          onTempDirDeleted?.call(tempDir.path);
        } catch (_) {
          // El directorio temporal del SO se limpiará posteriormente si hay bloqueo transitorio.
        }
      }
    }
  }
}
