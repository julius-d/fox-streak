// Home library: list of sets + FAB (issue #003).
//
// Lists title, item count. No "last score" — moved to #005/#012. Watches
// `watchAllSets` via [allSetsProvider]; counts/play-affordance via
// [itemsForSetProvider]. Each row's play icon jumps straight into
// `LessonScreen`, skipping `SetDetailScreen` entirely (#042).
//
// `newSetFab` is a speed-dial (issue #074): collapsed, it's a single
// extended FAB; tapping it expands two labeled mini-FABs ("New set",
// "Import") behind a scrim. Tapping a mini-FAB, the scrim, the main FAB
// again, or the back gesture collapses it. Import/Share used to live on
// `SetDetailScreen`'s now-removed overflow menu — Import moved to this
// speed-dial, Share moved into each card's three-dot menu.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../data/set_json_codec.dart';
import '../lesson/lesson.dart';
import '../pet/pet_providers.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'library_providers.dart';
import 'set_detail_screen.dart';
import 'set_editor_screen.dart';
import 'share_actions.dart';

/// Library home screen: all sets with counts + play/edit affordances.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _seeding = false;
  String? _seedError;
  bool _fabMenuExpanded = false;

  Future<void> _openEditor([QuestionSet? existing]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<int>(
        builder: (_) => SetEditorScreen(existing: existing),
      ),
    );
  }

  Future<void> _confirmDeleteSet(QuestionSet set) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await FoxConfirmDialog.show(
      context: context,
      title: l10n.deleteSetTitle,
      message: l10n.deleteSetMessage(set.title),
      confirmLabel: l10n.confirmDelete,
      cancelLabel: l10n.cancel,
      confirmKey: const Key('confirmDeleteSetButton'),
      cancelKey: const Key('cancelDeleteSetButton'),
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

  void _expandFabMenu() => setState(() => _fabMenuExpanded = true);

  void _collapseFabMenu() => setState(() => _fabMenuExpanded = false);

  Future<void> _createNewSet() async {
    _collapseFabMenu();
    await _openEditor();
  }

  Future<void> _importSet() async {
    _collapseFabMenu();
    final l10n = AppLocalizations.of(context)!;
    try {
      await importSetFromPicker(ref);
    } on SetImportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.importFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final setsAsync = ref.watch(allSetsProvider);
    return PopScope(
      canPop: !_fabMenuExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _collapseFabMenu();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.libraryTitle)),
        floatingActionButton: _fabMenuExpanded
            ? FloatingActionButton(
                key: const Key('newSetFab'),
                tooltip: l10n.newSetFabCollapseTooltip,
                onPressed: _collapseFabMenu,
                child: const Icon(Icons.close),
              )
            : FloatingActionButton.extended(
                key: const Key('newSetFab'),
                onPressed: _expandFabMenu,
                icon: const Icon(Icons.add),
                label: Text(l10n.newSet),
              ),
        body: Stack(
          children: [
            setsAsync.when(
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
                        MaterialPageRoute<void>(
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
            if (_fabMenuExpanded) _buildFabMenuOverlay(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildFabMenuOverlay(AppLocalizations l10n) {
    // `BlockSemantics` hides the dimmed Library list behind the scrim from
    // screen readers — without it, the scrim only dims the list visually;
    // a11y users could still navigate to and "activate" cards/menus that
    // are no longer hit-testable underneath it.
    return BlockSemantics(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('newSetFabScrim'),
              onTap: _collapseFabMenu,
              child: Container(color: Colors.black54),
            ),
          ),
          Positioned(
            right: FoxSpacing.lg,
            bottom: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  key: const Key('importSetFab'),
                  heroTag: 'importSetFab',
                  tooltip: l10n.importSet,
                  onPressed: _importSet,
                  icon: const Icon(Icons.file_upload),
                  label: Text(l10n.importSet),
                ),
                const SizedBox(height: FoxSpacing.sm),
                FloatingActionButton.extended(
                  key: const Key('newSetMiniFab'),
                  heroTag: 'newSetMiniFab',
                  tooltip: l10n.newSet,
                  onPressed: _createNewSet,
                  icon: const Icon(Icons.edit),
                  label: Text(l10n.newSet),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations l10n) {
    return FoxEmptyState(
      title: l10n.libraryEmptyTitle,
      message: l10n.libraryEmptyMessage,
      ctaLabel: l10n.libraryTryDemo,
      onCta: _seedDemo,
      isLoading: _seeding,
      loadingLabel: l10n.librarySeedLoading,
      errorMessage: _seedError != null ? l10n.librarySeedError : null,
      pet: ref.watch(equippedPetProvider),
      titleKey: const Key('libraryEmptyTitle'),
      ctaKey: const Key('tryDemoSetButton'),
      errorKey: const Key('librarySeedError'),
      loadingKey: const Key('librarySeedLoading'),
    );
  }
}

/// One set row: title, item count, play icon + three-dot menu.
///
/// The row itself is not a tap target (#042) — play and the three-dot menu
/// are explicit, unambiguous icon buttons instead of an implicit whole-row
/// `onTap` competing with them. The three-dot menu (#074) covers edit
/// items/rename/duplicate/share/delete; there is no separate pencil icon.
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

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    try {
      await shareSet(ref, set.id, set.title);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(itemsForSetProvider(set.id));
    final subtitle = itemsAsync.when(
      loading: () => l10n.libraryLoading,
      error: (_, _) => '',
      data: (loadedItems) => l10n.setItemCount(loadedItems.length),
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
            IconButton(
              key: Key('playSet-${set.id}'),
              tooltip: l10n.lessonStart,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.play_arrow),
              onPressed: () => startLessonFromSet(
                context: context,
                setId: set.id,
                itemsAsync: itemsAsync,
                l10n: l10n,
              ),
            ),
            PopupMenuButton<String>(
              key: Key('setMenu-${set.id}'),
              tooltip: l10n.setActions,
              onSelected: (value) {
                switch (value) {
                  case 'editItems':
                    onOpen();
                  case 'rename':
                    onRename();
                  case 'duplicate':
                    onDuplicate();
                  case 'share':
                    _share(context, ref, l10n);
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'editItems',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_note),
                    title: Text(l10n.editItems),
                  ),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.drive_file_rename_outline),
                    title: Text(l10n.rename),
                  ),
                ),
                PopupMenuItem(
                  value: 'duplicate',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copy),
                    title: Text(l10n.duplicate),
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.share),
                    title: Text(l10n.shareSet),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline),
                    title: Text(l10n.delete),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
