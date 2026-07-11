import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/knowledge_providers.dart';
import 'capture_screen.dart';
import 'review_screen.dart';
import 'widgets/item_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(knowledgeListProvider);
    final dueCount = ref.watch(dueItemsProvider).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCapture(context),
        icon: const Icon(Icons.add),
        label: const Text('Capture'),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong:\n$e')),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyState();
          }
          return Column(
            children: [
              if (dueCount > 0)
                _ReviewBanner(
                  count: dueCount,
                  onStart: () => _openReview(context),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, i) => ItemTile(item: items[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openCapture(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
  }

  void _openReview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReviewScreen()),
    );
  }
}

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.count, required this.onStart});

  final int count;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'item' : 'items'} ready to challenge you',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(onPressed: onStart, child: const Text('Review')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Your notes will hit back.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Capture a fact, a concept, a command, or a question. '
              'The app will quiz you on it later so you never forget.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
