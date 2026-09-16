import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models/gasto_model.dart';
import '../core/utils/currency_formatter.dart';

class ExportService {
  /// Genera un archivo CSV estructurado con todos los gastos e items
  static String generateCsvData(List<GastoModel> gastos) {
    final List<List<dynamic>> rows = [];

    rows.add([
      'ID',
      'Fecha',
      'Comercio / Beneficiario',
      'Categoría',
      'Moneda Original',
      'Total Original',
      'Total USD',
      'Desglose de Items',
      'Registrado En',
    ]);

    for (final gasto in gastos) {
      final itemsDescription = gasto.items.map((it) {
        return '${it.cantidad}x ${it.descripcion} (@${it.precioUnitario} = ${it.total})';
      }).join('; ');

      rows.add([
        gasto.id ?? '',
        gasto.fecha,
        gasto.comercio,
        gasto.categoria,
        gasto.moneda,
        gasto.totalOriginal,
        gasto.totalUsd,
        itemsDescription,
        gasto.creadoEn,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Genera un resumen en formato Markdown exportable
  static String generateMarkdownReport(List<GastoModel> gastos, {required String periodo}) {
    final buffer = StringBuffer();
    buffer.writeln('# Reporte de Gastos - GastoScan AI');
    buffer.writeln('**Periodo:** $periodo');
    buffer.writeln('**Fecha de Generacion:** ${DateTime.now().toIso8601String().substring(0, 10)}');
    buffer.writeln('');

    double totalGeneralUsd = 0.0;
    for (final g in gastos) {
      totalGeneralUsd += g.totalUsd;
    }

    buffer.writeln('### Resumen General');
    buffer.writeln('- **Total Gastos Registrados:** ${gastos.length}');
    buffer.writeln('- **Monto Consolidado (USD):** ${CurrencyFormatter.formatUsd(totalGeneralUsd)}');
    buffer.writeln('');

    buffer.writeln('### Detalle de Facturas');
    buffer.writeln('| Fecha | Comercio | Categoría | Moneda | Total Orig. | Total USD | Items |');
    buffer.writeln('| :--- | :--- | :--- | :--- | :--- | :--- | :--- |');

    for (final g in gastos) {
      final itemsSummary = g.items.map((i) => '${i.cantidad}x ${i.descripcion}').join(', ');
      buffer.writeln(
        '| ${g.fecha} | ${g.comercio} | ${g.categoria} | ${g.moneda} | ${g.totalOriginal} | ${CurrencyFormatter.formatUsd(g.totalUsd)} | $itemsSummary |'
      );
    }

    return buffer.toString();
  }

  /// Guarda el CSV o Markdown en el almacenamiento local y activa el menu para compartir
  static Future<void> exportAndShare({
    required String content,
    required String filename,
    required String mimeType,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$filename';
    final file = File(filePath);

    await file.writeAsString(content, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: mimeType)],
        subject: 'Exportacion GastoScan AI - $filename',
      ),
    );
  }
}
