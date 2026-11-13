import 'dart:convert';
import 'dart:io';

import 'package:gastoscan_ai/domain/diagnostics/rm03_copy_strategy.dart';
import 'package:gastoscan_ai/domain/diagnostics/rm03_diagnostic_protocol.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// CLI de diagnóstico de solo lectura RM-03 (`Q01..Q20`).
///
/// Uso:
///   dart run tool/diagnose_sqlite.dart --db <ruta_sqlite> [--out <ruta_json>]
Future<void> main(List<String> args) async {
  String? dbPath;
  String? outPath;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--db' && i + 1 < args.length) {
      dbPath = args[++i];
    } else if (args[i] == '--out' && i + 1 < args.length) {
      outPath = args[++i];
    }
  }

  if (dbPath == null || dbPath.trim().isEmpty) {
    stderr.writeln('Uso: dart run tool/diagnose_sqlite.dart --db <ruta> [--out <json>]');
    exitCode = 64;
    return;
  }

  sqfliteFfiInit();
  final strategy = FileRm03CopyStrategy(
    openReadOnly: (path) => databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    ),
  );

  final protocol = Rm03DiagnosticProtocol(copyStrategy: strategy);
  final report = await protocol.runOnFile(dbPath);
  final jsonStr = const JsonEncoder.withIndent('  ').convert(report.toJson());

  if (outPath != null && outPath.trim().isNotEmpty) {
    await File(outPath).writeAsString('$jsonStr\n', encoding: utf8);
    stdout.writeln('Reporte guardado en: $outPath');
  } else {
    stdout.writeln(jsonStr);
  }
}
