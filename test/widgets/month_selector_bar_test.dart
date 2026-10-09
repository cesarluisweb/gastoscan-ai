import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/ui/widgets/month_selector_bar.dart';

class FakeGastoProvider extends GastoProvider {
  int _mes;
  int _anio;

  FakeGastoProvider({int mes = 10, int anio = 2026})
      : _mes = mes,
        _anio = anio;

  @override
  int get selectedMonth => _mes;

  @override
  int get selectedYear => _anio;

  @override
  void cambiarMes(int year, int month) {
    _anio = year;
    _mes = month;
    notifyListeners();
  }

  @override
  Future<void> cargarDatos() async {}
}

void main() {
  group('MonthSelectorBar Widget Tests', () {
    late FakeGastoProvider gastoProvider;

    setUp(() {
      gastoProvider = FakeGastoProvider(mes: 10, anio: 2026);
    });

    Widget createWidgetUnderTest({String? keyPrefix, void Function(int, int)? onMonthChanged}) {
      return ChangeNotifierProvider<GastoProvider>.value(
        value: gastoProvider,
        child: MaterialApp(
          home: Scaffold(
            body: MonthSelectorBar(
              keyPrefix: keyPrefix,
              onMonthChanged: onMonthChanged,
            ),
          ),
        ),
      );
    }

    testWidgets('renders month and year in pill format with calendar and arrow icons', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Octubre 2026'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tapping chevron left navigates to previous month and decrements year when month is January', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Octubre -> Septiembre
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(gastoProvider.selectedMonth, 9);
      expect(gastoProvider.selectedYear, 2026);
      expect(find.text('Septiembre 2026'), findsOneWidget);

      // Now set to January 2026
      gastoProvider.cambiarMes(2026, 1);
      await tester.pumpAndSettle();
      expect(find.text('Enero 2026'), findsOneWidget);

      // Enero -> Diciembre of previous year
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(gastoProvider.selectedMonth, 12);
      expect(gastoProvider.selectedYear, 2025);
      expect(find.text('Diciembre 2025'), findsOneWidget);
    });

    testWidgets('tapping chevron right navigates to next month and increments year when month is December', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Octubre -> Noviembre
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();

      expect(gastoProvider.selectedMonth, 11);
      expect(gastoProvider.selectedYear, 2026);
      expect(find.text('Noviembre 2026'), findsOneWidget);

      // Set to December 2026
      gastoProvider.cambiarMes(2026, 12);
      await tester.pumpAndSettle();
      expect(find.text('Diciembre 2026'), findsOneWidget);

      // Diciembre -> Enero of next year
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();

      expect(gastoProvider.selectedMonth, 1);
      expect(gastoProvider.selectedYear, 2027);
      expect(find.text('Enero 2027'), findsOneWidget);
    });

    testWidgets('tapping pill opens 12-month dialog and selecting month updates provider and closes dialog', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap pill
      await tester.tap(find.byKey(const Key('month_selector_title')));
      await tester.pumpAndSettle();

      // Dialog is open with 12 months and current year
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Ene'), findsOneWidget);
      expect(find.text('Feb'), findsOneWidget);
      expect(find.text('Mar'), findsOneWidget);
      expect(find.text('Abr'), findsOneWidget);
      expect(find.text('May'), findsOneWidget);
      expect(find.text('Jun'), findsOneWidget);
      expect(find.text('Jul'), findsOneWidget);
      expect(find.text('Ago'), findsOneWidget);
      expect(find.text('Sep'), findsOneWidget);
      expect(find.text('Oct'), findsOneWidget);
      expect(find.text('Nov'), findsOneWidget);
      expect(find.text('Dic'), findsOneWidget);

      // Tap Mayo (month 5)
      await tester.tap(find.byKey(const Key('month_pick_5')));
      await tester.pumpAndSettle();

      // Dialog closes and provider is updated
      expect(gastoProvider.selectedMonth, 5);
      expect(gastoProvider.selectedYear, 2026);
      expect(find.text('Mayo 2026'), findsOneWidget);
    });

    testWidgets('respects keyPrefix for title and dialog picks', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(keyPrefix: 'analysis_'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('analysis_month_selector_title')), findsOneWidget);

      await tester.tap(find.byKey(const Key('analysis_month_selector_title')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('analysis_month_pick_3')), findsOneWidget);

      await tester.tap(find.byKey(const Key('analysis_month_pick_3')));
      await tester.pumpAndSettle();

      expect(gastoProvider.selectedMonth, 3);
      expect(find.text('Marzo 2026'), findsOneWidget);
    });

    testWidgets('supports custom onMonthChanged callback without relying solely on default provider', (tester) async {
      int? changedYear;
      int? changedMonth;

      await tester.pumpWidget(createWidgetUnderTest(
        onMonthChanged: (y, m) {
          changedYear = y;
          changedMonth = m;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(changedYear, 2026);
      expect(changedMonth, 9);
    });
  });
}
