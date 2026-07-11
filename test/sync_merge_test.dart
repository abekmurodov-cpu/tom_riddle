import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge/src/models/knowledge_item.dart';
import 'package:knowledge/src/sync/sync_state.dart';

KnowledgeItem item(String id, {required DateTime updatedAt, String front = 'q'}) {
  final created = DateTime(2026, 1, 1);
  return KnowledgeItem(
    id: id,
    front: front,
    type: KnowledgeType.fact,
    createdAt: created,
    dueDate: created,
    updatedAt: updatedAt,
  );
}

void main() {
  group('mergeSyncState (last-write-wins)', () {
    test('keeps the newer edit of the same note', () {
      final local = SyncState.from(
        [item('a', updatedAt: DateTime(2026, 2, 1), front: 'old')],
        {},
      );
      final remote = SyncState.from(
        [item('a', updatedAt: DateTime(2026, 3, 1), front: 'new')],
        {},
      );

      final merged = mergeSyncState(local, remote);
      expect(merged.items['a']!.front, 'new');
    });

    test('unions notes that exist on only one side', () {
      final local = SyncState.from([item('a', updatedAt: DateTime(2026, 2, 1))], {});
      final remote = SyncState.from([item('b', updatedAt: DateTime(2026, 2, 1))], {});

      final merged = mergeSyncState(local, remote);
      expect(merged.items.keys, containsAll(['a', 'b']));
    });

    test('a tombstone newer than the edit deletes the note', () {
      final local = SyncState.from([item('a', updatedAt: DateTime(2026, 2, 1))], {});
      final remote = SyncState(items: const {}, tombstones: {'a': DateTime(2026, 3, 1)});

      final merged = mergeSyncState(local, remote);
      expect(merged.items.containsKey('a'), isFalse);
      expect(merged.tombstones.containsKey('a'), isTrue);
    });

    test('an edit newer than the tombstone resurrects the note', () {
      final local = SyncState.from([item('a', updatedAt: DateTime(2026, 4, 1))], {});
      final remote = SyncState(items: const {}, tombstones: {'a': DateTime(2026, 3, 1)});

      final merged = mergeSyncState(local, remote);
      expect(merged.items.containsKey('a'), isTrue);
      expect(merged.tombstones.containsKey('a'), isFalse);
    });

    test('round-trips through JSON', () {
      final state = SyncState.from(
        [item('a', updatedAt: DateTime(2026, 2, 1))],
        {'z': DateTime(2026, 1, 15)},
      );
      final restored = SyncState.fromJson(state.toJson());
      expect(restored.items.keys, ['a']);
      expect(restored.tombstones['z'], DateTime(2026, 1, 15));
    });
  });
}
