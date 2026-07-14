import '../models/knowledge_item.dart';

/// How the user is quizzed during a practice session.
enum PracticeMethod {
  flashcard,
  multipleChoice,
  typeAnswer;

  String get label => switch (this) {
        PracticeMethod.flashcard => 'Flashcard',
        PracticeMethod.multipleChoice => 'Multiple choice',
        PracticeMethod.typeAnswer => 'Type the answer',
      };

  String get blurb => switch (this) {
        PracticeMethod.flashcard => 'Reveal the answer and grade yourself.',
        PracticeMethod.multipleChoice => 'Pick the right answer from options.',
        PracticeMethod.typeAnswer => 'Type it; checked by match or AI.',
      };
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

    if ((method == PracticeMethod.multipleChoice ||
            method == PracticeMethod.typeAnswer) &&
        !canGenerate) {
      pool = pool.where((i) => i.hasAnswer);
    }

    final queue = pool.toList()..shuffle();
    return queue;
  }
}
