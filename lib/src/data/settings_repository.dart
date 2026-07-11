import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Small key/value store for app preferences and attached-service credentials
/// (theme, Gemini key, Telegram bot config, practice defaults). Backed by its
/// own Hive box so it stays independent of the knowledge-items store and works
/// the same on mobile and web.
class SettingsRepository {
  SettingsRepository(this._box);

  static const String boxName = 'settings';

  // Keys.
  static const String kThemeMode = 'themeMode';
  static const String kGeminiApiKey = 'geminiApiKey';
  static const String kTelegramBotToken = 'telegramBotToken';
  static const String kTelegramChatId = 'telegramChatId';
  static const String kTelegramUser = 'telegramUser';
  static const String kTelegramPinnedMessageId = 'telegramPinnedMessageId';
  static const String kPracticeMethod = 'practiceMethod';
  static const String kPracticeScope = 'practiceScope';
  static const String kReminderEnabled = 'reminderEnabled';
  static const String kReminderHour = 'reminderHour';
  static const String kReminderMinute = 'reminderMinute';

  final Box _box;

  static Future<SettingsRepository> open() async {
    final box = await Hive.openBox(boxName);
    return SettingsRepository(box);
  }

  String? getString(String key) => _box.get(key) as String?;

  Future<void> setString(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _box.delete(key);
    } else {
      await _box.put(key, value);
    }
  }

  int? getInt(String key) => (_box.get(key) as num?)?.toInt();

  Future<void> setInt(String key, int? value) async {
    if (value == null) {
      await _box.delete(key);
    } else {
      await _box.put(key, value);
    }
  }
}
