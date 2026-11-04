import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/ui/widgets/app_bar_month_selector.dart';

class FakeGastoProvider extends GastoProvider {
  int _mes;
  int _anio;

  FakeGastoProvider({int mes = 11, int anio = 2026})
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

Widget createWidgetUnderTest({
  required double maxWidth,
  String? keyPrefix,
  int? selectedMonth,
  int? selectedYear,
  void Function(int year, int month)? onMonthChanged,
  FakeGastoProvider? provider,
}) {
  final p = provider ?? FakeGastoProvider(mes: selectedMonth ?? 11, anio: selectedYear ?? 2026);
  return ChangeNotifierProvider<GastoProvider>.value(
    value: p,
    child: MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: AppBarMonthSelector(
            keyPrefix: keyPrefix,
            maxWidth: maxWidth,
            selectedMonth: selectedMonth,
            selectedYear: selectedYear,
            onMonthChanged: onMonthChanged,
          ),
        ),
      ),
    ),
  );
}

Widget createRealLayoutHarness({
  required FakeGastoProvider provider,
  TextScaler? textScaler,
  double titleFontSize = 10,
}) {
  return ChangeNotifierProvider<GastoProvider>.value(
    value: provider,
    child: MaterialApp(
      home: MediaQuery(
        data: textScaler != null
            ? const MediaQueryData().copyWith(textScaler: textScaler)
            : const MediaQueryData(),
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Rinde Más',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.centerRight,
                      child: AppBarMonthSelector(
                        maxWidth: constraints.maxWidth,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                key: const Key('dashboard_search_button'),
                icon: const Icon(Icons.search, size: 22),
                tooltip: 'Buscar',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: () {},
              ),
              IconButton(
                key: const Key('dashboard_ai_chat_button'),
                icon: const Icon(Icons.auto_awesome, size: 22),
                tooltip: 'Asistente IA',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: () {},
              ),
            ],
          ),
          body: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

void main() {
  group('AppBarMonthSelector Tests', () {
    testWidgets('a) maxWidth 300 -> se ve "Noviembre 2026" completo y las 2 flechas', (tester) async {
      final provider = FakeGastoProvider(mes: 11, anio: 2026);
      await tester.pumpWidget(createWidgetUnderTest(maxWidth: 300, provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('Noviembre 2026'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('b) maxWidth 160 -> se ve "Nov 2026" y las 2 flechas', (tester) async {
      final provider = FakeGastoProvider(mes: 11, anio: 2026);
      await tester.pumpWidget(createWidgetUnderTest(maxWidth: 160, provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('Nov 2026'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('c) maxWidth 120 -> solo la píldora, sin flechas; al tocarla se abre el diálogo', (tester) async {
      final provider = FakeGastoProvider(mes: 11, anio: 2026);
      await tester.pumpWidget(createWidgetUnderTest(maxWidth: 120, provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('Nov 2026'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await tester.tap(find.byKey(const Key('month_selector_title')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('month_pick_5')), findsOneWidget);
    });

    testWidgets('d) maxWidth 60 -> devuelve SizedBox.shrink(), sin excepciones', (tester) async {
      final provider = FakeGastoProvider(mes: 11, anio: 2026);
      await tester.pumpWidget(createWidgetUnderTest(maxWidth: 60, provider: provider));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('month_selector_title')), findsNothing);
      expect(find.text('Nov 2026'), findsNothing);
      expect(find.text('Noviembre 2026'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('e1) Harness de layout real bombeado a 360x640 -> sin overflow y píldora tocable', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = FakeGastoProvider(mes: 11, anio: 2026);
      await tester.pumpWidget(createRealLayoutHarness(provider: provider));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final pillFinder = find.byKey(const Key('month_selector_title'));
      expect(pillFinder, findsOneWidget);

      await tester.tap(pillFinder);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('month_pick_11')), findsOneWidget);
    });

    testWidgets('e2) Harness de layout real bombeado a 320x568 -> sin overflow y píldora tocable', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = FakeGastoProvider(mes: 11, anio: 2026);
      await tester.pumpWidget(createRealLayoutHarness(provider: provider));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final pillFinder = find.byKey(const Key('month_selector_title'));
      expect(pillFinder, findsOneWidget);

      await tester.tap(pillFinder);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('month_pick_11')), findsOneWidget);
    });

    testWidgets('f) Mismo harness a maxWidth 160 con MediaQuery textScaler 1.3 -> sin overflow y píldora tocable', (tester) async {
      final provider = FakeGastoProvider(mes: 11, anio: 2026);
      await tester.pumpWidget(
        ChangeNotifierProvider<GastoProvider>.value(
          value: provider,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: Row(
                    children: [
                      const Text(
                        'Rinde Más',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) => Align(
                            alignment: Alignment.centerRight,
                            child: AppBarMonthSelector(
                              maxWidth: 160,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search, size: 22),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.auto_awesome, size: 22),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      final pillFinder = find.byKey(const Key('month_selector_title'));
      expect(pillFinder, findsOneWidget);

      await tester.tap(pillFinder);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('month_pick_11')), findsOneWidget);
    });

    testWidgets('g) Tap en flecha izquierda/derecha llama a cambiarMes con el mes esperado', (tester) async {
      final provider = FakeGastoProvider(mes: 10, anio: 2026);
      await tester.pumpWidget(createWidgetUnderTest(maxWidth: 300, provider: provider));
      await tester.pumpAndSettle();

      // Octubre -> Septiembre
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(provider.selectedMonth, 9);
      expect(provider.selectedYear, 2026);
      expect(find.text('Septiembre 2026'), findsOneWidget);

      // Septiembre -> Octubre
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();

      expect(provider.selectedMonth, 10);
      expect(provider.selectedYear, 2026);
      expect(find.text('Octubre 2026'), findsOneWidget);

      // Flecha izquierda en Enero 2023 (fecha mínima) queda deshabilitada
      provider.cambiarMes(AppConstants.fechaMinimaHistoricoTasas.year, 1);
      await tester.pumpAndSettle();
      expect(find.text('Enero 2023'), findsOneWidget);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      expect(provider.selectedMonth, 1);
      expect(provider.selectedYear, AppConstants.fechaMinimaHistoricoTasas.year);
    });

    testWidgets('respects keyPrefix for each tab and opens dialog with correct keys', (tester) async {
      final provider = FakeGastoProvider(mes: 11, anio: 2026);
      await tester.pumpWidget(createWidgetUnderTest(
        maxWidth: 300,
        keyPrefix: 'expense_history_',
        provider: provider,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expense_history_month_selector_title')), findsOneWidget);

      await tester.tap(find.byKey(const Key('expense_history_month_selector_title')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expense_history_month_pick_3')), findsOneWidget);
      await tester.tap(find.byKey(const Key('expense_history_month_pick_3')));
      await tester.pumpAndSettle();

      expect(provider.selectedMonth, 3);
    });

    testWidgets('supports custom onMonthChanged callback', (tester) async {
      int? changedYear;
      int? changedMonth;

      await tester.pumpWidget(createWidgetUnderTest(
        maxWidth: 300,
        onMonthChanged: (y, m) {
          changedYear = y;
          changedMonth = m;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(changedYear, 2026);
      expect(changedMonth, 10);
    });

    testWidgets('criterion 4: selector is not in AppBar while searching in Gastos', (tester) async {
      Widget buildAppBar({required bool isSearching}) {
        return MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: isSearching
                  ? const TextField(key: Key('expense_history_search_field'))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('Gastos'),
                        const SizedBox(width: 6),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) => Align(
                              alignment: Alignment.centerRight,
                              child: AppBarMonthSelector(
                                keyPrefix: 'expense_history_',
                                maxWidth: constraints.maxWidth,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      }

      final provider = FakeGastoProvider(mes: 11, anio: 2026);
      await tester.pumpWidget(
        ChangeNotifierProvider<GastoProvider>.value(
          value: provider,
          child: buildAppBar(isSearching: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expense_history_search_field')), findsOneWidget);
      expect(find.byKey(const Key('expense_history_month_selector_title')), findsNothing);

      await tester.pumpWidget(
        ChangeNotifierProvider<GastoProvider>.value(
          value: provider,
          child: buildAppBar(isSearching: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expense_history_search_field')), findsNothing);
      expect(find.byKey(const Key('expense_history_month_selector_title')), findsOneWidget);
    });
  });
}
