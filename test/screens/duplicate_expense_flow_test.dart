import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/review_expense_screen.dart';
import 'package:gastoscan_ai/ui/widgets/expense_card.dart';

class _FakeDatabaseHelper extends DatabaseHelper {
  _FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];
}

class _FakeSettingsProvider extends SettingsProvider {
  final double _usd;
  final double _eur;
  final double _usdt;

  _FakeSettingsProvider({
    double usd = 50.0,
    double eur = 55.0,
    double usdt = 60.0,
  })  : _usd = usd,
        _eur = eur,
        _usdt = usdt;

  @override
  double get tasaCambioVesUsd => _usd;

  @override
  double get tasaCambioVesEur => _eur;

  @override
  double get tasaCambioVesUsdt => _usdt;

  @override
  String get monedaPrincipal => 'USD';
}

class _FakeGastoProvider extends GastoProvider {
  final List<GastoModel> _gastos = [];
  int _nextId = 100;
  bool agregarCalled = false;
  bool actualizarCalled = false;
  GastoModel? lastAddedGasto;
  List<ItemGastoModel>? lastAddedItems;
  int? lastDeletedId;

  @override
  List<GastoModel> get gastos => _gastos;

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}

  @override
  Future<Map<String, PriceHistory>> buscarHistorialPrecios(
    List<String> descripcionesNormalizadas, {
    int? excludeGastoId,
    String? comercioActual,
    int diasVentana = 60,
    DateTime? referenceDate,
  }) async =>
      const {};

  @override
  Future<bool> agregarGasto(
    GastoModel gasto,
    List<ItemGastoModel> items, {
    List<int>? shoppingItemIds,
  }) async {
    agregarCalled = true;
    final inserted = gasto.copyWith(id: _nextId++, items: items);
    lastAddedGasto = inserted;
    lastAddedItems = items;
    _gastos.insert(0, inserted);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> actualizarGasto(GastoModel gasto, List<ItemGastoModel> items) async {
    actualizarCalled = true;
    return true;
  }

  @override
  Future<bool> eliminarGasto(int id) async {
    lastDeletedId = id;
    _gastos.removeWhere((g) => g.id == id);
    notifyListeners();
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildHarness({
    required Widget home,
    required _FakeGastoProvider gastoProvider,
    required _FakeSettingsProvider settingsProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ScanQueueProvider>(
          create: (_) => ScanQueueProvider(
            dbHelper: _FakeDatabaseHelper(),
            autoProcess: false,
          ),
        ),
      ],
      child: MaterialApp(home: home),
    );
  }

  testWidgets('ExpenseCard muestra opción Duplicar en el menú y dispara callback', (tester) async {
    bool duplicated = false;
    final gasto = GastoModel(
      id: 1,
      uuid: 'orig-uuid-1',
      fecha: '2026-11-03',
      comercio: 'Comisión App',
      moneda: 'USD',
      totalOriginal: 250,
      totalUsd: 250,
      tasaCambio: 40.0,
      categoria: 'Servicios',
      creadoEn: '2026-11-03T10:00:00Z',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseCard(
            gasto: gasto,
            onEdit: () {},
            onDelete: () {},
            onDuplicate: () => duplicated = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expense_card_menu_duplicate')), findsOneWidget);
    expect(find.text('Duplicar'), findsOneWidget);

    await tester.tap(find.byKey(const Key('expense_card_menu_duplicate')));
    await tester.pumpAndSettle();

    expect(duplicated, isTrue);
  });

  testWidgets('Duplicar gasto USD indexado BS_BCV recalcula Bs con tasa de hoy, sin foto, nuevo UUID y permite Deshacer', (tester) async {
    final gastoProvider = _FakeGastoProvider();
    final settingsProvider = _FakeSettingsProvider(usd: 50.0, eur: 55.0, usdt: 60.0);

    // Gasto histórico del 2026-11-03: $10 pagados en Bs a tasa 40.00 = Bs 400.00, con foto adjunta
    final gastoOriginal = GastoModel(
      id: 7,
      uuid: 'orig-uuid-bcv',
      fecha: '2026-11-03',
      comercio: 'Comisión Pago Móvil',
      moneda: 'VES',
      totalOriginal: 40000, // Bs 400.00
      totalUsd: 1000,       // $10.00
      tasaCambio: 40.0,
      fuenteTasaCambio: 'BCV (Pago en Bs. indexado a USD)',
      fechaTasaCambio: '2026-11-03',
      categoria: 'Servicios',
      rutaFotoLocal: '/tmp/recibo_viejo.jpg',
      creadoEn: '2026-11-03T08:00:00Z',
      items: [
        ItemGastoModel(
          id: 55,
          gastoId: 7,
          descripcion: 'Comisión fija',
          cantidad: 1,
          precioUnitario: 40000,
          total: 40000,
          categoria: 'Servicios',
        ),
      ],
    );

    await tester.pumpWidget(
      buildHarness(
        gastoProvider: gastoProvider,
        settingsProvider: settingsProvider,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => ReviewExpenseScreen(
                      templateGasto: gastoOriginal,
                      currentDate: DateTime(2026, 11, 25),
                    ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Duplicar gasto'), findsOneWidget);
    expect(find.byKey(const Key('btn_eliminar_gasto_appbar')), findsNothing);

    // Guardar directamente el duplicado
    await tester.tap(find.text('Guardar Gasto'));
    await tester.pumpAndSettle();

    expect(gastoProvider.agregarCalled, isTrue);
    expect(gastoProvider.actualizarCalled, isFalse);

    final saved = gastoProvider.lastAddedGasto!;
    expect(saved.uuid, isNot(equals(gastoOriginal.uuid)));
    expect(saved.fecha, equals('2026-11-25'));
    expect(saved.comercio, equals('Comisión Pago Móvil'));
    expect(saved.rutaFotoLocal, isNull);
    // $10.00 * tasa actual 50.00 = Bs 500.00 (50000 céntimos), NO los Bs 400.00 históricos
    expect(saved.moneda, equals('VES'));
    expect(saved.totalOriginal, equals(50000));
    expect(saved.totalUsd, equals(1000));

    // SnackBar con Deshacer
    expect(find.text('Gasto duplicado con éxito'), findsOneWidget);
    expect(find.byKey(const Key('snackbar_undo_duplicate')), findsOneWidget);

    await tester.tap(find.byKey(const Key('snackbar_undo_duplicate')));
    await tester.pumpAndSettle();

    expect(gastoProvider.lastDeletedId, equals(saved.id));
  });

  testWidgets('Duplicar gasto VES puro conserva bolívares y recalcula USD con tasa de hoy', (tester) async {
    final gastoProvider = _FakeGastoProvider();
    final settingsProvider = _FakeSettingsProvider(usd: 50.0, eur: 55.0, usdt: 60.0);

    // Gasto histórico en VES puro: Bs 200.00 a tasa 40.00 = $5.00
    final gastoVes = GastoModel(
      id: 9,
      uuid: 'orig-uuid-ves',
      fecha: '2026-11-01',
      comercio: 'Pasaje Urbano',
      moneda: 'VES',
      totalOriginal: 20000, // Bs 200.00
      totalUsd: 500,        // $5.00 histórico
      tasaCambio: 40.0,
      fuenteTasaCambio: 'BCV',
      fechaTasaCambio: '2026-11-01',
      categoria: 'Transporte',
      creadoEn: '2026-11-01T09:00:00Z',
    );

    await tester.pumpWidget(
      buildHarness(
        gastoProvider: gastoProvider,
        settingsProvider: settingsProvider,
        home: ReviewExpenseScreen(
          templateGasto: gastoVes,
          currentDate: DateTime(2026, 11, 25),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar Gasto'));
    await tester.pumpAndSettle();

    final saved = gastoProvider.lastAddedGasto!;
    expect(saved.moneda, equals('VES'));
    expect(saved.totalOriginal, equals(20000)); // Conserva Bs 200.00
    expect(saved.totalUsd, equals(400));        // Recalculado a tasa 50.00 -> $4.00
    expect(saved.fecha, equals('2026-11-25'));
  });

  testWidgets('Salir de Duplicar gasto sin editar no muestra diálogo de descartar cambios', (tester) async {
    final gastoProvider = _FakeGastoProvider();
    final settingsProvider = _FakeSettingsProvider(usd: 50.0);

    final gastoOriginal = GastoModel(
      id: 12,
      uuid: 'orig-uuid-back',
      fecha: '2026-11-05',
      comercio: 'Café',
      moneda: 'USD',
      totalOriginal: 300,
      totalUsd: 300,
      tasaCambio: 40.0,
      categoria: 'Alimentación',
      creadoEn: '2026-11-05T10:00:00Z',
    );

    await tester.pumpWidget(
      buildHarness(
        gastoProvider: gastoProvider,
        settingsProvider: settingsProvider,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => ReviewExpenseScreen(
                      templateGasto: gastoOriginal,
                      currentDate: DateTime(2026, 11, 25),
                    ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Duplicar gasto'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Duplicar gasto'), findsNothing);
    expect(find.text('Abrir'), findsOneWidget);
  });
}
