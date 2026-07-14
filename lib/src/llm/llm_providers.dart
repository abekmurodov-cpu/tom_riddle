import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../providers/settings_providers.dart';
import 'gemini_provider.dart';
import 'llm_provider.dart';

/// The currently attached Gemini API key (null when detached), persisted in
/// settings. Writing through this notifier is how the user attaches/detaches.
class GeminiKeyNotifier extends Notifier<String?> {
  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  @override
  String? build() => _settings.getString(SettingsRepository.kGeminiApiKey);

  Future<void> attach(String key) async {
    final trimmed = key.trim();
    await _settings.setString(SettingsRepository.kGeminiApiKey, trimmed);
    state = trimmed.isEmpty ? null : trimmed;
  }

  Future<void> detach() async {
    await _settings.setString(SettingsRepository.kGeminiApiKey, null);
    state = null;
  }
}

final geminiKeyProvider =
    NotifierProvider<GeminiKeyNotifier, String?>(GeminiKeyNotifier.new);

/// Gemini models the user can pick from in Settings.
const kGeminiModels = <String>[
  'gemini-2.5-flash',
  'gemini-3.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-3.1-flash-lite',
];

const kDefaultGeminiModel = 'gemini-3.1-flash-lite';

/// The selected Gemini model, persisted in settings.
class GeminiModelNotifier extends Notifier<String> {
  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  @override
  String build() =>
      _settings.getString(SettingsRepository.kGeminiModel) ?? kDefaultGeminiModel;

  Future<void> set(String model) async {
    await _settings.setString(SettingsRepository.kGeminiModel, model);
    state = model;
  }
}

final geminiModelProvider =
    NotifierProvider<GeminiModelNotifier, String>(GeminiModelNotifier.new);

/// The active LLM, or null when no provider is attached. UI features that use
/// the LLM watch this and hide/fall back when it is null.
final llmProvider = Provider<LlmProvider?>((ref) {
  final key = ref.watch(geminiKeyProvider);
  if (key == null || key.isEmpty) return null;
  final model = ref.watch(geminiModelProvider);
  return GeminiProvider(apiKey: key, model: model);
});
