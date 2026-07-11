import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/knowledge_providers.dart';
import '../sync/sync_providers.dart';
import 'home_screen.dart';
import 'notes_screen.dart';
import 'practice/practice_screen.dart';
import 'settings_screen.dart';

/// Top-level navigation: a persistent [NavigationBar] over four tabs. Each tab
/// hosts its own [Scaffold] (app bar / FAB), so screens keep their own chrome
/// while sharing the bottom bar. Tab state is kept alive with an [IndexedStack].
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Best-effort silent pull on startup when a sync backend is attached.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSync());
  }

  Future<void> _autoSync() async {
    final controller = ref.read(syncControllerProvider);
    if (controller == null) return;
    try {
      await controller.syncNow();
      if (mounted) ref.invalidate(knowledgeListProvider);
    } catch (_) {
      // Silent — the user can retry from Settings and see the error there.
    }
  }

  static const _tabs = [
    HomeScreen(),
    NotesScreen(),
    PracticeScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.park_outlined),
            selectedIcon: Icon(Icons.park),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
