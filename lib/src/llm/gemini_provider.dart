import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/knowledge_item.dart';
import 'llm_provider.dart';

/// [LlmProvider] backed by Google's Gemini REST API, using a user-supplied API
/// key (stored locally, never bundled). Calls the `generateContent` endpoint.
class GeminiProvider implements LlmProvider {
  GeminiProvider({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _client;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  @override
  String get displayName => 'Gemini ($model)';

  /// Sends [prompt] and returns the model's plain-text reply.
  Future<String> _generate(String prompt) async {
    final uri = Uri.parse('$_base/models/$model:generateContent?key=$apiKey');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Gemini error ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates');
    }
    final parts = (((candidates.first as Map)['content'] as Map)['parts']
        as List);
    final text = parts
        .map((p) => (p as Map)['text'] as String? ?? '')
        .join()
        .trim();
    if (text.isEmpty) throw Exception('Gemini returned empty text');
    return text;
  }

  @override
  Future<String> expandNote(KnowledgeItem item) {
    return _generate(
      'You are helping build a spaced-repetition flashcard. '
      'Give a concise, correct answer/explanation (1-3 sentences) for this '
      '${item.type.label.toLowerCase()} prompt. Reply with the answer only, no preamble.\n\n'
      'Prompt: ${item.front}',
    );
  }

  @override
  Future<List<String>> generatePractice(KnowledgeItem item,
      {int count = 3}) async {
    final raw = await _generate(
      'For a multiple-choice quiz, write exactly $count plausible but INCORRECT '
      'short answers (distractors) for this question. They must be clearly wrong '
      'but believable, and distinct from the correct answer. '
      'Return a JSON array of strings only, no other text.\n\n'
      'Question: ${item.front}\n'
      'Correct answer: ${item.back}',
    );
    try {
      final cleaned = raw
          .replaceAll(RegExp(r'^```(json)?'), '')
          .replaceAll(RegExp(r'```$'), '')
          .trim();
      final list = jsonDecode(cleaned) as List;
      return list.map((e) => e.toString()).take(count).toList();
    } catch (_) {
      // Fall back to splitting lines if the model didn't return clean JSON.
      return raw
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^[\-\*\d\.\)\s]+'), '').trim())
          .where((l) => l.isNotEmpty)
          .take(count)
          .toList();
    }
  }

  @override
  Future<LlmGrade> gradeAnswer(KnowledgeItem item, String answer) async {
    final raw = await _generate(
      'Grade a student\'s answer to a flashcard. Decide if it is essentially '
      'correct (meaning matches, ignore wording/typos). '
      'Return JSON: {"correct": true|false, "feedback": "one short sentence"}.\n\n'
      'Question: ${item.front}\n'
      'Expected answer: ${item.back}\n'
      'Student answer: $answer',
    );
    try {
      final cleaned = raw
          .replaceAll(RegExp(r'^```(json)?'), '')
          .replaceAll(RegExp(r'```$'), '')
          .trim();
      final map = jsonDecode(cleaned) as Map<String, dynamic>;
      return LlmGrade(
        correct: map['correct'] == true,
        feedback: map['feedback'] as String?,
      );
    } catch (_) {
      final correct = raw.toLowerCase().contains('correct') &&
          !raw.toLowerCase().contains('incorrect');
      return LlmGrade(correct: correct, feedback: raw);
    }
  }

  @override
  Future<String> suggestCategory(String front, String? back) async {
    final text = await _generate(
      'Suggest ONE short category label (1-2 words, Title Case) for this note. '
      'Reply with the label only.\n\nNote: $front${back == null ? '' : '\n$back'}',
    );
    return text.split('\n').first.trim();
  }
}
