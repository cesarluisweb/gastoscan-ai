import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/more_screen.dart';

class FakeTestUser extends Fake implements User {
  @override
  bool get isAnonymous => false;

  @override
  String get uid => 'user-test-uid';

  @override
  String? get email => 'test@rindemas.com';

  @override
  String? get displayName => 'Usuario Test';

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
  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {}

  @override
  Future<String?> vincularConEmail(String email, String password, {bool descartarDatosLocales = false}) async => null;

  @override
  Future<String?> iniciarSesionConEmail(String email, String password, {bool descartarDatosLocales = true}) async => null;

  Completer<String?>? vincularGoogleCompleter;

  @override
  Future<String?> vincularCuentaGoogle({bool descartarDatosLocales = false}) async {
    if (vincularGoogleCompleter != null) {
      return await vincularGoogleCompleter!.future;
    }
    return null;
  }

  @override
  Future<void> cerrarSesion() async {}

  String? errorEliminarCuenta;

  @override
  Future<String?> eliminarCuentaYDatos({String? reauthPassword}) async => errorEliminarCuenta;
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

void main() {
  group('MoreScreen Navigation & Hub Tests', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProvider gastoProvider;
    late FakeSettingsProvider settingsProvider;

    setUp(() {
      final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.physicalSizeTestValue = const Size(1080, 4000);
      binding.window.devicePixelRatioTestValue = 1.0;
      fakeDb = FakeDatabaseHelper();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb);
      gastoProvider = FakeGastoProvider();
      settingsProvider = FakeSettingsProvider();
    });

    tearDown(() {
      final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    Widget createWidgetUnderTest({User? customUser}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
        ],
        child: MaterialApp(
          home: MoreScreen(customUser: customUser),
        ),
      );
    }

    testWidgets('renders all hub sections in main view', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Más'), findsOneWidget);
      expect(find.text('Respaldo en la Nube'), findsOneWidget);
      expect(find.text('Lista de Compras'), findsOneWidget);
      expect(find.text('Asistente IA'), findsOneWidget);
      expect(find.text('Tasas de Cambio'), findsOneWidget);
      // Sin sincronización en vivo el provider conserva tasasSonReferencia=true
      expect(find.text('⚠ Tasa de referencia'), findsOneWidget);
      expect(find.text('Dólar BCV'), findsOneWidget);
      expect(find.text('Euro BCV'), findsOneWidget);
      expect(find.text('USDT Binance'), findsOneWidget);
      expect(find.text('Almacenamiento y Fotos', skipOffstage: false), findsOneWidget);
      expect(find.text('Exportar a Excel (.csv)', skipOffstage: false), findsOneWidget);
      expect(find.text('Exportar como Texto (.md)', skipOffstage: false), findsOneWidget);
      expect(find.text('Escribir a soporte', skipOffstage: false), findsOneWidget);
      expect(find.text('Visitar sitio web', skipOffstage: false), findsOneWidget);
      expect(find.text('Apoyar el proyecto ☕', skipOffstage: false), findsOneWidget);
      expect(find.text('Versión de la App', skipOffstage: false), findsOneWidget);
    });

    testWidgets('tapping shopping list navigates internally and back button returns to hub', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap shopping list
      await tester.tap(find.byKey(const Key('more_menu_shopping_list')));
      await tester.pumpAndSettle();

      // We should be in ShoppingListScreen
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Lista de Compras'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // We should be back in MoreScreen hub
      expect(find.text('Más'), findsOneWidget);
      expect(find.text('Respaldo en la Nube'), findsOneWidget);
    });

    testWidgets('tapping chat navigates internally and back button returns to hub', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap chat
      await tester.tap(find.byKey(const Key('more_menu_chat_ai')));
      await tester.pumpAndSettle();

      // We should be in ChatScreen
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Asistente IA'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // We should be back in MoreScreen hub
      expect(find.text('Más'), findsOneWidget);
      expect(find.text('Respaldo en la Nube'), findsOneWidget);
    });

    testWidgets('calling openChat navigates directly to chat view', (tester) async {
      final GlobalKey<MoreScreenState> moreKey = GlobalKey<MoreScreenState>();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ],
          child: MaterialApp(
            home: MoreScreen(key: moreKey),
          ),
        ),
      );
      await tester.pumpAndSettle();

      moreKey.currentState?.openChat();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Asistente IA'), findsOneWidget);
    });

    testWidgets('tapping view receipts navigates to ReceiptGalleryScreen and back button returns to hub', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap view receipts
      await tester.tap(find.byKey(const Key('more_menu_view_receipts'), skipOffstage: false));
      await tester.pumpAndSettle();

      // We should be in ReceiptGalleryScreen
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Comprobantes Guardados'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // We should be back in MoreScreen hub
      expect(find.text('Más'), findsOneWidget);
      expect(find.text('Almacenamiento y Fotos', skipOffstage: false), findsOneWidget);
    });

    testWidgets('tapping currency calculator navigates internally and back button returns to hub', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap currency calculator
      await tester.tap(find.byKey(const Key('more_menu_currency_calculator'), skipOffstage: false));
      await tester.pumpAndSettle();

      // We should be in CurrencyCalculatorScreen
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Calculadora Cambiaria'), findsOneWidget);
      expect(find.byKey(const Key('calc_divisa_input')), findsOneWidget);
      expect(find.byKey(const Key('calc_ves_input')), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // We should be back in MoreScreen hub
      expect(find.text('Más'), findsOneWidget);
    });

    testWidgets('renders email auth button and opens email auth modal', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_vincular_email')), findsOneWidget);
      expect(find.text('Vincular con correo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_vincular_email')));
      await tester.pumpAndSettle();

      expect(find.text('Vincular con Correo'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Vincular y Respaldar'), findsOneWidget);

      // Toggle to login mode
      await tester.tap(find.text('¿Ya tienes una cuenta registrada? Inicia sesión aquí'));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar Sesión con Correo'), findsOneWidget);
      expect(find.text('Iniciar Sesión'), findsWidgets);
    });

    testWidgets('tapping vincular con google shows loading state and disables buttons while in progress', (tester) async {
      final completer = Completer<String?>();
      gastoProvider.vincularGoogleCompleter = completer;

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final googleBtn = find.byKey(const Key('btn_vincular_google'));
      final emailBtn = find.byKey(const Key('btn_vincular_email'));

      expect(googleBtn, findsOneWidget);
      expect(emailBtn, findsOneWidget);
      expect(find.text('Vincular con Google'), findsOneWidget);

      await tester.tap(googleBtn);
      await tester.pump();

      // En progreso: botón muestra "Conectando con Google...", texto de respaldo visible, y ambos botones deshabilitados
      expect(find.text('Conectando con Google...'), findsOneWidget);
      expect(find.text('Conectando y respaldando tus datos en la nube...'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('btn_vincular_google'))).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('btn_vincular_email'))).onPressed, isNull);

      // Completar vinculación
      completer.complete(null);
      await tester.pumpAndSettle();

      expect(find.text('Cuenta vinculada con éxito'), findsOneWidget);
    });

    testWidgets('tapping eliminar cuenta and confirming shows success snackbar on success', (tester) async {
      gastoProvider.errorEliminarCuenta = null;
      await tester.pumpWidget(createWidgetUnderTest(customUser: FakeTestUser()));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('btn_eliminar_cuenta'));
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar cuenta y datos?'), findsOneWidget);
      await tester.tap(find.text('Eliminar definitivamente'));
      await tester.pumpAndSettle();

      expect(find.text('Cuenta y datos eliminados. Sesión cerrada.'), findsOneWidget);
    });

    testWidgets('tapping eliminar cuenta and confirming shows error snackbar on failure', (tester) async {
      gastoProvider.errorEliminarCuenta = 'Sin conexión a internet. Verifica tu red.';
      await tester.pumpWidget(createWidgetUnderTest(customUser: FakeTestUser()));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('btn_eliminar_cuenta'));
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar cuenta y datos?'), findsOneWidget);
      await tester.tap(find.text('Eliminar definitivamente'));
      await tester.pumpAndSettle();

      expect(find.text('Sin conexión a internet. Verifica tu red.'), findsOneWidget);
      expect(find.text('Cuenta y datos eliminados. Sesión cerrada.'), findsNothing);
    });

    testWidgets('Danger Zone is hidden for anonymous users and visible for logged in users', (tester) async {
      // Usuario anónimo por defecto
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Zona de Peligro'), findsNothing);
      expect(find.byKey(const Key('btn_eliminar_cuenta')), findsNothing);

      // Usuario con cuenta vinculada
      await tester.pumpWidget(createWidgetUnderTest(customUser: FakeTestUser()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_cerrar_sesion')), findsOneWidget);
      final dangerZoneText = find.text('Zona de Peligro');
      await tester.ensureVisible(dangerZoneText);
      await tester.pumpAndSettle();
      expect(dangerZoneText, findsOneWidget);
      expect(find.byKey(const Key('btn_eliminar_cuenta')), findsOneWidget);
    });

    testWidgets('renders rates legal disclaimer and legal disclaimer menu item in MoreScreen', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final ratesDisclaimer = find.byKey(const Key('more_rates_bcv_disclaimer'));
      await tester.ensureVisible(ratesDisclaimer);
      await tester.pumpAndSettle();
      expect(ratesDisclaimer, findsOneWidget);
      expect(find.byKey(const Key('more_rates_bcv_source_link')), findsOneWidget);

      final legalItem = find.byKey(const Key('more_menu_legal_disclaimer'));
      await tester.ensureVisible(legalItem);
      await tester.pumpAndSettle();
      expect(legalItem, findsOneWidget);

      // Tap on legal disclaimer item to open dialog
      await tester.tap(legalItem);
      await tester.pumpAndSettle();

      expect(find.text('Aviso Legal y Tasas'), findsOneWidget);
      expect(find.textContaining('Rinde Más es una aplicación independiente'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso Legal y Tasas'), findsNothing);
    });

    testWidgets('renders version card with Google Play button in MoreScreen', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final googlePlayBtn = find.byKey(const Key('btn_ver_google_play'));
      await tester.ensureVisible(googlePlayBtn);
      await tester.pumpAndSettle();

      expect(googlePlayBtn, findsOneWidget);
      expect(find.text('Google Play'), findsOneWidget);
      expect(find.text('Versión de la App'), findsOneWidget);
    });

    testWidgets('al tocar refresh_rates_btn ejecuta actualizacion y muestra feedback', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final refreshBtn = find.byKey(const Key('refresh_rates_btn'));
      await tester.ensureVisible(refreshBtn);
      await tester.pumpAndSettle();

      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

