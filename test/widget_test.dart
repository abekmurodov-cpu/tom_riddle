import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge/src/data/knowledge_repository.dart';
import 'package:knowledge/src/models/knowledge_item.dart';
import 'package:knowledge/src/providers/knowledge_providers.dart';
import 'package:knowledge/src/scheduler/spaced_repetition.dart';
import 'package:knowledge/src/ui/home_screen.dart';

/// Simple in-memory repository so tests don't touch Hive/disk.
class FakeRepository implements KnowledgeRepository {
  final Map<String, KnowledgeItem> _store = {};
  final Map<String, DateTime> _tombstones = {};

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
    _tombstones[id] = DateTime.now();
  }

  @override
  Future<List<KnowledgeItem>> getAll() async => _store.values.toList();

  @override
  Future<void> save(KnowledgeItem item) async {
    _store[item.id] = item;
    _tombstones.remove(item.id);
  }

  @override
  Future<void> removeValue(String id) async => _store.remove(id);

  @override
  Future<Map<String, DateTime>> getTombstones() async => Map.of(_tombstones);

  @override
  Future<void> setTombstone(String id, DateTime at) async =>
      _tombstones[id] = at;
}

void main() {
  group('SpacedRepetition', () {
    const scheduler = SpacedRepetition();

    KnowledgeItem freshItem() {
      final now = DateTime(2026, 1, 1);
      return KnowledgeItem(
        id: 'x',
        front: 'What is a mutex?',
        back: 'A mutual-exclusion lock.',
        type: KnowledgeType.concept,
        createdAt: now,
        dueDate: now,
      );
    }

    test('a "good" grade advances the interval and streak', () {
      final now = DateTime(2026, 1, 1);
      final graded = scheduler.schedule(freshItem(), ReviewGrade.good, now: now);

      expect(graded.repetitions, 1);
      expect(graded.intervalDays, 1);
      expect(graded.dueDate.isAfter(now), isTrue);
    });

    test('an "again" grade resets the streak to a 1-day interval', () {
      final now = DateTime(2026, 1, 1);
      final matured = freshItem().copyWith(repetitions: 5, intervalDays: 40);
      final graded = scheduler.schedule(matured, ReviewGrade.again, now: now);

      expect(graded.repetitions, 0);
      expect(graded.intervalDays, 1);
    });
  });

  testWidgets('empty state shows the tagline', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          knowledgeRepositoryProvider.overrideWithValue(FakeRepository()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your notes will hit back.'), findsOneWidget);
  });
}
