import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart';

import '../../llm/llm_providers.dart';
import '../../models/knowledge_item.dart';
import '../../practice/answer_matching.dart';
import '../../practice/code_drills.dart';
import '../../practice/practice_models.dart';
import '../../providers/knowledge_providers.dart';
import '../../scheduler/spaced_repetition.dart';
import '../widgets/note_image.dart';

const TextStyle _monoStyle = TextStyle(fontFamily: 'monospace', fontSize: 13);

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
  // Type-the-answer / write-the-code state.
  final _answerController = TextEditingController();
  // Fill-in-the-blank: one controller per blank.
  final List<TextEditingController> _blankControllers = [];
  // Reorder: current arrangement as indices into the note's reorderSegments.
  List<int> _reorderCurrent = [];
  // Shared "answered" result for objective modes.
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
    for (final c in _blankControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _disposeBlankControllers() {
    for (final c in _blankControllers) {
      c.dispose();
    }
    _blankControllers.clear();
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
    switch (widget.config.method) {
      case PracticeMethod.multipleChoice:
        await _ensureQuiz();
        _buildOptions();
      case PracticeMethod.flashcard:
      case PracticeMethod.typeAnswer:
        await _ensureQuiz();
      case PracticeMethod.fillBlank:
      case PracticeMethod.reorder:
        await _ensureDrills();
        _setupCoding();
      case PracticeMethod.codeSnippet:
        break; // graded on submit against the reference code
    }
    if (mounted) setState(() => _preparing = false);
  }

  /// Generates + caches code drills (deterministically, no LLM) from the note's
  /// code, which lives in the answer/details field (back). Self-heals notes
  /// whose cached drills were built from the wrong field.
  Future<void> _ensureDrills() async {
    final drills = generateCodeDrills(_item.back ?? '');
    final upToDate = listEquals(_item.reorderSegments, drills.reorderSegments) &&
        listEquals(_item.fillBlankAnswers, drills.fillBlankAnswers) &&
        _item.fillBlankTemplate == drills.fillBlankTemplate;
    if (upToDate) return;
    final updated = _item.copyWith(
      fillBlankTemplate: drills.fillBlankTemplate,
      fillBlankAnswers: drills.fillBlankAnswers,
      reorderSegments: drills.reorderSegments,
    );
    _setItem(updated);
    await ref.read(knowledgeListProvider.notifier).persist(updated);
  }

  /// Prepares per-blank controllers or a shuffled reorder list for the current
  /// coding drill.
  void _setupCoding() {
    _disposeBlankControllers();
    _blankControllers.addAll(
      List.generate(_item.fillBlankAnswers.length, (_) => TextEditingController()),
    );
    _reorderCurrent = _shuffledOrder(_item.reorderSegments.length);
  }

  /// A shuffled index order [0..n) that differs from the sorted answer order.
  List<int> _shuffledOrder(int n) {
    final identity = List.generate(n, (i) => i);
    if (n < 2) return identity;
    final order = List.of(identity)..shuffle();
    return listEquals(order, identity) ? order.reversed.toList() : order;
  }

  /// Generates and caches a quiz for the current note when one isn't stored yet
  /// and an LLM is attached. Facts get a reworded [quizQuestion] so practice
  /// asks a real question instead of echoing the fact; the answer is cached so
  /// answer-less facts become practiceable and future runs are instant.
  Future<void> _ensureQuiz() async {
    // Non-question notes need a reworded prompt; regenerate if an older cached
    // quiz predates that (has options but no quizQuestion).
    final missingQuestion = _item.type != KnowledgeType.question &&
        (_item.quizQuestion == null || _item.quizQuestion!.trim().isEmpty);
    if (_item.hasMcOptions && !missingQuestion) return;
    final llm = ref.read(llmProvider);
    if (llm == null) return;
    try {
      final quiz = await llm.generateQuiz(_item);
      var updated = _item.copyWith(
        mcAnswer: quiz.answer,
        mcDistractors: quiz.distractors,
        back: _item.hasAnswer ? _item.back : quiz.answer,
      );
      // Reword the shown prompt for any content note (fact, code, command,
      // concept); notes already phrased as a question keep their own wording.
      if (_item.type != KnowledgeType.question) {
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

  /// The answer to reveal / check for the current note. When the prompt was
  /// reworded into a generated question, the matching answer is the concise
  /// [mcAnswer]; otherwise prefer the note's own detailed [back].
  String? get _revealAnswer =>
      (_item.quizQuestion != null && _item.quizQuestion!.trim().isNotEmpty)
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
    _disposeBlankControllers();
    setState(() {
      _index++;
      _revealed = false;
      _chosen = null;
      _options = null;
      _correctOption = null;
      _wasCorrect = null;
      _feedback = null;
      _reorderCurrent = [];
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
      PracticeMethod.codeSnippet => _buildCodeSnippet(),
      PracticeMethod.fillBlank => _buildFillBlank(),
      PracticeMethod.reorder => _buildReorder(),
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

  // --- Write the code -----------------------------------------------------
  Widget _buildCodeSnippet() {
    final answered = _wasCorrect != null;
    // The prompt (front) describes what to write; the reference code is in back.
    final task = _item.front.trim().isNotEmpty
        ? _item.front
        : 'Reproduce this code snippet from memory.';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _codeTaskHeader('Write the code', task),
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          enabled: !answered,
          minLines: 5,
          maxLines: 16,
          style: _monoStyle,
          decoration: const InputDecoration(
            labelText: 'Your code',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (!answered)
          FilledButton(
            onPressed: _grading ? null : _checkCode,
            child: _grading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Check'),
          )
        else ...[
          _resultBanner(),
          const SizedBox(height: 12),
          _referenceCodeBlock(),
          const SizedBox(height: 12),
          _nextBar(),
        ],
      ],
    );
  }

  Future<void> _checkCode() async {
    final submitted = _answerController.text;
    if (submitted.trim().isEmpty) return;
    final reference = _item.back ?? '';
    final llm = ref.read(llmProvider);
    setState(() => _grading = true);
    bool correct;
    String? feedback;
    if (llm != null) {
      try {
        final g = await llm.gradeCode(_item, submitted);
        correct = g.correct;
        feedback = g.feedback;
      } catch (_) {
        correct = codeMatches(submitted, reference);
        feedback = 'AI check failed; used a whitespace-insensitive match.';
      }
    } else {
      correct = codeMatches(submitted, reference);
      feedback = correct
          ? null
          : 'Offline check needs an equivalent match (ignoring whitespace and '
              'comments). Attach Gemini to accept any working code.';
    }
    if (!mounted) return;
    setState(() => _grading = false);
    await _submitObjective(correct, feedback: feedback);
  }

  // --- Fill in the blank --------------------------------------------------
  Widget _buildFillBlank() {
    if (_preparing) return const Center(child: CircularProgressIndicator());
    final answered = _wasCorrect != null;
    final answers = _item.fillBlankAnswers;
    final template = _item.fillBlankTemplate ?? _item.back ?? '';
    final display = template.replaceAllMapped(
      fillBlankPlaceholderPattern,
      (m) => '[${int.parse(m.group(1)!) + 1}]',
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _codeTaskHeader('Fill in the blanks',
            'Type the token that belongs in each numbered blank.'),
        const SizedBox(height: 12),
        _codeBlock(display),
        const SizedBox(height: 16),
        for (var i = 0; i < answers.length; i++)
          _blankField(i, answers[i], answered),
        const SizedBox(height: 8),
        if (!answered)
          FilledButton(onPressed: _checkBlanks, child: const Text('Check'))
        else ...[
          _resultBanner(),
          const SizedBox(height: 12),
          _nextBar(),
        ],
      ],
    );
  }

  Widget _blankField(int i, String answer, bool answered) {
    final correct = _blankControllers[i].text.trim() == answer.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _blankControllers[i],
        enabled: !answered,
        style: _monoStyle,
        decoration: InputDecoration(
          isDense: true,
          prefixText: '${i + 1}.  ',
          border: const OutlineInputBorder(),
          suffixIcon: answered
              ? Icon(correct ? Icons.check : Icons.close,
                  color: correct
                      ? const Color(0xFF2E9E4F)
                      : const Color(0xFFD64545))
              : null,
          helperText: answered && !correct ? 'Answer: $answer' : null,
        ),
      ),
    );
  }

  void _checkBlanks() {
    final answers = _item.fillBlankAnswers;
    var allCorrect = answers.isNotEmpty;
    for (var i = 0; i < answers.length; i++) {
      if (_blankControllers[i].text.trim() != answers[i].trim()) {
        allCorrect = false;
      }
    }
    _submitObjective(allCorrect);
  }

  // --- Reorder the code ---------------------------------------------------
  Widget _buildReorder() {
    if (_preparing) return const Center(child: CircularProgressIndicator());
    final answered = _wasCorrect != null;
    final segments = _item.reorderSegments;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _codeTaskHeader(
              'Reorder the code', 'Drag the lines into the correct order.'),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _reorderCurrent.length,
            buildDefaultDragHandles: !answered,
            onReorderItem: _onReorder,
            itemBuilder: (context, i) {
              final idx = _reorderCurrent[i];
              final correctHere = idx == i;
              final border = !answered
                  ? null
                  : (correctHere
                      ? const Color(0xFF2E9E4F)
                      : const Color(0xFFD64545));
              return Card(
                key: ValueKey(idx),
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: border == null
                      ? BorderSide.none
                      : BorderSide(color: border, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 40, 12),
                  child: Text(segments[idx], style: _monoStyle),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: answered
              ? Column(
                  children: [_resultBanner(), const SizedBox(height: 12), _nextBar()])
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: _checkReorder, child: const Text('Check')),
                ),
        ),
      ],
    );
  }

  // onReorderItem pre-adjusts newIndex for the removed item, so no -1 fixup.
  void _onReorder(int oldIndex, int newIndex) {
    if (_wasCorrect != null) return;
    setState(() {
      final moved = _reorderCurrent.removeAt(oldIndex);
      _reorderCurrent.insert(newIndex, moved);
    });
  }

  void _checkReorder() {
    final ordered = [for (final idx in _reorderCurrent) _item.reorderSegments[idx]];
    _submitObjective(listEquals(ordered, _item.reorderSegments));
  }

  // --- Shared code widgets ------------------------------------------------
  Widget _codeTaskHeader(String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _codeBlock(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(code, style: _monoStyle),
    );
  }

  Widget _referenceCodeBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reference', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        _codeBlock(_item.back ?? ''),
      ],
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
