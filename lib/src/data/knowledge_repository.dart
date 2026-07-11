import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/knowledge_item.dart';

/// Storage contract for knowledge items. Kept abstract so the app can swap the
/// local Hive store for a synced/remote backend later without touching the UI.
///
/// Deletions are recorded as **tombstones** (id → deletion time) so that a
/// delete on one device can propagate through sync instead of a stale copy on
/// another device silently resurrecting the note.
abstract class KnowledgeRepository {
  Future<List<KnowledgeItem>> getAll();
  Future<void> save(KnowledgeItem item);

  /// Deletes a note (user-initiated): removes the value and records a tombstone
  /// stamped now.
  Future<void> delete(String id);

  /// Removes a note's stored value without recording a tombstone. Used by the
  /// sync layer when applying a merge, where the tombstone time is set
  /// explicitly via [setTombstone] to preserve the winning timestamp.
  Future<void> removeValue(String id);

  Future<Map<String, DateTime>> getTombstones();
  Future<void> setTombstone(String id, DateTime at);
}

/// Hive-backed local store. Items are persisted as JSON strings keyed by id,
/// which works uniformly on mobile and web and keeps the model free of
/// generated Hive adapters. Tombstones live in a sibling box keyed by id with
/// ISO-8601 timestamps.
class HiveKnowledgeRepository implements KnowledgeRepository {
  HiveKnowledgeRepository(this._box, this._tombstones);

  static const String boxName = 'knowledge_items';
  static const String tombstoneBoxName = 'knowledge_tombstones';

  final Box<String> _box;
  final Box<String> _tombstones;

  /// Opens Hive and the item + tombstone boxes. Call once during app startup.
  static Future<HiveKnowledgeRepository> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(boxName);
    final tombstones = await Hive.openBox<String>(tombstoneBoxName);
    return HiveKnowledgeRepository(box, tombstones);
  }

  @override
  Future<List<KnowledgeItem>> getAll() async {
    return _box.values
        .map((json) => KnowledgeItem.fromJson(json))
        .toList(growable: false);
  }

  @override
  Future<void> save(KnowledgeItem item) async {
    await _box.put(item.id, item.toJson());
    // A resurrected/edited note clears any stale tombstone.
    await _tombstones.delete(item.id);
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
    await _tombstones.put(id, DateTime.now().toIso8601String());
  }

  @override
  Future<void> removeValue(String id) async {
    await _box.delete(id);
  }

  @override
  Future<Map<String, DateTime>> getTombstones() async {
    return {
      for (final key in _tombstones.keys)
        key as String: DateTime.parse(_tombstones.get(key) as String),
    };
  }

  @override
  Future<void> setTombstone(String id, DateTime at) async {
    await _tombstones.put(id, at.toIso8601String());
  }
}
