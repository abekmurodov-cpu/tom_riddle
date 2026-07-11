import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/knowledge_item.dart';
import '../providers/knowledge_providers.dart';
import '../scheduler/spaced_repetition.dart';
import 'widgets/note_image.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late final List<KnowledgeItem> _queue;
  int _index = 0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    // Snapshot the due queue once so grading (which reschedules items out of
    // the due list) doesn't reshuffle the session under us.
    _queue = List.of(ref.read(dueItemsProvider));
  }

  Future<void> _grade(ReviewGrade grade) async {
    await ref
        .read(knowledgeListProvider.notifier)
        .grade(_queue[_index], grade);
    if (!mounted) return;
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _index >= _queue.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(done ? 'Done' : 'Review  ${_index + 1}/${_queue.length}'),
      ),
      body: done ? _DoneView(count: _queue.length) : _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final item = _queue[_index];
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: item.hasAnswer && !_revealed
                ? () => setState(() => _revealed = true)
                : null,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.type.label.toUpperCase(),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    Text(item.front, style: theme.textTheme.headlineSmall),
                    if (item.hasImage) ...[
                      const SizedBox(height: 12),
                      NoteImage(noteId: item.id),
                    ],
                    if (_revealed) ...[
                      const Divider(height: 32),
                      Text(
                        item.hasAnswer ? item.back! : '(no answer recorded yet)',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: _revealed || !item.hasAnswer
              ? _GradeButtons(onGrade: _grade)
              : FilledButton.tonal(
                  onPressed: () => setState(() => _revealed = true),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Reveal answer'),
                  ),
                ),
        ),
      ],
    );
  }
}

class _GradeButtons extends StatelessWidget {
  const _GradeButtons({required this.onGrade});

  final void Function(ReviewGrade) onGrade;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final grade in ReviewGrade.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                onPressed: () => onGrade(grade),
                child: Text(grade.label),
              ),
            ),
          ),
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            count == 0 ? 'Nothing due right now.' : 'Reviewed $count. Nice work.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}
