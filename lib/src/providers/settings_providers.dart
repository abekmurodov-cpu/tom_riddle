import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';

/// Bound to the concrete repository in `main` via a ProviderScope override,
/// mirroring [knowledgeRepositoryProvider].
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('settingsRepositoryProvider must be overridden');
});

/// Current theme mode, persisted in the settings box.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  @override
  ThemeMode build() {
    final stored = _settings.getString(SettingsRepository.kThemeMode);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _settings.setString(SettingsRepository.kThemeMode, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
