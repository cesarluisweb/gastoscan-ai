import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/currency_calculator_screen.dart';
import 'package:gastoscan_ai/ui/screens/review_expense_screen.dart';

class FakeSettingsProvider extends SettingsProvider {
  @override
  double get tasaCambioVesUsd => 45.0;

  @override
  double get tasaCambioVesEur => 49.0;

  @override
  double get tasaCambioVesUsdt => 52.0;

  @override
  String get monedaPrincipal => 'USD';

  @override
  Future<void> loadSettings() async {}
}

void main() {
  late FakeSettingsProvider settingsProvider;

  setUp(() {
    settingsProvider = FakeSettingsProvider();
  });

  Widget createWidgetUnderTest() {
    return ChangeNotifierProvider<SettingsProvider>.value(
      value: settingsProvider,
      child: const MaterialApp(
        home: CurrencyCalculatorScreen(showBackButton: true),
      ),
    );
  }

  group('CurrencyCalculatorScreen Tests', () {
    testWidgets('renders all initial fields, chips and comparison rows', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Calculadora Cambiaria'), findsOneWidget);
      expect(find.byKey(const Key('calc_divisa_input')), findsOneWidget);
      expect(find.byKey(const Key('calc_ves_input')), findsOneWidget);
      expect(find.byKey(const Key('calc_chip_dolar_bcv')), findsOneWidget);
      expect(find.byKey(const Key('calc_chip_euro_bcv')), findsOneWidget);
      expect(find.byKey(const Key('calc_chip_usdt')), findsOneWidget);
      expect(find.byKey(const Key('calc_chip_custom')), findsOneWidget);

      expect(find.byKey(const Key('calc_copy_ves_button')), findsOneWidget);
      expect(find.byKey(const Key('calc_register_expense_button')), findsOneWidget);

      // Initial calculation: 1.00 USD at 45.0 = Bs. 45.00
      final vesField = tester.widget<TextField>(find.byKey(const Key('calc_ves_input')));
      expect(vesField.controller?.text, '45.00');
    });

    testWidgets('typing in divisa field updates bolivares field in real time', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter 10 in divisa
      await tester.enterText(find.byKey(const Key('calc_divisa_input')), '10');
      await tester.pumpAndSettle();

      final vesField = tester.widget<TextField>(find.byKey(const Key('calc_ves_input')));
      expect(vesField.controller?.text, '450.00');
    });

    testWidgets('typing in ves field updates divisa field in real time', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter 90 in VES field (90 / 45 = 2)
      await tester.enterText(find.byKey(const Key('calc_ves_input')), '90');
      await tester.pumpAndSettle();

      final divisaField = tester.widget<TextField>(find.byKey(const Key('calc_divisa_input')));
      expect(divisaField.controller?.text, '2.00');
    });

    testWidgets('selecting Euro BCV chip recalculates with EUR rate', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Set 10 in divisa
      await tester.enterText(find.byKey(const Key('calc_divisa_input')), '10');
      await tester.pumpAndSettle();

      // Tap Euro chip (rate = 49.0)
      await tester.tap(find.byKey(const Key('calc_chip_euro_bcv')));
      await tester.pumpAndSettle();

      final vesField = tester.widget<TextField>(find.byKey(const Key('calc_ves_input')));
      expect(vesField.controller?.text, '490.00');
    });

    testWidgets('selecting custom rate chip allows entering custom rate', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter 10 in divisa
      await tester.enterText(find.byKey(const Key('calc_divisa_input')), '10');
      await tester.pumpAndSettle();

      // Tap Custom rate chip
      await tester.tap(find.byKey(const Key('calc_chip_custom')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calc_custom_rate_input')), findsOneWidget);

      // Enter custom rate: 50.0
      await tester.enterText(find.byKey(const Key('calc_custom_rate_input')), '50');
      await tester.pumpAndSettle();

      final vesField = tester.widget<TextField>(find.byKey(const Key('calc_ves_input')));
      expect(vesField.controller?.text, '500.00');
    });

    testWidgets('tapping copiar Bs. button copies amount to clipboard and shows snackbar', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('calc_ves_input')), '150');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calc_copy_ves_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Monto en Bs. copiado:'), findsOneWidget);
    });

    testWidgets('tapping registrar gasto navigates to ReviewExpenseScreen pre-filled', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Set 100 in VES
      await tester.enterText(find.byKey(const Key('calc_ves_input')), '100');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calc_register_expense_button')));
      await tester.pumpAndSettle();

      // Navigated to ReviewExpenseScreen
      expect(find.byType(ReviewExpenseScreen), findsOneWidget);
      expect(find.text('Revisar Gasto'), findsOneWidget);
    });
  });
}
