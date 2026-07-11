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
  category;

  String get label => switch (this) {
        PracticeScope.all => 'All notes',
        PracticeScope.due => 'Due only',
        PracticeScope.category => 'Category cram',
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
  /// filtered by scope. Multiple-choice needs a recorded answer to quiz against,
  /// so notes without a `back` are dropped for that method. Order is shuffled.
  List<KnowledgeItem> buildQueue({
    required List<KnowledgeItem> all,
    required List<KnowledgeItem> due,
  }) {
    Iterable<KnowledgeItem> pool = switch (scope) {
      PracticeScope.all => all,
      PracticeScope.due => due,
      PracticeScope.category =>
        all.where((i) => (i.category?.trim() ?? '') == category?.trim()),
    };

    if (method == PracticeMethod.multipleChoice ||
        method == PracticeMethod.typeAnswer) {
      pool = pool.where((i) => i.hasAnswer);
    }

    final queue = pool.toList()..shuffle();
    return queue;
  }
}
