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
      expect(find.textContaining('Empieza tocando el botón +'), findsOneWidget);
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

      expect(find.textContaining('Has superado tu presupuesto general'), findsOneWidget);
    });

    testWidgets('displays budget alert when spent is 85 percent or more', (tester) async {
      final gasto = GastoModel(
        id: 1,
        uuid: 'uuid-1',
        fecha: '2026-09-15',
        comercio: 'Mercado',
        moneda: 'USD',
        totalOriginal: 9000,
        totalUsd: 9000,
        categoria: 'Alimentación',
        creadoEn: '2026-09-15T10:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiInsightCard(
              gastos: [gasto],
              presupuestoGeneral: 100.0,
              totalesPorCategoria: const {'Alimentación': 90.0},
              totalGastadoMes: 90.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('llevas gastado el 90%'), findsOneWidget);
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

      expect(find.textContaining('Asigna un presupuesto mensual en la pestaña de Análisis'), findsOneWidget);
    });
  });
}
