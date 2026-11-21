import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/services/ai_report_service.dart';

void main() {
  group('AiReportService.buildPayload', () {
    test('construye el documento con los campos esperados', () {
      final payload = AiReportService.buildPayload(
        uid: 'uid-123',
        textoRespuesta: '  Respuesta con espacios  ',
        motivo: 'Inexacta',
        comentario: '  Dato errado  ',
        creadoEn: 'MARCA_TIEMPO',
      );

      expect(payload, {
        'uid': 'uid-123',
        'texto_respuesta': 'Respuesta con espacios',
        'motivo': 'Inexacta',
        'comentario': 'Dato errado',
        'origen': 'app',
        'creado_en': 'MARCA_TIEMPO',
      });
    });

    test('normaliza un motivo desconocido a Otro', () {
      final payload = AiReportService.buildPayload(
        uid: 'u1',
        textoRespuesta: 'Texto',
        motivo: 'MotivoInventado',
        creadoEn: 'MARCA_TIEMPO',
      );

      expect(payload['motivo'], 'Otro');
    });

    test('recorta la respuesta y el comentario a sus límites', () {
      final payload = AiReportService.buildPayload(
        uid: 'u1',
        textoRespuesta: 'a' * 5000,
        motivo: 'Otro',
        comentario: 'b' * 700,
        creadoEn: 'MARCA_TIEMPO',
      );

      expect(
        (payload['texto_respuesta'] as String).length,
        AiReportService.maxTextoRespuesta,
      );
      expect(
        (payload['comentario'] as String).length,
        AiReportService.maxComentario,
      );
    });

    test('rechaza una respuesta vacía', () {
      expect(
        () => AiReportService.buildPayload(
          uid: 'u1',
          textoRespuesta: '   ',
          motivo: 'Otro',
          creadoEn: 'MARCA_TIEMPO',
        ),
        throwsA(isA<AiReportException>()),
      );
    });
  });
}
