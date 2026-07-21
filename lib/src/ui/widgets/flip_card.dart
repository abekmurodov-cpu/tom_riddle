import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A Quizlet-style flashcard: a compact card that flips in 3D between [front]
/// and [back] on tap. Reports flips via [onFlip] so the parent can, e.g., reveal
/// grading buttons once the answer side has been shown.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.onFlip,
  });

  final Widget front;
  final Widget back;
  final ValueChanged<bool>? onFlip;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _showingBack = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    _showingBack = !_showingBack;
    if (_showingBack) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onFlip?.call(_showingBack);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle = _controller.value * math.pi;
          final isBack = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // perspective
              ..rotateY(angle),
            child: isBack
                // Counter-rotate so the back face reads correctly.
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _Face(child: widget.back),
                  )
                : _Face(child: widget.front),
          );
        },
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}
