import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/knowledge_item.dart';
import '../../providers/knowledge_providers.dart';

/// A single knowledge item rendered as a card tile. Shared between the Home
/// list and the Notes list view.
class ItemTile extends ConsumerWidget {
  const ItemTile({super.key, required this.item, this.onTap});

  final KnowledgeItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        title: Text(item.front, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.hasAnswer ? item.back! : 'No answer yet',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: item.hasAnswer
              ? null
              : TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600]),
        ),
        leading: TypeChip(type: item.type),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: () =>
              ref.read(knowledgeListProvider.notifier).delete(item.id),
        ),
      ),
    );
  }
}

/// Round avatar with an icon representing the [KnowledgeType].
class TypeChip extends StatelessWidget {
  const TypeChip({super.key, required this.type});

  final KnowledgeType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      KnowledgeType.fact => Icons.lightbulb_outline,
      KnowledgeType.concept => Icons.hub_outlined,
      KnowledgeType.command => Icons.terminal,
      KnowledgeType.code => Icons.code,
      KnowledgeType.question => Icons.help_outline,
    };
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      child: Icon(icon, size: 20),
    );
  }
}
