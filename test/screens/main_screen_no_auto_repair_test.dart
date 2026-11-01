import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/main_screen.dart';

class FakeDatabaseHelperForMainScreen extends DatabaseHelper {
  FakeDatabaseHelperForMainScreen() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];
}

class TrackingGastoProvider extends GastoProvider {
  bool repararTasasCalled = false;
  double? lastTasaFallback;
  bool? lastDryRun;

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}

  @override
  Future<int> repararTasasHistoricas({
    double tasaFallback = AppConstants.defaultTasaCambio,
    bool dryRun = true,
  }) async {
    repararTasasCalled = true;
    lastTasaFallback = tasaFallback;
    lastDryRun = dryRun;
    return 0;
  }
}

class FakeSettingsProviderForMainScreen extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

void main() {
  group('E0-05a: Neutralización de auto-ejecución de reparaciones en MainScreen', () {
    late FakeDatabaseHelperForMainScreen fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late TrackingGastoProvider gastoProvider;
    late FakeSettingsProviderForMainScreen settingsProvider;

    setUp(() {
      fakeDb = FakeDatabaseHelperForMainScreen();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      gastoProvider = TrackingGastoProvider();
      settingsProvider = FakeSettingsProviderForMainScreen();
    });

    Widget createWidgetUnderTest() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: const MaterialApp(
          home: MainScreen(),
        ),
      );
    }

    testWidgets('abrir MainScreen NO ejecuta repararTasasHistoricas ni mutaciones monetarias', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Debe quedar demostrado que al montar/abrir la pantalla principal,
      // NO se invoca repararTasasHistoricas.
      expect(gastoProvider.repararTasasCalled, isFalse);
      expect(gastoProvider.lastTasaFallback, isNull);
      expect(gastoProvider.lastDryRun, isNull);
    });
  });
}
