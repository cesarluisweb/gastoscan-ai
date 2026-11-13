import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import 'rm03_copy_strategy.dart';

/// Excepción cuando no puede garantizarse el modo de solo lectura.
class Rm03DiagnosticSecurityException implements Exception {
  final String message;
  const Rm03DiagnosticSecurityException(this.message);

  @override
  String toString() => 'Rm03DiagnosticSecurityException: $message';
}

/// Excepción cuando faltan columnas normativas en la tabla `gastos`.
class Rm03DiagnosticSchemaException implements Exception {
  final int schemaVersion;
  final List<String> missingColumns;
  const Rm03DiagnosticSchemaException({
    required this.schemaVersion,
    required this.missingColumns,
  });

  @override
  String toString() =>
      'Rm03DiagnosticSchemaException(v$schemaVersion): faltan columnas ${missingColumns.join(', ')}';
}

/// Resultado agregado sin PII de una consulta diagnóstica RM-03.
class Rm03QueryResult {
  final String code;
  final String title;
  final String clase; // 'D' | 'S' | 'V' | 'N' | 'V/S' | 'S/N' | 'indicio'
  final int totalEvaluated;
  final int affectedCount;
  final Map<String, int> breakdown;
  final List<String> sampleHashes;

  const Rm03QueryResult({
    required this.code,
    required this.title,
    required this.clase,
    required this.totalEvaluated,
    required this.affectedCount,
    this.breakdown = const {},
    this.sampleHashes = const [],
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'clase': clase,
        'total_evaluated': totalEvaluated,
        'affected_count': affectedCount,
        'breakdown': breakdown,
        'sample_hashes': sampleHashes,
      };
}

/// Reporte completo del protocolo de diagnóstico RM-03 (`Q01..Q20`), sin PII.
class Rm03DiagnosticReport {
  final String executedAtIso;
  final int schemaVersion;
  final bool readOnlyVerified;
  final List<Rm03QueryResult> results;

  const Rm03DiagnosticReport({
    required this.executedAtIso,
    required this.schemaVersion,
    required this.readOnlyVerified,
    required this.results,
  });

  Map<String, dynamic> toJson() => {
        'executed_at_iso': executedAtIso,
        'schema_version': schemaVersion,
        'read_only_verified': readOnlyVerified,
        'results': results.map((r) => r.toJson()).toList(),
      };

  Rm03QueryResult? byCode(String code) {
    for (final r in results) {
      if (r.code == code) return r;
    }
    return null;
  }
}

class _QuerySpec {
  final String code;
  final String title;
  final String clase;
  final String sql;

  const _QuerySpec({
    required this.code,
    required this.title,
    required this.clase,
    required this.sql,
  });
}

/// Ejecutor del protocolo de diagnóstico de solo lectura `Q01..Q20` (A-14).
///
/// Recibe exclusivamente una ruta de archivo; nunca acepta una `Database` abierta
/// para evitar contaminar la sesión principal con `PRAGMA query_only = ON`.
class Rm03DiagnosticProtocol {
  static const int _maxSampleHashes = 20;

  static const List<String> _requiredGastosColumns = [
    'id',
    'uuid',
    'fecha',
    'moneda',
    'total_original',
    'total_usd',
    'total_usdt',
    'total_eur',
    'tasa_cambio',
    'tasa_usdt',
    'tasa_eur',
    'fuente_tasa_cambio',
    'fecha_tasa_cambio',
    'eliminado_en',
  ];

  final Rm03CopyStrategy _copyStrategy;
  final DateTime Function() _now;
  final String Function()? _saltGenerator;

  Rm03DiagnosticProtocol({
    Rm03CopyStrategy? copyStrategy,
    DateTime Function()? now,
    String Function()? saltGenerator,
  })  : _copyStrategy = copyStrategy ?? FileRm03CopyStrategy(),
        _now = now ?? (() => DateTime.now().toUtc()),
        _saltGenerator = saltGenerator;

  /// Ejecuta `Q01..Q20` sobre una copia temporal aislada de [sourceDbPath].
  Future<Rm03DiagnosticReport> runOnFile(String sourceDbPath) {
    return _copyStrategy.withReadOnlyCopy(sourceDbPath, _executeOnReadOnlyDb);
  }

  Future<Rm03DiagnosticReport> _executeOnReadOnlyDb(Database db) async {
    await db.execute('PRAGMA query_only = ON;');
    final qOnlyRows = await db.rawQuery('PRAGMA query_only;');
    final qOnlyVal = qOnlyRows.isNotEmpty
        ? (qOnlyRows.first.values.first as num?)?.toInt()
        : null;
    if (qOnlyVal != 1) {
      throw const Rm03DiagnosticSecurityException(
        'No se pudo verificar PRAGMA query_only = 1 en la copia temporal.',
      );
    }

    final versionRows = await db.rawQuery('PRAGMA user_version;');
    final schemaVersion = versionRows.isNotEmpty
        ? ((versionRows.first.values.first as num?)?.toInt() ?? 0)
        : 0;

    final tableInfoRows = await db.rawQuery('PRAGMA table_info(gastos);');
    final existingColumns = tableInfoRows
        .map((row) => (row['name'] as String?)?.toLowerCase() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();

    final missingColumns = _requiredGastosColumns
        .where((col) => !existingColumns.contains(col))
        .toList();
    if (missingColumns.isNotEmpty) {
      throw Rm03DiagnosticSchemaException(
        schemaVersion: schemaVersion,
        missingColumns: missingColumns,
      );
    }

    final totalRowsResult = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM gastos WHERE eliminado_en IS NULL;',
    );
    final totalActive =
        (totalRowsResult.first['n'] as num?)?.toInt() ?? 0;

    final ephemeralSalt = _saltGenerator?.call() ?? _generateEphemeralSalt();
    final results = <Rm03QueryResult>[];

    for (final spec in _specs) {
      _assertReadOnlySql(spec.sql);
      final rows = await db.rawQuery(spec.sql);
      results.add(_buildResult(spec, rows, totalActive, ephemeralSalt));
    }

    // Q20: Indicios estadísticos (contrato-v1.2.md:579)
    _assertReadOnlySql(_q20Sql);
    final q20Rows = await db.rawQuery(_q20Sql);
    final q20Breakdown = <String, int>{};
    var q20Total = 0;
    for (final row in q20Rows) {
      final campo = row['campo']?.toString() ?? '';
      final valor = row['valor']?.toString() ?? '';
      final n = (row['n'] as num?)?.toInt() ?? 0;
      q20Breakdown['$campo|$valor'] = n;
      q20Total += n;
    }
    results.add(
      Rm03QueryResult(
        code: 'Q20',
        title: 'Indicios estadísticos {36.5, 40.0, 474.0, 850.0}',
        clase: 'indicio',
        totalEvaluated: totalActive,
        affectedCount: q20Total,
        breakdown: q20Breakdown,
      ),
    );

    return Rm03DiagnosticReport(
      executedAtIso: _now().toIso8601String(),
      schemaVersion: schemaVersion,
      readOnlyVerified: true,
      results: results,
    );
  }

  Rm03QueryResult _buildResult(
    _QuerySpec spec,
    List<Map<String, Object?>> rows,
    int totalActive,
    String salt,
  ) {
    final hashes = <String>[];
    final breakdown = <String, int>{};
    final isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}');

    for (final row in rows) {
      if (hashes.length < _maxSampleHashes) {
        final rawUuid = row['uuid']?.toString() ?? row['id']?.toString() ?? '';
        if (rawUuid.isNotEmpty) {
          hashes.add(_sha256Hex('$salt:$rawUuid'));
        }
      }

      if (spec.code == 'Q05' || spec.code == 'Q06') {
        final estado = row['estado_tasa']?.toString() ?? 'DESCONOCIDO';
        breakdown[estado] = (breakdown[estado] ?? 0) + 1;
      } else if (spec.code == 'Q18') {
        final rawFechaTasa = (row['fecha_tasa_cambio'] as String?)?.trim() ?? '';
        if (rawFechaTasa.isEmpty) {
          breakdown['VACIA'] = (breakdown['VACIA'] ?? 0) + 1;
        } else if (isoDatePattern.hasMatch(rawFechaTasa)) {
          breakdown['ISO_DISTINTA'] = (breakdown['ISO_DISTINTA'] ?? 0) + 1;
        } else {
          breakdown['ETIQUETA_NO_ISO'] = (breakdown['ETIQUETA_NO_ISO'] ?? 0) + 1;
        }
      } else {
        final moneda = row['moneda']?.toString();
        if (moneda != null && moneda.isNotEmpty) {
          breakdown[moneda] = (breakdown[moneda] ?? 0) + 1;
        }
      }
    }

    return Rm03QueryResult(
      code: spec.code,
      title: spec.title,
      clase: spec.clase,
      totalEvaluated: totalActive,
      affectedCount: rows.length,
      breakdown: breakdown,
      sampleHashes: hashes,
    );
  }

  /// Valida que la sentencia SQL sea estrictamente de lectura.
  static void assertReadOnlySql(String sql) => _assertReadOnlySql(sql);

  static void _assertReadOnlySql(String sql) {
    final withoutLineComments = sql.replaceAll(RegExp(r'--[^\n]*'), ' ');
    final withoutBlockComments =
        withoutLineComments.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
    final trimmed = withoutBlockComments.trimLeft().toUpperCase();

    if (!(trimmed.startsWith('SELECT') || trimmed.startsWith('WITH'))) {
      throw const Rm03DiagnosticSecurityException(
        'Sentencia rechazada: solo se permiten consultas SELECT o WITH.',
      );
    }

    final forbidden = RegExp(
      r'\b(UPDATE|DELETE|INSERT|DROP|ALTER|CREATE|VACUUM|ANALYZE|ATTACH|DETACH|REPLACE)\b',
    );
    final withoutStrings = trimmed.replaceAll(RegExp(r"'[^']*'"), "''");
    if (forbidden.hasMatch(withoutStrings)) {
      throw const Rm03DiagnosticSecurityException(
        'Sentencia rechazada: contiene palabra clave mutante prohibida.',
      );
    }
  }

  static String _generateEphemeralSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static const List<_QuerySpec> _specs = [
    _QuerySpec(
      code: 'Q01',
      title: 'Valores negativos o fuera de dominio',
      clase: 'D',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_usdt, total_eur,
       tasa_cambio, tasa_usdt, tasa_eur
FROM gastos
WHERE eliminado_en IS NULL
  AND (total_original < 0 OR total_usd < 0 OR total_usdt < 0 OR total_eur < 0
       OR tasa_cambio < 0 OR tasa_usdt < 0 OR tasa_eur < 0);
''',
    ),
    _QuerySpec(
      code: 'Q02',
      title: 'Identidad de la moneda de origen',
      clase: 'D',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_usdt, total_eur
FROM gastos
WHERE eliminado_en IS NULL
  AND (
       (moneda = 'USD'  AND ABS(total_usd  - total_original) > 1)
    OR (moneda = 'USDT' AND total_usdt IS NOT NULL AND ABS(total_usdt - total_original) > 1)
    OR (moneda = 'EUR'  AND total_eur  IS NOT NULL AND ABS(total_eur  - total_original) > 1)
  );
''',
    ),
    _QuerySpec(
      code: 'Q03',
      title: 'Importe original cero con equivalencias no cero',
      clase: 'D',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_usdt, total_eur
FROM gastos
WHERE eliminado_en IS NULL
  AND total_original = 0
  AND (total_usd <> 0 OR total_usdt <> 0 OR total_eur <> 0);
''',
    ),
    _QuerySpec(
      code: 'Q04',
      title: 'tasa_cambio = 1.0 (violación de dominio)',
      clase: 'D',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, tasa_cambio,
       fuente_tasa_cambio, fecha_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND tasa_cambio = 1.0;
''',
    ),
    _QuerySpec(
      code: 'Q05',
      title: 'tasa_cambio = 0 o NULL',
      clase: 'V/S',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_usdt, total_eur,
       CASE WHEN tasa_cambio IS NULL THEN 'NULL' ELSE 'CERO' END AS estado_tasa,
       fuente_tasa_cambio, fecha_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND (tasa_cambio IS NULL OR tasa_cambio = 0);
''',
    ),
    _QuerySpec(
      code: 'Q06',
      title: 'VES con total_usd > 0 y tasa NULL/0',
      clase: 'V',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd,
       CASE WHEN tasa_cambio IS NULL THEN 'NULL' ELSE 'CERO' END AS estado_tasa,
       fuente_tasa_cambio, fecha_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'VES'
  AND total_usd > 0
  AND (tasa_cambio IS NULL OR tasa_cambio = 0);
''',
    ),
    _QuerySpec(
      code: 'Q07',
      title: 'Tasa implícita vs almacenada en VES (>5%)',
      clase: 'S',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, tasa_cambio,
       ROUND(total_original * 1.0 / total_usd, 4) AS tasa_implicita,
       ROUND(ABS((total_original * 1.0 / total_usd) - tasa_cambio) / tasa_cambio * 100, 2) AS diferencia_pct,
       fuente_tasa_cambio, fecha_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'VES'
  AND total_usd > 0
  AND tasa_cambio > 1
  AND ABS((total_original * 1.0 / total_usd) - tasa_cambio) / tasa_cambio > 0.05;
''',
    ),
    _QuerySpec(
      code: 'Q08',
      title: 'EUR con total_usd = 0',
      clase: 'V',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'EUR'
  AND total_usd = 0
  AND total_original > 0;
''',
    ),
    _QuerySpec(
      code: 'Q09',
      title: 'EUR con total_eur = total_usd',
      clase: 'S',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'EUR'
  AND total_eur IS NOT NULL
  AND total_usd > 0
  AND ABS(total_eur - total_usd) <= 1;
''',
    ),
    _QuerySpec(
      code: 'Q10a',
      title: 'tasa_eur = tasa_cambio en EUR',
      clase: 'S',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'EUR'
  AND tasa_eur IS NOT NULL
  AND tasa_cambio IS NOT NULL
  AND ABS(tasa_eur - tasa_cambio) < 0.000001;
''',
    ),
    _QuerySpec(
      code: 'Q10b',
      title: 'tasa_eur = tasa_cambio con identidad del cruce rota',
      clase: 'D',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur,
       ROUND(total_eur * tasa_eur, 2) AS ves_desde_eur,
       ROUND(total_usd * tasa_cambio, 2) AS ves_desde_usd
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'EUR'
  AND tasa_eur IS NOT NULL
  AND tasa_cambio IS NOT NULL
  AND ABS(tasa_eur - tasa_cambio) < 0.000001
  AND total_original > 0
  AND total_usd > 0
  AND ABS((total_original * tasa_eur) - (total_usd * tasa_cambio)) > 100;
''',
    ),
    _QuerySpec(
      code: 'Q11',
      title: 'tasa_usdt = tasa_cambio en VES/EUR',
      clase: 'S',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_usdt,
       tasa_cambio, tasa_usdt, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda IN ('VES', 'EUR')
  AND tasa_usdt IS NOT NULL
  AND tasa_cambio IS NOT NULL
  AND ABS(tasa_usdt - tasa_cambio) < 0.000001;
''',
    ),
    _QuerySpec(
      code: 'Q12',
      title: 'VES con total_usdt = total_usd',
      clase: 'V/S',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_usdt,
       tasa_cambio, tasa_usdt, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'VES'
  AND total_usdt IS NOT NULL
  AND total_usd > 0
  AND ABS(total_usdt - total_usd) <= 1;
''',
    ),
    _QuerySpec(
      code: 'Q13',
      title: 'EUR/USDT con total_eur = total_usd',
      clase: 'S',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur, tasa_usdt, fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda IN ('EUR', 'USDT')
  AND total_eur IS NOT NULL
  AND total_usd > 0
  AND ABS(total_eur - total_usd) <= 1;
''',
    ),
    _QuerySpec(
      code: 'Q14',
      title: 'VES: total_original vs total_usd * tasa_cambio',
      clase: 'S',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, tasa_cambio,
       ROUND(total_usd * tasa_cambio, 2) AS ves_implicito,
       ROUND(total_original - (total_usd * tasa_cambio), 2) AS diferencia,
       fuente_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'VES'
  AND total_usd > 0
  AND tasa_cambio > 1
  AND ABS(total_original - (total_usd * tasa_cambio)) > 100;
''',
    ),
    _QuerySpec(
      code: 'Q15',
      title: 'Identidad del cruce EUR',
      clase: 'S',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_eur,
       tasa_cambio, tasa_eur,
       ROUND(total_eur * tasa_eur, 2) AS ves_desde_eur,
       ROUND(total_usd * tasa_cambio, 2) AS ves_desde_usd,
       ROUND((total_eur * tasa_eur) - (total_usd * tasa_cambio), 2) AS diferencia
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'EUR'
  AND total_eur > 0
  AND total_usd > 0
  AND tasa_eur > 1
  AND tasa_cambio > 1
  AND ABS((total_eur * tasa_eur) - (total_usd * tasa_cambio)) > 100;
''',
    ),
    _QuerySpec(
      code: 'Q16',
      title: 'USDT: lente VES P2P vs BCV',
      clase: 'V',
      sql: '''
SELECT id, uuid, moneda, total_original, total_usd, total_usdt,
       tasa_cambio, tasa_usdt,
       ROUND(total_usdt * tasa_usdt, 2) AS ves_p2p,
       ROUND(total_usd * tasa_cambio, 2) AS ves_bcv,
       ROUND((total_usdt * tasa_usdt) - (total_usd * tasa_cambio), 2) AS diferencia
FROM gastos
WHERE eliminado_en IS NULL
  AND moneda = 'USDT'
  AND total_usdt > 0
  AND tasa_usdt > 1
  AND tasa_cambio > 1
  AND ABS((total_usdt * tasa_usdt) - (total_usd * tasa_cambio)) > 100;
''',
    ),
    _QuerySpec(
      code: 'Q17',
      title: 'UUID duplicado (integridad de sync)',
      clase: 'D',
      sql: '''
SELECT uuid, COUNT(*) AS n
FROM gastos
WHERE eliminado_en IS NULL
GROUP BY uuid
HAVING COUNT(*) > 1;
''',
    ),
    _QuerySpec(
      code: 'Q18',
      title: 'Fecha de tasa distinta de la fecha del gasto',
      clase: 'S',
      sql: '''
SELECT id, uuid, fecha, fecha_tasa_cambio, fuente_tasa_cambio, tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND tasa_cambio > 1
  AND (
       fecha_tasa_cambio IS NULL
    OR TRIM(fecha_tasa_cambio) = ''
    OR substr(fecha_tasa_cambio, 1, 10) <> substr(fecha, 1, 10)
  );
''',
    ),
    _QuerySpec(
      code: 'Q19',
      title: 'Procedencia ausente (fuente_tasa_cambio)',
      clase: 'S/N',
      sql: '''
SELECT id, uuid, moneda, tasa_cambio, fuente_tasa_cambio, fecha_tasa_cambio
FROM gastos
WHERE eliminado_en IS NULL
  AND tasa_cambio > 1
  AND (fuente_tasa_cambio IS NULL OR TRIM(fuente_tasa_cambio) = '');
''',
    ),
  ];

  static const String _q20Sql = '''
SELECT 'tasa_cambio' AS campo, '36.5' AS valor, COUNT(*) AS n
  FROM gastos WHERE eliminado_en IS NULL AND tasa_cambio = 36.5
UNION ALL SELECT 'tasa_cambio', '40.0',  COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_cambio = 40.0
UNION ALL SELECT 'tasa_cambio', '474.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_cambio = 474.0
UNION ALL SELECT 'tasa_cambio', '850.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_cambio = 850.0
UNION ALL SELECT 'tasa_usdt',   '36.5',  COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_usdt   = 36.5
UNION ALL SELECT 'tasa_usdt',   '40.0',  COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_usdt   = 40.0
UNION ALL SELECT 'tasa_usdt',   '474.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_usdt   = 474.0
UNION ALL SELECT 'tasa_usdt',   '850.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_usdt   = 850.0
UNION ALL SELECT 'tasa_eur',    '36.5',  COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_eur    = 36.5
UNION ALL SELECT 'tasa_eur',    '40.0',  COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_eur    = 40.0
UNION ALL SELECT 'tasa_eur',    '474.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_eur    = 474.0
UNION ALL SELECT 'tasa_eur',    '850.0', COUNT(*) FROM gastos WHERE eliminado_en IS NULL AND tasa_eur    = 850.0;
''';
}

/// Implementación pura de SHA-256 en Dart para evitar dependencias nuevas en pubspec.yaml.
String _sha256Hex(String input) {
  const k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  int rotr(int x, int n) => ((x & 0xffffffff) >>> n) | ((x << (32 - n)) & 0xffffffff);

  final msg = utf8.encode(input);
  final bitLen = msg.length * 8;
  final paddedLen = ((msg.length + 9 + 63) ~/ 64) * 64;
  final padded = Uint8List(paddedLen)..setAll(0, msg);
  padded[msg.length] = 0x80;

  final view = ByteData.sublistView(padded);
  view.setUint32(paddedLen - 8, (bitLen ~/ 0x100000000) & 0xffffffff, Endian.big);
  view.setUint32(paddedLen - 4, bitLen & 0xffffffff, Endian.big);

  var h0 = 0x6a09e667;
  var h1 = 0xbb67ae85;
  var h2 = 0x3c6ef372;
  var h3 = 0xa54ff53a;
  var h4 = 0x510e527f;
  var h5 = 0x9b05688c;
  var h6 = 0x1f83d9ab;
  var h7 = 0x5be0cd19;

  final w = List<int>.filled(64, 0);
  for (var offset = 0; offset < paddedLen; offset += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = view.getUint32(offset + i * 4, Endian.big);
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }

    var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
    for (var i = 0; i < 64; i++) {
      final S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final temp1 = (h + S1 + ch + k[i] + w[i]) & 0xffffffff;
      final S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (S0 + maj) & 0xffffffff;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }

    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
    h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff;
    h7 = (h7 + h) & 0xffffffff;
  }

  return [h0, h1, h2, h3, h4, h5, h6, h7]
      .map((v) => v.toRadixString(16).padLeft(8, '0'))
      .join();
}
