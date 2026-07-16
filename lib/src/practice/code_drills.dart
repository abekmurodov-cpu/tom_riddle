import 'dart:math' as math;

/// Pre-generated drills for a code note. Built once (deterministically, no LLM)
/// so fill-in-the-blank and reorder practice cost zero API credits.
class CodeDrills {
  const CodeDrills({
    required this.fillBlankTemplate,
    required this.fillBlankAnswers,
    required this.reorderSegments,
  });

  final String? fillBlankTemplate;
  final List<String> fillBlankAnswers;
  final List<String> reorderSegments;
}

/// Placeholder written into [CodeDrills.fillBlankTemplate] for blank index i.
String fillBlankPlaceholder(int i) => '«$i»'; // «i»

/// Matches the placeholders when splitting a template for rendering.
final RegExp fillBlankPlaceholderPattern = RegExp('«(\\d+)»');

const int _maxBlanks = 6;
const int _maxSegments = 8;

/// Builds fill-in-the-blank and reorder drills from raw [code], purely by
/// heuristics (no network). Returns empty drills when the code is too small.
CodeDrills generateCodeDrills(String code) {
  final fill = _buildFillBlankTemplate(code);
  return CodeDrills(
    fillBlankTemplate: fill.template,
    fillBlankAnswers: fill.answers,
    reorderSegments: _splitReorderSegments(code),
  );
}

class _FillBlank {
  const _FillBlank(this.template, this.answers);
  final String? template;
  final List<String> answers;
}

/// Blanks out a spread of identifier/keyword tokens. Deterministic: given the
/// same code it always blanks the same tokens.
_FillBlank _buildFillBlankTemplate(String code) {
  final wordRe = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');
  final candidates = wordRe
      .allMatches(code)
      .where((m) => m.group(0)!.length >= 2)
      .toList();
  if (candidates.length < 2) return const _FillBlank(null, []);

  final blankCount =
      math.max(1, math.min(_maxBlanks, (candidates.length * 0.2).round()));
  final step = candidates.length / blankCount;

  // Evenly spaced, de-duplicated by start offset, kept in source order.
  final chosen = <RegExpMatch>[];
  final seenStarts = <int>{};
  for (var i = 0; i < blankCount; i++) {
    final match = candidates[(i * step).floor()];
    if (seenStarts.add(match.start)) chosen.add(match);
  }
  chosen.sort((a, b) => a.start.compareTo(b.start));

  final buf = StringBuffer();
  final answers = <String>[];
  var cursor = 0;
  for (final m in chosen) {
    buf.write(code.substring(cursor, m.start));
    buf.write(fillBlankPlaceholder(answers.length));
    answers.add(m.group(0)!);
    cursor = m.end;
  }
  buf.write(code.substring(cursor));
  return _FillBlank(buf.toString(), answers);
}

/// Splits code into logical chunks in order. Uses non-empty lines, grouping
/// consecutive lines when there are more than [_maxSegments] so the reorder
/// task stays manageable.
List<String> _splitReorderSegments(String code) {
  final lines =
      code.split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.length < 2) return const [];
  if (lines.length <= _maxSegments) return lines;

  final groupSize = (lines.length / _maxSegments).ceil();
  final segments = <String>[];
  for (var i = 0; i < lines.length; i += groupSize) {
    final end = math.min(i + groupSize, lines.length);
    segments.add(lines.sublist(i, end).join('\n'));
  }
  return segments;
}

/// Normalizes code for whitespace/comment-insensitive comparison, used to grade
/// the "type the code" drill offline (when no LLM is attached). Strips line
/// (`//`, `#`) comments, collapses whitespace, and drops trailing semicolons.
String normalizeCode(String code) {
  final withoutComments = code
      .split('\n')
      .map((line) {
        final slash = line.indexOf('//');
        final hash = line.indexOf('#');
        var cut = line.length;
        if (slash >= 0) cut = math.min(cut, slash);
        if (hash >= 0) cut = math.min(cut, hash);
        return line.substring(0, cut);
      })
      .join('\n');
  return withoutComments
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('; ', ' ')
      .replaceAll(RegExp(r';\s*$'), '')
      .trim();
}

/// Offline check for the "type the code" drill: true when the submitted code
/// matches the reference ignoring whitespace and comments.
bool codeMatches(String submitted, String reference) {
  final a = normalizeCode(submitted);
  final b = normalizeCode(reference);
  return a.isNotEmpty && a == b;
}
