import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/datasources/remote/gemini_service.dart';
import 'package:gastoscan_ai/data/models/gemini_extraction_result.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/main_screen.dart';
import 'package:gastoscan_ai/ui/screens/review_expense_screen.dart';
import 'package:gastoscan_ai/ui/widgets/budget_bottom_sheet.dart';
import 'package:gastoscan_ai/ui/widgets/voice_expense_sheet.dart';

class FakeGeminiVoiceService extends GeminiService {
  @override
  Future<List<GeminiExtractionResult>> parseVoiceExpense(String spokenText) async {
    return [
      GeminiExtractionResult(
        comercio: 'Automercado',
        fecha: '2026-10-26',
        moneda: 'USD',
        totalOriginal: 25.0,
        tasaCambioDetectada: null,
        impuestoIva: 0.0,
        items: [],
      ),
    ];
  }
}

class FakeDatabaseHelper extends DatabaseHelper {
  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];
}

class FakeGastoProvider extends GastoProvider {
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
  Future<void> cargarDatos() async {}
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  double get tasaCambioVesUsd => 40.0;

  @override
  double get tasaCambioVesEur => 44.0;

  @override
  double get tasaCambioVesUsdt => 40.0;

  @override
  Future<void> loadSettings() async {}
}

void main() {
  group('Pruebas de Geometría Real y Anclaje de Bottom Sheets (Edge-to-Edge)', () {
    late FakeGeminiVoiceService fakeGemini;
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueue;
    late FakeGastoProvider fakeGasto;
    late FakeSettingsProvider fakeSettings;

    setUp(() {
      fakeGemini = FakeGeminiVoiceService();
      fakeDb = FakeDatabaseHelper();
      scanQueue = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      fakeGasto = FakeGastoProvider();
      fakeSettings = FakeSettingsProvider();
    });

    Widget wrapWithProviders(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueue),
          ChangeNotifierProvider<GastoProvider>.value(value: fakeGasto),
          ChangeNotifierProvider<SettingsProvider>.value(value: fakeSettings),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('VoiceExpenseSheet: anclada abajo y con scrim visible arriba', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapWithProviders(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('btn_open_voice'),
                onPressed: () => VoiceExpenseSheet.show(ctx, geminiService: fakeGemini),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_open_voice')));
      await tester.pumpAndSettle();

      final surface = find.byKey(const Key('sheet_surface_voice'));
      expect(surface, findsOneWidget);

      // Invariante 1: el contenido no ocupa el 100% de la pantalla (hay scrim visible arriba)
      expect(tester.getTopLeft(surface).dy, greaterThan(0));

      // Invariante 2: la superficie de la hoja está perfectamente anclada en el borde inferior
      expect(tester.getBottomLeft(surface).dy, moreOrLessEquals(640, epsilon: 1.0));
    });

    testWidgets('BudgetBottomSheet: anclada abajo, shrink-wrapped y con botón visible sobre la barra', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapWithProviders(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('btn_open_budget'),
                onPressed: () => BudgetBottomSheet.show(ctx),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_open_budget')));
      await tester.pumpAndSettle();

      final surface = find.byKey(const Key('sheet_surface_budget'));
      expect(surface, findsOneWidget);

      // Invariante: scrim visible arriba y anclaje al borde inferior
      expect(tester.getTopLeft(surface).dy, greaterThan(0));
      expect(tester.getBottomLeft(surface).dy, moreOrLessEquals(640, epsilon: 1.0));

      // El botón de guardar debe estar visible y por encima de la barra del sistema (640 - 48 = 592)
      final saveBtn = find.text('Guardar Presupuestos');
      expect(saveBtn, findsOneWidget);
      expect(tester.getBottomLeft(saveBtn).dy, lessThanOrEqualTo(592));
    });

    testWidgets('ReviewExpenseScreen selector de comprobante: anclada abajo y shrink-wrapped', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapWithProviders(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('btn_open_picker'),
                onPressed: () => ReviewExpenseScreen.showImagePickerOptions(
                  ctx,
                  onPickImage: (_) {},
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_open_picker')));
      await tester.pumpAndSettle();

      final surface = find.byKey(const Key('sheet_surface_picker'));
      expect(surface, findsOneWidget);

      expect(tester.getTopLeft(surface).dy, greaterThan(0));
      expect(tester.getBottomLeft(surface).dy, moreOrLessEquals(640, epsilon: 1.0));
    });

    testWidgets('MainScreen menú central (+): anclado abajo y shrink-wrapped', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapWithProviders(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('btn_open_add_menu'),
                onPressed: () => MainScreen.showAddMenu(ctx),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_open_add_menu')));
      await tester.pumpAndSettle();

      final surface = find.byKey(const Key('sheet_surface_add_menu'));
      expect(surface, findsOneWidget);

      expect(tester.getTopLeft(surface).dy, greaterThan(0));
      expect(tester.getBottomLeft(surface).dy, moreOrLessEquals(640, epsilon: 1.0));
    });

    testWidgets('Resistencia con teclado abierto: sin desbordamientos de RenderFlex', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapWithProviders(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('btn_open_budget_kb'),
                onPressed: () => BudgetBottomSheet.show(ctx),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_open_budget_kb')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
