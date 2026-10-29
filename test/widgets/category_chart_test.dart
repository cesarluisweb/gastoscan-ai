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

    testWidgets('sin presupuesto muestra botón sutil Asignar presupuesto sin subrayado', (tester) async {
      await pumpChart(
        tester,
        const CategoryChart(
          categoryTotals: {'Educación': 1500.0},
          monedaPrincipal: 'VES',
        ),
      );

      final promptFinder = find.byKey(const Key('assign_budget_prompt_Educación'));
      expect(promptFinder, findsOneWidget);
      expect(find.text('Asignar presupuesto'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.descendant(
        of: promptFinder,
        matching: find.text('Asignar presupuesto'),
      ));
      expect(textWidget.style?.decoration, isNot(TextDecoration.underline));
    });

    testWidgets('con presupuesto el nombre de la categoría tiene maxLines 1 y botón editar existe', (tester) async {
      await pumpChart(
        tester,
        const CategoryChart(
          categoryTotals: {'Alimentación': 136388.0},
          categoryBudgets: {'Alimentación': 177778.18},
          presupuestoGeneral: 500000.0,
          totalGastadoMes: 136388.0,
          monedaPrincipal: 'VES',
        ),
      );

      final nameFinder = find.text('Alimentación');
      expect(nameFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(nameFinder);
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);

      expect(find.byKey(const Key('edit_budget_Alimentación')), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.textContaining('consumido'), findsOneWidget);
    });
  });

  group('CategoryChart UX-06 Grouping Tests', () {
    testWidgets('consolidates categories after top 4 with +X categorias in Dashboard view', (tester) async {
      await pumpChart(
        tester,
        const CategoryChart(
          categoryTotals: {
            'Alimentación': 100.0,
            'Transporte': 80.0,
            'Servicios': 60.0,
            'Salud': 40.0,
            'Higiene': 20.0,
            'Hogar': 10.0,
          },
          showBudgetBars: false,
          monedaPrincipal: 'USD',
        ),
      );

      // Top 4 categories are visible
      expect(find.text('Alimentación'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('Servicios'), findsOneWidget);
      expect(find.text('Salud'), findsOneWidget);

      // The remaining 2 categories are consolidated as '+2 categorías'
      expect(find.text('+2 categorías'), findsOneWidget);
      // Individual remaining categories are not in the list
      expect(find.text('Higiene'), findsNothing);
      expect(find.text('Hogar'), findsNothing);
    });
  });
}
