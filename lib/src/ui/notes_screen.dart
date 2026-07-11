import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/knowledge_providers.dart';
import 'widgets/category_tree.dart';
import 'widgets/item_tile.dart';
import 'widgets/note_detail_sheet.dart';

enum _NotesView { list, tree }

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  static const int _pageSize = 50;

  _NotesView _view = _NotesView.list;
  int _visible = _pageSize;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      final total = ref.read(notesSortedProvider).length;
      if (_visible < total) {
        setState(() => _visible = (_visible + _pageSize).clamp(0, total));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<_NotesView>(
              segments: const [
                ButtonSegment(
                  value: _NotesView.list,
                  label: Text('List'),
                  icon: Icon(Icons.view_list),
                ),
                ButtonSegment(
                  value: _NotesView.tree,
                  label: Text('Tree'),
                  icon: Icon(Icons.park),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
        ),
      ),
      body: switch (_view) {
        _NotesView.list => _buildList(),
        _NotesView.tree => _buildTree(),
      },
    );
  }

  Widget _buildList() {
    final notes = ref.watch(notesSortedProvider);
    if (notes.isEmpty) return const _EmptyNotes();
    final count = _visible.clamp(0, notes.length);
    final hasMore = count < notes.length;
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: count + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        if (i >= count) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = notes[i];
        return ItemTile(
          item: item,
          onTap: () => showNoteDetailSheet(context, item),
        );
      },
    );
  }

  Widget _buildTree() {
    final groups = ref.watch(notesByCategoryProvider);
    if (groups.isEmpty) return const _EmptyNotes();
    final entries = groups.entries.toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const _TreeLegend(),
        for (final entry in entries)
          CategoryTree(
            category: entry.key,
            notes: entry.value,
            onLeafTap: (item) => showNoteDetailSheet(context, item),
          ),
      ],
    );
  }
}

class _TreeLegend extends StatelessWidget {
  const _TreeLegend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          dot(const Color(0xFF2E9E4F), 'Recalled'),
          dot(const Color(0xFFD64545), 'Needs work'),
          dot(const Color(0xFFE0A93B), 'New'),
        ],
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_outlined,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            const Text('No notes yet. Capture some and watch them grow.'),
          ],
        ),
      ),
    );
  }
}
