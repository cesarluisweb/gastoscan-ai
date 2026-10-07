import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/utils/currency_formatter.dart';
import 'package:gastoscan_ai/ui/widgets/category_chart.dart';

void main() {
  Future<void> pumpChart(WidgetTester tester, CategoryChart chart) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: chart),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CategoryChart moneda del presupuesto', () {
    testWidgets('gastado y presupuesto en la misma moneda (VES)', (tester) async {
      await pumpChart(
        tester,
        const CategoryChart(
          categoryTotals: {'Comida': 1500.0},
          categoryBudgets: {'Comida': 5000.0},
          presupuestoGeneral: 10000.0,
          totalGastadoMes: 1500.0,
          monedaPrincipal: 'VES',
        ),
      );

      expect(
        find.text(
          '${CurrencyFormatter.formatVes(1500.0)} / ${CurrencyFormatter.formatVes(5000.0)}',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('category_budget_item_Comida')), findsOneWidget);
    });

    testWidgets('sin presupuesto no muestra ratio gastado/presupuesto', (tester) async {
      await pumpChart(
        tester,
        const CategoryChart(
          categoryTotals: {'Comida': 1500.0},
          monedaPrincipal: 'VES',
        ),
      );

      expect(find.byKey(const Key('category_budget_item_Comida')), findsOneWidget);
      expect(find.textContaining(' / '), findsNothing);
    });

    testWidgets('presupuesto USD se muestra sin conversión artificial', (tester) async {
      await pumpChart(
        tester,
        const CategoryChart(
          categoryTotals: {'Comida': 12.5},
          categoryBudgets: {'Comida': 100.0},
          presupuestoGeneral: 500.0,
          totalGastadoMes: 12.5,
          monedaPrincipal: 'USD',
        ),
      );

      expect(
        find.text(
          '${CurrencyFormatter.formatUsd(12.5)} / ${CurrencyFormatter.formatUsd(100.0)}',
        ),
        findsOneWidget,
      );
    });
  });
}
