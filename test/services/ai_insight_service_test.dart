import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
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

class FakeDbForSignals extends DatabaseHelper {
  List<GastoModel> prevMonthGastos = const [];
  Map<String, PriceHistory> mockPriceHistory = const {};

  FakeDbForSignals() : super.test();

  @override
  Future<List<GastoModel>> getGastosByMonth(int year, int month) async {
    return prevMonthGastos;
  }

  @override
  Future<Map<String, PriceHistory>> findPriceHistory(
    List<String> descripcionesNormalizadas, {
    int? excludeGastoId,
    String? comercioActual,
    int diasVentana = 60,
    DateTime? referenceDate,
  }) async {
    return mockPriceHistory;
  }
}

List<GastoModel> _buildSampleGastos(int count, {int totalUsdCents = 2000}) {
  return List.generate(count, (i) {
    return GastoModel(
      id: i + 1,
      uuid: 'uuid-${i + 1}',
      fecha: '2026-11-${(i + 1).toString().padLeft(2, '0')}',
      comercio: i.isEven ? 'Farmatodo' : 'Unicasa',
      moneda: 'USD',
      totalOriginal: totalUsdCents,
      totalUsd: totalUsdCents,
      categoria: 'Alimentación',
      creadoEn: '2026-11-10T10:00:00',
      items: [
        ItemGastoModel(
          descripcion: 'Café Molido 500g',
          cantidad: 1,
          precioUnitario: totalUsdCents - 200,
          total: totalUsdCents - 200,
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
  group('AiInsightService v2 Tests (AI-08)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('parseStrictDashboardInsight accepts valid JSON and strictly rejects plain text or malformed prefixes', () {
      final validJson = AiInsightService.parseStrictDashboardInsight(
        '{"consejo": "Pagaste **\$ 4,50** por **Café Molido** en **Farmatodo**, un **25%** más que en **Unicasa**."}',
      );
      expect(validJson, isNotNull);
      expect(validJson, contains('Farmatodo'));

      final validMdJson = AiInsightService.parseStrictDashboardInsight(
        '```json\n{"consejo": "Llevas **6 compras pequeñas** que ya suman **\$ 38,00** este mes."}\n```',
      );
      expect(validMdJson, isNotNull);
      expect(validMdJson, contains('6 compras pequeñas'));

      // Rechaza texto plano de Worker viejo
      final plainTextRejected = AiInsightService.parseStrictDashboardInsight(
        'Consejo corto: Tienes un presupuesto de \$600 y has gastado \$306.51.',
      );
      expect(plainTextRejected, isNull);

      // Rechaza incluso si viniera en JSON pero con prefijo "Consejo corto:" o consejo confuso de ahorro BCV vs USDT
      final badPrefixRejected = AiInsightService.parseStrictDashboardInsight(
        '{"consejo": "Consejo corto: Tienes un presupuesto de \$600 y has gastado \$306.51."}',
      );
      expect(badPrefixRejected, isNull);

      final fxSavingRejected = AiInsightService.parseStrictDashboardInsight(
        '{"consejo": "Has ahorrado **\$ 52,00** este mes pagando en bolívares a tasa BCV en lugar de USDT."}',
      );
      expect(fxSavingRejected, isNull);

      expect(
        AiInsightService.stripMarkdownForCopy('Pagaste **\$ 4,50** en *Farmatodo*'),
        'Pagaste \$ 4,50 en Farmatodo',
      );
    });

    test('computeHiddenSignals extracts hidden signals (price diff, ant expenses and prev month)', () async {
      final fakeDb = FakeDbForSignals()
        ..prevMonthGastos = [
          GastoModel(
            id: 99,
            uuid: 'prev-1',
            fecha: '2026-10-05',
            comercio: 'Unicasa',
            moneda: 'USD',
            totalOriginal: 10000,
            totalUsd: 10000,
            categoria: 'Alimentación',
            creadoEn: '2026-10-05T10:00:00',
          ),
        ]
        ..mockPriceHistory = {
          'cafe molido 500g': const PriceHistory(
            descripcionNorm: 'cafe molido 500g',
            registros: 2,
            mejorPrecio: UnitPriceRef(
              precioUsd: 3.60,
              fecha: '2026-11-02',
              comercio: 'Unicasa',
              comercioNorm: 'unicasa',
              cantidad: 1,
            ),
            entradas: [
              UnitPriceRef(
                precioUsd: 4.50,
                fecha: '2026-11-10',
                comercio: 'Farmatodo',
                comercioNorm: 'farmatodo',
                cantidad: 1,
              ),
              UnitPriceRef(
                precioUsd: 3.60,
                fecha: '2026-11-02',
                comercio: 'Unicasa',
                comercioNorm: 'unicasa',
                cantidad: 1,
              ),
            ],
          ),
        };

      // 5 compras pequeñas de $6,00 = $30,00 (ahorro vs $100 de octubre, gastos hormiga, diff precio y brecha FX)
      final gastos = _buildSampleGastos(5, totalUsdCents: 600);

      final signals = await AiInsightService.computeHiddenSignals(
        gastos: gastos,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 30.0,
        totalMesUsdt: 22.0,
        currentDate: DateTime(2026, 11, 15),
        dbHelper: fakeDb,
      );

      expect(signals.priceFindings.length, 1);
      expect(signals.priceFindings.first['tipo'], 'otro_comercio_mas_barato');
      expect(signals.priceFindings.first['diferencia_pct'], 25);

      expect(signals.antExpenses, isNotNull);
      expect(signals.antExpenses!['cantidad_compras'], 5);
      expect(signals.antExpenses!['total_usd'], 30.0);

      expect(signals.prevMonthComparison, isNotNull);
      expect(signals.prevMonthComparison!['categoria_con_ahorro']['categoria'], 'Alimentación');
    });

    test('buildCompactContextForGemini excludes IVA items and includes hidden signals without repeating SummaryCard totals', () {
      final gastos = _buildSampleGastos(3);
      const signals = AiHiddenSignals(
        antExpenses: {'cantidad_compras': 5, 'total_usd': 32.0, 'porcentaje_del_mes': 22},
      );
      final ctx = AiInsightService.buildCompactContextForGemini(
        gastos: gastos,
        totalMesUsd: 60.0,
        presupuestoUsd: 200.0,
        metaAhorroUsd: 20.0,
        monedaLente: 'USD',
        now: DateTime(2026, 11, 15),
        hiddenSignals: signals,
      );

      final topProductos = ctx['top_productos_sin_iva'] as List;
      expect(topProductos.length, 1);
      expect(topProductos.first['producto'], 'Café Molido 500g');
      expect(ctx.containsKey('gastos_hormiga'), isTrue);
      // Evita incitar a Gemini a repetir el presupuesto/total que ya se muestra arriba
      expect(ctx.containsKey('presupuesto_usd'), isFalse);
      expect(ctx.containsKey('total_mes_usd'), isFalse);
    });

    test('refreshBackgroundInsightIfNeeded purges legacy v1 cache, ignores non-JSON responses, and enforces 24h quota cap', () async {
      SharedPreferences.setMockInitialValues({
        'ai_insight_cached_short_v1': 'Consejo corto: Tienes un presupuesto de \$600...',
        'ai_insight_last_fetch_date_v1': '2026-11-15',
      });
      final prefs = await SharedPreferences.getInstance();
      final fakeGemini = FakeGeminiServiceForInsight();
      final gastos3 = _buildSampleGastos(3);

      // 1. Si el Worker viejo devuelve texto plano sin JSON, NO lo guarda en caché v2 y purga v1
      fakeGemini.nextRawText = 'Consejo corto: Tienes un presupuesto de \$600 y has gastado \$306.51.';
      final rejected = await AiInsightService.refreshBackgroundInsightIfNeeded(
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
      expect(rejected, isNull);
      expect(prefs.containsKey('ai_insight_cached_short_v1'), isFalse);
      expect(prefs.containsKey(AiInsightService.prefTextKey), isFalse);
      expect(fakeGemini.callCount, 1);

      // 2. Respuesta JSON válida -> se guarda en caché v2
      fakeGemini.nextRawText =
          '{"consejo": "El **Café Molido** te salió un **25%** más barato en **Unicasa** que en **Farmatodo** esta semana."}';
      final valid = await AiInsightService.refreshBackgroundInsightIfNeeded(
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
      expect(valid, contains('Unicasa'));
      expect(fakeGemini.callCount, 2);
      expect(fakeGemini.lastModo, 'insight_inicio');

      // 3. Misma fecha (aunque suban los gastos a 4) -> respeta tope de 1 llamada por día
      final sameDayCached = await AiInsightService.refreshBackgroundInsightIfNeeded(
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
      expect(sameDayCached, valid);
      expect(fakeGemini.callCount, 2);

      // 4. Día siguiente con gastos nuevos -> refresca
      fakeGemini.nextRawText =
          '{"consejo": "Buen control en **Alimentación**: llevas **20%** menos que el mes pasado a esta misma fecha."}';
      final nextDayUpdated = await AiInsightService.refreshBackgroundInsightIfNeeded(
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
      expect(nextDayUpdated, contains('20%'));
      expect(fakeGemini.callCount, 3);
    });
  });
}
