import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../llm/llm_providers.dart';
import '../notifications/notification_providers.dart';
import '../providers/knowledge_providers.dart';
import '../providers/settings_providers.dart';
import '../sync/sync_providers.dart';
import '../sync/telegram_sync_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _ThemeSection(),
          if (!kIsWeb) _RemindersSection(),
          _LlmSection(),
          _TelegramSection(),
        ],
      ),
    );
  }
}

/// Reusable section header used across the settings screen.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child,
        const Divider(height: 24),
      ],
    );
  }
}

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SettingsSection(
      title: 'Appearance',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('System'),
              icon: Icon(Icons.brightness_auto),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) =>
              ref.read(themeModeProvider.notifier).set(s.first),
        ),
      ),
    );
  }
}

class _RemindersSection extends ConsumerWidget {
  const _RemindersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder = ref.watch(reminderProvider);
    final notifier = ref.read(reminderProvider.notifier);
    return SettingsSection(
      title: 'Reminders',
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Daily review reminder'),
            subtitle: const Text('A nudge to review your notes'),
            value: reminder.enabled,
            onChanged: notifier.setEnabled,
          ),
          ListTile(
            enabled: reminder.enabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Reminder time'),
            trailing: Text(reminder.time.format(context)),
            onTap: reminder.enabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: reminder.time,
                    );
                    if (picked != null) {
                      await notifier.setTime(picked.hour, picked.minute);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _LlmSection extends ConsumerStatefulWidget {
  const _LlmSection();

  @override
  ConsumerState<_LlmSection> createState() => _LlmSectionState();
}

class _LlmSectionState extends ConsumerState<_LlmSection> {
  final _keyController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    await ref.read(geminiKeyProvider.notifier).attach(key);
    _keyController.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final key = ref.watch(geminiKeyProvider);
    final attached = key != null && key.isNotEmpty;

    return SettingsSection(
      title: 'AI provider',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: attached
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF2E9E4F)),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Gemini attached')),
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(geminiKeyProvider.notifier).detach(),
                        icon: const Icon(Icons.link_off),
                        label: const Text('Detach'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: ref.watch(geminiModelProvider),
                        items: [
                          for (final m in kGeminiModels)
                            DropdownMenuItem(value: m, child: Text(m)),
                        ],
                        onChanged: (m) {
                          if (m != null) {
                            ref.read(geminiModelProvider.notifier).set(m);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attach Gemini to auto-expand notes, generate quizzes, '
                    'grade typed answers, and suggest categories.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Gemini API key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _attach,
                      icon: const Icon(Icons.link),
                      label: const Text('Attach'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TelegramSection extends ConsumerStatefulWidget {
  const _TelegramSection();

  @override
  ConsumerState<_TelegramSection> createState() => _TelegramSectionState();
}

class _TelegramSectionState extends ConsumerState<_TelegramSection> {
  final _tokenController = TextEditingController();
  final _chatController = TextEditingController();
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _tokenController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearBusy() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = null;
    });
  }

  Future<void> _attach() async {
    final token = _tokenController.text.trim();
    final chatId = _chatController.text.trim();
    if (token.isEmpty || chatId.isEmpty) return;
    setState(() {
      _busy = true;
      _status = 'Validating bot…';
    });
    try {
      // Validate the token before persisting.
      final username =
          await TelegramSyncService(botToken: token, chatId: chatId).getMe();
      await ref.read(telegramConfigProvider.notifier).attach(
            TelegramConfig(botToken: token, chatId: chatId, user: username),
          );
      _tokenController.clear();
      _chatController.clear();
      _report('Attached @$username');
    } catch (e) {
      _report('Could not attach: $e');
    } finally {
      _clearBusy();
    }
  }

  Future<void> _syncNow() async {
    final controller = ref.read(syncControllerProvider);
    if (controller == null) return;
    setState(() {
      _busy = true;
      _status = 'Syncing…';
    });
    try {
      final summary = await controller.syncNow();
      // Reload the list so merged remote notes appear immediately.
      ref.invalidate(knowledgeListProvider);
      _report('Synced ${summary.noteCount} notes');
    } catch (e) {
      _report('Sync failed: $e');
    } finally {
      _clearBusy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(telegramConfigProvider);
    final attached = config != null;

    return SettingsSection(
      title: 'Sync (Telegram)',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: attached
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_done, color: Color(0xFF2E9E4F)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Connected${config.user == null ? '' : ' · @${config.user}'}\nChat ${config.chatId}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _syncNow,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.sync),
                        label: Text(_status ?? 'Sync now'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => ref
                                .read(telegramConfigProvider.notifier)
                                .detach(),
                        icon: const Icon(Icons.link_off),
                        label: const Text('Detach'),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sync across devices via a Telegram bot. Create a bot with '
                    '@BotFather, make a private channel, add the bot as an admin, '
                    'and paste the token + chat id below. Note: the bot token is '
                    'stored on-device.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tokenController,
                    decoration: const InputDecoration(
                      labelText: 'Bot token',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      labelText: 'Chat / channel id',
                      hintText: 'e.g. @my_channel or -1001234567890',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _attach,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.link),
                      label: Text(_status ?? 'Attach'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
