/// Normalizes an answer for comparison: lowercased, trimmed, punctuation
/// stripped, and internal whitespace collapsed to single spaces.
String normalizeAnswer(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Levenshtein edit distance between two strings.
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);

  for (var i = 0; i < a.length; i++) {
    curr[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      curr[j + 1] = [
        curr[j] + 1, // insertion
        prev[j + 1] + 1, // deletion
        prev[j] + cost, // substitution
      ].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

/// Similarity ratio in [0, 1] based on edit distance over the longer length.
double similarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 1;
  return 1 - levenshtein(a, b) / maxLen;
}

/// Whether a typed [guess] is close enough to the [expected] answer using
/// normalized fuzzy matching. Used when no LLM is attached to grade answers.
bool isAnswerCorrect(String guess, String expected, {double threshold = 0.85}) {
  final g = normalizeAnswer(guess);
  final e = normalizeAnswer(expected);
  if (g.isEmpty) return false;
  if (g == e) return true;
  // Accept when the guess contains the expected answer (or vice versa) for
  // short keyword-style answers.
  if (e.isNotEmpty && (g.contains(e) || e.contains(g))) return true;
  return similarity(g, e) >= threshold;
}
