import '../data/image_store.dart';
import '../data/knowledge_repository.dart';
import 'sync_state.dart';
import 'telegram_sync_service.dart';

/// Outcome of a sync run, for surfacing in the UI.
class SyncSummary {
  const SyncSummary({required this.noteCount, required this.deletedCount});

  final int noteCount;
  final int deletedCount;
}

/// Orchestrates a full sync: pull the remote snapshot, merge it with local
/// state (last-write-wins via [mergeSyncState]), write the result back through
/// the [KnowledgeRepository], then push the merged snapshot so other devices
/// converge.
class SyncController {
  SyncController({
    required this.repo,
    required this.images,
    required this.service,
  });

  final KnowledgeRepository repo;
  final ImageStore images;
  final TelegramSyncService service;

  Future<SyncSummary> syncNow() async {
    // 1. Pull remote (tolerate an empty/corrupt blob as "nothing there yet").
    SyncState remote;
    final remoteJson = await service.pull();
    if (remoteJson == null || remoteJson.trim().isEmpty) {
      remote = const SyncState(items: {}, tombstones: {});
    } else {
      try {
        remote = SyncState.fromJson(remoteJson);
      } catch (_) {
        remote = const SyncState(items: {}, tombstones: {});
      }
    }

    // 2. Snapshot local (with images for notes that have them).
    final localItems = await repo.getAll();
    final localImages = <String, String>{
      for (final i in localItems)
        if (i.hasImage && images.getBase64(i.id) != null)
          i.id: images.getBase64(i.id)!,
    };
    final local = SyncState.from(
      localItems,
      await repo.getTombstones(),
      images: localImages,
    );

    // 3. Merge notes + tombstones (last-write-wins).
    final merged = mergeSyncState(local, remote);

    // 4. Reconcile images: keep an image for each surviving note, preferring
    //    the local copy, else the remote one.
    final mergedImages = <String, String>{
      for (final id in merged.items.keys)
        if ((local.images[id] ?? remote.images[id]) != null)
          id: (local.images[id] ?? remote.images[id])!,
    };
    final converged = SyncState(
      items: merged.items,
      tombstones: merged.tombstones,
      images: mergedImages,
    );

    // 5. Apply locally, then push the converged snapshot.
    await _apply(converged);
    await service.push(converged.toJson());

    return SyncSummary(
      noteCount: converged.items.length,
      deletedCount: converged.tombstones.length,
    );
  }

  Future<void> _apply(SyncState merged) async {
    // Live notes first: save() also clears any stale tombstone for that id.
    for (final item in merged.items.values) {
      await repo.save(item);
      final b64 = merged.images[item.id];
      if (b64 != null) {
        await images.putBase64(item.id, b64);
      } else if (item.hasImage) {
        // Item claims an image we don't have locally and remote didn't send —
        // nothing to store; leave as-is.
      }
    }
    // Then deletions: drop the value + image and record the winning time.
    final existing = {for (final i in await repo.getAll()) i.id};
    for (final entry in merged.tombstones.entries) {
      if (existing.contains(entry.key)) {
        await repo.removeValue(entry.key);
      }
      await images.delete(entry.key);
      await repo.setTombstone(entry.key, entry.value);
    }
  }
}
