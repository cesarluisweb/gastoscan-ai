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
      // Paridad 1:1 con USDT inmutable frente a spread cambiario
      expect(CurrencyFormatter.convertFromUsd(19.99, 'USDT', 40.0, tasaUsdt: 45.0), 19.99);
    });

    test('formatAmount and formatPreferido support EUR and USDT', () {
      expect(CurrencyFormatter.formatAmount(25.5, 'EUR'), contains('€'));
      expect(CurrencyFormatter.formatAmount(50.0, 'USDT'), contains('USDT'));
      expect(CurrencyFormatter.formatEur(15.0), contains('€'));
      expect(CurrencyFormatter.formatUsdt(100.0), contains('USDT'));

      final eurFormatted = CurrencyFormatter.formatPreferido(10.0, 400.0, 40.0, 'EUR', tasaEur: 44.0);
      expect(eurFormatted, contains('€'));

      // Pagado en divisa (USD): 19.99 USD se mantiene 19.99 USDT en formatPreferido (paridad 1:1)
      final usdtDivisa = CurrencyFormatter.formatPreferido(
        19.99,
        800.0,
        40.0,
        'USDT',
        tasaUsdt: 45.0,
        monedaOrigen: 'USD',
      );
      expect(usdtDivisa, contains('19,99'));
      expect(usdtDivisa, contains('USDT'));

      // Pagado en bolívares (VES): 800 Bs a tasa BCV 40 = 20 USD, pero a tasa P2P 50 = 16 USDT
      final usdtBs = CurrencyFormatter.formatPreferido(
        20.0,
        800.0,
        40.0,
        'USDT',
        tasaUsdt: 50.0,
        monedaOrigen: 'VES',
      );
      expect(usdtBs, contains('16,00'));
      expect(usdtBs, contains('USDT'));

      // Con totalUsdt precalculado (inmutabilidad SQLite v17)
      final usdtPrecalculado = CurrencyFormatter.formatPreferido(
        20.0,
        800.0,
        40.0,
        'USDT',
        totalUsdt: 15.50,
      );
      expect(usdtPrecalculado, contains('15,50'));
      expect(usdtPrecalculado, contains('USDT'));
    });

    test('convertAmount correctly converts EUR and USDT to USD', () {
      final eurToUsd = CurrencyFormatter.convertAmount(
        100.0,
        'EUR',
        'USD',
        40.0,
        tasaEur: 44.0,
      );
      expect(eurToUsd, 110.0);

      // Paridad 1:1 directa entre USDT y USD
      final usdtToUsd = CurrencyFormatter.convertAmount(
        19.99,
        'USDT',
        'USD',
        40.0,
        tasaUsdt: 45.0,
      );
      expect(usdtToUsd, 19.99);

      final usdToUsdt = CurrencyFormatter.convertAmount(
        19.99,
        'USD',
        'USDT',
        40.0,
        tasaUsdt: 45.0,
      );
      expect(usdToUsdt, 19.99);
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

    testWidgets('renders USDT and brecha capturada badge when monedaPrincipal is USDT', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 25.0,
              totalVes: 1000.0,
              totalUsdt: 20.0,
              periodo: 'Septiembre 2026',
              monedaPrincipal: 'USDT',
              tasaCambio: 40.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.formatUsdt(20.0)), findsOneWidget);
      expect(find.text('Brecha capturada: +$5.00 vs BCV'), findsOneWidget);
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

    testWidgets('displays EUR as primary with converted amount when monedaPrincipal is EUR', (tester) async {
      // 20 USD * 40 VES/USD = 800 VES. 800 VES / 50 VES/EUR = 16.0 EUR
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              gasto: gasto,
              monedaPrincipal: 'EUR',
              tasaCambio: 40.0,
              tasaEur: 50.0,
              onDelete: () {},
              onEdit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.formatEur(16.0)), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatVes(800.0)), findsOneWidget);
    });

    testWidgets('displays USDT as primary with 1:1 parity when monedaPrincipal is USDT', (tester) async {
      // 20 USD se mantiene 20.00 USDT en paridad 1:1 sin distorsión por tasa P2P
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              gasto: gasto,
              monedaPrincipal: 'USDT',
              tasaCambio: 40.0,
              tasaUsdt: 45.0, // Spread de mercado no altera la cantidad en USDT
              onDelete: () {},
              onEdit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.formatUsdt(20.0)), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatVes(800.0)), findsOneWidget);
    });

    testWidgets('displays USDT as primary with P2P rate when gasto is in VES', (tester) async {
      final gastoVes = GastoModel(
        id: 2,
        uuid: 'uuid-2',
        fecha: '2026-09-20',
        comercio: 'Bomba Gasolina',
        moneda: 'VES',
        totalOriginal: 80000, // Bs. 800.00
        totalUsd: 2000,       // $20.00 a tasa BCV 40
        totalUsdt: 1600,      // 16.00 USDT a tasa P2P 50
        tasaCambio: 40.0,
        tasaUsdt: 50.0,
        categoria: 'Transporte',
        creadoEn: '2026-09-20T10:00:00',
        items: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              gasto: gastoVes,
              monedaPrincipal: 'USDT',
              tasaCambio: 40.0,
              tasaUsdt: 50.0,
              onDelete: () {},
              onEdit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.formatUsdt(16.0)), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatVes(800.0)), findsOneWidget);
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

      expect(
        find.text('${CurrencyFormatter.formatVes(800.0)} / ${CurrencyFormatter.formatVes(2000.0)}'),
        findsOneWidget,
      );
    });

    testWidgets('renders EUR symbol and converted amounts when monedaPrincipal is EUR', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryChart(
                categoryTotals: const {'Alimentación': 20.0},
                categoryBudgets: const {'Alimentación': 50.0},
                presupuestoGeneral: 200.0,
                totalGastadoMes: 20.0,
                monedaPrincipal: 'EUR',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('${CurrencyFormatter.formatEur(20.0)} / ${CurrencyFormatter.formatEur(50.0)}'),
        findsOneWidget,
      );
      expect(find.text(CurrencyFormatter.formatEur(20.0)), findsWidgets);
    });

    testWidgets('renders USDT symbol and amounts when monedaPrincipal is USDT', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryChart(
                categoryTotals: const {'Alimentación': 25.0},
                categoryBudgets: const {'Alimentación': 60.0},
                presupuestoGeneral: 300.0,
                totalGastadoMes: 25.0,
                monedaPrincipal: 'USDT',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('${CurrencyFormatter.formatUsdt(25.0)} / ${CurrencyFormatter.formatUsdt(60.0)}'),
        findsOneWidget,
      );
    });
  });
}
