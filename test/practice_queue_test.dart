import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge/src/models/knowledge_item.dart';
import 'package:knowledge/src/practice/practice_models.dart';

KnowledgeItem note(
  String id, {
  String? back,
  bool? lastCorrect,
  int lapses = 0,
}) {
  final now = DateTime(2026, 1, 1);
  return KnowledgeItem(
    id: id,
    front: 'q$id',
    back: back,
    type: KnowledgeType.fact,
    createdAt: now,
    dueDate: now,
    lastCorrect: lastCorrect,
    lapses: lapses,
  );
}

void main() {
  group('PracticeConfig.buildQueue', () {
    test('weak points scope selects last-wrong or repeatedly-lapsed notes', () {
      final all = [
        note('ok', back: 'a', lastCorrect: true),
        note('wrong', back: 'a', lastCorrect: false),
        note('lapsed', back: 'a', lastCorrect: true, lapses: 3),
        note('fresh', back: 'a'),
      ];
      const config = PracticeConfig(
        method: PracticeMethod.flashcard,
        scope: PracticeScope.weakPoints,
      );
      final ids = config.buildQueue(all: all, due: const []).map((i) => i.id);
      expect(ids, containsAll(['wrong', 'lapsed']));
      expect(ids, isNot(contains('ok')));
      expect(ids, isNot(contains('fresh')));
    });

    test('MC drops answer-less notes unless generation is available', () {
      final all = [note('has', back: 'a'), note('bare')];
      const config = PracticeConfig(
        method: PracticeMethod.multipleChoice,
        scope: PracticeScope.all,
      );

      final noAi = config.buildQueue(all: all, due: const []);
      expect(noAi.map((i) => i.id), ['has']);

      final withAi =
          config.buildQueue(all: all, due: const [], canGenerate: true);
      expect(withAi.map((i) => i.id), containsAll(['has', 'bare']));
    });
  });
}
