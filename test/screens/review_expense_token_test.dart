import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/review_expense_screen.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];
}

class FakeGastoProvider extends GastoProvider {
  final List<GastoModel> _gastos = [];

  @override
  List<GastoModel> get gastos => _gastos;

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}

  @override
  Future<Map<String, dynamic>?> buscarPrecioAnterior(String descripcion, {int? excludeGastoId}) async => null;
}

class FakeSettingsProvider extends SettingsProvider {
  double tasaUsd = 881.88;
  double tasaEur = 950.0;
  double tasaUsdt = 900.0;

  @override
  double get tasaCambioVesUsd => tasaUsd;

  @override
  double get tasaCambioVesEur => tasaEur;

  @override
  double get tasaCambioVesUsdt => tasaUsdt;

  @override
  String get monedaPrincipal => 'USD';

  @override
  Future<void> loadSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDatabaseHelper fakeDb;
  late ScanQueueProvider scanQueueProvider;
  late FakeGastoProvider gastoProvider;
  late FakeSettingsProvider settingsProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'cached_rate_usd': 881.88,
      'cached_rate_eur': 950.0,
      'cached_rate_usdt': 900.0,
    });
    fakeDb = FakeDatabaseHelper();
    scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
    gastoProvider = FakeGastoProvider();
    settingsProvider = FakeSettingsProvider();
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
      ],
      child: const MaterialApp(
        home: ReviewExpenseScreen(),
      ),
    );
  }

  testWidgets('ReviewExpenseScreen mounts and loads rates without error under token guard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.text('Registrar gasto'), findsOneWidget);
    expect(find.byType(ReviewExpenseScreen), findsOneWidget);
  });
}
