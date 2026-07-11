import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../providers/knowledge_providers.dart';
import '../providers/settings_providers.dart';
import 'sync_controller.dart';
import 'telegram_sync_service.dart';

/// Telegram sync credentials the user supplied via "Attach Telegram".
class TelegramConfig {
  const TelegramConfig({
    required this.botToken,
    required this.chatId,
    this.user,
  });

  final String botToken;
  final String chatId;

  /// Display identity captured at attach time (bot username or account name).
  final String? user;
}

/// Persists the attached Telegram config; null when detached.
class TelegramConfigNotifier extends Notifier<TelegramConfig?> {
  SettingsRepository get _s => ref.read(settingsRepositoryProvider);

  @override
  TelegramConfig? build() {
    final token = _s.getString(SettingsRepository.kTelegramBotToken);
    final chatId = _s.getString(SettingsRepository.kTelegramChatId);
    if (token == null || chatId == null) return null;
    return TelegramConfig(
      botToken: token,
      chatId: chatId,
      user: _s.getString(SettingsRepository.kTelegramUser),
    );
  }

  Future<void> attach(TelegramConfig config) async {
    await _s.setString(SettingsRepository.kTelegramBotToken, config.botToken);
    await _s.setString(SettingsRepository.kTelegramChatId, config.chatId);
    await _s.setString(SettingsRepository.kTelegramUser, config.user);
    state = config;
  }

  Future<void> detach() async {
    await _s.setString(SettingsRepository.kTelegramBotToken, null);
    await _s.setString(SettingsRepository.kTelegramChatId, null);
    await _s.setString(SettingsRepository.kTelegramUser, null);
    state = null;
  }
}

final telegramConfigProvider =
    NotifierProvider<TelegramConfigNotifier, TelegramConfig?>(
  TelegramConfigNotifier.new,
);

/// The Telegram service for the attached config, or null when detached.
final telegramServiceProvider = Provider<TelegramSyncService?>((ref) {
  final config = ref.watch(telegramConfigProvider);
  if (config == null) return null;
  return TelegramSyncService(
    botToken: config.botToken,
    chatId: config.chatId,
  );
});

/// The sync controller, or null when no Telegram service is attached.
final syncControllerProvider = Provider<SyncController?>((ref) {
  final service = ref.watch(telegramServiceProvider);
  if (service == null) return null;
  return SyncController(
    repo: ref.read(knowledgeRepositoryProvider),
    images: ref.read(imageStoreProvider),
    service: service,
  );
});
