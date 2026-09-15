## 2026-09-15T21:08:11Z
You are Worker 4 for Milestone 4 (R4: Recordatorios de Inactividad - Push Locales) of "Rinde Más" (Flutter App).

Your working directory is:
H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\worker_m4_r4

Read these files before starting:
- Authoritative User Request: H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\ORIGINAL_REQUEST.md
- Master Project Plan: H:\My Drive\Documentos\Trabajo\Control de gastos VE\PROJECT.md
- Architecture Skill: H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\skills\flutter-apply-architecture-best-practices\SKILL.md

Workspace Root:
H:\My Drive\Documentos\Trabajo\Control de gastos VE

Project Technical Rules:
- Google Drive sync: Never run concurrent npm/build processes if applicable.
- If using PowerShell Set-Content, ALWAYS use `-Encoding UTF8`.

Task Scope:
Implement R4: Recordatorios de Inactividad (Push Locales):
1. Dependencies & Android Permissions:
   - Check `pubspec.yaml`: ensure `flutter_local_notifications` (e.g. `^17.2.2` or compatible) and `timezone: ^0.9.4` are declared in dependencies.
   - Check `android/app/src/main/AndroidManifest.xml`: ensure all required permissions are declared:
     - `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
     - `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>`
     - `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>`
     - `<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>`
     - `<uses-permission android:name="android.permission.VIBRATE"/>`
     - Add scheduled notification receiver or boot receiver in `<application>` tag if standard for flutter_local_notifications.
2. Notification Service Implementation:
   - Implement `NotificationService` (in `lib/services/notification_service.dart` or `lib/core/services/notification_service.dart`):
     - Initialize `FlutterLocalNotificationsPlugin` with Android initialization settings (`@mipmap/ic_launcher` or app icon) and Darwin/iOS settings.
     - Set up Android notification channel (e.g. id: `'inactivity_reminders'`, name: `'Recordatorios de Inactividad'`, description: `'Notificaciones automáticas si no registras gastos en 3 días'`, importance: `Importance.high`, priority: `Priority.high`).
     - Method `scheduleInactivityReminder({Duration duration = const Duration(days: 3)})`:
       - Cancels any existing scheduled inactivity notification.
       - Schedules a notification to fire after 3 days (or custom duration for testing).
       - Notification message: friendly reminder to register expenses (e.g. title: "¡Te extrañamos en Rinde Más!", body: "Han pasado 3 días desde tu último registro. ¡No olvides anotar tus comprobantes!").
     - Method `cancelInactivityReminder()`.
     - Method `recordActivityAndReschedule()`: resets the 3-day inactivity countdown.
3. Integration with App Lifecycle & Expense Logging:
   - In `main.dart` or `DashboardScreen.initState`: initialize `NotificationService` and trigger `recordActivityAndReschedule()`.
   - In `GastoProvider` (when a new expense is successfully saved): trigger `recordActivityAndReschedule()`.
4. Acceptance Criteria:
   - "El código compila correctamente con los permisos de Android requeridos para notificaciones locales, y existe la función de scheduling para 3 días."
5. Tests:
   - Create unit tests in `test/services/notification_service_test.dart` verifying:
     - 3-day scheduling function defaults to `Duration(days: 3)`.
     - Rescheduling logic cancels previous notification and schedules new one.
     - Integration triggers on expense registration.
   - Verify Android permissions in `android/app/src/main/AndroidManifest.xml`.
   - Verify 100% syntax balance.
