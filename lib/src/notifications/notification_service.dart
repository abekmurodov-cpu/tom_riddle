import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Reminders are scheduled in this zone (Uzbekistan, UTC+5).
const String _timeZone = 'Asia/Tashkent';

/// Schedules local "time to review" reminders on Android and macOS — a safe
/// no-op on web (the plugin has no web implementation).
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const int _dailyReminderId = 1001;
  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'review_reminders',
      'Review reminders',
      channelDescription: 'Daily nudges to review your knowledge',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    macOS: DarwinNotificationDetails(),
  );

  /// Initializes the plugin and the timezone database. Call once at startup.
  Future<void> init() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_timeZone));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  /// Requests notification permission (Android 13+, macOS). Returns true if
  /// granted (or if the platform doesn't gate it).
  Future<bool> requestPermission() async {
    if (kIsWeb || !_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (macos != null) {
      return await macos.requestPermissions(
              alert: true, badge: true, sound: true) ??
          true;
    }
    return false;
  }

  /// (Re)schedules a daily reminder at [hour]:[minute]. Prefers exact alarms so
  /// it fires on time; if the OS denies exact-alarm permission it falls back to
  /// inexact scheduling (which Android may delay to save battery).
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    if (kIsWeb || !_ready) return;
    await cancelDailyReminder();
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          _dailyReminderId,
          'Knowledge',
          'Time to review — your notes are waiting to challenge you.',
          _nextInstanceOf(hour, minute),
          _details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.time,
        );
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  Future<void> cancelDailyReminder() async {
    if (kIsWeb || !_ready) return;
    await _plugin.cancel(_dailyReminderId);
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
