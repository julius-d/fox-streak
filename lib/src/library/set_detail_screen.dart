// Set detail: item list + overflow menu (issue #003).
//
// Shows items text-only (no images — #014). No field editing here; add/edit
// goes through `ItemEditorDialog` (field widgets owned by #004).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../data/set_json_codec.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import '../lesson/lesson.dart';
import 'item_editor.dart';
import 'item_type_icons.dart';
import 'library_providers.dart';
import 'share_actions.dart';

/// Detail view for one set: its items plus share/import overflow menu.
class SetDetailScreen extends ConsumerWidget {
  final int setId;

  const SetDetailScreen({super.key, required this.setId});

  Future<void> _confirmDeleteItem(
    BuildContext context,
    WidgetRef ref,
    int itemId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await FoxConfirmDialog.show(
      context: context,
      title: l10n.deleteItemTitle,
      message: l10n.deleteItemMessage,
      confirmLabel: l10n.confirmDelete,
      cancelLabel: l10n.cancel,
      confirmKey: const Key('confirmDeleteItemButton'),
    );
    if (confirmed == true) {
      await ref.read(setsRepositoryProvider).deleteItem(itemId);
    }
  }

  Future<void> _openItemEditor(
    BuildContext context,
    WidgetRef ref, [
    Item? existing,
  ]) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => ItemEditorDialog(setId: setId, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final setsRepo = ref.read(setsRepositoryProvider);
    final itemsAsync = ref.watch(itemsForSetProvider(setId));
    var title = l10n.libraryTitle;
    ref.watch(allSetsProvider).whenData((allSets) {
      for (final s in allSets) {
        if (s.id == setId) title = s.title;
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<String>(
            key: const Key('setOverflowMenu'),
            tooltip: l10n.setActions,
            onSelected: (value) async {
              if (value == 'share') {
                try {
                  final set = await setsRepo.getSetById(setId);
                  if (!context.mounted) return;
                  await shareSet(ref, setId, set?.title ?? 'set');
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
                }
              } else if (value == 'import') {
                try {
                  await importSetFromPicker(ref);
                } on SetImportException catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.importFailed)));
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'share', child: Text(l10n.shareSet)),
              PopupMenuItem(value: 'import', child: Text(l10n.importSet)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addItemFab'),
        onPressed: () => _openItemEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.setDetailAddItem),
      ),
      body: itemsAsync.when(
        loading: () => Center(child: Text(l10n.libraryLoading)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (items) {
          if (items.isEmpty) {
            return FoxEmptyState(
              title: l10n.setDetailEmpty,
              message: l10n.lessonEmptySetNote,
              mascotState: FoxMascotState.empty,
              ctaLabel: l10n.lessonBackToLibrary,
              onCta: () => Navigator.of(context).pop(),
              ctaKey: const Key('emptySetBackToLibraryButton'),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = items[index];
                  final typeLabel = switch (item.type) {
                    'vocab' => l10n.typeVocab,
                    'phone' => l10n.typePhone,
                    'date' => l10n.typeDate,
                    _ => item.type,
                  };
                  return ListTile(
                    key: Key('itemTile-${item.id}'),
                    leading: Icon(
                      iconForItemType(item.type),
                      color: colorForItemType(context, item.type),
                    ),
                    title: Text(item.prompt),
                    subtitle: Text('$typeLabel · ${item.answer}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: Key('editItem-${item.id}'),
                          tooltip: l10n.edit,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openItemEditor(context, ref, item),
                        ),
                        IconButton(
                          key: Key('deleteItem-${item.id}'),
                          tooltip: l10n.delete,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _confirmDeleteItem(context, ref, item.id),
                        ),
                      ],
                    ),
                  );
                }, childCount: items.length),
              ),
              // Lesson entry button as footer
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(FoxSpacing.lg),
                  child: LessonEntryButton(setId: setId),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
