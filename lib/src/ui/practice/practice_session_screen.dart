import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../llm/llm_providers.dart';
import '../../models/knowledge_item.dart';
import '../../practice/answer_matching.dart';
import '../../practice/practice_models.dart';
import '../../providers/knowledge_providers.dart';
import '../../scheduler/spaced_repetition.dart';
import '../widgets/note_image.dart';

/// Runs a configured practice session over [queue]. Each answered card feeds the
/// SM-2 scheduler (correct → good, wrong → again), which updates the note's
/// `lastCorrect` and therefore its tree-view leaf color.
class PracticeSessionScreen extends ConsumerStatefulWidget {
  const PracticeSessionScreen({
    super.key,
    required this.config,
    required this.queue,
  });

  final PracticeConfig config;
  final List<KnowledgeItem> queue;

  @override
  ConsumerState<PracticeSessionScreen> createState() =>
      _PracticeSessionScreenState();
}

class _PracticeSessionScreenState
    extends ConsumerState<PracticeSessionScreen> {
  // Local, mutable copy so generated answers/quizzes update the current card.
  late final List<KnowledgeItem> _queue = List.of(widget.queue);
  int _index = 0;
  int _correctCount = 0;

  // Prep (AI answer/quiz generation) in flight for the current card.
  bool _preparing = false;
  // Flashcard state.
  bool _revealed = false;
  // Multiple-choice state.
  List<String>? _options;
  String? _correctOption;
  String? _chosen;
  // Type-the-answer state.
  final _answerController = TextEditingController();
  // Shared "answered" result for MC / type.
  bool? _wasCorrect;
  String? _feedback;
  bool _grading = false;

  @override
  void initState() {
    super.initState();
    _prepareItem();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  KnowledgeItem get _item => _queue[_index];

  void _setItem(KnowledgeItem updated) {
    if (!mounted) return;
    setState(() => _queue[_index] = updated);
  }

  /// Prepares the current card: generate + cache a quiz (a reworded question for
  /// bare facts, a concise answer, and wrong options) when an LLM is attached,
  /// then build the multiple-choice option set.
  Future<void> _prepareItem() async {
    setState(() {
      _preparing = true;
      _options = null;
      _correctOption = null;
    });
    await _ensureQuiz();
    if (widget.config.method == PracticeMethod.multipleChoice) {
      _buildOptions();
    }
    if (mounted) setState(() => _preparing = false);
  }

  /// Generates and caches a quiz for the current note when one isn't stored yet
  /// and an LLM is attached. Facts get a reworded [quizQuestion] so practice
  /// asks a real question instead of echoing the fact; the answer is cached so
  /// answer-less facts become practiceable and future runs are instant.
  Future<void> _ensureQuiz() async {
    if (_item.hasMcOptions) return;
    final llm = ref.read(llmProvider);
    if (llm == null) return;
    try {
      final quiz = await llm.generateQuiz(_item);
      var updated = _item.copyWith(
        mcAnswer: quiz.answer,
        mcDistractors: quiz.distractors,
        back: _item.hasAnswer ? _item.back : quiz.answer,
      );
      // Rewrite the shown prompt only for bare facts; other note types keep
      // their own wording.
      if (_item.type == KnowledgeType.fact) {
        updated = updated.copyWith(quizQuestion: quiz.question);
      }
      _setItem(updated);
      await ref.read(knowledgeListProvider.notifier).persist(updated);
    } catch (_) {
      // Fall back to non-AI behavior (local distractors / raw prompt).
    }
  }

  /// Builds [_options]/[_correctOption] from the cached quiz, or from distractors
  /// drawn from other notes when no quiz is available.
  void _buildOptions() {
    final String correct;
    final List<String> distractors;
    if (_item.hasMcOptions) {
      correct = _item.mcAnswer!;
      distractors = _item.mcDistractors;
    } else {
      correct = _item.mcAnswer ?? _item.back ?? _item.front;
      distractors = _localDistractors(_item);
    }
    final options = <String>{correct, ...distractors}.toList()..shuffle();
    setState(() {
      _correctOption = correct;
      _options = options;
    });
  }

  /// The answer to reveal / check for the current note. Facts prefer the concise
  /// [mcAnswer]; other notes prefer their detailed [back].
  String? get _revealAnswer => _item.type == KnowledgeType.fact
      ? (_item.mcAnswer ?? _item.back)
      : (_item.back ?? _item.mcAnswer);

  bool get _canReveal => _revealAnswer?.trim().isNotEmpty ?? false;

  /// Distractors drawn from other notes' answers (same category preferred).
  List<String> _localDistractors(KnowledgeItem item) {
    final all = ref.read(notesSortedProvider);
    final pool = all
        .where((i) => i.id != item.id && i.hasAnswer && i.back != item.back)
        .toList();
    pool.sort((a, b) {
      final aSame = a.category == item.category ? 0 : 1;
      final bSame = b.category == item.category ? 0 : 1;
      return aSame.compareTo(bSame);
    });
    return pool.take(3).map((i) => i.back!).toList();
  }

  Future<void> _grade(ReviewGrade grade) async {
    await ref.read(knowledgeListProvider.notifier).grade(_item, grade);
    if (grade.quality >= 3) _correctCount++;
    _advance();
  }

  Future<void> _submitObjective(bool correct, {String? feedback}) async {
    setState(() {
      _wasCorrect = correct;
      _feedback = feedback;
    });
    // Persist the outcome via the scheduler.
    await ref.read(knowledgeListProvider.notifier).grade(
          _item,
          correct ? ReviewGrade.good : ReviewGrade.again,
        );
    if (correct) _correctCount++;
  }

  void _advance() {
    if (!mounted) return;
    setState(() {
      _index++;
      _revealed = false;
      _chosen = null;
      _options = null;
      _correctOption = null;
      _wasCorrect = null;
      _feedback = null;
      _answerController.clear();
    });
    if (_index < _queue.length) _prepareItem();
  }

  @override
  Widget build(BuildContext context) {
    final done = _index >= _queue.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(done
            ? 'Done'
            : '${widget.config.method.label}  ${_index + 1}/${_queue.length}'),
      ),
      body: done ? _buildDone() : _buildBody(),
    );
  }

  Widget _buildBody() {
    return switch (widget.config.method) {
      PracticeMethod.flashcard => _buildFlashcard(),
      PracticeMethod.multipleChoice => _buildMultipleChoice(),
      PracticeMethod.typeAnswer => _buildTypeAnswer(),
    };
  }

  Widget _promptCard(BuildContext context, {Widget? extra}) {
    final theme = Theme.of(context);
    return Container(
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
            Text(_item.type.label.toUpperCase(),
                style: theme.textTheme.labelSmall
                    ?.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Text(_item.practicePrompt, style: theme.textTheme.headlineSmall),
            if (_item.hasImage) ...[
              const SizedBox(height: 12),
              NoteImage(noteId: _item.id),
            ],
            ?extra,
          ],
        ),
      ),
    );
  }

  // --- Flashcard ---------------------------------------------------------
  Widget _buildFlashcard() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _canReveal && !_revealed
                ? () => setState(() => _revealed = true)
                : null,
            child: _promptCard(
              context,
              extra: _revealed
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 16),
                          Text(
                            _revealAnswer ?? '(no answer recorded yet)',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: _preparing
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _revealed || !_canReveal
                  ? Row(
                      children: [
                        for (final grade in ReviewGrade.values)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: OutlinedButton(
                                onPressed: () => _grade(grade),
                                child: Text(grade.label),
                              ),
                            ),
                          ),
                      ],
                    )
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

  // --- Multiple choice ---------------------------------------------------
  Widget _buildMultipleChoice() {
    final answered = _wasCorrect != null;
    return Column(
      children: [
        _promptCard(context),
        Expanded(
          child: _preparing || _options == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final option in _options!)
                      _OptionTile(
                        text: option,
                        correctAnswer: _correctOption ?? '',
                        chosen: _chosen,
                        answered: answered,
                        onTap: answered
                            ? null
                            : () {
                                setState(() => _chosen = option);
                                _submitObjective(option == _correctOption);
                              },
                      ),
                  ],
                ),
        ),
        if (answered) _nextBar(),
      ],
    );
  }

  // --- Type the answer ---------------------------------------------------
  Widget _buildTypeAnswer() {
    final answered = _wasCorrect != null;
    return Column(
      children: [
        _promptCard(context),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _answerController,
            enabled: !answered,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your answer',
              border: OutlineInputBorder(),
            ),
            onSubmitted: answered ? null : (_) => _checkTyped(),
          ),
        ),
        const SizedBox(height: 12),
        if (!answered)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: (_grading || _preparing) ? null : _checkTyped,
              child: (_grading || _preparing)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Check'),
            ),
          ),
        if (answered) ...[
          _resultBanner(),
          const Spacer(),
          _nextBar(),
        ],
      ],
    );
  }

  Future<void> _checkTyped() async {
    final guess = _answerController.text.trim();
    if (guess.isEmpty) return;
    final expected = _revealAnswer ?? '';
    final llm = ref.read(llmProvider);
    setState(() => _grading = true);
    bool correct;
    String? feedback;
    if (llm != null) {
      try {
        final grade = await llm.gradeAnswer(_item, guess);
        correct = grade.correct;
        feedback = grade.feedback;
      } catch (_) {
        correct = isAnswerCorrect(guess, expected);
      }
    } else {
      correct = isAnswerCorrect(guess, expected);
    }
    if (!mounted) return;
    setState(() => _grading = false);
    await _submitObjective(correct, feedback: feedback);
  }

  Widget _resultBanner() {
    final correct = _wasCorrect == true;
    final color = correct ? const Color(0xFF2E9E4F) : const Color(0xFFD64545);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
                const SizedBox(width: 8),
                Text(correct ? 'Correct' : 'Incorrect',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Answer: ${_revealAnswer ?? _correctOption ?? '—'}'),
            if (_feedback != null) ...[
              const SizedBox(height: 4),
              Text(_feedback!, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nextBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _advance,
          child: Text(_index + 1 >= widget.queue.length ? 'Finish' : 'Next'),
        ),
      ),
    );
  }

  Widget _buildDone() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined,
              size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Scored $_correctCount / ${widget.queue.length}',
              style: Theme.of(context).textTheme.titleLarge),
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

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.correctAnswer,
    required this.chosen,
    required this.answered,
    required this.onTap,
  });

  final String text;
  final String correctAnswer;
  final String? chosen;
  final bool answered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCorrect = text == correctAnswer;
    final isChosen = text == chosen;
    Color? border;
    if (answered) {
      if (isCorrect) {
        border = const Color(0xFF2E9E4F);
      } else if (isChosen) {
        border = const Color(0xFFD64545);
      }
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: border == null
            ? BorderSide.none
            : BorderSide(color: border, width: 2),
      ),
      child: ListTile(
        title: Text(text),
        trailing: answered && isCorrect
            ? const Icon(Icons.check, color: Color(0xFF2E9E4F))
            : (answered && isChosen
                ? const Icon(Icons.close, color: Color(0xFFD64545))
                : null),
        onTap: onTap,
      ),
    );
  }
}
