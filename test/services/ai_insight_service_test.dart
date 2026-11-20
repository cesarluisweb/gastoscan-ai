import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/data/datasources/remote/gemini_service.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/services/ai_insight_service.dart';

class FakeGeminiServiceForInsight extends GeminiService {
  int callCount = 0;
  Map<String, dynamic>? lastContextData;
  String? lastModo;
  String nextRawText = '';
  bool shouldThrow = false;

  @override
  Future<Map<String, dynamic>> chatWithAnalyst({
    required List<Map<String, String>> messages,
    required Map<String, dynamic> contextData,
    String? modo,
  }) async {
    callCount++;
    lastContextData = contextData;
    lastModo = modo;
    if (shouldThrow) {
      throw Exception('Simulated network error');
    }
    return {'text': nextRawText};
  }
}

List<GastoModel> _buildSampleGastos(int count) {
  return List.generate(count, (i) {
    return GastoModel(
      id: i + 1,
      uuid: 'uuid-${i + 1}',
      fecha: '2026-11-${(i + 1).toString().padLeft(2, '0')}',
      comercio: i.isEven ? 'Farmatodo' : 'Unicasa',
      moneda: 'USD',
      totalOriginal: 2000,
      totalUsd: 2000,
      categoria: 'Alimentación',
      creadoEn: '2026-11-10T10:00:00',
      items: [
        ItemGastoModel(
          descripcion: 'Café Molido 500g',
          cantidad: 1,
          precioUnitario: 1800,
          total: 1800,
          categoria: 'Alimentación',
        ),
        ItemGastoModel(
          descripcion: 'IVA (16%)',
          cantidad: 1,
          precioUnitario: 200,
          total: 200,
          categoria: 'Otros',
        ),
      ],
    );
  });
}

void main() {
  group('AiInsightService & GeminiService Insight Tests (AI-08)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('parseDashboardInsightResponse parses clean JSON, markdown JSON and plain text fallback', () {
      final jsonRes = AiInsightService.parseDashboardInsightResponse(
        '{"resumen": "Ahorra comparando precios en tus 3 comercios frecuentes.", "detalle": "• **Detalle 1:** Gastaste \$60 en 3 compras."}',
      );
      expect(jsonRes, isNotNull);
      expect(jsonRes!['resumen'], 'Ahorra comparando precios en tus 3 comercios frecuentes.');
      expect(jsonRes['detalle'], contains('Detalle 1:'));

      final mdRes = AiInsightService.parseDashboardInsightResponse(
        '```json\n{"resumen": "Consejo corto.", "detalle": "Consejo largo detallado."}\n```',
      );
      expect(mdRes, isNotNull);
      expect(mdRes!['resumen'], 'Consejo corto.');
      expect(mdRes['detalle'], 'Consejo largo detallado.');

      final plainRes = AiInsightService.parseDashboardInsightResponse(
        'Concentraste tus compras en supermercados. Revisa el comparador por unidad para ahorrar.',
      );
      expect(plainRes, isNotNull);
      expect(plainRes!['resumen'], 'Concentraste tus compras en supermercados.');
      expect(plainRes['detalle'], contains('Revisa el comparador por unidad'));
    });

    test('buildCompactContextForGemini strictly excludes IVA tax items from top_productos_sin_iva', () {
      final gastos = _buildSampleGastos(3);
      final ctx = AiInsightService.buildCompactContextForGemini(
        gastos: gastos,
        totalMesUsd: 60.0,
        presupuestoUsd: 200.0,
        metaAhorroUsd: 20.0,
        monedaLente: 'USD',
        now: DateTime(2026, 11, 15),
      );

      final topProductos = ctx['top_productos_sin_iva'] as List;
      expect(topProductos.length, 1);
      expect(topProductos.first['producto'], 'Café Molido 500g');
      expect(
        topProductos.any((p) => p['producto'].toString().toUpperCase().contains('IVA')),
        isFalse,
      );
    });

    test('refreshBackgroundInsightIfNeeded does not call Gemini when expenses < 3', () async {
      final fakeGemini = FakeGeminiServiceForInsight();
      final prefs = await SharedPreferences.getInstance();

      final res = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(2),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 40.0,
        presupuestoUsd: 200.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );

      expect(res, isNull);
      expect(fakeGemini.callCount, 0);
    });

    test('refreshBackgroundInsightIfNeeded calls Gemini once per day and caches for 24h / unchanged signature', () async {
      final fakeGemini = FakeGeminiServiceForInsight()
        ..nextRawText =
            '{"resumen": "Agrupa tus compras de Farmatodo para estirar tu presupuesto.", "detalle": "• **Farmatodo:** 2 visitas por **\$40,00**."}';
      final prefs = await SharedPreferences.getInstance();
      final gastos3 = _buildSampleGastos(3);

      // 1. Primera llamada con 3 gastos en el mes actual -> llama a Gemini y guarda en caché
      final first = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastos3,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 60.0,
        presupuestoUsd: 200.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );

      expect(first, isNotNull);
      expect(first!['resumen'], 'Agrupa tus compras de Farmatodo para estirar tu presupuesto.');
      expect(fakeGemini.callCount, 1);
      expect(fakeGemini.lastModo, 'insight_inicio');

      // 2. Segunda llamada el mismo día (incluso con 4 gastos) -> respeta tope de 1 vez por día (24h)
      final secondSameDay = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(4),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 80.0,
        presupuestoUsd: 200.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );

      expect(secondSameDay!['resumen'], first['resumen']);
      expect(fakeGemini.callCount, 1);

      // 3. Llamada al día siguiente pero SIN cambios en los 3 gastos -> no gasta cuota
      final nextDaySameGastos = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastos3,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 60.0,
        presupuestoUsd: 200.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 16),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );

      expect(nextDaySameGastos!['resumen'], first['resumen']);
      expect(fakeGemini.callCount, 1);

      // 4. Llamada al día siguiente CON un gasto nuevo (4 gastos) -> refresca el consejo
      fakeGemini.nextRawText =
          '{"resumen": "Nuevo consejo del día 16 tras tu cuarta compra.", "detalle": "Detalle actualizado del día 16."}';
      final nextDayNewGastos = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(4),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 80.0,
        presupuestoUsd: 200.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 16),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );

      expect(nextDayNewGastos!['resumen'], 'Nuevo consejo del día 16 tras tu cuarta compra.');
      expect(fakeGemini.callCount, 2);
    });
  });
}
