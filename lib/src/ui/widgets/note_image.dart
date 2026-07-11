import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/knowledge_providers.dart';

/// Displays a note's stored image (if any) as a rounded, contained thumbnail.
/// Reads bytes synchronously from the [ImageStore]; renders nothing when the
/// note has no image.
class NoteImage extends ConsumerWidget {
  const NoteImage({super.key, required this.noteId, this.maxHeight = 220});

  final String noteId;
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Depend on the list so the image refreshes when notes mutate.
    ref.watch(knowledgeListProvider);
    final bytes = ref.read(imageStoreProvider).getBytes(noteId);
    if (bytes == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Image.memory(
          bytes,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
