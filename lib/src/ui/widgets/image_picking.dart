import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Whether the platform has a camera worth offering (mobile only).
bool get _isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Prompts the user to pick an image and returns its bytes, or null if
/// cancelled. On mobile it offers camera/gallery; on desktop and web it goes
/// straight to the file picker (no camera). Bytes (not paths) so it works
/// uniformly across platforms and can be base64-stored + synced.
Future<Uint8List?> pickImageBytes(BuildContext context) async {
  ImageSource source = ImageSource.gallery;
  if (_isMobile) {
    final picked = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return null;
    source = picked;
  }

  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 80,
  );
  if (file == null) return null;
  return file.readAsBytes();
}
