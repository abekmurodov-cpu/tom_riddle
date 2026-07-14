import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/image_store.dart';
import '../data/knowledge_repository.dart';
import '../models/knowledge_item.dart';
import '../scheduler/spaced_repetition.dart';

/// Bound to the concrete repository in `main` via a ProviderScope override.
final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  throw UnimplementedError('knowledgeRepositoryProvider must be overridden');
});

/// Bound to the concrete image store in `main` via a ProviderScope override.
final imageStoreProvider = Provider<ImageStore>((ref) {
  throw UnimplementedError('imageStoreProvider must be overridden');
});

final _schedulerProvider =
    Provider<SpacedRepetition>((ref) => const SpacedRepetition());

const _uuid = Uuid();

/// Owns the full list of knowledge items and all mutations to it.
class KnowledgeListNotifier extends AsyncNotifier<List<KnowledgeItem>> {
  KnowledgeRepository get _repo => ref.read(knowledgeRepositoryProvider);
  ImageStore get _images => ref.read(imageStoreProvider);

  @override
  Future<List<KnowledgeItem>> build() => _repo.getAll();

  Future<void> addItem({
    required String front,
    String? back,
    required KnowledgeType type,
    String? category,
    Uint8List? imageBytes,
    String? mcAnswer,
    List<String> mcDistractors = const [],
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    if (imageBytes != null) {
      await _images.putBytes(id, imageBytes);
    }
    final item = KnowledgeItem(
      id: id,
      front: front.trim(),
      back: back?.trim().isEmpty ?? true ? null : back!.trim(),
      type: type,
      category: category?.trim().isEmpty ?? true ? null : category!.trim(),
      createdAt: now,
      dueDate: now, // due immediately so it appears in the first review
      hasImage: imageBytes != null,
      mcAnswer: mcAnswer,
      mcDistractors: mcDistractors,
    );
    await _repo.save(item);
    await _refresh();
  }

  /// Persists an already-built item (bumping [updatedAt] for sync). Used by the
  /// practice flow to cache a generated answer / multiple-choice quiz.
  Future<void> persist(KnowledgeItem item) async {
    await _repo.save(item.copyWith(updatedAt: DateTime.now()));
    await _refresh();
  }

  /// Attaches (or replaces) an image on an existing note.
  Future<void> setImage(KnowledgeItem item, Uint8List bytes) async {
    await _images.putBytes(item.id, bytes);
    await _repo.save(item.copyWith(hasImage: true, updatedAt: DateTime.now()));
    await _refresh();
  }

  /// Removes a note's image.
  Future<void> removeImage(KnowledgeItem item) async {
    await _images.delete(item.id);
    await _repo.save(item.copyWith(hasImage: false, updatedAt: DateTime.now()));
    await _refresh();
  }

  /// Records a review outcome, reschedules the item, and persists it.
  Future<void> grade(KnowledgeItem item, ReviewGrade grade) async {
    final updated = ref.read(_schedulerProvider).schedule(item, grade);
    await _repo.save(updated);
    await _refresh();
  }

  /// Edits a note's content fields and persists it, bumping [updatedAt] so the
  /// change wins during sync.
  Future<void> updateItem(
    KnowledgeItem item, {
    required String front,
    String? back,
    required KnowledgeType type,
    String? category,
  }) async {
    final updated = item.copyWith(
      front: front.trim(),
      back: back?.trim().isEmpty ?? true ? null : back!.trim(),
      type: type,
      category: category?.trim().isEmpty ?? true ? null : category!.trim(),
      updatedAt: DateTime.now(),
    );
    await _repo.save(updated);
    await _refresh();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await _images.delete(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = AsyncData(await _repo.getAll());
  }
}

final knowledgeListProvider =
    AsyncNotifierProvider<KnowledgeListNotifier, List<KnowledgeItem>>(
  KnowledgeListNotifier.new,
);

/// Items whose due date has arrived, oldest-due first — the review queue.
final dueItemsProvider = Provider<List<KnowledgeItem>>((ref) {
  final items = ref.watch(knowledgeListProvider).asData?.value ?? const [];
  final now = DateTime.now();
  final due = items.where((i) => i.isDue(now)).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return due;
});

/// Label used to group notes with no category in the tree view.
const String kUngroupedCategory = 'Ungrouped';

/// All notes, newest first — the backing order for the paginated list view.
final notesSortedProvider = Provider<List<KnowledgeItem>>((ref) {
  final items = ref.watch(knowledgeListProvider).asData?.value ?? const [];
  final sorted = List.of(items)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted;
});

/// Notes grouped by category (uncategorized → [kUngroupedCategory]); one entry
/// per category becomes one tree in the tree view. Categories are alphabetical,
/// with [kUngroupedCategory] last.
final notesByCategoryProvider =
    Provider<Map<String, List<KnowledgeItem>>>((ref) {
  final items = ref.watch(notesSortedProvider);
  final groups = <String, List<KnowledgeItem>>{};
  for (final item in items) {
    final key = (item.category == null || item.category!.trim().isEmpty)
        ? kUngroupedCategory
        : item.category!.trim();
    (groups[key] ??= <KnowledgeItem>[]).add(item);
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      if (a == kUngroupedCategory) return 1;
      if (b == kUngroupedCategory) return -1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  return {for (final k in keys) k: groups[k]!};
});

/// Distinct category names present in the store (excludes the synthetic
/// ungrouped bucket) — used to populate the practice "category" picker.
final categoriesProvider = Provider<List<String>>((ref) {
  final groups = ref.watch(notesByCategoryProvider);
  return groups.keys.where((k) => k != kUngroupedCategory).toList();
});
