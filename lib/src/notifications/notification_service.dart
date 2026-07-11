import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules local "time to review" reminders. Android-only in practice —
/// every method is a safe no-op on web (the plugin has no web implementation).
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const int _dailyReminderId = 1001;
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'review_reminders',
    'Review reminders',
    channelDescription: 'Daily nudges to review your knowledge',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  /// Initializes the plugin and the timezone database. Call once at startup.
  Future<void> init() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to UTC if the device timezone can't be resolved.
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  /// Requests notification permission (Android 13+). Returns true if granted.
  Future<bool> requestPermission() async {
    if (kIsWeb || !_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// (Re)schedules a daily reminder at [hour]:[minute]. Uses inexact scheduling
  /// so no exact-alarm permission is needed.
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    if (kIsWeb || !_ready) return;
    await cancelDailyReminder();
    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Knowledge',
      'Time to review — your notes are waiting to challenge you.',
      _nextInstanceOf(hour, minute),
      const NotificationDetails(android: _androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
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
