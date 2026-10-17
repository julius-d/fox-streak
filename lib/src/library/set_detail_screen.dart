// Set detail: item list + overflow menu (issue #003).
//
// Shows items text-only (no images — #014). No field editing here; add/edit
// goes through `ItemEditorScreen` (field widgets owned by #004; converted
// from a dialog to a full screen by #047).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../data/set_json_codec.dart';
import '../data/validation.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import '../lesson/lesson.dart';
import 'date_display.dart';
import 'item_editor.dart';
import 'item_type_icons.dart';
import 'library_providers.dart';
import 'phone_formatting.dart';
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
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemEditorScreen(setId: setId, existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final setsRepo = ref.read(setsRepositoryProvider);
    final itemsAsync = ref.watch(itemsForSetProvider(setId));
    var title = l10n.libraryTitle;
    String? category;
    ref.watch(allSetsProvider).whenData((allSets) {
      for (final s in allSets) {
        if (s.id == setId) {
          title = s.title;
          category = s.category;
        }
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
      // Two stacked FABs (#042): "Start lesson" (primary, bottom) stays
      // reachable without scrolling past the item list; "Add item"
      // (secondary) sits above it. Distinct heroTags since both are mounted
      // at once.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            key: const Key('addItemFab'),
            heroTag: 'addItemFab',
            tooltip: l10n.setDetailAddItem,
            // `small`'s 40dp visual size is below the 48dp a11y floor
            // (#015); desktop platforms default `materialTapTargetSize` to
            // `shrinkWrap` (no tap-target padding), unlike mobile's
            // `padded` default — override explicitly so Windows/macOS get
            // the same 48dp tap target as Android/iOS.
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onPressed: () => _openItemEditor(context, ref),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: FoxSpacing.sm),
          FloatingActionButton.extended(
            key: const Key('startLessonFab'),
            heroTag: 'startLessonFab',
            onPressed: () => startLessonFromSet(
              context: context,
              setId: setId,
              itemsAsync: itemsAsync,
              l10n: l10n,
            ),
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.lessonStart),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => Center(child: Text(l10n.libraryLoading)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (loadedItems) {
          if (loadedItems.isEmpty) {
            return FoxEmptyState(
              title: l10n.setDetailEmpty,
              message: l10n.lessonEmptySetNote,
              mascotState: FoxMascotState.empty,
              ctaLabel: l10n.lessonBackToLibrary,
              onCta: () => Navigator.of(context).pop(),
              ctaKey: const Key('emptySetBackToLibraryButton'),
            );
          }
          return ListView.builder(
            itemCount: loadedItems.length,
            itemBuilder: (context, index) {
              final item = loadedItems[index];
              final typeLabel = switch (item.type) {
                'choice' => l10n.typeChoice,
                'freeText' => l10n.typeFreeText,
                'phone' => l10n.typePhone,
                'date' => l10n.typeDate,
                _ => item.type,
              };
              final displayAnswer = switch (item.type) {
                'date' => formatDateForDisplay(
                  item.answer,
                  Localizations.localeOf(context),
                ),
                'phone' => groupPhoneForDisplay(normalizePhone(item.answer)),
                _ => item.answer,
              };
              return ListTile(
                key: Key('itemTile-${item.id}'),
                leading: Icon(
                  key: Key('itemTypeIcon-${item.id}'),
                  iconForItemType(item.type, category),
                  color: colorForItemType(context, item.type, category),
                ),
                title: Text(item.prompt),
                subtitle: Text('$typeLabel · $displayAnswer'),
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
            },
          );
        },
      ),
    );
  }
}
