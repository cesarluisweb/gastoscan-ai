import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/providers/chat_provider.dart';
import 'package:gastoscan_ai/services/ai_insight_service.dart';
import 'package:gastoscan_ai/ui/widgets/ai_insight_card.dart';

void main() {
  group('AiInsightCard Tests', () {
    testWidgets('displays welcome prompt when expenses are empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: const [],
              presupuestoGeneral: 0.0,
              totalesPorCategoria: const {},
              totalGastadoMes: 0.0,
              currentDate: DateTime(2026, 9, 15),
              mes: 9,
              anio: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_insight_card')), findsOneWidget);
      expect(find.text('Asistente IA'), findsOneWidget);
      expect(find.textContaining('botón +'), findsOneWidget);
    });

    testWidgets('displays over budget warning when spent exceeds budget', (tester) async {
      final gasto = GastoModel(
        id: 1,
        uuid: 'uuid-1',
        fecha: '2026-09-15',
        comercio: 'Mercado',
        moneda: 'USD',
        totalOriginal: 12000,
        totalUsd: 12000,
        categoria: 'Alimentación',
        creadoEn: '2026-09-15T10:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: [gasto],
              presupuestoGeneral: 100.0,
              totalesPorCategoria: const {'Alimentación': 120.0},
              totalGastadoMes: 120.0,
              currentDate: DateTime(2026, 9, 15),
              mes: 9,
              anio: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Superaste tu presupuesto'), findsOneWidget);
    });

    testWidgets('displays daily pace recommendation when budget is healthy', (tester) async {
      final gasto = GastoModel(
        id: 1,
        uuid: 'uuid-1',
        fecha: '2026-09-15',
        comercio: 'Mercado',
        moneda: 'USD',
        totalOriginal: 5000,
        totalUsd: 5000,
        categoria: 'Alimentación',
        creadoEn: '2026-09-15T10:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: [gasto],
              presupuestoGeneral: 100.0,
              totalesPorCategoria: const {'Alimentación': 50.0},
              totalGastadoMes: 50.0,
              currentDate: DateTime(2026, 9, 15),
              mes: 9,
              anio: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Puedes gastar hasta'), findsOneWidget);
      expect(find.textContaining('/día'), findsOneWidget);
    });

    testWidgets('suggests defining budget when no general budget exists', (tester) async {
      final gasto = GastoModel(
        id: 1,
        uuid: 'uuid-1',
        fecha: '2026-09-15',
        comercio: 'Mercado',
        moneda: 'USD',
        totalOriginal: 3000,
        totalUsd: 3000,
        categoria: 'Alimentación',
        creadoEn: '2026-09-15T10:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: [gasto],
              presupuestoGeneral: 0.0,
              totalesPorCategoria: const {},
              totalGastadoMes: 30.0,
              currentDate: DateTime(2026, 9, 15),
              mes: 9,
              anio: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Define un presupuesto mensual'), findsOneWidget);
    });

    testWidgets('displays new month motivational insight when in first days with budget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: const [],
              presupuestoGeneral: 150.0,
              totalesPorCategoria: const {},
              totalGastadoMes: 0.0,
              currentDate: DateTime(2026, 10, 3),
              mes: 10,
              anio: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_insight_card')), findsOneWidget);
      expect(find.textContaining('Nuevo mes'), findsOneWidget);
      expect(find.textContaining('aplicar lo aprendido'), findsOneWidget);
    });

    testWidgets('displays compromised savings goal alert when spent exceeds spending limit', (tester) async {
      final gasto = GastoModel(
        id: 1,
        uuid: 'uuid-1',
        fecha: '2026-09-15',
        comercio: 'Mercado',
        moneda: 'USD',
        totalOriginal: 45000,
        totalUsd: 45000,
        categoria: 'Alimentación',
        creadoEn: '2026-09-15T10:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: [gasto],
              presupuestoGeneral: 500.0,
              metaAhorro: 100.0,
              totalesPorCategoria: const {'Alimentación': 450.0},
              totalGastadoMes: 450.0,
              currentDate: DateTime(2026, 9, 15),
              mes: 9,
              anio: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tu meta de ahorro'), findsOneWidget);
      expect(find.textContaining('comprometida'), findsOneWidget);
    });

    testWidgets('displays concise daily pace discounting savings goal without redundant boilerplate or robot icon', (tester) async {
      final gasto = GastoModel(
        id: 1,
        uuid: 'uuid-1',
        fecha: '2026-09-15',
        comercio: 'Mercado',
        moneda: 'USD',
        totalOriginal: 15000,
        totalUsd: 15000,
        categoria: 'Alimentación',
        creadoEn: '2026-09-15T10:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: [gasto],
              presupuestoGeneral: 500.0,
              metaAhorro: 100.0,
              totalesPorCategoria: const {'Alimentación': 150.0},
              totalGastadoMes: 150.0,
              currentDate: DateTime(2026, 9, 15),
              mes: 9,
              anio: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sin icono de robotcito
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
      // Descuenta la meta de ahorro ($500 - $100 - $150 = $250 / 15 días = $ 16,67/día) sin texto redundante
      expect(find.textContaining('Puedes gastar hasta \$ 16,67/día'), findsOneWidget);
      expect(find.textContaining('Excelente administración'), findsNothing);
      expect(find.textContaining('protegida'), findsNothing);
      // Nunca muestra asteriscos literales **
      expect(find.textContaining('**'), findsNothing);

      // Verifica que el monto está renderizado en negrita real (FontWeight.w700)
      final richText = tester.widget<Text>(find.textContaining('\$ 16,67/día'));
      final rootSpan = richText.textSpan as TextSpan;
      final boldSpans = (rootSpan.children ?? [])
          .whereType<TextSpan>()
          .where((s) => s.style?.fontWeight == FontWeight.w700)
          .map((s) => s.text)
          .toList();
      expect(boldSpans, contains('\$ 16,67/día'));
      expect(boldSpans, contains('15 días'));
    });

    testWidgets('does not double-multiply VES amounts by tasaCambio ([F1-C03])', (tester) async {
      final gasto = GastoModel(
        id: 1,
        uuid: 'uuid-ves',
        fecha: '2026-10-15',
        comercio: 'Mercado',
        moneda: 'VES',
        totalOriginal: 450000,
        totalUsd: 1000,
        categoria: 'Alimentación',
        creadoEn: '2026-10-15T10:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: [gasto],
              presupuestoGeneral: 5000.0,
              metaAhorro: 1000.0,
              totalesPorCategoria: const {'Alimentación': 4500.0},
              totalGastadoMes: 4500.0,
              monedaPresupuesto: 'VES',
              tasaCambio: 400.0,
              currentDate: DateTime(2026, 10, 15),
              mes: 10,
              anio: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exceso es 500 Bs y meta es 1.000 Bs (NO 200.000 Bs ni 400.000 Bs)
      expect(find.textContaining('Bs. 500,00'), findsOneWidget);
      expect(find.textContaining('Bs. 1.000,00'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
    });

    testWidgets('shows single cached Gemini insight and triggers live deep-dive in ChatProvider on Consultar tap (AI-08)', (tester) async {
      final chatProvider = ChatProvider();
      bool navigatedToChat = false;

      final gasto = GastoModel(
        id: 1,
        uuid: 'uuid-ai08',
        fecha: '2026-11-10',
        comercio: 'Farmatodo',
        moneda: 'USD',
        totalOriginal: 4000,
        totalUsd: 4000,
        categoria: 'Salud',
        creadoEn: '2026-11-10T10:00:00',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: chatProvider,
          child: MaterialApp(
            home: Scaffold(
              body: AiInsightCard(
                gastos: [gasto],
                presupuestoGeneral: 200.0,
                totalesPorCategoria: const {'Salud': 40.0},
                totalGastadoMes: 40.0,
                currentDate: DateTime(2026, 11, 10),
                mes: 11,
                anio: 2026,
                cachedGeminiText: 'Concentraste **3 compras** en **Farmatodo** por **\$ 40,00** esta semana; comparar precios por unidad te ayudará a ahorrar.',
                onChatTap: () {
                  navigatedToChat = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Muestra el consejo de Gemini con negritas reales, sin asteriscos literales ni repetir SummaryCard
      expect(find.textContaining('Concentraste 3 compras en Farmatodo por \$ 40,00'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);

      // Al tocar Consultar -> debe poner la burbuja del Asistente y dejar listo el deep-dive en vivo
      await tester.tap(find.byKey(const Key('ai_insight_card_consultar_btn')));
      await tester.pumpAndSettle();

      expect(navigatedToChat, isTrue);
      expect(chatProvider.messages.length, 1);
      expect(chatProvider.messages.first['role'], 'assistant');
      expect(chatProvider.messages.first['text'], contains('Sobre el análisis de hoy:'));
      expect(chatProvider.hasUserMessages, isFalse);
      expect(chatProvider.pendingInsightDeepDive, contains('Farmatodo'));
    });

    testWidgets('ignores malformed cached prefix and shows hidden price difference insight locally (AI-08)', (tester) async {
      final gasto = GastoModel(
        id: 1,
        uuid: 'uuid-price',
        fecha: '2026-11-12',
        comercio: 'Farmatodo',
        moneda: 'USD',
        totalOriginal: 450,
        totalUsd: 450,
        categoria: 'Alimentación',
        creadoEn: '2026-11-12T10:00:00',
      );

      const hiddenSignals = AiHiddenSignals(
        priceFindings: [
          {
            'tipo': 'otro_comercio_mas_barato',
            'producto': 'Café Molido',
            'comercio_reciente': 'Farmatodo',
            'precio_reciente_usd': 4.50,
            'comercio_mas_barato': 'Unicasa',
            'precio_mas_barato_usd': 3.60,
            'diferencia_pct': 25,
          },
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: [gasto],
              presupuestoGeneral: 300.0,
              totalesPorCategoria: const {'Alimentación': 45.0},
              totalGastadoMes: 45.0,
              currentDate: DateTime(2026, 11, 12),
              mes: 11,
              anio: 2026,
              cachedGeminiText: 'Consejo corto: Tienes un presupuesto de \$300 y has gastado \$45.',
              hiddenSignals: hiddenSignals,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Consejo corto:'), findsNothing);
      expect(find.textContaining('Pagaste \$ 4,50 por Café Molido en Farmatodo'), findsOneWidget);
      expect(find.textContaining('25%'), findsOneWidget);
      expect(find.textContaining('Unicasa'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
    });

    testWidgets('displays single curated insight on even days without mixing daily pace (AI-08)', (tester) async {
      final gasto = GastoModel(
        id: 1,
        uuid: 'uuid-even',
        fecha: '2026-09-16',
        comercio: 'Mercado',
        moneda: 'USD',
        totalOriginal: 5000,
        totalUsd: 5000,
        categoria: 'Alimentación',
        creadoEn: '2026-09-16T10:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: [gasto],
              presupuestoGeneral: 200.0,
              totalesPorCategoria: const {'Alimentación': 50.0},
              totalGastadoMes: 50.0,
              currentDate: DateTime(2026, 9, 16), // dayOfYear = 258 (par) -> consejo curado único
              mes: 9,
              anio: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
      expect(find.textContaining('Puedes gastar hasta'), findsNothing);
      expect(find.textContaining('**'), findsNothing);
    });

    testWidgets('displays category budget warning heuristic when a category reaches >= 80% of its budget (AI-08)', (tester) async {
      final gasto = GastoModel(
        id: 1,
        uuid: 'uuid-cat',
        fecha: '2026-11-12',
        comercio: 'Unicasa',
        moneda: 'USD',
        totalOriginal: 8500,
        totalUsd: 8500,
        categoria: 'Alimentación',
        creadoEn: '2026-11-12T10:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: [gasto],
              presupuestoGeneral: 300.0,
              totalesPorCategoria: const {'Alimentación': 85.0},
              presupuestosPorCategoria: const {'Alimentación': 100.0},
              totalGastadoMes: 85.0,
              currentDate: DateTime(2026, 11, 12),
              mes: 11,
              anio: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Atención en Alimentación: ya usaste el 85%'), findsOneWidget);
      expect(find.textContaining('Puedes gastar hasta'), findsNothing);
      expect(find.textContaining('**'), findsNothing);
    });
  });
}
