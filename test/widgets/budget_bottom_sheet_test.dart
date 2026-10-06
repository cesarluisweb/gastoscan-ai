import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/widgets/budget_bottom_sheet.dart';

class TestGastoProvider extends GastoProvider {
  double _general = 100.0;
  double _meta = 20.0;
  String _moneda = 'USD';
  final Map<String, double> _cats = {'Alimentación': 50.0};

  @override
  double get presupuestoGeneral => _general;

  @override
  double get metaAhorro => _meta;

  @override
  String get monedaPresupuesto => _moneda;

  @override
  double getPresupuestoCategoria(String categoria) => _cats[categoria] ?? 0.0;

  @override
  Future<bool> guardarTodoElPresupuesto(
    double general,
    Map<String, double> categorias, {
    String moneda = 'USD',
    double metaAhorro = 0.0,
  }) async {
    _general = general;
    _cats.clear();
    _cats.addAll(categorias);
    _moneda = moneda;
    _meta = metaAhorro;
    notifyListeners();
    return true;
  }
}

class TestSettingsProvider extends SettingsProvider {
  @override
  double get tasaCambioVesUsd => 40.0;

  @override
  double get tasaCambioVesEur => 44.0;

  @override
  double get tasaCambioVesUsdt => 40.0;
}

void main() {
  testWidgets('BudgetBottomSheet renders all 4 currency buttons and converts values', (tester) async {
    final gastoProvider = TestGastoProvider();
    final settingsProvider = TestSettingsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: BudgetBottomSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 4 currency toggle buttons exist
    expect(find.byKey(const Key('budget_currency_usd_btn')), findsOneWidget);
    expect(find.byKey(const Key('budget_currency_ves_btn')), findsOneWidget);
    expect(find.byKey(const Key('budget_currency_eur_btn')), findsOneWidget);
    expect(find.byKey(const Key('budget_currency_usdt_btn')), findsOneWidget);

    // Initial value in USD is 100
    expect(find.text('100'), findsOneWidget);

    // Switch to VES (100 * 40 = 4000)
    await tester.tap(find.byKey(const Key('budget_currency_ves_btn')));
    await tester.pumpAndSettle();

    expect(find.text('4000'), findsOneWidget);

    // Switch to EUR (4000 / 44 = ~90.91)
    await tester.tap(find.byKey(const Key('budget_currency_eur_btn')));
    await tester.pumpAndSettle();

    expect(find.text('90.91'), findsOneWidget);

    // Switch to USDT (4000 / 40 = 100)
    await tester.tap(find.byKey(const Key('budget_currency_usdt_btn')));
    await tester.pumpAndSettle();

    expect(find.text('100'), findsOneWidget);
  });
}
