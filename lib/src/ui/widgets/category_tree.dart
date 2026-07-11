import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/knowledge_item.dart';

/// Color a leaf takes based on the note's recall history.
Color leafColor(KnowledgeItem item) {
  return switch (item.lastCorrect) {
    true => const Color(0xFF2E9E4F), // recalled — green
    false => const Color(0xFFD64545), // needs work — red
    null => const Color(0xFFE0A93B), // never reviewed — amber
  };
}

/// A single category rendered as a literal tree: a trunk with branches and one
/// tappable leaf per note. Leaf positions are deterministic (seeded by index)
/// so a note keeps its spot across rebuilds. Leaf color reflects recall:
/// green = last recall correct, red = last recall wrong, amber = never reviewed.
class CategoryTree extends StatelessWidget {
  const CategoryTree({
    super.key,
    required this.category,
    required this.notes,
    required this.onLeafTap,
    this.height = 300,
  });

  final String category;
  final List<KnowledgeItem> notes;
  final void Function(KnowledgeItem) onLeafTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${notes.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: height,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  final layout = _TreeLayout(size: size, count: notes.length);
                  return Stack(
                    children: [
                      // Trunk + branches painted behind the leaves.
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TreePainter(
                            layout: layout,
                            barkColor: scheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      // One tappable leaf per note.
                      for (var i = 0; i < notes.length; i++)
                        Positioned(
                          left: layout.leafAt(i).dx - _leafRadius,
                          top: layout.leafAt(i).dy - _leafRadius,
                          child: _Leaf(
                            item: notes[i],
                            color: leafColor(notes[i]),
                            onTap: () => onLeafTap(notes[i]),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const double _leafRadius = 11;

class _Leaf extends StatelessWidget {
  const _Leaf({required this.item, required this.color, required this.onTap});

  final KnowledgeItem item;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: item.front,
        child: Container(
          width: _leafRadius * 2,
          height: _leafRadius * 2,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deterministic geometry for a tree: canopy leaves arranged in a phyllotaxis
/// (golden-angle) spiral inside an ellipse, plus main branch endpoints.
class _TreeLayout {
  _TreeLayout({required this.size, required this.count}) {
    trunkBase = Offset(size.width / 2, size.height);
    trunkTop = Offset(size.width / 2, size.height * 0.5);
    canopyCenter = Offset(size.width / 2, size.height * 0.32);
    // Canopy grows with note count but never past the card bounds.
    final maxR =
        math.min(size.width / 2 - _leafRadius, size.height * 0.42);
    canopyRadius = math.min(maxR, 24 + math.sqrt(count) * 16);
  }

  final Size size;
  final int count;
  late final Offset trunkBase;
  late final Offset trunkTop;
  late final Offset canopyCenter;
  late final double canopyRadius;

  static const double _goldenAngle = 2.399963229728653;

  Offset leafAt(int i) {
    if (count <= 1) return canopyCenter;
    final t = (i + 0.5) / count;
    final r = canopyRadius * math.sqrt(t);
    final theta = i * _goldenAngle;
    return Offset(
      canopyCenter.dx + r * math.cos(theta),
      // Squash vertically so the canopy reads as a rounded crown.
      canopyCenter.dy + r * math.sin(theta) * 0.85,
    );
  }

  /// A few branch endpoints fanning from the trunk top toward the canopy edge.
  List<Offset> get branchEnds {
    const n = 4;
    return [
      for (var i = 0; i < n; i++)
        Offset(
          canopyCenter.dx +
              canopyRadius * 0.8 * math.cos(math.pi * (0.15 + 0.7 * i / (n - 1) + 1)),
          canopyCenter.dy +
              canopyRadius * 0.5 * math.sin(math.pi * (0.15 + 0.7 * i / (n - 1))),
        ),
    ];
  }
}

class _TreePainter extends CustomPainter {
  _TreePainter({required this.layout, required this.barkColor});

  final _TreeLayout layout;
  final Color barkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final trunk = Paint()
      ..color = barkColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Trunk (tapered: thick at base).
    trunk.strokeWidth = 10;
    canvas.drawLine(layout.trunkBase, layout.trunkTop, trunk);

    // Main branches from the trunk top up into the canopy.
    trunk.strokeWidth = 4;
    for (final end in layout.branchEnds) {
      canvas.drawLine(layout.trunkTop, end, trunk);
    }
    // A soft short branch straight up into the crown center.
    canvas.drawLine(layout.trunkTop, layout.canopyCenter, trunk);
  }

  @override
  bool shouldRepaint(covariant _TreePainter old) =>
      old.layout.size != layout.size ||
      old.layout.count != layout.count ||
      old.barkColor != barkColor;
}
