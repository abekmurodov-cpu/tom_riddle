import '../models/knowledge_item.dart';

/// Result of grading a free-typed answer with an LLM.
class LlmGrade {
  const LlmGrade({required this.correct, this.feedback});

  final bool correct;
  final String? feedback;
}

/// A cached multiple-choice quiz for a note: one concise correct answer plus
/// short plausible-but-wrong distractors. Kept deliberately terse (1–2
/// sentences each) so options read cleanly rather than dumping the full detail.
class McQuiz {
  const McQuiz({
    required this.question,
    required this.answer,
    required this.distractors,
  });

  /// A clear question testing the note (reworded from a bare fact if needed).
  final String question;
  final String answer;
  final List<String> distractors;
}

/// Abstraction over a large-language-model backend. Implementations are
/// attached/detached at runtime by the user (starting with Gemini). Every
/// method may throw on network/credential errors — callers treat the LLM as a
/// best-effort enhancement and fall back to non-LLM behavior when it is absent
/// or fails.
abstract class LlmProvider {
  /// Human-readable name of the attached model/provider (for settings UI).
  String get displayName;

  /// Given a note whose answer is missing, returns a concise answer/explanation
  /// for its [KnowledgeItem.front].
  Future<String> expandNote(KnowledgeItem item);

  /// Builds a full multiple-choice quiz for [item]: a concise correct answer
  /// plus [distractorCount] short wrong options. Works even when the note has no
  /// recorded answer yet (it reasons from the prompt).
  Future<McQuiz> generateQuiz(KnowledgeItem item, {int distractorCount = 3});

  /// Judges whether [answer] is a correct response to [item].
  Future<LlmGrade> gradeAnswer(KnowledgeItem item, String answer);

  /// Suggests a short category/tag for a freshly captured note.
  Future<String> suggestCategory(String front, String? back);
}
