import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'providers/gasto_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/scan_queue_provider.dart';
import 'services/notification_service.dart';
import 'ui/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialize error: $e");
  }

  
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint("Error signing in anonymously: $e");
  }

  // Inicializar Notificaciones Locales y programar recordatorio de inactividad
  try {
    await NotificationService.instance.initialize();
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
