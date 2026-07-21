import 'package:flutter/material.dart';

/// Language-agnostic code colors that read well on both light and dark themes.
class CodeColors {
  const CodeColors._();
  static const keyword = Color(0xFF9C6BFF); // purple
  static const string = Color(0xFF3FA66A); // green
  static const comment = Color(0xFF8A8A8A); // grey
  static const number = Color(0xFFCC7832); // orange
}

/// Common keywords across popular languages. Approximate on purpose — this is a
/// lightweight highlighter, not a real parser.
const _keywords = <String>{
  'abstract', 'and', 'as', 'async', 'await', 'bool', 'break', 'case', 'catch',
  'char', 'class', 'const', 'continue', 'def', 'default', 'do', 'double',
  'elif', 'else', 'enum', 'export', 'extends', 'false', 'final', 'finally',
  'float', 'fn', 'for', 'from', 'func', 'function', 'go', 'if', 'impl',
  'import', 'in', 'int', 'interface', 'is', 'lambda', 'let', 'long', 'match',
  'mut', 'new', 'nil', 'none', 'not', 'null', 'or', 'override', 'package',
  'pass', 'print', 'private', 'protected', 'public', 'raise', 'return', 'self',
  'static', 'str', 'string', 'struct', 'super', 'switch', 'this', 'throw',
  'true', 'try', 'type', 'typedef', 'undefined', 'union', 'unsigned', 'use',
  'var', 'void', 'while', 'with', 'yield',
};

final _tokenPattern = RegExp(
  r'(?<comment>//[^\n]*|#[^\n]*|/\*[\s\S]*?\*/)'
  r'''|(?<string>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`[^`]*`)'''
  r'|(?<number>\b\d+(?:\.\d+)?\b)'
  r'|(?<word>[A-Za-z_][A-Za-z0-9_]*)',
);

/// Builds colored [TextSpan]s for [code] over [base], coloring comments,
/// strings, numbers and common keywords.
List<TextSpan> highlightCode(String code, TextStyle base) {
  final spans = <TextSpan>[];
  var last = 0;
  for (final m in _tokenPattern.allMatches(code)) {
    if (m.start > last) {
      spans.add(TextSpan(text: code.substring(last, m.start), style: base));
    }
    final text = m.group(0)!;
    Color? color;
    if (m.namedGroup('comment') != null) {
      color = CodeColors.comment;
    } else if (m.namedGroup('string') != null) {
      color = CodeColors.string;
    } else if (m.namedGroup('number') != null) {
      color = CodeColors.number;
    } else if (m.namedGroup('word') != null && _keywords.contains(text)) {
      color = CodeColors.keyword;
    }
    spans.add(TextSpan(
      text: text,
      style: color == null ? base : base.copyWith(color: color),
    ));
    last = m.end;
  }
  if (last < code.length) {
    spans.add(TextSpan(text: code.substring(last), style: base));
  }
  return spans;
}
