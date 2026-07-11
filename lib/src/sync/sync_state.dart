import 'dart:convert';

import '../models/knowledge_item.dart';

/// The full syncable snapshot: live notes plus deletion tombstones. Serialized
/// to JSON and stored as the single source-of-truth blob in Telegram.
class SyncState {
  const SyncState({
    required this.items,
    required this.tombstones,
    this.images = const {},
  });

  /// Live notes keyed by id.
  final Map<String, KnowledgeItem> items;

  /// Deleted note ids → deletion time.
  final Map<String, DateTime> tombstones;

  /// Note id → base64 image, for notes that have one. Kept alongside items so a
  /// single blob carries images across devices.
  final Map<String, String> images;

  static const int version = 1;

  factory SyncState.from(
    List<KnowledgeItem> items,
    Map<String, DateTime> tombstones, {
    Map<String, String> images = const {},
  }) {
    return SyncState(
      items: {for (final i in items) i.id: i},
      tombstones: tombstones,
      images: images,
    );
  }

  Map<String, dynamic> toMap() => {
        'version': version,
        'items': items.values.map((i) => i.toMap()).toList(),
        'tombstones': {
          for (final e in tombstones.entries) e.key: e.value.toIso8601String(),
        },
        'images': images,
      };

  String toJson() => jsonEncode(toMap());

  factory SyncState.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    final items = <String, KnowledgeItem>{};
    for (final raw in (map['items'] as List? ?? const [])) {
      final item = KnowledgeItem.fromMap(raw as Map<String, dynamic>);
      items[item.id] = item;
    }
    final tombstones = <String, DateTime>{};
    final rawTomb = map['tombstones'] as Map<String, dynamic>? ?? const {};
    rawTomb.forEach((k, v) => tombstones[k] = DateTime.parse(v as String));
    final images = <String, String>{};
    final rawImages = map['images'] as Map<String, dynamic>? ?? const {};
    rawImages.forEach((k, v) => images[k] = v as String);
    return SyncState(items: items, tombstones: tombstones, images: images);
  }
}

/// Merges two snapshots with **last-write-wins** semantics per note id:
///
/// * The surviving note is whichever side has the newer [KnowledgeItem.updatedAt].
/// * A tombstone (deletion) wins when its time is at or after the surviving
///   note's `updatedAt` — a delete beats an equal-or-older edit; a newer edit
///   resurrects the note.
///
/// Pure and deterministic, so it can be unit-tested without any network.
SyncState mergeSyncState(SyncState local, SyncState remote) {
  final ids = <String>{
    ...local.items.keys,
    ...remote.items.keys,
    ...local.tombstones.keys,
    ...remote.tombstones.keys,
  };

  final mergedItems = <String, KnowledgeItem>{};
  final mergedTombstones = <String, DateTime>{};

  for (final id in ids) {
    final localItem = local.items[id];
    final remoteItem = remote.items[id];
    final best = _newer(localItem, remoteItem);

    final tomb = _maxDate(local.tombstones[id], remote.tombstones[id]);

    if (tomb != null && (best == null || !tomb.isBefore(best.updatedAt))) {
      mergedTombstones[id] = tomb;
    } else if (best != null) {
      mergedItems[id] = best;
    }
  }

  return SyncState(items: mergedItems, tombstones: mergedTombstones);
}

KnowledgeItem? _newer(KnowledgeItem? a, KnowledgeItem? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.updatedAt.isBefore(b.updatedAt) ? b : a;
}

DateTime? _maxDate(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}
