import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/receipt_gallery_screen.dart';

class FakeGastoProvider extends GastoProvider {
  final List<GastoModel> _customGastos;
  int _mes;
  int _anio;

  FakeGastoProvider({
    List<GastoModel>? initialGastos,
    int mes = 10,
    int anio = 2026,
  })  : _customGastos = initialGastos ?? [],
        _mes = mes,
        _anio = anio;

  @override
  List<GastoModel> get gastos => _customGastos;

  @override
  int get selectedMonth => _mes;

  @override
  int get selectedYear => _anio;

  @override
  Future<void> cargarDatos() async {}

  @override
  void cambiarMes(int year, int month) {
    _anio = year;
    _mes = month;
    notifyListeners();
  }
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}

  @override
  String get monedaPrincipal => 'USD';
}

void main() {
  group('ReceiptGalleryScreen Widget Tests', () {
    late FakeGastoProvider gastoProvider;
    late FakeSettingsProvider settingsProvider;

    setUp(() {
      gastoProvider = FakeGastoProvider();
      settingsProvider = FakeSettingsProvider();
    });

    Widget createWidgetUnderTest({VoidCallback? onBack}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: MaterialApp(
          home: ReceiptGalleryScreen(
            showBackButton: true,
            onBack: onBack,
          ),
        ),
      );
    }

    testWidgets('displays empty state when there are no receipts with existing files', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Comprobantes Guardados'), findsOneWidget);
      expect(find.textContaining('No hay comprobantes en'), findsOneWidget);
      expect(find.textContaining('Las facturas escaneadas'), findsOneWidget);
    });

    testWidgets('month navigation buttons update selected month and year', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Octubre 2026'), findsOneWidget);

      // Tap next month
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Noviembre 2026'), findsOneWidget);

      // Tap previous month twice
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(find.text('Septiembre 2026'), findsOneWidget);
    });

    testWidgets('invokes onBack callback when back button is pressed', (tester) async {
      bool backPressed = false;
      await tester.pumpWidget(createWidgetUnderTest(onBack: () {
        backPressed = true;
      }));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(backPressed, isTrue);
    });
  });
}
