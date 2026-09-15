import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Servicio centralizado de notificaciones locales de "Rinde Más".
/// Administra los recordatorios automáticos de inactividad (R4) tras 3 días
/// sin registrar gastos o abrir la app.
class NotificationService {
  static NotificationService _instance = NotificationService._internal();

  /// Acceso a la instancia única del servicio.
  static NotificationService get instance => _instance;

  /// Permite inyectar una instancia personalizada para pruebas unitarias.
  @visibleForTesting
  static set instance(NotificationService service) => _instance = service;

  FlutterLocalNotificationsPlugin _notificationsPlugin;

  // Constantes de canal e identificación
  static const int inactivityNotificationId = 1001;
  static const String inactivityChannelId = 'inactivity_reminders';
  static const String inactivityChannelName = 'Recordatorios de Inactividad';
  static const String inactivityChannelDesc =
      'Notificaciones automáticas si no registras gastos en 3 días';

  static const String defaultNotificationTitle = '¡Te extrañamos en Rinde Más!';
  static const String defaultNotificationBody =
      'Han pasado 3 días desde tu último registro. ¡No olvides registrar tus facturas!';

  // Estado interno para observabilidad y pruebas
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  DateTime? _lastActivityTime;
  DateTime? get lastActivityTime => _lastActivityTime;

  DateTime? _lastScheduledTime;
  DateTime? get lastScheduledTime => _lastScheduledTime;

  Duration? _lastScheduledDuration;
  Duration? get lastScheduledDuration => _lastScheduledDuration;

  bool _isReminderScheduled = false;
  bool get isReminderScheduled => _isReminderScheduled;

  NotificationService._internal({FlutterLocalNotificationsPlugin? plugin})
      : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Constructor visible para pruebas unitarias.
  @visibleForTesting
  NotificationService.test({FlutterLocalNotificationsPlugin? plugin})
      : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Constructor fábrica que retorna la instancia compartida o una con plugin personalizado.
  factory NotificationService({FlutterLocalNotificationsPlugin? plugin}) {
    if (plugin != null) {
      return NotificationService._internal(plugin: plugin);
    }
    return _instance;
  }

  /// Inicializa el plugin de notificaciones locales y la base de datos de zonas horarias.
  Future<bool> initialize({
    FlutterLocalNotificationsPlugin? plugin,
    bool requestPermission = true,
  }) async {
    if (plugin != null) {
      _notificationsPlugin = plugin;
    }

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('NotificationService: Error al inicializar timezone: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    bool initialized = false;
    try {
      final result = await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('NotificationService: Notificación pulsada: ${response.payload}');
        },
      );
      initialized = result ?? false;

      if (requestPermission) {
        await requestPermissions();
      }
    } catch (e) {
      debugPrint('NotificationService: Inicialización en plataforma no disponible: $e');
    }

    _isInitialized = true;
    return initialized;
  }

  /// Solicita los permisos necesarios en Android (13+) e iOS.
  Future<void> requestPermissions() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }

      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Error al solicitar permisos: $e');
    }
  }

  /// Cancela cualquier recordatorio de inactividad programado previamente.
  Future<void> cancelInactivityReminder() async {
    try {
      await _notificationsPlugin.cancel(inactivityNotificationId);
    } catch (e) {
      debugPrint('NotificationService: Excepción al cancelar recordatorio: $e');
    }
    _isReminderScheduled = false;
    _lastScheduledTime = null;
    _lastScheduledDuration = null;
  }

  /// Programa un recordatorio de inactividad a ejecutarse luego de [duration]
  /// (por defecto 3 días). Cancela siempre cualquier notificación previa antes.
  Future<void> scheduleInactivityReminder({
    Duration duration = const Duration(days: 3),
    String title = defaultNotificationTitle,
    String body = defaultNotificationBody,
  }) async {
    // 1. Cancelar cualquier recordatorio previo
    await cancelInactivityReminder();

    // 2. Calcular la fecha objetivo
    final scheduledDate = DateTime.now().add(duration);
    _lastScheduledTime = scheduledDate;
    _lastScheduledDuration = duration;
    _isReminderScheduled = true;

    // 3. Programar la notificación local
    try {
      final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        inactivityChannelId,
        inactivityChannelName,
        channelDescription: inactivityChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails darwinDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        inactivityNotificationId,
        title,
        body,
        scheduledTzDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService: Excepción al programar recordatorio: $e');
    }
  }

  /// Registra la actividad del usuario (ej. abrir la app o guardar un gasto)
  /// y reinicia la cuenta regresiva del recordatorio a 3 días.
  Future<void> recordActivityAndReschedule() async {
    _lastActivityTime = DateTime.now();
    await scheduleInactivityReminder(duration: const Duration(days: 3));
  }
}
