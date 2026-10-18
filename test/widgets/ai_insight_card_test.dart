import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/ui/widgets/ai_insight_card.dart';

void main() {
  group('AiInsightCard Tests', () {
    testWidgets('displays welcome prompt when expenses are empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: [],
              presupuestoGeneral: 0.0,
              totalesPorCategoria: {},
              totalGastadoMes: 0.0,
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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tu meta de ahorro'), findsOneWidget);
      expect(find.textContaining('comprometida'), findsOneWidget);
    });

    testWidgets('displays pace and protected savings goal when healthy with savings goal', (tester) async {
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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('protegida'), findsOneWidget);
      expect(find.textContaining('/día'), findsOneWidget);
    });
  });
}
