import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/knowledge_item.dart';
import '../../providers/knowledge_providers.dart';
import 'image_picking.dart';
import 'item_tile.dart';
import 'note_image.dart';

/// Bottom sheet showing a note's details with quick edit + delete. Opened from
/// the notes list and from tree leaves.
Future<void> showNoteDetailSheet(BuildContext context, KnowledgeItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NoteDetailSheet(item: item),
  );
}

class _NoteDetailSheet extends ConsumerStatefulWidget {
  const _NoteDetailSheet({required this.item});

  final KnowledgeItem item;

  @override
  ConsumerState<_NoteDetailSheet> createState() => _NoteDetailSheetState();
}

class _NoteDetailSheetState extends ConsumerState<_NoteDetailSheet> {
  late final TextEditingController _front =
      TextEditingController(text: widget.item.front);
  late final TextEditingController _back =
      TextEditingController(text: widget.item.back ?? '');
  late final TextEditingController _category =
      TextEditingController(text: widget.item.category ?? '');
  late KnowledgeType _type = widget.item.type;
  bool _editing = false;

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(knowledgeListProvider.notifier).updateItem(
          widget.item,
          front: _front.text,
          back: _back.text,
          type: _type,
          category: _category.text,
        );
    if (mounted) setState(() => _editing = false);
  }

  Future<void> _delete() async {
    await ref.read(knowledgeListProvider.notifier).delete(widget.item.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickImage() async {
    final bytes = await pickImageBytes(context);
    if (bytes == null) return;
    await ref.read(knowledgeListProvider.notifier).setImage(widget.item, bytes);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: _editing ? _buildEdit() : _buildView(item),
    );
  }

  Widget _buildView(KnowledgeItem item) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TypeChip(type: item.type),
            const SizedBox(width: 12),
            Expanded(
              child: Text(item.type.label.toUpperCase(),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(letterSpacing: 1.2)),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => setState(() => _editing = true),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(item.front, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        NoteImage(noteId: item.id),
        const Divider(height: 28),
        Text(
          item.hasAnswer ? item.back! : 'No answer yet',
          style: item.hasAnswer
              ? theme.textTheme.bodyLarge
              : theme.textTheme.bodyLarge
                  ?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        if (item.category != null)
          Chip(
            avatar: const Icon(Icons.folder_outlined, size: 16),
            label: Text(item.category!),
          ),
      ],
    );
  }

  Widget _buildEdit() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final type in KnowledgeType.values)
              ChoiceChip(
                label: Text(type.label),
                selected: _type == type,
                onSelected: (_) => setState(() => _type = type),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _front,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
              labelText: 'Prompt', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _back,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
              labelText: 'Answer / details', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _category,
          decoration: const InputDecoration(
              labelText: 'Category', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(widget.item.hasImage ? 'Replace image' : 'Add image'),
            ),
            if (widget.item.hasImage) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => ref
                    .read(knowledgeListProvider.notifier)
                    .removeImage(widget.item),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ],
    );
  }
}
