import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/knowledge_item.dart';
import '../providers/knowledge_providers.dart';
import '../scheduler/spaced_repetition.dart';
import 'widgets/flip_card.dart';
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
    final showGrades = _revealed || !item.hasAnswer;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FlipCard(
                      key: ValueKey(_index),
                      onFlip: (back) {
                        if (back && !_revealed) {
                          setState(() => _revealed = true);
                        }
                      },
                      front: _face(
                        context,
                        item.type.label.toUpperCase(),
                        item.front,
                        image: item.hasImage ? item.id : null,
                      ),
                      back: _face(
                        context,
                        'ANSWER',
                        item.hasAnswer
                            ? item.back!
                            : '(no answer recorded yet)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      showGrades
                          ? 'How well did you recall it?'
                          : 'Tap the card to flip',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: showGrades
              ? _GradeButtons(onGrade: _grade)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _face(BuildContext context, String label, String text, {String? image}) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2, color: theme.colorScheme.primary)),
        const SizedBox(height: 14),
        if (image != null) ...[
          NoteImage(noteId: image, maxHeight: 140),
          const SizedBox(height: 14),
        ],
        Text(text, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
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
