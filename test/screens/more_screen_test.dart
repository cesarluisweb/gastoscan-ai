import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/core/constants/app_colors.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/providers/chat_provider.dart';
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
  FakeGastoProvider() : super(autoLoad: false);

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

      await tester.tap(find.byKey(const Key('more_group_about')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sheet_surface_about')), findsOneWidget);
      expect(find.byKey(const Key('more_menu_check_updates')), findsOneWidget);
      expect(find.text('Buscar actualizaciones'), findsOneWidget);
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
  });
}

