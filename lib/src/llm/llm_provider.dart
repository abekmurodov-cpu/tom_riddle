import '../models/knowledge_item.dart';

/// Result of grading a free-typed answer with an LLM.
class LlmGrade {
  const LlmGrade({required this.correct, this.feedback});

  final bool correct;
  final String? feedback;
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

  /// Returns [count] plausible-but-wrong short answers to use as multiple-choice
  /// distractors for [item].
  Future<List<String>> generatePractice(KnowledgeItem item, {int count = 3});

  /// Judges whether [answer] is a correct response to [item].
  Future<LlmGrade> gradeAnswer(KnowledgeItem item, String answer);

  /// Suggests a short category/tag for a freshly captured note.
  Future<String> suggestCategory(String front, String? back);
}
