import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../providers/settings_providers.dart';
import 'notification_service.dart';

/// Bound in `main` to the initialized service via a ProviderScope override.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('notificationServiceProvider must be overridden');
});

/// User's reminder preference: whether a daily nudge is on and at what time.
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

class ReminderNotifier extends Notifier<ReminderSettings> {
  SettingsRepository get _s => ref.read(settingsRepositoryProvider);
  NotificationService get _service => ref.read(notificationServiceProvider);

  @override
  ReminderSettings build() {
    return ReminderSettings(
      enabled: _s.getString(SettingsRepository.kReminderEnabled) == 'true',
      hour: _s.getInt(SettingsRepository.kReminderHour) ?? 9,
      minute: _s.getInt(SettingsRepository.kReminderMinute) ?? 0,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _service.requestPermission();
      if (!granted) return;
      await _service.scheduleDailyReminder(state.hour, state.minute);
    } else {
      await _service.cancelDailyReminder();
    }
    await _s.setString(
        SettingsRepository.kReminderEnabled, enabled ? 'true' : 'false');
    state = state.copyWith(enabled: enabled);
  }

  Future<void> setTime(int hour, int minute) async {
    await _s.setInt(SettingsRepository.kReminderHour, hour);
    await _s.setInt(SettingsRepository.kReminderMinute, minute);
    state = state.copyWith(hour: hour, minute: minute);
    if (state.enabled) {
      await _service.scheduleDailyReminder(hour, minute);
    }
  }
}

final reminderProvider =
    NotifierProvider<ReminderNotifier, ReminderSettings>(ReminderNotifier.new);
