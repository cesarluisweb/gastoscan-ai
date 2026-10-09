import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/constants/app_constants.dart';

/// Servicio centralizado de notificaciones locales de "Rinde Más".
/// Administra los recordatorios automáticos de inactividad (R4) tras 7 días
/// sin registrar gastos o abrir la app, y alertas de facturas pendientes de revisión.
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
      'Notificaciones automáticas si no registras gastos en 7 días';

  static const String defaultNotificationTitle = 'Presupuesto al día';
  static const String defaultNotificationBody =
      'Han pasado 7 días sin registrar gastos. Revisa tus comprobantes para mantener tu presupuesto al día.';

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

  // Manejo de Deep-linking y Cold Start
  String? _initialPayload;
  String? get initialPayload => _initialPayload;

  final ValueNotifier<String?> selectedPayloadNotifier = ValueNotifier<String?>(null);

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
          if (response.payload != null && response.payload!.isNotEmpty) {
            selectedPayloadNotifier.value = response.payload;
          }
        },
      );
      initialized = result ?? false;

      // Soporte para Cold Start (arranque en frío con app cerrada)
      final launchDetails = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse?.payload != null) {
        _initialPayload = launchDetails.notificationResponse!.payload;
        selectedPayloadNotifier.value = _initialPayload;
        debugPrint('NotificationService: Cold start desde notificación con payload: $_initialPayload');
      }

      if (requestPermission) {
        await requestPermissions();
      }
    } catch (e) {
      debugPrint('NotificationService: Inicialización en plataforma no disponible: $e');
    }

    _isInitialized = true;
    return initialized;
  }

  /// Limpia el payload consumido tras navegar.
  void clearPayload() {
    _initialPayload = null;
    selectedPayloadNotifier.value = null;
  }

  /// Verifica si las notificaciones están habilitadas en las preferencias de usuario.
  Future<bool> _sonRecordatoriosHabilitados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(AppConstants.prefRecordatoriosActivos) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Solicita los permisos necesarios en Android (13+) e iOS.
  Future<void> requestPermissions() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
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
  /// (por defecto 7 días). Cancela siempre cualquier notificación previa antes.
  Future<void> scheduleInactivityReminder({
    Duration duration = const Duration(days: 7),
    String title = defaultNotificationTitle,
    String body = defaultNotificationBody,
  }) async {
    // 1. Cancelar cualquier recordatorio previo
    await cancelInactivityReminder();

    // 2. Verificar preferencia de usuario
    final habilitadas = await _sonRecordatoriosHabilitados();
    if (!habilitadas) {
      return;
    }

    // 3. Calcular la fecha objetivo
    final scheduledDate = DateTime.now().add(duration);
    _lastScheduledTime = scheduledDate;
    _lastScheduledDuration = duration;
    _isReminderScheduled = true;

    // 4. Programar la notificación local
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
        payload: 'inactivity_reminder',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService: Excepción al programar recordatorio: $e');
    }
  }

  /// Registra la actividad del usuario (ej. abrir la app o guardar un gasto)
  /// y reinicia la cuenta regresiva del recordatorio a 7 días.
  Future<void> recordActivityAndReschedule() async {
    _lastActivityTime = DateTime.now();
    await scheduleInactivityReminder(duration: const Duration(days: 7));
  }

  // Estado interno para control de recordatorio de pendientes
  int? _scheduledPendingCount;
  DateTime? _scheduledPendingTime;

  /// Cancela cualquier recordatorio de facturas pendientes de revisión.
  Future<void> cancelPendingReviewReminder() async {
    try {
      await _notificationsPlugin.cancel(1002);
    } catch (e) {
      debugPrint('NotificationService: Excepción al cancelar recordatorio de pendientes: $e');
    }
    _scheduledPendingCount = null;
    _scheduledPendingTime = null;
  }

  /// Programa un recordatorio para revisar facturas pendientes.
  /// Si ya hay una alarma programada para la misma cantidad de facturas y no ha vencido,
  /// mantiene la hora para evitar posponerla en bucle cada vez que la app consulta la cola.
  Future<void> schedulePendingReviewReminder({
    Duration duration = const Duration(hours: 2),
    int count = 1,
  }) async {
    final habilitadas = await _sonRecordatoriosHabilitados();
    if (!habilitadas) {
      await cancelPendingReviewReminder();
      return;
    }

    if (_scheduledPendingCount == count &&
        _scheduledPendingTime != null &&
        _scheduledPendingTime!.isAfter(DateTime.now())) {
      // Ya programado para esta misma cantidad de facturas sin expirar; no reiniciar el reloj
      return;
    }

    await cancelPendingReviewReminder();

    final scheduledDate = DateTime.now().add(duration);
    _scheduledPendingCount = count;
    _scheduledPendingTime = scheduledDate;

    try {
      final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'pending_reviews',
        'Facturas Pendientes',
        channelDescription: 'Recordatorios para revisar facturas procesadas',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final facturaTexto = count == 1 ? '1 factura esperando' : '$count facturas esperando';

      await _notificationsPlugin.zonedSchedule(
        1002,
        'Facturas listas para revisar',
        'Tienes $facturaTexto revisión para sumarse a este mes.',
        scheduledTzDate,
        notificationDetails,
        payload: 'pending_reviews',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService: Excepción al programar recordatorio de pendientes: $e');
    }
  }
}
