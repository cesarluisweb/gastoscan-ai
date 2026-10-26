import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/widgets/auth_modal_sheet.dart';

class FakeAuthGastoProvider extends GastoProvider {
  Completer<String?>? vincularCompleter;
  String? lastVincularEmail;
  String? lastVincularPassword;

  @override
  Future<String?> vincularConEmail(String email, String password, {bool descartarDatosLocales = false}) async {
    lastVincularEmail = email;
    lastVincularPassword = password;
    if (vincularCompleter != null) {
      return await vincularCompleter!.future;
    }
    return null;
  }

  @override
  Future<String?> iniciarSesionConEmail(String email, String password, {bool descartarDatosLocales = false}) async {
    return null;
  }
}

class FakeAuthSettingsProvider extends SettingsProvider {
  int loadSettingsCount = 0;

  FakeAuthSettingsProvider() : super(autoLoad: false);

  @override
  Future<void> loadSettings() async {
    loadSettingsCount++;
  }
}

void main() {
  group('AuthEmailDialog Tests (Geometría flotante, ciclo de vida y teclado)', () {
    late FakeAuthGastoProvider fakeGasto;
    late FakeAuthSettingsProvider fakeSettings;

    setUp(() {
      fakeGasto = FakeAuthGastoProvider();
      fakeSettings = FakeAuthSettingsProvider();
    });

    Widget createTestHarness({Widget? child}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<GastoProvider>.value(value: fakeGasto),
          ChangeNotifierProvider<SettingsProvider>.value(value: fakeSettings),
        ],
        child: MaterialApp(
          home: child ??
              Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('btn_open_auth'),
                    onPressed: () => mostrarModalAutenticacionEmail(ctx),
                    child: const Text('Abrir Auth'),
                  ),
                ),
              ),
        ),
      );
    }

    testWidgets('Geometría: se renderiza como Dialog centrado y flotante sobre scrim', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_open_auth')));
      await tester.pumpAndSettle();

      final dialogSurface = find.byKey(const Key('dialog_surface_auth'));
      expect(dialogSurface, findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);

      // Invariantes del diálogo flotante:
      // No está pegado ni arriba ni abajo (está centrado con espacio en ambos extremos)
      expect(tester.getTopLeft(dialogSurface).dy, greaterThan(20));
      expect(tester.getBottomLeft(dialogSurface).dy, lessThan(620));
    });

    testWidgets('Ciclo de vida: abrir y cerrar dos veces seguidas no genera excepciones ni fugas', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      // Primera apertura y cierre
      await tester.tap(find.byKey(const Key('btn_open_auth')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dialog_surface_auth')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dialog_surface_auth')), findsNothing);

      // Segunda apertura y cierre
      await tester.tap(find.byKey(const Key('btn_open_auth')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dialog_surface_auth')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dialog_surface_auth')), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Teclado abierto (300dp): sin desbordamientos de RenderFlex', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_open_auth')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog_surface_auth')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bloqueo de cierre tocando el barrier durante la carga', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.reset);

      fakeGasto.vincularCompleter = Completer<String?>();

      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_open_auth')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('auth_email_input')), 'usuario@correo.com');
      await tester.enterText(find.byKey(const Key('auth_password_input')), 'secreto123');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('auth_submit_btn')));
      await tester.pump(); // Inicia la carga

      // Verificar que está en carga
      expect(find.text('Sincronizando...'), findsOneWidget);

      // Tocar fuera del diálogo en el barrier (esquina superior izquierda)
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();

      // El diálogo DEBE seguir montado (PopScope bloquea el pop durante carga)
      expect(find.byKey(const Key('dialog_surface_auth')), findsOneWidget);

      // Completar la operación exitosamente
      fakeGasto.vincularCompleter!.complete(null);
      await tester.pumpAndSettle();

      // El diálogo se cerró tras finalizar con éxito y ejecutó loadSettings
      expect(find.byKey(const Key('dialog_surface_auth')), findsNothing);
      expect(fakeSettings.loadSettingsCount, 1);
    });
  });
}
