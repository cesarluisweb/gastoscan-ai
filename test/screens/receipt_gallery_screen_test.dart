import 'dart:io';
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
  int eliminarFotoLlamadas = 0;
  int eliminarFotosLoteLlamadas = 0;

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

  @override
  Future<bool> eliminarFotoComprobante(GastoModel gasto) async {
    eliminarFotoLlamadas++;
    return true;
  }

  @override
  Future<int> eliminarFotosComprobantes(List<GastoModel> gastos) async {
    eliminarFotosLoteLlamadas += gastos.length;
    return gastos.length;
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

    testWidgets('enters selection mode, selects multiple receipts and confirms deletion', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('gallery_test_');
      final file1 = File('${tempDir.path}/rec1.jpg')..writeAsBytesSync([1, 2, 3]);
      final file2 = File('${tempDir.path}/rec2.jpg')..writeAsBytesSync([1, 2, 3]);

      final mockGastos = [
        GastoModel(
          id: 101,
          uuid: 'uuid-1',
          fecha: '2026-10-15',
          comercio: 'Supermercado Día a Día',
          moneda: 'USD',
          totalOriginal: 3500,
          totalUsd: 3500,
          tasaCambio: 1.0,
          categoria: 'Alimentación',
          rutaFotoLocal: file1.path,
          items: [],
        ),
        GastoModel(
          id: 102,
          uuid: 'uuid-2',
          fecha: '2026-10-16',
          comercio: 'Locatel',
          moneda: 'USD',
          totalOriginal: 1200,
          totalUsd: 1200,
          tasaCambio: 1.0,
          categoria: 'Salud',
          rutaFotoLocal: file2.path,
          items: [],
        ),
      ];

      gastoProvider = FakeGastoProvider(initialGastos: mockGastos);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('2 comprobantes guardados'), findsOneWidget);
      expect(find.byKey(const Key('btn_seleccionar_comprobantes')), findsOneWidget);

      // Enter selection mode via button
      await tester.tap(find.byKey(const Key('btn_seleccionar_comprobantes')));
      await tester.pumpAndSettle();

      expect(find.text('Selecciona comprobantes'), findsOneWidget);

      // Tap first receipt card to select
      await tester.tap(find.text('Supermercado Día a Día'));
      await tester.pumpAndSettle();

      expect(find.text('1 seleccionado'), findsOneWidget);
      expect(find.byKey(const Key('btn_eliminar_seleccionados_bottom')), findsOneWidget);

      // Select all via toggle button
      await tester.tap(find.byKey(const Key('btn_toggle_seleccionar_todos')));
      await tester.pumpAndSettle();

      expect(find.text('2 seleccionados'), findsOneWidget);

      // Tap delete bottom button
      await tester.tap(find.byKey(const Key('btn_eliminar_seleccionados_bottom')));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('¿Eliminar 2 fotos?'), findsOneWidget);
      expect(
        find.textContaining('Los registros de compras, montos y categorías se conservarán intactos'),
        findsOneWidget,
      );

      // Confirm deletion
      await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar 2 fotos'));
      await tester.pumpAndSettle();

      expect(gastoProvider.eliminarFotosLoteLlamadas, equals(2));

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}
