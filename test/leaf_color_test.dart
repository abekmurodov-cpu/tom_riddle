import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge/src/models/knowledge_item.dart';
import 'package:knowledge/src/ui/widgets/category_tree.dart';

KnowledgeItem withCorrect(bool? lastCorrect) {
  final now = DateTime(2026, 1, 1);
  return KnowledgeItem(
    id: 'x',
    front: 'q',
    type: KnowledgeType.fact,
    createdAt: now,
    dueDate: now,
    lastCorrect: lastCorrect,
  );
}

void main() {
  group('leafColor', () {
    test('never-reviewed note is amber', () {
      expect(leafColor(withCorrect(null)), const Color(0xFFE0A93B));
    });

    test('last-correct note is green', () {
      expect(leafColor(withCorrect(true)), const Color(0xFF2E9E4F));
    });

    test('last-wrong note is red', () {
      expect(leafColor(withCorrect(false)), const Color(0xFFD64545));
    });
  });
}
