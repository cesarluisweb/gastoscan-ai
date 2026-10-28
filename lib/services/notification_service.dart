import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/constants/app_constants.dart';

/// Handler top-level para mensajes de Firebase Cloud Messaging en segundo plano.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('NotificationService: FCM background message recibido: ${message.messageId}');
}

/// Servicio centralizado de notificaciones locales y push de "Rinde Más".
/// Administra:
/// 1. Recordatorios de inactividad a 30 días (R4).
/// 2. Recordatorios quincenales de compras (sábados 18:30) con mensajes rotativos del Asistente IA.
/// 3. Alertas de facturas pendientes de revisión.
/// 4. Notificaciones masivas a voluntad (Broadcast) vía Firebase Cloud Messaging.
class NotificationService {
  static NotificationService _instance = NotificationService._internal();

  /// Acceso a la instancia única del servicio.
  static NotificationService get instance => _instance;

  /// Permite inyectar una instancia personalizada para pruebas unitarias.
  @visibleForTesting
  static set instance(NotificationService service) => _instance = service;

  FlutterLocalNotificationsPlugin _notificationsPlugin;
  FirebaseMessaging? _firebaseMessaging;

  // Constantes de canal e identificación para Inactividad
  static const int inactivityNotificationId = AppConstants.inactivityNotificationId;
  static const String inactivityChannelId = AppConstants.channelInactivityId;
  static const String inactivityChannelName = AppConstants.channelInactivityName;
  static const String inactivityChannelDesc = AppConstants.channelInactivityDesc;

  static const String defaultNotificationTitle = AppConstants.defaultInactivityTitle;
  static const String defaultNotificationBody = AppConstants.defaultInactivityBody;

  // Constantes de canal e identificación para Compras Quincenales
  static const int weekendNotificationId = AppConstants.weekendReminderNotificationId;
  static const String weekendChannelId = AppConstants.channelWeekendId;
  static const String weekendChannelName = AppConstants.channelWeekendName;
  static const String weekendChannelDesc = AppConstants.channelWeekendDesc;

  // Constantes de canal e identificación para Broadcast
  static const int broadcastNotificationId = AppConstants.broadcastNotificationId;
  static const String broadcastChannelId = AppConstants.channelBroadcastId;
  static const String broadcastChannelName = AppConstants.channelBroadcastName;
  static const String broadcastChannelDesc = AppConstants.channelBroadcastDesc;

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

  bool _isWeekendReminderScheduled = false;
  bool get isWeekendReminderScheduled => _isWeekendReminderScheduled;
  DateTime? _lastWeekendScheduledTime;
  DateTime? get lastWeekendScheduledTime => _lastWeekendScheduledTime;

  // Manejo de Deep-linking y Cold Start
  String? _initialPayload;
  String? get initialPayload => _initialPayload;

  final ValueNotifier<String?> selectedPayloadNotifier = ValueNotifier<String?>(null);

  NotificationService._internal({FlutterLocalNotificationsPlugin? plugin, FirebaseMessaging? messaging})
      : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _firebaseMessaging = messaging;

  /// Constructor visible para pruebas unitarias.
  @visibleForTesting
  NotificationService.test({FlutterLocalNotificationsPlugin? plugin, FirebaseMessaging? messaging})
      : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _firebaseMessaging = messaging;

  /// Constructor fábrica que retorna la instancia compartida o una con plugin personalizado.
  factory NotificationService({FlutterLocalNotificationsPlugin? plugin, FirebaseMessaging? messaging}) {
    if (plugin != null || messaging != null) {
      return NotificationService._internal(plugin: plugin, messaging: messaging);
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

  /// Inicializa Firebase Cloud Messaging (FCM) para recibir notificaciones Broadcast.
  Future<void> initializeFirebaseMessaging({FirebaseMessaging? messaging}) async {
    try {
      if (messaging != null) {
        _firebaseMessaging = messaging;
      } else {
        if (Firebase.apps.isNotEmpty) {
          _firebaseMessaging = FirebaseMessaging.instance;
        }
      }

      if (_firebaseMessaging == null) return;

      // 1. Solicitar permisos de notificación en iOS y Android 13+
      await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. Suscribirse al topic general por defecto si está activo
      final prefs = await SharedPreferences.getInstance();
      final bool anunciosActivos = prefs.getBool(AppConstants.prefAnunciosActivos) ?? true;
      if (anunciosActivos) {
        await _firebaseMessaging!.subscribeToTopic(AppConstants.fcmTopicGeneral);
        debugPrint('NotificationService: Suscrito a topic FCM: ${AppConstants.fcmTopicGeneral}');
      }

      // 3. Escuchar notificaciones cuando la app está abierta en primer plano (foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('NotificationService: FCM Foreground recibido: ${message.notification?.title}');
        _mostrarNotificacionBroadcastLocal(message);
      });

      // 4. Manejar apertura de la app desde notificación en segundo plano
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('NotificationService: App abierta desde FCM push: ${message.messageId}');
        final payload = message.data['payload'] ?? 'broadcast_opened';
        selectedPayloadNotifier.value = payload;
      });

      // 5. Manejar arranque en frío desde FCM si estaba cerrada
      final initialMessage = await _firebaseMessaging!.getInitialMessage();
      if (initialMessage != null) {
        final payload = initialMessage.data['payload'] ?? 'broadcast_opened';
        _initialPayload = payload;
        selectedPayloadNotifier.value = payload;
        debugPrint('NotificationService: Cold start desde FCM con payload: $payload');
      }
    } catch (e) {
      debugPrint('NotificationService: Inicialización FCM omitida o falló: $e');
    }
  }

  /// Suscribe el dispositivo al topic de difusión general en Firebase.
  Future<void> subscribeToBroadcastTopic() async {
    try {
      if (_firebaseMessaging != null) {
        await _firebaseMessaging!.subscribeToTopic(AppConstants.fcmTopicGeneral);
      } else if (Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.subscribeToTopic(AppConstants.fcmTopicGeneral);
      }
    } catch (e) {
      debugPrint('NotificationService: Error suscribiendo a topic: $e');
    }
  }

  /// Desuscribe el dispositivo del topic de difusión general en Firebase.
  Future<void> unsubscribeFromBroadcastTopic() async {
    try {
      if (_firebaseMessaging != null) {
        await _firebaseMessaging!.unsubscribeFromTopic(AppConstants.fcmTopicGeneral);
      } else if (Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(AppConstants.fcmTopicGeneral);
      }
    } catch (e) {
      debugPrint('NotificationService: Error desuscribiendo de topic: $e');
    }
  }

  /// Muestra una notificación local en Android cuando llega un push con la app en primer plano.
  Future<void> _mostrarNotificacionBroadcastLocal(RemoteMessage message) async {
    try {
      final title = message.notification?.title ?? message.data['titulo'] ?? 'Aviso de Rinde Más';
      final body = message.notification?.body ?? message.data['mensaje'] ?? '';

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        broadcastChannelId,
        broadcastChannelName,
        channelDescription: broadcastChannelDesc,
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

      await _notificationsPlugin.show(
        broadcastNotificationId,
        title,
        body,
        notificationDetails,
        payload: message.data['payload'] ?? 'broadcast_opened',
      );
    } catch (e) {
      debugPrint('NotificationService: Error al mostrar banner local FCM: $e');
    }
  }

  /// Limpia el payload consumido tras navegar.
  void clearPayload() {
    _initialPayload = null;
    selectedPayloadNotifier.value = null;
  }

  /// Verifica si las notificaciones de inactividad están habilitadas.
  Future<bool> _sonRecordatoriosHabilitados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(AppConstants.prefRecordatoriosActivos) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Verifica si el recordatorio quincenal de fin de semana está habilitado.
  Future<bool> _esRecordatorioFinDeSemanaHabilitado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(AppConstants.prefRecordatorioFinDeSemana) ?? true;
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
  /// (por defecto 30 días, respetando el descanso del usuario).
  Future<void> scheduleInactivityReminder({
    Duration duration = const Duration(days: 30),
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

  // --- RECORDATORIO QUINCENAL DE FIN DE SEMANA ---

  /// Calcula la próxima fecha de fin de semana (sábado a las 18:30) asegurando cadencia quincenal.
  static DateTime calcularProximaFechaQuincenal(DateTime now, {DateTime? ultimoProgramado}) {
    int daysUntilSaturday = (DateTime.saturday - now.weekday) % 7;
    DateTime nextSaturday = DateTime(
      now.year,
      now.month,
      now.day + daysUntilSaturday,
      18,
      30,
    );

    // Si hoy es sábado y ya pasaron las 18:30, el próximo sábado es dentro de 7 días
    if (daysUntilSaturday == 0 && now.isAfter(nextSaturday)) {
      nextSaturday = nextSaturday.add(const Duration(days: 7));
    }

    // Si ya hubo un recordatorio programado o ejecutado recientemente (< 11 días),
    // saltar al sábado siguiente para mantener la cadencia quincenal (~14 días)
    if (ultimoProgramado != null) {
      final diferencia = nextSaturday.difference(ultimoProgramado).inDays.abs();
      if (diferencia < 10) {
        nextSaturday = nextSaturday.add(const Duration(days: 7));
      }
    }

    return nextSaturday;
  }

  /// Cancela el recordatorio quincenal de fin de semana.
  Future<void> cancelBiweeklyWeekendReminder() async {
    try {
      await _notificationsPlugin.cancel(weekendNotificationId);
    } catch (e) {
      debugPrint('NotificationService: Excepción al cancelar recordatorio fin de semana: $e');
    }
    _isWeekendReminderScheduled = false;
    _lastWeekendScheduledTime = null;
  }

  /// Programa el recordatorio quincenal de compras de fin de semana (sábado 18:30)
  /// con rotación de mensajes del Asistente IA.
  Future<void> scheduleBiweeklyWeekendReminder({
    DateTime? targetDate,
    String? customTitle,
    String? customBody,
  }) async {
    await cancelBiweeklyWeekendReminder();

    final habilitado = await _esRecordatorioFinDeSemanaHabilitado();
    if (!habilitado) return;

    final prefs = await SharedPreferences.getInstance();

    // 1. Determinar fecha objetivo
    DateTime scheduledDate;
    if (targetDate != null) {
      scheduledDate = targetDate;
    } else {
      DateTime? ultimoProgramado;
      final ultimoTs = prefs.getInt(AppConstants.prefUltimoRecordatorioFinDeSemanaTs);
      if (ultimoTs != null && ultimoTs > 0) {
        ultimoProgramado = DateTime.fromMillisecondsSinceEpoch(ultimoTs);
      }
      scheduledDate = calcularProximaFechaQuincenal(DateTime.now(), ultimoProgramado: ultimoProgramado);
    }

    _lastWeekendScheduledTime = scheduledDate;
    _isWeekendReminderScheduled = true;
    await prefs.setInt(AppConstants.prefUltimoRecordatorioFinDeSemanaTs, scheduledDate.millisecondsSinceEpoch);

    // 2. Seleccionar el mensaje rotativo del Asistente IA
    String title = customTitle ?? '';
    String body = customBody ?? '';

    if (title.isEmpty || body.isEmpty) {
      List<Map<String, String>> pool = AppConstants.defaultMensajesAsistenteQuincenal;
      final cachedJson = prefs.getString(AppConstants.prefCachedMensajesQuincenalesJson);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson) as List;
          final customList = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
          if (customList.isNotEmpty) {
            pool = customList;
          }
        } catch (_) {}
      }

      int indice = prefs.getInt(AppConstants.prefIndiceMensajeRotativo) ?? 0;
      if (indice >= pool.length) indice = 0;

      final selectedMsg = pool[indice];
      title = selectedMsg['titulo'] ?? 'Mantén tu presupuesto al día';
      body = selectedMsg['cuerpo'] ?? 'Aquí estoy para ayudarte: si hiciste compras hoy, tómale foto a los comprobantes.';

      // Avanzar al siguiente mensaje para la próxima quincena
      await prefs.setInt(AppConstants.prefIndiceMensajeRotativo, (indice + 1) % pool.length);
    }

    // 3. Programar la notificación local
    try {
      final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        weekendChannelId,
        weekendChannelName,
        channelDescription: weekendChannelDesc,
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

      await _notificationsPlugin.zonedSchedule(
        weekendNotificationId,
        title,
        body,
        scheduledTzDate,
        notificationDetails,
        payload: 'weekend_reminder',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('NotificationService: Recordatorio quincenal programado para: $scheduledDate');
    } catch (e) {
      debugPrint('NotificationService: Excepción al programar recordatorio fin de semana: $e');
    }
  }

  /// Registra la actividad del usuario (ej. abrir la app o guardar un gasto),
  /// reinicia el recordatorio de inactividad a 30 días y asegura la programación quincenal.
  Future<void> recordActivityAndReschedule() async {
    _lastActivityTime = DateTime.now();
    await scheduleInactivityReminder(duration: const Duration(days: 30));
    await scheduleBiweeklyWeekendReminder();
  }

  // --- RECORDATORIO DE FACTURAS PENDIENTES DE REVISIÓN ---

  int? _scheduledPendingCount;
  DateTime? _scheduledPendingTime;

  /// Cancela cualquier recordatorio de facturas pendientes de revisión.
  Future<void> cancelPendingReviewReminder() async {
    try {
      await _notificationsPlugin.cancel(AppConstants.pendingReviewNotificationId);
    } catch (e) {
      debugPrint('NotificationService: Excepción al cancelar recordatorio de pendientes: $e');
    }
    _scheduledPendingCount = null;
    _scheduledPendingTime = null;
  }

  /// Programa un recordatorio para revisar facturas pendientes.
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

      final titulo = count == 1 ? 'Factura lista para revisar' : 'Facturas listas para revisar';
      final facturaTexto = count == 1 ? '1 factura esperando' : '$count facturas esperando';

      await _notificationsPlugin.zonedSchedule(
        AppConstants.pendingReviewNotificationId,
        titulo,
        'Tienes $facturaTexto revisión para sumarse a este mes.',
        scheduledTzDate,
        notificationDetails,
        payload: 'pending_reviews',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService: Excepción al programar recordatorio de pendientes: $e');
    }
  }
}
