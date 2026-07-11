import '../models/knowledge_item.dart';

/// How well the user recalled an item during review. Maps onto SM-2 quality
/// scores (0–5); we expose four buttons instead of a raw scale.
enum ReviewGrade {
  again, // failed to recall
  hard, // recalled with serious difficulty
  good, // recalled correctly
  easy; // recalled effortlessly

  int get quality => switch (this) {
        ReviewGrade.again => 1,
        ReviewGrade.hard => 3,
        ReviewGrade.good => 4,
        ReviewGrade.easy => 5,
      };

  String get label => switch (this) {
        ReviewGrade.again => 'Again',
        ReviewGrade.hard => 'Hard',
        ReviewGrade.good => 'Good',
        ReviewGrade.easy => 'Easy',
      };
}

/// Pure SM-2 spaced-repetition scheduler.
///
/// Given an item and how the user graded their recall, returns a copy with
/// updated [KnowledgeItem.repetitions], [KnowledgeItem.easeFactor],
/// [KnowledgeItem.intervalDays] and a fresh [KnowledgeItem.dueDate].
class SpacedRepetition {
  const SpacedRepetition();

  static const double _minEase = 1.3;

  KnowledgeItem schedule(
    KnowledgeItem item,
    ReviewGrade grade, {
    DateTime? now,
  }) {
    final reviewedAt = now ?? DateTime.now();
    final q = grade.quality;
    final correct = q >= 3;

    int repetitions;
    int intervalDays;

    if (q < 3) {
      // Lapse: reset the streak and show it again tomorrow.
      repetitions = 0;
      intervalDays = 1;
    } else {
      repetitions = item.repetitions + 1;
      intervalDays = switch (repetitions) {
        1 => 1,
        2 => 6,
        _ => (item.intervalDays * item.easeFactor).round().clamp(1, 365 * 10),
      };
    }

    // Update the ease factor per SM-2, clamped to a sane floor.
    final updatedEase =
        (item.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
            .clamp(_minEase, double.infinity)
            .toDouble();

    return item.copyWith(
      repetitions: repetitions,
      easeFactor: updatedEase,
      intervalDays: intervalDays,
      lastReviewedAt: reviewedAt,
      dueDate: DateTime(reviewedAt.year, reviewedAt.month, reviewedAt.day)
          .add(Duration(days: intervalDays)),
      updatedAt: reviewedAt,
      lastCorrect: correct,
      lapses: correct ? item.lapses : item.lapses + 1,
    );
  }
}
