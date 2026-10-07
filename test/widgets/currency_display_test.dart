import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/utils/currency_formatter.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/ui/widgets/summary_card.dart';
import 'package:gastoscan_ai/ui/widgets/expense_card.dart';
import 'package:gastoscan_ai/ui/widgets/category_chart.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('formatPreferido returns VES when preferred is VES', () {
      final formatted = CurrencyFormatter.formatPreferido(10.0, 400.0, 40.0, 'VES');
      expect(formatted, contains('Bs.'));
      expect(formatted, contains('400'));
    });

    test('formatPreferido calculates VES using tasaCambio when totalVes is zero/null', () {
      final formatted = CurrencyFormatter.formatPreferido(10.0, null, 40.0, 'VES');
      expect(formatted, contains('Bs.'));
      expect(formatted, contains('400'));
    });

    test('formatPreferido returns USD when preferred is USD', () {
      final formatted = CurrencyFormatter.formatPreferido(10.0, 400.0, 40.0, 'USD');
      expect(formatted, contains('\$'));
      expect(formatted, contains('10'));
    });

    test('formatSecundario returns opposite currency', () {
      final secondaryForVes = CurrencyFormatter.formatSecundario(10.0, 400.0, 40.0, 'VES');
      expect(secondaryForVes, contains('\$'));
      expect(secondaryForVes, contains('10'));

      final secondaryForUsd = CurrencyFormatter.formatSecundario(10.0, 400.0, 40.0, 'USD');
      expect(secondaryForUsd, contains('Bs.'));
      expect(secondaryForUsd, contains('400'));
    });

    test('convertFromUsd converts properly', () {
      expect(CurrencyFormatter.convertFromUsd(10.0, 'VES', 50.0), 500.0);
      expect(CurrencyFormatter.convertFromUsd(10.0, 'USD', 50.0), 10.0);
      expect(CurrencyFormatter.convertFromUsd(10.0, 'EUR', 40.0, tasaEur: 44.0), closeTo(9.09, 0.01));
      expect(CurrencyFormatter.convertFromUsd(10.0, 'USDT', 40.0, tasaUsdt: 40.0), 10.0);
    });

    test('formatAmount and formatPreferido support EUR and USDT', () {
      expect(CurrencyFormatter.formatAmount(25.5, 'EUR'), contains('€'));
      expect(CurrencyFormatter.formatAmount(50.0, 'USDT'), contains('USDT'));
      expect(CurrencyFormatter.formatEur(15.0), contains('€'));
      expect(CurrencyFormatter.formatUsdt(100.0), contains('USDT'));

      final eurFormatted = CurrencyFormatter.formatPreferido(10.0, 400.0, 40.0, 'EUR', tasaEur: 44.0);
      expect(eurFormatted, contains('€'));

      final usdtFormatted = CurrencyFormatter.formatPreferido(10.0, 400.0, 40.0, 'USDT', tasaUsdt: 40.0);
      expect(usdtFormatted, contains('USDT'));
    });
  });

  group('SummaryCard Currency Preference Tests', () {
    testWidgets('renders USD on top when monedaPrincipal is USD', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 25.0,
              totalVes: 1000.0,
              periodo: 'Septiembre 2026',
              monedaPrincipal: 'USD',
              tasaCambio: 40.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.formatUsd(25.0)), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatVes(1000.0)), findsOneWidget);
    });

    testWidgets('renders VES on top when monedaPrincipal is VES', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 25.0,
              totalVes: 1000.0,
              periodo: 'Septiembre 2026',
              monedaPrincipal: 'VES',
              tasaCambio: 40.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.formatVes(1000.0)), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatUsd(25.0)), findsOneWidget);
    });
  });

  group('ExpenseCard Currency Preference Tests', () {
    final gasto = GastoModel(
      id: 1,
      uuid: 'uuid-1',
      fecha: '2026-09-20',
      comercio: 'Automercado Plaza',
      moneda: 'USD',
      totalOriginal: 2000,
      totalUsd: 2000,
      tasaCambio: 40.0,
      categoria: 'Alimentación',
      creadoEn: '2026-09-20T10:00:00',
      items: [
        ItemGastoModel(
          id: 1,
          gastoId: 1,
          descripcion: 'Arroz',
          cantidad: 1.0,
          precioUnitario: 2000,
          total: 2000,
        ),
      ],
    );

    testWidgets('displays USD as primary when monedaPrincipal is USD', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              gasto: gasto,
              monedaPrincipal: 'USD',
              onDelete: () {},
              onEdit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.formatUsd(20.0)), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatVes(800.0)), findsOneWidget);
    });

    testWidgets('displays VES as primary when monedaPrincipal is VES', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              gasto: gasto,
              monedaPrincipal: 'VES',
              onDelete: () {},
              onEdit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.formatVes(800.0)), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatUsd(20.0)), findsOneWidget);
    });
  });

  group('CategoryChart Currency Preference Tests', () {
    testWidgets('renders category totals and budgets in the budget currency (VES)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryChart(
                categoryTotals: const {'Alimentación': 800.0},
                categoryBudgets: const {'Alimentación': 2000.0},
                presupuestoGeneral: 10000.0,
                totalGastadoMes: 800.0,
                monedaPrincipal: 'VES',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // La vista usa la moneda del presupuesto: totales y budgets llegan ya
      // convertidos por el llamador, el chart no aplica tasas.
      expect(
        find.text('${CurrencyFormatter.formatVes(800.0)} / ${CurrencyFormatter.formatVes(2000.0)}'),
        findsOneWidget,
      );
    });
  });
}
