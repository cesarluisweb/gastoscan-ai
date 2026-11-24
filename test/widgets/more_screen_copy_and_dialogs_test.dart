import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/providers/chat_provider.dart';
import 'package:gastoscan_ai/services/notification_service.dart';
import 'package:gastoscan_ai/ui/screens/more_screen.dart';

class FakeTestUser extends Fake implements User {
  final bool _isAnonymous;
  final String _uid;

  FakeTestUser({bool isAnonymous = false, String uid = 'test-uid'})
      : _isAnonymous = isAnonymous,
        _uid = uid;

  @override
  bool get isAnonymous => _isAnonymous;

  @override
  String get uid => _uid;

  @override
  String? get email => _isAnonymous ? null : 'test@rindemas.com';

  @override
  String? get displayName => _isAnonymous ? null : 'César Usuario';

  @override
  String? get photoURL => null;

  @override
  List<UserInfo> get providerData => [];
}

class FakeDatabaseHelper extends DatabaseHelper {
  FakeDatabaseHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];

  @override
  Future<int> resetStaleProcessingScanQueueItems() async => 0;

  @override
  Future<int> resetFailedScanQueueItems() async => 0;

  @override
  Future<int> clearPendingScanQueueItems() async => 0;

  @override
  Future<void> limpiarBaseDatosLocal() async {}
}

class FakeGastoProvider extends GastoProvider {
  bool cerrarSesionCalled = false;
  bool lastEliminarFotosPassed = false;
  String? lastReauthPasswordPassed;
  String? errorEliminarCuenta;

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}

  @override
  Future<void> cerrarSesion() async {
    cerrarSesionCalled = true;
  }

  @override
  Future<String?> eliminarCuentaYDatos({String? reauthPassword, bool eliminarFotos = false}) async {
    lastEliminarFotosPassed = eliminarFotos;
    lastReauthPasswordPassed = reauthPassword;
    return errorEliminarCuenta;
  }
}

class FakeSettingsProvider extends SettingsProvider {
  FakeSettingsProvider()
      : super(
          autoLoad: false,
          enableConnectivityListener: false,
        );

  @override
  Future<void> loadSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDatabaseHelper fakeDb;
  late ScanQueueProvider scanQueueProvider;
  late FakeGastoProvider gastoProvider;
  late FakeSettingsProvider settingsProvider;
  late ChatProvider chatProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance = NotificationService.test();
    fakeDb = FakeDatabaseHelper();
    scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
    gastoProvider = FakeGastoProvider();
    settingsProvider = FakeSettingsProvider();
    chatProvider = ChatProvider();
  });

  tearDown(() {
    scanQueueProvider.dispose();
    gastoProvider.dispose();
    settingsProvider.dispose();
    chatProvider.dispose();
    NotificationService.instance = NotificationService.test();
  });

  Widget createWidgetUnderTest({User? customUser}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ],
      child: MaterialApp(
        home: MoreScreen(customUser: customUser),
      ),
    );
  }

  testWidgets('Cerrar sesión shows linked copy when user is linked', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final linkedUser = FakeTestUser(isAnonymous: false);
    await tester.pumpWidget(createWidgetUnderTest(customUser: linkedUser));
    await tester.pumpAndSettle();

    final btnAjustes = find.byKey(const Key('btn_ajustes_cuenta'));
    expect(btnAjustes, findsOneWidget);
    await tester.tap(btnAjustes);
    await tester.pumpAndSettle();

    final btnCerrarSesion = find.widgetWithText(OutlinedButton, 'Cerrar sesión');
    expect(btnCerrarSesion, findsOneWidget);
    await tester.tap(btnCerrarSesion);
    await tester.pumpAndSettle();

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    expect(
      find.textContaining('Tus gastos numéricos están respaldados en la nube'),
      findsOneWidget,
    );
  });

  testWidgets('Eliminar cuenta dialog includes eliminarFotos switch and passes value to provider', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final user = FakeTestUser(isAnonymous: false);
    await tester.pumpWidget(createWidgetUnderTest(customUser: user));
    await tester.pumpAndSettle();

    final btnAjustes = find.byKey(const Key('btn_ajustes_cuenta'));
    expect(btnAjustes, findsOneWidget);
    await tester.tap(btnAjustes);
    await tester.pumpAndSettle();

    final btnEliminar = find.widgetWithText(OutlinedButton, 'Eliminar cuenta y datos');
    expect(btnEliminar, findsOneWidget);
    await tester.tap(btnEliminar);
    await tester.pumpAndSettle();

    expect(find.text('¿Eliminar cuenta y datos?'), findsOneWidget);
    final checkboxFinder = find.byType(CheckboxListTile);
    expect(checkboxFinder, findsOneWidget);

    // Default is unchecked (false)
    CheckboxListTile checkboxWidget = tester.widget(checkboxFinder);
    expect(checkboxWidget.value, isFalse);

    // Toggle to true
    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    checkboxWidget = tester.widget(checkboxFinder);
    expect(checkboxWidget.value, isTrue);

    // Escribir ELIMINAR para habilitar el botón
    await tester.enterText(find.byKey(const Key('delete_account_confirm_input')), 'ELIMINAR');
    await tester.pumpAndSettle();

    // Confirm deletion
    final btnConfirmar = find.widgetWithText(ElevatedButton, 'Eliminar definitivamente');
    await tester.tap(btnConfirmar);
    await tester.pumpAndSettle();

    expect(gastoProvider.lastEliminarFotosPassed, isTrue);
  });

  testWidgets('Modal Notificaciones incluye switch de Tasa de cambio diaria y persiste cambios', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final user = FakeTestUser(isAnonymous: false);
    await tester.pumpWidget(createWidgetUnderTest(customUser: user));
    await tester.pumpAndSettle();

    final btnPreferencias = find.byKey(const Key('more_group_preferences'));
    expect(btnPreferencias, findsOneWidget);
    await tester.tap(btnPreferencias);
    await tester.pumpAndSettle();

    final btnNotificaciones = find.byKey(const Key('more_menu_notifications'));
    expect(btnNotificaciones, findsOneWidget);
    await tester.tap(btnNotificaciones);
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const Key('switch_notif_tasa_diaria'));
    expect(switchFinder, findsOneWidget);
    expect(find.text('Tasa de cambio diaria'), findsOneWidget);

    SwitchListTile tile = tester.widget<SwitchListTile>(switchFinder);
    expect(tile.value, isTrue);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    tile = tester.widget<SwitchListTile>(switchFinder);
    expect(tile.value, isFalse);
    expect(settingsProvider.tasaDiariaActiva, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConstants.prefTasaDiariaActiva), isFalse);
  });
}
