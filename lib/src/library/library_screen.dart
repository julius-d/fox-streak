// Home library: list of sets + FAB (issue #003).
//
// Lists title, item count, type icons (vocab/phone/date). No "last score" —
// moved to #005/#012. Watches `watchAllSets` via [allSetsProvider];
// counts/icons via [itemsForSetProvider].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/providers.dart';
import 'item_type_icons.dart';
import 'library_providers.dart';
import 'set_detail_screen.dart';
import 'set_editor_screen.dart';

/// Library home screen: all sets with counts + type icons.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _seeding = false;
  String? _seedError;

  Future<void> _openEditor([QuestionSet? existing]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SetEditorScreen(existing: existing)),
    );
  }

  Future<void> _confirmDeleteSet(QuestionSet set) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSetTitle),
        content: Text(l10n.deleteSetMessage(set.title)),
        actions: [
          TextButton(
            key: const Key('cancelDeleteSetButton'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirmDeleteSetButton'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirmDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(setsRepositoryProvider).deleteSet(set.id);
    }
  }

  Future<void> _duplicateSet(int id) async {
    await ref.read(setsRepositoryProvider).duplicateSet(id);
  }

  Future<void> _seedDemo() async {
    setState(() {
      _seeding = true;
      _seedError = null;
    });
    try {
      await ref.read(seedLoaderProvider).ensureSeeded();
    } catch (e) {
      setState(() => _seedError = e.toString());
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final setsAsync = ref.watch(allSetsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraryTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newSetFab'),
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(l10n.newSet),
      ),
      body: setsAsync.when(
        loading: () => Center(
          key: const Key('libraryLoading'),
          child: Text(l10n.libraryLoading),
        ),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (sets) {
          if (sets.isEmpty) return _buildEmpty(context, l10n);
          return ListView.builder(
            itemCount: sets.length,
            itemBuilder: (context, index) {
              final set = sets[index];
              return _SetCard(
                set: set,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SetDetailScreen(setId: set.id),
                  ),
                ),
                onRename: () => _openEditor(set),
                onDuplicate: () => _duplicateSet(set.id),
                onDelete: () => _confirmDeleteSet(set),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.libraryEmptyTitle,
              key: const Key('libraryEmptyTitle'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(l10n.libraryEmptyMessage, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (_seeding)
              Text(
                l10n.librarySeedLoading,
                key: const Key('librarySeedLoading'),
              )
            else
              FilledButton(
                key: const Key('tryDemoSetButton'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _seedDemo,
                child: Text(l10n.libraryTryDemo),
              ),
            if (_seedError != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.librarySeedError,
                key: const Key('librarySeedError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One set row: title, item count, type icons, overflow menu.
class _SetCard extends ConsumerWidget {
  final QuestionSet set;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _SetCard({
    required this.set,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(itemsForSetProvider(set.id));
    final subtitle = itemsAsync.when(
      loading: () => l10n.libraryLoading,
      error: (_, _) => '',
      data: (items) => l10n.setItemCount(items.length),
    );
    final icons = itemsAsync.when(
      loading: () => const <Widget>[],
      error: (_, _) => const <Widget>[],
      data: (items) {
        final types = items.map((e) => e.type).toSet().toList()..sort();
        return [
          for (final t in types)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(iconForItemType(t), size: 18),
            ),
        ];
      },
    );
    return Card(
      child: ListTile(
        key: Key('setTile-${set.id}'),
        minVerticalPadding: 12,
        title: Text(set.title),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...icons,
            PopupMenuButton<String>(
              key: Key('setMenu-${set.id}'),
              tooltip: l10n.setActions,
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    onRename();
                  case 'duplicate':
                    onDuplicate();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
                PopupMenuItem(value: 'duplicate', child: Text(l10n.duplicate)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}
