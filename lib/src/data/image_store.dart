import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Stores note images as base64 strings keyed by note id, in their own Hive box
/// so they don't bloat the item records. Base64 keeps storage uniform across
/// mobile and web and lets images ride along in the Telegram sync blob.
class ImageStore {
  ImageStore(this._box);

  static const String boxName = 'note_images';

  final Box<String> _box;

  static Future<ImageStore> open() async {
    final box = await Hive.openBox<String>(boxName);
    return ImageStore(box);
  }

  bool has(String id) => _box.containsKey(id);

  /// Raw base64 for a note's image, or null if none.
  String? getBase64(String id) => _box.get(id);

  /// Decoded bytes for display, or null if none.
  Uint8List? getBytes(String id) {
    final b64 = _box.get(id);
    if (b64 == null) return null;
    return base64Decode(b64);
  }

  Future<void> putBytes(String id, Uint8List bytes) async {
    await _box.put(id, base64Encode(bytes));
  }

  Future<void> putBase64(String id, String base64) async {
    await _box.put(id, base64);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
