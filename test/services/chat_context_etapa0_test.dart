import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/domain/finance/savings_health_calculator.dart';
import 'package:gastoscan_ai/services/ai_insight_service.dart';
import 'package:gastoscan_ai/services/chat_context_builder.dart';
import 'package:gastoscan_ai/services/chat_signal_selector.dart';

class _CountingFakeDb extends DatabaseHelper {
  int getGastosByMonthCalls = 0;
  int findPriceHistoryCalls = 0;
  List<GastoModel> prevMonthGastos = const [];
  Map<String, PriceHistory> mockPriceHistory = const {};

  _CountingFakeDb() : super.test();

  @override
  Future<List<GastoModel>> getGastosByMonth(int year, int month) async {
    getGastosByMonthCalls++;
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
    findPriceHistoryCalls++;
    return mockPriceHistory;
  }
}

GastoModel _makeGasto({
  required int id,
  required String fecha,
  required String comercio,
  required int totalCents,
  String categoria = 'Alimentación',
  List<ItemGastoModel> items = const [],
}) {
  return GastoModel(
    id: id,
    uuid: 'uuid-$id',
    fecha: fecha,
    comercio: comercio,
    moneda: 'USD',
    totalOriginal: totalCents,
    totalUsd: totalCents,
    categoria: categoria,
    creadoEn: '${fecha}T12:00:00Z',
    items: items,
  );
}

void main() {
  group('AI-11 Etapa 0 — Grupo 1: Consultas directas y acciones (0 señales ocultas)', () {
    const directQueries = [
      '¿Cuánto gasté en pan?',
      '¿Cuánto gasté en farmacia este mes?',
      'Compré 5\$ de queso en Unimarket',
      'Agrega leche y café a la lista de compras',
      '¿Qué tengo pendiente en mi lista?',
    ];

    for (final query in directQueries) {
      test('clasifica "$query" como direct_or_action sin señales ocultas', () {
        final sel = ChatSignalSelector.select(currentMessage: query);
        expect(sel.intentGroup, 'direct_or_action');
        expect(sel.needsAnyHiddenSignal, isFalse);
        expect(sel.includeAntExpenses, isFalse);
        expect(sel.includePrevMonthComparison, isFalse);
        expect(sel.includePriceFindings, isFalse);
        expect(sel.includeTemporalContext, isFalse);
        expect(sel.includeTopComercios, isFalse);
      });
    }
  });

  group('AI-11 Etapa 0 — Grupo 2: Análisis específico (selección exacta de señales)', () {
    test('comparativa mensual activa solo comparativa_mes_anterior + contexto_temporal', () {
      final sel = ChatSignalSelector.select(
        currentMessage: '¿Estoy gastando más que el mes pasado?',
      );
      expect(sel.intentGroup, 'prev_month');
      expect(sel.includePrevMonthComparison, isTrue);
      expect(sel.includeTemporalContext, isTrue);
      expect(sel.includePriceFindings, isFalse);
      expect(sel.includeAntExpenses, isFalse);
      expect(sel.includeTopComercios, isFalse);
    });

    test('consulta de precios activa solo diferencias_precios + top_comercios', () {
      final sel = ChatSignalSelector.select(
        currentMessage: '¿Dónde me salió más barato el café?',
      );
      expect(sel.intentGroup, 'prices');
      expect(sel.includePriceFindings, isTrue);
      expect(sel.includeTopComercios, isTrue);
      expect(sel.includePrevMonthComparison, isFalse);
      expect(sel.includeAntExpenses, isFalse);
    });

    test('consulta de gastos pequeños activa solo gastos_hormiga', () {
      final sel = ChatSignalSelector.select(
        currentMessage: '¿Qué gastos pequeños están sumando más?',
      );
      expect(sel.intentGroup, 'ant_expenses');
      expect(sel.includeAntExpenses, isTrue);
      expect(sel.includePrevMonthComparison, isFalse);
      expect(sel.includePriceFindings, isFalse);
    });

    test('consulta de ritmo y presupuesto activa análisis completo + contexto_temporal', () {
      final sel = ChatSignalSelector.select(
        currentMessage: '¿Voy muy rápido con el presupuesto este mes?',
      );
      expect(sel.intentGroup, 'analysis_or_budget');
      expect(sel.includeAntExpenses, isTrue);
      expect(sel.includePrevMonthComparison, isTrue);
      expect(sel.includePriceFindings, isTrue);
      expect(sel.includeTemporalContext, isTrue);
      expect(sel.includeTopComercios, isTrue);
    });

    test('consulta de ahorro general activa todas las señales', () {
      final sel = ChatSignalSelector.select(
        currentMessage: '¿En qué se me está yendo el dinero y cómo ahorro?',
      );
      expect(sel.intentGroup, 'analysis_or_budget');
      expect(sel.needsAnyHiddenSignal, isTrue);
      expect(sel.includeTemporalContext, isTrue);
      expect(sel.includeTopComercios, isTrue);
    });
  });

  group('AI-11 Etapa 0 — Grupo 3: Integridad temporal y fiscal AI-06', () {
    test('día 2 del mes con \$200 bloquea proyección (inicio_de_mes)', () {
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 600,
        metaAhorro: 100,
        gastoAcumulado: 200,
        diaActual: 2,
        diasTotalesMes: 30,
      );
      final temporal = ChatContextBuilder.buildTemporalContext(
        selectedYear: 2026,
        selectedMonth: 11,
        cantidadComprasMes: 5,
        savingsSnapshot: snapshot,
        currentDate: DateTime(2026, 11, 2),
      );
      expect(temporal['proyeccion_confiable'], isFalse);
      expect(temporal['gasto_proyectado_fin_mes'], isNull);
      expect(temporal['motivo_sin_proyeccion'], 'inicio_de_mes');
      expect(temporal['dias_transcurridos'], 2);
      expect(temporal['gasto_diario_promedio'], 100.0);
    });

    test('día 15 del mes con solo 2 gastos bloquea proyección (pocos_gastos)', () {
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 600,
        metaAhorro: 100,
        gastoAcumulado: 150,
        diaActual: 15,
        diasTotalesMes: 30,
      );
      final temporal = ChatContextBuilder.buildTemporalContext(
        selectedYear: 2026,
        selectedMonth: 11,
        cantidadComprasMes: 2,
        savingsSnapshot: snapshot,
        currentDate: DateTime(2026, 11, 15),
      );
      expect(temporal['proyeccion_confiable'], isFalse);
      expect(temporal['gasto_proyectado_fin_mes'], isNull);
      expect(temporal['motivo_sin_proyeccion'], 'pocos_gastos');
    });

    test('mes pasado seleccionado marca mes_cerrado y periodo_consultado correcto', () {
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 500,
        metaAhorro: 50,
        gastoAcumulado: 410,
        diaActual: 31,
        diasTotalesMes: 31,
      );
      final temporal = ChatContextBuilder.buildTemporalContext(
        selectedYear: 2026,
        selectedMonth: 10,
        cantidadComprasMes: 14,
        savingsSnapshot: snapshot,
        currentDate: DateTime(2026, 11, 21),
      );
      expect(temporal['es_mes_actual'], isFalse);
      expect(temporal['periodo_consultado'], '2026-10');
      expect(temporal['proyeccion_confiable'], isFalse);
      expect(temporal['gasto_proyectado_fin_mes'], isNull);
      expect(temporal['motivo_sin_proyeccion'], 'mes_cerrado');
    });

    test('normaliza factura legada (G) con línea IVA 16% y factura AI-06 imputada en una sola entrada comparable Con IVA', () {
      // Factura 1 (legada): Harina PAN (G) en base $10.00 + IVA 16% $1.60 = $11.60
      final legacyInvoice = _makeGasto(
        id: 1,
        fecha: '2026-11-05',
        comercio: 'Unicasa',
        totalCents: 1160,
        items: [
          ItemGastoModel(
            descripcion: 'Harina PAN (G)',
            cantidad: 1,
            precioUnitario: 1000,
            total: 1000,
            categoria: 'Alimentación',
          ),
          ItemGastoModel(
            descripcion: 'IVA 16%',
            cantidad: 1,
            precioUnitario: 160,
            total: 160,
            categoria: 'Otros',
          ),
        ],
      );

      // Factura 2 (AI-06): Harina PAN ya imputada Con IVA $11.60 (baseImponibleOriginal = 1000)
      final imputedInvoice = _makeGasto(
        id: 2,
        fecha: '2026-11-12',
        comercio: 'Farmatodo',
        totalCents: 1160,
        items: [
          ItemGastoModel(
            descripcion: 'Harina PAN',
            cantidad: 1,
            precioUnitario: 1160,
            total: 1160,
            baseImponibleOriginal: 1000,
            categoria: 'Alimentación',
          ),
        ],
      );

      final top = ChatContextBuilder.buildTopProducts([legacyInvoice, imputedInvoice]);
      expect(top.length, 1);
      expect(top.first['producto'], 'Harina PAN');
      expect(top.first['cantidad'], 2.0);
      expect(top.first['veces_comprado'], 2);
      // $11.60 (ajustado 1.16) + $11.60 (ya imputado) = $23.20 exactos
      expect(top.first['total_usd'], 23.20);
    });

    test('instante 02:30 UTC (22:30 VET del día previo) conserva fecha de Venezuela', () {
      final lateNightUtc = DateTime.utc(2026, 11, 22, 2, 30);
      final vetDate = ChatContextBuilder.resolveVenezuelaDate(currentDate: lateNightUtc);
      expect(ChatContextBuilder.formatIsoDate(vetDate), '2026-11-21');

      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 400,
        metaAhorro: 50,
        gastoAcumulado: 210,
        diaActual: 21,
        diasTotalesMes: 30,
      );
      final ctx = ChatContextBuilder.buildSemanticChatContext(
        gastos: [
          _makeGasto(id: 1, fecha: '2026-11-05', comercio: 'A', totalCents: 7000),
          _makeGasto(id: 2, fecha: '2026-11-10', comercio: 'B', totalCents: 7000),
          _makeGasto(id: 3, fecha: '2026-11-18', comercio: 'C', totalCents: 7000),
        ],
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 210,
        totalMesUsdt: 190,
        totalMesVes: 10500,
        tasaCambioVesUsd: 50,
        tasaCambioVesEur: 54,
        tasaCambioVesUsdt: 55,
        presupuestoGeneral: 400,
        metaAhorro: 50,
        monedaPresupuesto: 'USD',
        monedaPrincipal: 'VES',
        presupuestosPorCategoria: const {},
        savingsSnapshot: snapshot,
        shoppingItems: const [],
        selection: const ChatSignalSelection.all(),
        currentDate: lateNightUtc,
      );
      expect(ctx['fecha_hoy'], '2026-11-21');
      expect(ctx['moneda_principal'], 'VES');
      expect(ctx['contexto_temporal']['fecha_hoy_ve'], '2026-11-21');
      expect(ctx['contexto_temporal']['proyeccion_confiable'], isTrue);
      expect(ctx['gasto_proyectado_fin_mes'], 300.0);
    });
  });

  group('AI-11 Etapa 0 — Grupo 4: Repreguntas, SQLite selectivo, orden y exclusiones', () {
    test('repregunta corta "¿y por qué?" hereda comparativa_mes_anterior del turno previo', () {
      final sel = ChatSignalSelector.select(
        currentMessage: '¿y por qué?',
        previousUserMessage: '¿Estoy gastando más que el mes pasado?',
      );
      expect(sel.intentGroup, 'followup_inherited');
      expect(sel.includePrevMonthComparison, isTrue);
      expect(sel.includeTemporalContext, isTrue);
      expect(sel.includePriceFindings, isFalse);
    });

    test('forceAllSignals (Consultar ->) mantiene todas las señales aunque el mensaje sea corto', () {
      final sel = ChatSignalSelector.select(
        currentMessage: 'Ver más',
        forceAllSignals: true,
      );
      expect(sel.includeAntExpenses, isTrue);
      expect(sel.includePrevMonthComparison, isTrue);
      expect(sel.includePriceFindings, isTrue);
      expect(sel.includeTemporalContext, isTrue);
      expect(sel.includeTopComercios, isTrue);
    });

    test('computeHiddenSignals respeta flags selectivos y omite consultas SQLite innecesarias', () async {
      final fakeDb = _CountingFakeDb();
      final gastos = List.generate(
        5,
        (i) => _makeGasto(
          id: i + 1,
          fecha: '2026-11-0${i + 1}',
          comercio: 'Kiosco',
          totalCents: 500,
          items: [
            ItemGastoModel(
              descripcion: 'Café negro',
              cantidad: 1,
              precioUnitario: 500,
              total: 500,
              categoria: 'Alimentación',
            ),
          ],
        ),
      );

      // Solo gastos hormiga -> 0 llamadas a SQLite
      final antOnly = await AiInsightService.computeHiddenSignals(
        gastos: gastos,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 25.0,
        totalMesUsdt: 25.0,
        currentDate: DateTime(2026, 11, 15),
        dbHelper: fakeDb,
        includeAntExpenses: true,
        includePrevMonthComparison: false,
        includePriceFindings: false,
      );
      expect(fakeDb.getGastosByMonthCalls, 0);
      expect(fakeDb.findPriceHistoryCalls, 0);
      expect(antOnly.antExpenses, isNotNull);
      expect(antOnly.antExpenses!['umbral_usd'], 10.0);
      expect(antOnly.antExpenses!['moneda'], 'USD');
      expect(antOnly.prevMonthComparison, isNull);

      // Mes sin historial previo en SQLite -> omite comparativa limpiamente
      final noPrev = await AiInsightService.computeHiddenSignals(
        gastos: gastos,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 25.0,
        totalMesUsdt: 25.0,
        currentDate: DateTime(2026, 11, 15),
        dbHelper: fakeDb,
        includeAntExpenses: false,
        includePrevMonthComparison: true,
        includePriceFindings: false,
      );
      expect(fakeDb.getGastosByMonthCalls, 1);
      expect(fakeDb.findPriceHistoryCalls, 0);
      expect(noPrev.prevMonthComparison, isNull);

      // Solo diferencias de precios -> llama solo findPriceHistory y adjunta ventana_dias/moneda
      fakeDb.mockPriceHistory = {
        'cafe negro': const PriceHistory(
          descripcionNorm: 'cafe negro',
          registros: 2,
          mejorPrecio: UnitPriceRef(
            precioUsd: 3.00,
            fecha: '2026-11-01',
            comercio: 'Unicasa',
            comercioNorm: 'unicasa',
            cantidad: 1,
          ),
          entradas: [
            UnitPriceRef(
              precioUsd: 5.00,
              fecha: '2026-11-12',
              comercio: 'Kiosco',
              comercioNorm: 'kiosco',
              cantidad: 1,
            ),
            UnitPriceRef(
              precioUsd: 3.00,
              fecha: '2026-11-01',
              comercio: 'Unicasa',
              comercioNorm: 'unicasa',
              cantidad: 1,
            ),
          ],
        ),
      };
      final pricesOnly = await AiInsightService.computeHiddenSignals(
        gastos: gastos,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 25.0,
        totalMesUsdt: 25.0,
        currentDate: DateTime(2026, 11, 15),
        dbHelper: fakeDb,
        includeAntExpenses: false,
        includePrevMonthComparison: false,
        includePriceFindings: true,
      );
      expect(fakeDb.getGastosByMonthCalls, 1);
      expect(fakeDb.findPriceHistoryCalls, 1);
      expect(pricesOnly.priceFindings.length, 1);
      expect(pricesOnly.priceFindings.first['ventana_dias'], 60);
      expect(pricesOnly.priceFindings.first['moneda'], 'USD');

      // Verificar patrón compromet[a-z]* ("¿Mi meta está comprometida?")
      final metaSel = ChatSignalSelector.select(
        currentMessage: '¿Mi meta está comprometida este mes?',
      );
      expect(metaSel.intentGroup, 'analysis_or_budget');
      expect(metaSel.needsAnyHiddenSignal, isTrue);
    });

    test('top_productos_mes ordena por total_usd DESC (1 carne \$35 antes que 10 chicles \$2)', () {
      final g = _makeGasto(
        id: 1,
        fecha: '2026-11-10',
        comercio: 'Excelsior Gama',
        totalCents: 3700,
        items: [
          ItemGastoModel(
            descripcion: 'Chicle',
            cantidad: 10,
            precioUnitario: 20,
            total: 200,
            categoria: 'Alimentación',
          ),
          ItemGastoModel(
            descripcion: 'Carne de res',
            cantidad: 1,
            precioUnitario: 3500,
            total: 3500,
            categoria: 'Alimentación',
          ),
        ],
      );
      final top = ChatContextBuilder.buildTopProducts([g]);
      expect(top.first['producto'], 'Carne de res');
      expect(top.first['total_usd'], 35.0);
      expect(top[1]['producto'], 'Chicle');
      expect(top[1]['cantidad'], 10.0);
    });

    test('excluye impuestos en top_productos_mes, añade metadatos de período en comparativa y calcula Black Friday 2026', () async {
      final fakeDb = _CountingFakeDb()
        ..prevMonthGastos = [
          _makeGasto(
            id: 90,
            fecha: '2026-10-05',
            comercio: 'Unicasa',
            totalCents: 10000,
            categoria: 'Alimentación',
          ),
        ];

      final gastos = [
        _makeGasto(
          id: 1,
          fecha: '2026-11-05',
          comercio: 'Unicasa',
          totalCents: 3000,
          items: [
            ItemGastoModel(
              descripcion: 'Arroz',
              cantidad: 1,
              precioUnitario: 2500,
              total: 2500,
              categoria: 'Alimentación',
            ),
            ItemGastoModel(
              descripcion: 'IVA 16%',
              cantidad: 1,
              precioUnitario: 500,
              total: 500,
              categoria: 'Otros',
            ),
          ],
        ),
      ];

      final top = ChatContextBuilder.buildTopProducts(gastos);
      expect(top.map((e) => e['producto']), ['Arroz']);

      final signals = await AiInsightService.computeHiddenSignals(
        gastos: gastos,
        selectedYear: 2026,
        selectedMonth: 11,
        totalMesUsd: 30.0,
        totalMesUsdt: 30.0,
        currentDate: DateTime(2026, 11, 15),
        dbHelper: fakeDb,
        includeAntExpenses: false,
        includePrevMonthComparison: true,
        includePriceFindings: false,
      );
      expect(signals.prevMonthComparison, isNotNull);
      expect(signals.prevMonthComparison!['periodo_actual'], '2026-11-01..2026-11-15');
      expect(signals.prevMonthComparison!['periodo_anterior'], '2026-10-01..2026-10-15');
      expect(signals.prevMonthComparison!['comparacion_parcial'], isTrue);
      expect(signals.prevMonthComparison!['moneda'], 'USD');

      // Fórmula determinista de Black Friday 2026 (viernes tras 4.º jueves de nov = 27/11/2026)
      expect(
        ChatContextBuilder.formatIsoDate(ChatContextBuilder.calculateBlackFriday(2026)),
        '2026-11-27',
      );
    });
  });
}
