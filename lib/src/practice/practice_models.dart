import '../models/knowledge_item.dart';
import 'code_drills.dart';

/// How the user is quizzed during a practice session. The last three are the
/// "coding branch": they only apply to code notes.
enum PracticeMethod {
  flashcard,
  multipleChoice,
  typeAnswer,
  codeSnippet,
  fillBlank,
  reorder;

  String get label => switch (this) {
        PracticeMethod.flashcard => 'Flashcard',
        PracticeMethod.multipleChoice => 'Multiple choice',
        PracticeMethod.typeAnswer => 'Type the answer',
        PracticeMethod.codeSnippet => 'Write the code',
        PracticeMethod.fillBlank => 'Fill in the blank',
        PracticeMethod.reorder => 'Reorder the code',
      };

  String get blurb => switch (this) {
        PracticeMethod.flashcard => 'Reveal the answer and grade yourself.',
        PracticeMethod.multipleChoice => 'Pick the right answer from options.',
        PracticeMethod.typeAnswer => 'Type it; checked by match or AI.',
        PracticeMethod.codeSnippet =>
          'Rewrite the snippet; graded on working syntax, not an exact match.',
        PracticeMethod.fillBlank => 'Fill the blanked-out tokens in the code.',
        PracticeMethod.reorder => 'Drag the shuffled code lines back into order.',
      };

  /// True for the coding-only drills, which quiz code-type notes.
  bool get isCoding =>
      this == PracticeMethod.codeSnippet ||
      this == PracticeMethod.fillBlank ||
      this == PracticeMethod.reorder;
}

/// Which notes a practice session draws from.
enum PracticeScope {
  all,
  due,
  weakPoints,
  category;

  String get label => switch (this) {
        PracticeScope.all => 'All notes',
        PracticeScope.due => 'Due only',
        PracticeScope.weakPoints => 'Weak points',
        PracticeScope.category => 'Category cram',
      };

  String get blurb => switch (this) {
        PracticeScope.all => 'Every note, regardless of schedule.',
        PracticeScope.due =>
          'Only notes the spaced-repetition scheduler says are due today.',
        PracticeScope.weakPoints =>
          'Notes you last got wrong or keep lapsing on (the red leaves).',
        PracticeScope.category => 'All notes in one category you choose.',
      };
}

/// A configured practice run and the notes it will quiz.
class PracticeConfig {
  const PracticeConfig({
    required this.method,
    required this.scope,
    this.category,
  });

  final PracticeMethod method;
  final PracticeScope scope;
  final String? category;

  /// Builds the queue from [all] (every note) and [due] (currently-due notes),
  /// filtered by scope. Multiple-choice and type-the-answer need something to
  /// quiz against: notes without a recorded answer are dropped — UNLESS an LLM
  /// is attached ([canGenerate]), in which case they're kept and the answer/quiz
  /// is generated at practice time. Order is shuffled.
  List<KnowledgeItem> buildQueue({
    required List<KnowledgeItem> all,
    required List<KnowledgeItem> due,
    bool canGenerate = false,
  }) {
    Iterable<KnowledgeItem> pool = switch (scope) {
      PracticeScope.all => all,
      PracticeScope.due => due,
      PracticeScope.weakPoints => all.where((i) => i.isWeak),
      PracticeScope.category =>
        all.where((i) => (i.category?.trim() ?? '') == category?.trim()),
    };

    if (method.isCoding) {
      // Coding drills only quiz code notes that can actually produce the drill.
      pool = pool.where((i) => i.type == KnowledgeType.code).where((i) {
        return switch (method) {
          PracticeMethod.fillBlank => _canFillBlank(i),
          PracticeMethod.reorder => _canReorder(i),
          _ => i.front.trim().isNotEmpty, // codeSnippet: needs reference code
        };
      });
    } else if ((method == PracticeMethod.multipleChoice ||
            method == PracticeMethod.typeAnswer) &&
        !canGenerate) {
      pool = pool.where((i) => i.hasAnswer);
    }

    final queue = pool.toList()..shuffle();
    return queue;
  }

  static bool _canFillBlank(KnowledgeItem i) =>
      i.fillBlankAnswers.isNotEmpty ||
      generateCodeDrills(i.front).fillBlankAnswers.isNotEmpty;

  static bool _canReorder(KnowledgeItem i) =>
      i.reorderSegments.length > 1 ||
      generateCodeDrills(i.front).reorderSegments.length > 1;
}
