import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'providers/gasto_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/scan_queue_provider.dart';
import 'providers/chat_provider.dart';
import 'services/notification_service.dart';
import 'ui/screens/main_screen.dart';
import 'services/sync_service.dart';

/// Punto de entrada oficial de Rinde Más.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar Edge-to-Edge nativo y barras del sistema transparentes (Android 15+)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase initialize error: $e");
  }

  try {
    // Intentar restaurar sesión de Google de forma silenciosa al iniciar
    final syncService = SyncService();
    await syncService.intentarLoginSilencioso();

    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint("Error signing in: $e");
  }

  // Inicializar Notificaciones Locales, Broadcast FCM y programar recordatorios
  try {
    await NotificationService.instance.initialize();
    await NotificationService.instance.initializeFirebaseMessaging();
    await NotificationService.instance.recordActivityAndReschedule();
  } catch (e) {
    debugPrint("Error initializing notifications: $e");
  }

  runApp(const GastoScanApp());
}

class GastoScanApp extends StatelessWidget {
  const GastoScanApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => GastoProvider()),
        ChangeNotifierProvider(create: (_) => ScanQueueProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'Rinde Más',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainScreen(),
      ),
    );
  }
}
