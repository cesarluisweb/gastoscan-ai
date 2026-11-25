import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/core/constants/app_colors.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/providers/chat_provider.dart';
import 'package:gastoscan_ai/services/connectivity_service.dart';
import 'package:gastoscan_ai/services/profile_avatar_service.dart';
import 'package:gastoscan_ai/services/sync_coordinator.dart';
import 'package:gastoscan_ai/services/update_service.dart';
import 'package:gastoscan_ai/ui/screens/more_screen.dart';

class _FakeUpdateService extends UpdateService {
  final UpdateInfo? cachedInfo;
  final UpdateInfo? liveInfo;

  _FakeUpdateService({this.cachedInfo, this.liveInfo});

  @override
  Future<UpdateInfo?> getCachedUpdateInfo({
    String? currentVersion,
    int? currentBuildNumber,
  }) async =>
      cachedInfo;

  @override
  Future<UpdateInfo?> checkForUpdate({
    bool force = false,
    Duration throttleDuration = const Duration(hours: 4),
    String? currentVersion,
    int? currentBuildNumber,
  }) async =>
      liveInfo;
}

final Uint8List _kAvatarTestPngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class FakeTestUser extends Fake implements User {
  final String _uid;
  final String? _photoUrl;

  FakeTestUser({String uid = 'user-test-uid', String? photoUrl})
      : _uid = uid,
        _photoUrl = photoUrl;

  @override
  bool get isAnonymous => false;

  @override
  String get uid => _uid;

  @override
  String? get email => 'test@rindemas.com';

  @override
  String? get displayName => 'Usuario Test';

  @override
  String? get photoURL => _photoUrl;

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
  FakeGastoProvider() : super(autoLoad: false);

  final ValueNotifier<SyncState> fakeSyncNotifier =
      ValueNotifier<SyncState>(const SyncState.inactiva());
  int manualSyncCalls = 0;

  @override
  SyncState get syncState => fakeSyncNotifier.value;

  @override
  ValueListenable<SyncState> get syncStateListenable => fakeSyncNotifier;

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<void> sincronizarConFirestore() async {
    manualSyncCalls++;
  }

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

  bool lastEliminarFotosPassed = false;

  @override
  Future<String?> eliminarCuentaYDatos({String? reauthPassword, bool eliminarFotos = false}) async {
    lastEliminarFotosPassed = eliminarFotos;
    return errorEliminarCuenta;
  }
}

class FakeSettingsProvider extends SettingsProvider {
  FakeSettingsProvider() : super(autoLoad: false);

  int actualizarTasaCalls = 0;

  @override
  Future<void> loadSettings() async {}

  @override
  Future<bool> actualizarTasaAutomatica({http.Client? client}) async {
    actualizarTasaCalls++;
    return true;
  }
}

void main() {
  group('MoreScreen Navigation & Hub Tests', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeGastoProvider gastoProvider;
    late FakeSettingsProvider settingsProvider;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      fakeDb = FakeDatabaseHelper();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      gastoProvider = FakeGastoProvider();
      settingsProvider = FakeSettingsProvider();
    });

    tearDown(() {
      scanQueueProvider.dispose();
      settingsProvider.dispose();
      gastoProvider.dispose();
      ConnectivityService.reset();
      ProfileAvatarService.reset();
    });

    Widget createWidgetUnderTest({User? customUser}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
          ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
        ],
        child: MaterialApp(
          home: MoreScreen(customUser: customUser),
        ),
      );
    }

    void setLargeViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('renders all hub sections in main view', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Más'), findsOneWidget);
      expect(find.text('Tus datos solo están en este teléfono'), findsOneWidget);
      expect(find.text('HERRAMIENTAS'), findsOneWidget);
      expect(find.text('Lista de Compras'), findsOneWidget);
      expect(find.text('Calculadora'), findsOneWidget);
      expect(find.text('Comprobantes'), findsOneWidget);
      expect(find.text('Asistente IA'), findsOneWidget);
      expect(find.text('Tasas de Cambio'), findsOneWidget);
      // Sin sincronización en vivo el provider conserva tasasSonReferencia=true
      expect(find.text('Sin tasa disponible'), findsOneWidget);
      expect(find.text('Dólar BCV'), findsOneWidget);
      expect(find.text('Euro BCV'), findsOneWidget);
      expect(find.text('USDT P2P'), findsOneWidget);
      expect(find.byKey(const Key('more_currency_lens_dropdown')), findsNothing);
      expect(find.byKey(const Key('more_group_preferences')), findsOneWidget);
      expect(find.byKey(const Key('more_group_support')), findsOneWidget);
      expect(find.byKey(const Key('more_group_about')), findsOneWidget);
      expect(find.text('Sobre Rinde Más'), findsOneWidget);
      expect(find.byKey(const Key('more_rates_bcv_disclaimer')), findsOneWidget);
      expect(find.byKey(const Key('more_rates_bcv_source_link')), findsOneWidget);
      expect(find.byKey(const Key('more_app_version_footer')), findsOneWidget);
      expect(find.byKey(const Key('more_menu_legal_disclaimer')), findsNothing);
      expect(find.byKey(const Key('btn_ver_google_play')), findsNothing);

      final aiMaterial = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const Key('more_menu_chat_ai')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(aiMaterial.color, AppColors.card);
    });

    testWidgets('tapping shopping list navigates internally and back button returns to hub', (tester) async {
      setLargeViewport(tester);
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
      expect(find.text('HERRAMIENTAS'), findsOneWidget);
    });

    testWidgets('tapping chat navigates internally and back button returns to hub', (tester) async {
      setLargeViewport(tester);
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
      expect(find.text('HERRAMIENTAS'), findsOneWidget);
    });

    testWidgets('calling openChat navigates directly to chat view', (tester) async {
      setLargeViewport(tester);
      final GlobalKey<MoreScreenState> moreKey = GlobalKey<MoreScreenState>();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
            ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
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
      setLargeViewport(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap view receipts
      await tester.tap(find.byKey(const Key('more_menu_view_receipts')));
      await tester.pumpAndSettle();

      // We should be in ReceiptGalleryScreen
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Comprobantes Guardados'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // We should be back in MoreScreen hub
      expect(find.text('Más'), findsOneWidget);
      expect(find.text('HERRAMIENTAS'), findsOneWidget);
    });

    testWidgets('tapping currency calculator navigates internally and back button returns to hub', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap currency calculator
      await tester.tap(find.byKey(const Key('more_menu_currency_calculator')));
      await tester.pumpAndSettle();

      // We should be in CurrencyCalculatorScreen
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Calculadora Cambiaria'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // We should be back in MoreScreen hub
      expect(find.text('Más'), findsOneWidget);
      expect(find.text('HERRAMIENTAS'), findsOneWidget);
    });

    testWidgets('renders email auth button and opens email auth modal', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_vincular_email')), findsOneWidget);
      expect(find.text('Correo'), findsOneWidget);

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
      setLargeViewport(tester);
      final completer = Completer<String?>();
      gastoProvider.vincularGoogleCompleter = completer;

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final googleBtn = find.byKey(const Key('btn_vincular_google'));
      final emailBtn = find.byKey(const Key('btn_vincular_email'));

      expect(googleBtn, findsOneWidget);
      expect(emailBtn, findsOneWidget);
      expect(find.text('Google'), findsOneWidget);

      await tester.tap(googleBtn);
      await tester.pump();

      // En progreso: botón muestra "Conectando...", y ambos botones deshabilitados
      expect(find.text('Conectando...'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('btn_vincular_google'))).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('btn_vincular_email'))).onPressed, isNull);

      // Completar vinculación
      completer.complete(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Cuenta vinculada con éxito'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('tapping eliminar cuenta and confirming shows success snackbar on success', (tester) async {
      setLargeViewport(tester);
      gastoProvider.errorEliminarCuenta = null;
      await tester.pumpWidget(createWidgetUnderTest(customUser: FakeTestUser()));
      await tester.pumpAndSettle();

      // Abrir ajustes de cuenta
      final btnAjustes = find.byKey(const Key('btn_ajustes_cuenta'));
      expect(btnAjustes, findsOneWidget);
      await tester.tap(btnAjustes);
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('btn_eliminar_cuenta'));
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar cuenta y datos?'), findsOneWidget);

      // El botón debe estar deshabilitado antes de escribir ELIMINAR
      final confirmBtnFinder = find.widgetWithText(ElevatedButton, 'Eliminar definitivamente');
      expect(tester.widget<ElevatedButton>(confirmBtnFinder).onPressed, isNull);

      // Ingresar ELIMINAR
      await tester.enterText(find.byKey(const Key('delete_account_confirm_input')), 'eliminar');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(confirmBtnFinder).onPressed, isNotNull);

      await tester.tap(confirmBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Cuenta y datos eliminados. Sesión cerrada.'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('tapping eliminar cuenta and confirming shows error snackbar on failure', (tester) async {
      setLargeViewport(tester);
      gastoProvider.errorEliminarCuenta = 'Sin conexión a internet. Verifica tu red.';
      await tester.pumpWidget(createWidgetUnderTest(customUser: FakeTestUser()));
      await tester.pumpAndSettle();

      final btnAjustes = find.byKey(const Key('btn_ajustes_cuenta'));
      await tester.tap(btnAjustes);
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('btn_eliminar_cuenta'));
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar cuenta y datos?'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('delete_account_confirm_input')), 'ELIMINAR');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar definitivamente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Sin conexión a internet. Verifica tu red.'), findsOneWidget);
      expect(find.text('Cuenta y datos eliminados. Sesión cerrada.'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('Danger Zone is hidden for anonymous users and visible for logged in users in sheet', (tester) async {
      setLargeViewport(tester);
      // Usuario anónimo por defecto
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_ajustes_cuenta')), findsNothing);
      expect(find.byKey(const Key('btn_borrar_datos_local')), findsOneWidget);

      // Usuario con cuenta vinculada
      await tester.pumpWidget(createWidgetUnderTest(customUser: FakeTestUser()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_ajustes_cuenta')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_ajustes_cuenta')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_cerrar_sesion')), findsOneWidget);
      expect(find.text('Zona de Peligro'), findsOneWidget);
      expect(find.byKey(const Key('btn_eliminar_cuenta')), findsOneWidget);
    });

    testWidgets('renders BCV legal disclaimer at bottom and passive version footer in MoreScreen', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('more_rates_bcv_disclaimer')), findsOneWidget);
      expect(find.text('Aviso legal sobre tasas oficiales'), findsOneWidget);
      expect(find.textContaining('no representa, no está afiliada'), findsOneWidget);
      expect(find.byKey(const Key('more_rates_bcv_source_link')), findsOneWidget);
      expect(find.byKey(const Key('more_app_version_footer')), findsOneWidget);
      expect(find.textContaining('Rinde Más v'), findsOneWidget);
      expect(find.byKey(const Key('more_menu_legal_disclaimer')), findsNothing);
    });

    testWidgets('opens Preferencias y datos sheet and updates monedaPrincipal via CurrencyLensDropdown', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('more_group_preferences')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sheet_surface_preferences')), findsOneWidget);
      expect(find.text('Moneda de reportes'), findsOneWidget);
      expect(find.byKey(const Key('more_currency_lens_dropdown')), findsOneWidget);

      await tester.tap(find.byKey(const Key('more_currency_lens_dropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lens_switch_ves')));
      await tester.pumpAndSettle();

      expect(settingsProvider.monedaPrincipal, 'VES');
    });

    testWidgets('opens Soporte y comunidad and Sobre Rinde Más sheets cleanly', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('more_group_support')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sheet_surface_support')), findsOneWidget);
      expect(find.byKey(const Key('more_menu_support_whatsapp')), findsOneWidget);
      expect(find.byKey(const Key('more_menu_website')), findsOneWidget);
      expect(find.byKey(const Key('more_menu_donate')), findsOneWidget);

      Navigator.of(tester.element(find.byKey(const Key('sheet_surface_support')))).pop();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rate_card_usd')), findsOneWidget);
      expect(find.byKey(const Key('rate_card_eur')), findsOneWidget);
      expect(find.byKey(const Key('rate_card_usdt')), findsOneWidget);

      await tester.tap(find.byKey(const Key('more_group_about')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sheet_surface_about')), findsOneWidget);
      expect(find.byKey(const Key('more_menu_check_updates')), findsNothing);
      expect(find.text('Buscar actualizaciones'), findsNothing);
      expect(find.byKey(const Key('btn_ver_google_play')), findsOneWidget);
      expect(find.text('Ver en Google Play'), findsOneWidget);
      expect(find.byKey(const Key('more_menu_privacy_policy')), findsOneWidget);
      expect(find.byKey(const Key('more_menu_terms')), findsOneWidget);
    });

    testWidgets('renders hub and modal sheets cleanly on 360x640 with 1.3x text scaling', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
            ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: const MoreScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final hubScrollable = find.descendant(
        of: find.byType(Scaffold),
        matching: find.byType(Scrollable),
      ).first;

      await tester.scrollUntilVisible(
        find.byKey(const Key('more_group_preferences')),
        180,
        scrollable: hubScrollable,
      );
      await tester.ensureVisible(find.byKey(const Key('more_group_preferences')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('more_group_preferences')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sheet_surface_preferences')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byKey(const Key('more_menu_notifications')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('more_menu_notifications')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sheet_surface_notifications')), findsOneWidget);
      expect(tester.takeException(), isNull);

      Navigator.of(tester.element(find.byKey(const Key('sheet_surface_notifications')))).pop();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('more_group_about')),
        180,
        scrollable: hubScrollable,
      );
      await tester.ensureVisible(find.byKey(const Key('more_group_about')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('more_group_about')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sheet_surface_about')), findsOneWidget);
      expect(tester.takeException(), isNull);

      Navigator.of(tester.element(find.byKey(const Key('sheet_surface_about')))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('al tocar refresh_rates_btn ejecuta actualizacion silenciosa', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final refreshBtn = find.byKey(const Key('refresh_rates_btn'));
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(settingsProvider.actualizarTasaCalls, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('avatar cacheado en disco se muestra con FileImage incluso sin conexion', (tester) async {
      setLargeViewport(tester);
      final tempDir = Directory.systemTemp.createTempSync('more_avatar_offline_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      const photoUrl = 'https://lh3.googleusercontent.com/cached-offline.png';
      await tester.runAsync(() async {
        final seedService = ProfileAvatarService(
          httpClient: MockClient((_) async => http.Response.bytes(
                _kAvatarTestPngBytes,
                200,
                headers: {'content-type': 'image/png'},
              )),
          connectivityService: ConnectivityService(testConnected: true),
          baseDirectoryProvider: () async => tempDir,
        );
        final saved = await seedService.ensureAvatarCached(uid: 'uid-offline', photoUrl: photoUrl);
        expect(saved, isNotNull);
      });

      int offlineHttpCalls = 0;
      final offlineConnectivity = ConnectivityService(testConnected: false);
      final offlineAvatarService = ProfileAvatarService(
        httpClient: MockClient((_) async {
          offlineHttpCalls++;
          return http.Response('offline', 503);
        }),
        connectivityService: offlineConnectivity,
        baseDirectoryProvider: () async => tempDir,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
            ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
          ],
          child: MaterialApp(
            home: MoreScreen(
              customUser: FakeTestUser(uid: 'uid-offline', photoUrl: photoUrl),
              profileAvatarService: offlineAvatarService,
              connectivityService: offlineConnectivity,
            ),
          ),
        ),
      );
      for (int i = 0; i < 40; i++) {
        await tester.pump();
        final currentAvatar = tester.widget<CircleAvatar>(
          find.byKey(const Key('more_account_avatar')),
        );
        if (currentAvatar.backgroundImage is FileImage) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
      }

      final avatar = tester.widget<CircleAvatar>(find.byKey(const Key('more_account_avatar')));
      expect(avatar.backgroundImage, isA<FileImage>());
      expect(offlineHttpCalls, 0);
    });

    testWidgets('sin cache offline muestra inicial y al reconectar descarga y muestra FileImage', (tester) async {
      setLargeViewport(tester);
      final tempDir = Directory.systemTemp.createTempSync('more_avatar_reconnect_');
      final connController = StreamController<bool>.broadcast();
      addTearDown(() async {
        await connController.close();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      const photoUrl = 'https://lh3.googleusercontent.com/reconnect-photo.png';
      int httpCalls = 0;
      final downloadRequested = Completer<void>();
      final connectivity = ConnectivityService(
        testController: connController,
        testConnected: false,
      );
      final avatarService = ProfileAvatarService(
        httpClient: MockClient((_) async {
          httpCalls++;
          if (!downloadRequested.isCompleted) {
            downloadRequested.complete();
          }
          return http.Response.bytes(
            _kAvatarTestPngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
        connectivityService: connectivity,
        baseDirectoryProvider: () async => tempDir,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
            ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
          ],
          child: MaterialApp(
            home: MoreScreen(
              customUser: FakeTestUser(uid: 'uid-reconnect', photoUrl: photoUrl),
              profileAvatarService: avatarService,
              connectivityService: connectivity,
              avatarReconnectDebounce: const Duration(milliseconds: 20),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();

      // Offline y sin cache previa: muestra la inicial 'U', nunca circulo vacio ni llamada HTTP
      final avatarOffline = tester.widget<CircleAvatar>(find.byKey(const Key('more_account_avatar')));
      expect(avatarOffline.backgroundImage, isNull);
      expect(find.descendant(of: find.byKey(const Key('more_account_avatar')), matching: find.text('U')), findsOneWidget);
      expect(httpCalls, 0);

      // Al recuperar conexion, descarga automaticamente tras debounce y pinta FileImage
      // Nota: El Timer del debounce corre en FakeAsync, pero el IO de disco dentro de
      // _syncAvatarForUser (exists/stat/rename) completa en la zona real (`runAsync`),
      // por lo que debemos avanzar el reloj simulado antes de esperar IO real.
      connController.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      for (int i = 0; i < 40 && !downloadRequested.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(downloadRequested.isCompleted, isTrue);
      for (int i = 0; i < 40; i++) {
        await tester.pump();
        final currentAvatar = tester.widget<CircleAvatar>(
          find.byKey(const Key('more_account_avatar')),
        );
        if (currentAvatar.backgroundImage is FileImage) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
      }

      final avatarOnline = tester.widget<CircleAvatar>(find.byKey(const Key('more_account_avatar')));
      expect(httpCalls, 1);
      expect(avatarOnline.backgroundImage, isA<FileImage>());
    });

    testWidgets('usuario autenticado sin photoURL muestra inicial sin intentar descargas', (tester) async {
      setLargeViewport(tester);
      int httpCalls = 0;
      final connectivity = ConnectivityService(testConnected: true);
      final avatarService = ProfileAvatarService(
        httpClient: MockClient((_) async {
          httpCalls++;
          return http.Response('no deberia llamarse', 500);
        }),
        connectivityService: connectivity,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
            ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
          ],
          child: MaterialApp(
            home: MoreScreen(
              customUser: FakeTestUser(uid: 'uid-email-only', photoUrl: null),
              profileAvatarService: avatarService,
              connectivityService: connectivity,
            ),
          ),
        ),
      );
      await tester.pump();

      final avatar = tester.widget<CircleAvatar>(find.byKey(const Key('more_account_avatar')));
      expect(avatar.backgroundImage, isNull);
      expect(find.descendant(of: find.byKey(const Key('more_account_avatar')), matching: find.text('U')), findsOneWidget);
      expect(httpCalls, 0);
    });

    testWidgets('REL-04: muestra píldora de nueva versión desde caché y abre diálogo al comprobar actualizaciones', (tester) async {
      setLargeViewport(tester);
      final fakeInfo = UpdateInfo(
        version: '1.6.0',
        buildNumber: 750,
        releaseNotes: 'Duplicar gasto disponible.',
        apkUrl: UpdateService.playStoreWebUrl,
        hasUpdate: true,
      );
      final fakeUpdateService = _FakeUpdateService(
        cachedInfo: fakeInfo,
        liveInfo: fakeInfo,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GastoProvider>.value(value: gastoProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
            ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
          ],
          child: MaterialApp(
            home: MoreScreen(updateService: fakeUpdateService),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('more_update_available_pill')), findsOneWidget);
      expect(find.text('Nueva v1.6.0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('more_group_about')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_comprobar_actualizaciones')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_comprobar_actualizaciones')));
      await tester.pumpAndSettle();

      expect(find.text('Actualización lista'), findsOneWidget);
      expect(find.text('Duplicar gasto disponible.'), findsOneWidget);
    });

    testWidgets('Cuenta vinculada muestra botón circular de sincronizar y caja de error en permission-denied', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(createWidgetUnderTest(customUser: FakeTestUser()));
      await tester.pumpAndSettle();

      final btnSync = find.byKey(const Key('btn_sincronizar_cuenta'));
      final btnAjustes = find.byKey(const Key('btn_ajustes_cuenta'));
      expect(btnSync, findsOneWidget);
      expect(btnAjustes, findsOneWidget);
      expect(find.text('Sincronización activa'), findsOneWidget);

      await tester.tap(btnSync);
      await tester.pump();
      expect(gastoProvider.manualSyncCalls, equals(1));

      gastoProvider.fakeSyncNotifier.value = const SyncState.error(
        message: 'Actualiza Rinde Más desde Google Play para seguir respaldando tus gastos.',
        errorCode: 'permission-denied',
        consecutiveFailures: 1,
      );
      await tester.pump();

      expect(find.text('Actualización requerida'), findsOneWidget);
      expect(find.byKey(const Key('more_sync_error_box')), findsOneWidget);
      expect(find.text('Google Play'), findsOneWidget);
    });
  });
}

