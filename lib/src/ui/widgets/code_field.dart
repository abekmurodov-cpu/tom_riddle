import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'code_highlighter.dart';

/// A [TextEditingController] that renders its text with lightweight syntax
/// highlighting, giving the code editor colored tokens as you type.
class CodeEditingController extends TextEditingController {
  CodeEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    return TextSpan(style: base, children: highlightCode(text, base));
  }
}

/// A code editor field: monospace, syntax-highlighted, and Tab inserts two
/// spaces (instead of moving focus) like a real editor.
class CodeField extends StatefulWidget {
  const CodeField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.hintText,
    this.minLines = 6,
    this.maxLines = 20,
  });

  final CodeEditingController controller;
  final bool enabled;
  final String? hintText;
  final int minLines;
  final int maxLines;

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  static const _indent = '  ';

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    final value = widget.controller.value;
    final sel = value.selection;
    if (!sel.isValid) return KeyEventResult.ignored;
    final newText = value.text.replaceRange(sel.start, sel.end, _indent);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + _indent.length),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      onKeyEvent: widget.enabled ? _onKey : null,
      child: TextField(
        controller: widget.controller,
        enabled: widget.enabled,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          hintText: widget.hintText,
          alignLabelWithHint: true,
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
