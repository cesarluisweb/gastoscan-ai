import 'dart:async';
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
  Future<Map<String, dynamic>> Function(int callIndex, Map<String, dynamic> contextData)?
      customHandler;

  @override
  Future<Map<String, dynamic>> chatWithAnalyst({
    required List<Map<String, String>> messages,
    required Map<String, dynamic> contextData,
    String? modo,
  }) async {
    callCount++;
    final currentCall = callCount;
    lastContextData = contextData;
    lastModo = modo;
    if (customHandler != null) {
      return customHandler!(currentCall, contextData);
    }
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
      AiInsightService.resetInFlightStateForTesting();
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

    test('refreshBackgroundInsightIfNeeded purges legacy cache, counts malformed responses, invalidates on deletion, enforces 3/day cap, and refreshes on new day', () async {
      SharedPreferences.setMockInitialValues({
        'ai_insight_cached_short_v1': 'Consejo corto: Tienes un presupuesto de \$600...',
        'ai_insight_last_fetch_date_v1': '2026-11-15',
      });
      final prefs = await SharedPreferences.getInstance();
      final fakeGemini = FakeGeminiServiceForInsight();
      addTearDown(fakeGemini.close);
      final gastos3 = _buildSampleGastos(3);
      final gastos4High = [
        ...gastos3,
        GastoModel(
          id: 99,
          uuid: 'uuid-high',
          fecha: '2026-11-15',
          comercio: 'Tienda Lujo',
          moneda: 'USD',
          totalOriginal: 50000,
          totalUsd: 50000,
          categoria: 'Otros',
          creadoEn: '2026-11-15T10:00:00',
        ),
      ];

      // 1. Respuesta degradada no-JSON: purga v1, NO guarda texto en v3, pero SÍ cuenta en cuota diaria (1/3)
      fakeGemini.nextRawText = 'Consejo corto: Tienes un presupuesto de \$600 y has gastado \$306.51.';
      final rejected = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastos4High,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 560.0,
        presupuestoUsd: 1000.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(rejected, isNull);
      expect(prefs.containsKey('ai_insight_cached_short_v1'), isFalse);
      expect(prefs.containsKey(AiInsightService.prefTextKey), isFalse);
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 1);
      expect(fakeGemini.callCount, 1);

      // 2. Respuesta JSON válida con gasto alto -> guarda caché v3 y consume cupo 2/3
      fakeGemini.nextRawText =
          '{"consejo": "El gasto alto de **\$ 500,00** en **Tienda Lujo** concentró la mayor parte del mes."}';
      final validWithHigh = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastos4High,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 560.0,
        presupuestoUsd: 1000.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(validWithHigh, contains('Tienda Lujo'));
      expect(fakeGemini.callCount, 2);
      expect(fakeGemini.lastModo, 'insight_inicio');
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 2);

      // 2b. Misma firma y mismo día -> hit de caché sin llamar a Gemini
      final cacheHit = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastos4High,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 560.0,
        presupuestoUsd: 1000.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(cacheHit, validWithHigh);
      expect(fakeGemini.callCount, 2);

      // 3. Se borra el gasto alto el MISMO día -> invalida caché vieja y regenera consejo limpio (cupo 3/3)
      fakeGemini.nextRawText =
          '{"consejo": "El **Café Molido** te salió un **25%** más barato en **Unicasa** que en **Farmatodo**."}';
      final afterDelete = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastos3,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 60.0,
        presupuestoUsd: 1000.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(afterDelete, contains('Unicasa'));
      expect(afterDelete, isNot(contains('Tienda Lujo')));
      expect(fakeGemini.callCount, 3);
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 3);

      // 4. 4.º cambio el MISMO día -> tope 3/3 alcanzado: purga caché obsoleta, NO llama Gemini y devuelve null
      final gastos5 = _buildSampleGastos(5);
      final cappedResult = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastos5,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 100.0,
        presupuestoUsd: 1000.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(cappedResult, isNull);
      expect(fakeGemini.callCount, 3);
      expect(prefs.containsKey(AiInsightService.prefTextKey), isFalse);
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 3);

      // 5. Día siguiente (frescura diaria incluso con los mismos gastos) -> reinicia cuota a 1/3 y regenera
      fakeGemini.nextRawText =
          '{"consejo": "Buen control en **Alimentación**: llevas **20%** menos que el mes pasado a esta fecha."}';
      final nextDayFresh = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastos5,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 100.0,
        presupuestoUsd: 1000.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 16),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(nextDayFresh, contains('20%'));
      expect(fakeGemini.callCount, 4);
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 1);
      expect(prefs.getString(AiInsightService.prefCachedDateKey), '2026-11-16');

      // 5b. Mismo día nuevo y mismos gastos -> hit de caché (0 llamadas extra)
      final nextDayCacheHit = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastos5,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 100.0,
        presupuestoUsd: 1000.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 16),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(nextDayCacheHit, nextDayFresh);
      expect(fakeGemini.callCount, 4);

      // 6. Tercer día sin cambios en gastos -> la caché de ayer caduca y genera análisis fresco de hoy
      fakeGemini.nextRawText =
          '{"consejo": "Tus compras en **Farmatodo** subieron esta quincena; revisa alternativas cercanas."}';
      final thirdDayFresh = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastos5,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 100.0,
        presupuestoUsd: 1000.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 17),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(thirdDayFresh, contains('Farmatodo'));
      expect(fakeGemini.callCount, 5);
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 1);
    });

    test('concurrent burst of 4 distinct signatures strictly respects 3/day cap and never writes stale text', () async {
      final prefs = await SharedPreferences.getInstance();
      final completers = <Completer<Map<String, dynamic>>>[
        Completer<Map<String, dynamic>>(),
        Completer<Map<String, dynamic>>(),
        Completer<Map<String, dynamic>>(),
      ];
      final fakeGemini = FakeGeminiServiceForInsight()
        ..customHandler = (callIndex, _) => completers[callIndex - 1].future;
      addTearDown(fakeGemini.close);

      final f1 = AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(3, totalUsdCents: 1000),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 30.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      final f2 = AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(3, totalUsdCents: 2000),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 60.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      final f3 = AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(3, totalUsdCents: 3000),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 90.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      final f4 = AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(3, totalUsdCents: 4000),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 120.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );

      // Permitir que todas las llamadas alcancen el punto síncrono
      await Future<void>.delayed(Duration.zero);
      expect(fakeGemini.callCount, 3);

      // Completar en orden LIFO (2, 1, 0) para verificar que el contador en disco nunca retrocede (3 -> 1)
      completers[2].complete({'text': '{"consejo": "Consejo obsoleto número tres para prueba de ráfaga."}'});
      completers[1].complete({'text': '{"consejo": "Consejo obsoleto número dos para prueba de ráfaga."}'});
      completers[0].complete({'text': '{"consejo": "Consejo obsoleto número uno para prueba de ráfaga."}'});

      final results = await Future.wait([f1, f2, f3, f4]);
      expect(results, [isNull, isNull, isNull, isNull]);
      expect(fakeGemini.callCount, 3);
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 3);
      expect(prefs.containsKey(AiInsightService.prefTextKey), isFalse);
    });

    test('midnight crossover in-flight request does not block next day refresh or overwrite next day quota', () async {
      final prefs = await SharedPreferences.getInstance();
      final day1Completer = Completer<Map<String, dynamic>>();
      final fakeGemini = FakeGeminiServiceForInsight()
        ..customHandler = (callIndex, _) {
          if (callIndex == 1) return day1Completer.future;
          return Future.value({
            'text': '{"consejo": "Consejo fresco del día siguiente que no debe ser bloqueado ni pisado."}',
          });
        };
      addTearDown(fakeGemini.close);

      final gastosSame = _buildSampleGastos(3, totalUsdCents: 2000);

      // Petición lenta iniciada el día 15 queda en vuelo
      final day1Future = AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastosSame,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 60.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15, 23, 59),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      await Future<void>.delayed(Duration.zero);
      expect(fakeGemini.callCount, 1);

      // Cruce de medianoche (día 16) con los MISMOS gastos -> NO debe quedar bloqueado por el token del día 15
      final day2Result = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastosSame,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 60.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 16, 0, 1),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(day2Result, contains('día siguiente'));
      expect(fakeGemini.callCount, 2);
      expect(prefs.getString(AiInsightService.prefLastFetchDateKey), '2026-11-16');
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 1);

      // Ahora completa tarde la petición del día 15 -> NO debe pisar cuota ni caché del día 16
      day1Completer.complete({
        'text': '{"consejo": "Consejo viejo del día 15 que nunca debe pisar al día 16."}',
      });
      expect(await day1Future, isNull);
      expect(prefs.getString(AiInsightService.prefLastFetchDateKey), '2026-11-16');
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 1);
      expect(prefs.getString(AiInsightService.prefTextKey), contains('día siguiente'));
      expect(prefs.getString(AiInsightService.prefCachedDateKey), '2026-11-16');
    });

    test('migrates existing users with prefLastFetchDateKey == todayIso and missing prefFetchCountKey as count 1', () async {
      SharedPreferences.setMockInitialValues({
        AiInsightService.prefLastFetchDateKey: '2026-11-15',
      });
      final prefs = await SharedPreferences.getInstance();
      final fakeGemini = FakeGeminiServiceForInsight()
        ..nextRawText = '{"consejo": "Consejo migrado con conteo inicial en uno para hoy."}';
      addTearDown(fakeGemini.close);

      final r1 = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(3, totalUsdCents: 1500),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 45.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(r1, isNotNull);
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 2);

      final r2 = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(4, totalUsdCents: 1500),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 60.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(r2, isNotNull);
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 3);

      // 3.ª llamada nueva hoy (sería la 4.ª real) -> bloqueada
      final r3 = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(5, totalUsdCents: 1500),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 75.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(r3, isNull);
      expect(fakeGemini.callCount, 2);
    });

    test('dropping below 3 expenses purges cached insight content while preserving daily quota counters', () async {
      final prefs = await SharedPreferences.getInstance();
      final fakeGemini = FakeGeminiServiceForInsight()
        ..nextRawText = '{"consejo": "Consejo válido cuando había tres gastos en noviembre."}';
      addTearDown(fakeGemini.close);

      final valid = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(3),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 60.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(valid, isNotNull);
      expect(prefs.containsKey(AiInsightService.prefTextKey), isTrue);

      final afterDrop = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: _buildSampleGastos(2),
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 40.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(afterDrop, isNull);
      expect(prefs.containsKey(AiInsightService.prefTextKey), isFalse);
      expect(prefs.containsKey(AiInsightService.prefSignatureKey), isFalse);
      expect(prefs.containsKey(AiInsightService.prefYearMonthKey), isFalse);
      expect(prefs.containsKey(AiInsightService.prefCachedDateKey), isFalse);
      expect(prefs.getString(AiInsightService.prefLastFetchDateKey), '2026-11-15');
      expect(prefs.getInt(AiInsightService.prefFetchCountKey), 1);
    });

    test('in-flight signature token is never left stuck when a later call bumps epoch and exits at quota cap', () async {
      SharedPreferences.setMockInitialValues({
        AiInsightService.prefLastFetchDateKey: '2026-11-15',
        AiInsightService.prefFetchCountKey: 2,
      });
      final prefs = await SharedPreferences.getInstance();
      final slowCompleter = Completer<Map<String, dynamic>>();
      final fakeGemini = FakeGeminiServiceForInsight()
        ..customHandler = (callIndex, _) {
          if (callIndex == 1) return slowCompleter.future;
          return Future.value({
            'text': '{"consejo": "Nuevo consejo al día siguiente tras liberar token en vuelo."}',
          });
        };
      addTearDown(fakeGemini.close);

      final gastosA = _buildSampleGastos(3, totalUsdCents: 2000);
      final gastosB = _buildSampleGastos(4, totalUsdCents: 2000);

      // Llamada A toma el cupo 3/3 y queda en vuelo
      final futureA = AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastosA,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 60.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      await Future<void>.delayed(Duration.zero);
      expect(fakeGemini.callCount, 1);

      // Llamada B llega y sale por tope 3/3 (sube la época sin tocar el token de A)
      final resB = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastosB,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 80.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 15),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(resB, isNull);
      expect(fakeGemini.callCount, 1);

      // Completa llamada A: época superada -> descarta escritura, pero DEBE liberar su token en finally
      slowCompleter.complete({
        'text': '{"consejo": "Consejo viejo de A que no debe persistirse ni atascar el token."}',
      });
      expect(await futureA, isNull);
      expect(prefs.containsKey(AiInsightService.prefTextKey), isFalse);

      // Al día siguiente, gastosA NO está bloqueado y puede volver a consultar a Gemini
      final nextDayA = await AiInsightService.refreshBackgroundInsightIfNeeded(
        gastos: gastosA,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 60.0,
        presupuestoUsd: 500.0,
        metaAhorroUsd: 0.0,
        currentDate: DateTime(2026, 11, 16),
        geminiService: fakeGemini,
        prefsInstance: prefs,
      );
      expect(nextDayA, contains('liberar token'));
      expect(fakeGemini.callCount, 2);
    });

    test('buildExpenseSignature is deterministic, order-independent, ignores sync metadata, detects edits, and avoids delimiter collisions', () {
      final g1 = GastoModel(
        id: 1,
        uuid: 'u-1',
        fecha: '2026-11-10',
        comercio: 'Farmatodo',
        moneda: 'USD',
        totalOriginal: 2000,
        totalUsd: 2000,
        categoria: 'Alimentación',
        creadoEn: '2026-11-10T10:00:00',
        actualizadoEn: '2026-11-10T10:00:00',
        synced: 0,
        items: [
          ItemGastoModel(descripcion: 'Café', cantidad: 1, precioUnitario: 1200, total: 1200, categoria: 'Alimentación'),
          ItemGastoModel(descripcion: 'Pan', cantidad: 2, precioUnitario: 400, total: 800, categoria: 'Alimentación'),
        ],
      );
      final g2 = GastoModel(
        id: 2,
        uuid: 'u-2',
        fecha: '2026-11-11',
        comercio: 'Unicasa',
        moneda: 'USD',
        totalOriginal: 1000,
        totalUsd: 1000,
        categoria: 'Higiene',
        creadoEn: '2026-11-11T10:00:00',
        items: [
          ItemGastoModel(descripcion: 'Jabón', cantidad: 1, precioUnitario: 1000, total: 1000, categoria: 'Higiene'),
        ],
      );

      final sigOriginal = AiInsightService.buildExpenseSignature(
        year: 2026,
        month: 11,
        gastos: [g1, g2],
        totalMesUsd: 30.0,
      );

      // Orden distinto de gastos e ítems + cambios de metadatos volátiles de sync -> misma firma
      final g1SyncedReordered = g1.copyWith(
        actualizadoEn: '2026-11-15T22:00:00',
        synced: 1,
        firestoreId: 'fs-abc-123',
        rutaFotoLocal: '/tmp/otra_ruta.jpg',
        items: g1.items.reversed.toList(),
      );
      final sigReordered = AiInsightService.buildExpenseSignature(
        year: 2026,
        month: 11,
        gastos: [g2, g1SyncedReordered],
        totalMesUsd: 30.0,
      );
      expect(sigReordered, sigOriginal);

      // Editar categoría o comercio sin cambiar totalMesUsd -> firma distinta
      final sigCatEdited = AiInsightService.buildExpenseSignature(
        year: 2026,
        month: 11,
        gastos: [g1.copyWith(categoria: 'Salud'), g2],
        totalMesUsd: 30.0,
      );
      expect(sigCatEdited, isNot(sigOriginal));

      final sigCommerceEdited = AiInsightService.buildExpenseSignature(
        year: 2026,
        month: 11,
        gastos: [g1.copyWith(comercio: 'Excelsior Gama'), g2],
        totalMesUsd: 30.0,
      );
      expect(sigCommerceEdited, isNot(sigOriginal));

      // Prueba anti-colisión de delimitadores (|, ,, \n) en descripciones de ítems
      final gDelimOneItem = g2.copyWith(
        items: [
          ItemGastoModel(
            descripcion: 'Queso | 1kg, fresco\nEspecial',
            cantidad: 1,
            precioUnitario: 1000,
            total: 1000,
            categoria: 'Alimentación',
          ),
        ],
      );
      final gDelimTwoItems = g2.copyWith(
        items: [
          ItemGastoModel(
            descripcion: 'Queso',
            cantidad: 1,
            precioUnitario: 500,
            total: 500,
            categoria: 'Alimentación',
          ),
          ItemGastoModel(
            descripcion: '1kg, fresco\nEspecial',
            cantidad: 1,
            precioUnitario: 500,
            total: 500,
            categoria: 'Alimentación',
          ),
        ],
      );
      final sigDelim1 = AiInsightService.buildExpenseSignature(
        year: 2026,
        month: 11,
        gastos: [gDelimOneItem],
        totalMesUsd: 10.0,
      );
      final sigDelim2 = AiInsightService.buildExpenseSignature(
        year: 2026,
        month: 11,
        gastos: [gDelimTwoItems],
        totalMesUsd: 10.0,
      );
      expect(sigDelim1, isNot(sigDelim2));
    });
  });
}
