// Home library: list of sets + FAB (issue #003).
//
// Lists title and mastery crowns (#134, replacing the item count). No "last
// score" — moved to #005/#012. Watches `watchAllSets` via [allSetsProvider];
// play-affordance via [itemsForSetProvider], crowns via
// [masteryForSetProvider]. Each row's play icon jumps straight into
// `LessonScreen`, skipping `SetDetailScreen` entirely (#042).
//
// `newSetFab` is a speed-dial (issue #074): collapsed, it's a single
// extended FAB; tapping it expands labeled mini-FABs ("New set", "Import",
// and — issue #101 — "Marketplace") behind a scrim. Tapping a mini-FAB,
// the scrim, the main FAB again, or the back gesture collapses it. Since
// #133 the menu animates (see `speed_dial.dart`): options pop in bottom →
// top, the main FAB morphs into a round ×, closing plays it in reverse —
// instant under the OS reduce-motion setting.
// Import/Share used to live on `SetDetailScreen`'s now-removed overflow
// menu — Import moved to this speed-dial, Share moved into each card's
// three-dot menu.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/packs_repository.dart';
import '../data/providers.dart';
import '../data/set_json_codec.dart';
import '../data/set_mastery.dart';
import '../lesson/lesson.dart';
import '../marketplace/marketplace_sources_screen.dart';
import '../pet/pet_providers.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'library_providers.dart';
import 'pack_management_screen.dart';
import 'pack_picker.dart';
import 'pack_sections.dart';
import 'set_detail_screen.dart';
import 'set_editor_screen.dart';
import 'set_mastery_indicator.dart';
import 'share_actions.dart';
import 'speed_dial.dart';

/// Library home screen: all sets with mastery + play/edit affordances.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  bool _seeding = false;
  String? _seedError;

  /// Drives the speed-dial: 0 collapsed, 1 open. Its status is the menu's
  /// state — forward/completed counts as open, so a close tap mid-pop
  /// reverses from wherever the animation is.
  late final AnimationController _fabMenu =
      AnimationController(vsync: this, reverseDuration: speedDialCloseDuration)
        ..addStatusListener((_) {
          // Rebuild for scrim mounting and `PopScope.canPop`.
          if (mounted) setState(() {});
        });

  bool get _fabMenuExpanded => _fabMenu.status.isForwardOrCompleted;

  @override
  void dispose() {
    _fabMenu.dispose();
    super.dispose();
  }

  Future<void> _openEditor({QuestionSet? existing, int? packId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<int>(
        builder: (_) =>
            SetEditorScreen(existing: existing, initialPackId: packId),
      ),
    );
  }

  Future<void> _moveSet(QuestionSet set, List<Pack> targets) async {
    final l10n = AppLocalizations.of(context)!;
    final targetId = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.moveToPackTitle),
        children: [
          for (final pack in targets)
            SimpleDialogOption(
              key: Key('moveTarget-${pack.id}'),
              onPressed: () => Navigator.of(ctx).pop(pack.id),
              child: Text(pack.title),
            ),
        ],
      ),
    );
    if (targetId == null) return;
    await ref.read(setsRepositoryProvider).moveSetToPack(set.id, targetId);
  }

  Future<void> _togglePack(Pack pack) => ref
      .read(packsRepositoryProvider)
      .setCollapsed(pack.id, collapsed: !pack.collapsed);

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

  void _toggleFabMenu() =>
      _fabMenuExpanded ? _collapseFabMenu() : _expandFabMenu();

  void _expandFabMenu() {
    // A snack bar lifts the FAB slot; the option stack's height cap
    // (short screens) doesn't account for that, so clear it first.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (MediaQuery.disableAnimationsOf(context)) {
      _fabMenu.value = 1;
    } else {
      _fabMenu.forward();
    }
    FoxFeedback.tick(context, ref);
  }

  /// Never awaited: picking an option navigates right away while the menu
  /// closes underneath.
  void _collapseFabMenu() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _fabMenu.value = 0;
    } else {
      _fabMenu.reverse();
    }
  }

  Future<void> _createNewSet() async {
    _collapseFabMenu();
    await _openEditor();
  }

  Future<void> _importSet() async {
    _collapseFabMenu();
    final l10n = AppLocalizations.of(context)!;
    try {
      await importSetFromPicker(
        ref,
        choosePack: () => showPackChoiceDialog(context),
      );
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

  Future<void> _openMarketplace() async {
    _collapseFabMenu();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MarketplaceSourcesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final setsAsync = ref.watch(allSetsProvider);
    final packsAsync = ref.watch(allPacksProvider);
    final appBar = AppBar(
      title: Text(l10n.libraryTitle),
      actions: [
        IconButton(
          key: const Key('managePacksButton'),
          tooltip: l10n.packManageTitle,
          icon: const Icon(Icons.folder_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PackManagementScreen(),
            ),
          ),
        ),
      ],
    );
    return PopScope(
      canPop: !_fabMenuExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _collapseFabMenu();
      },
      child: Scaffold(
        appBar: appBar,
        floatingActionButton: _buildFabMenu(context, l10n, appBar),
        body: Stack(
          children: [
            if (setsAsync.hasError)
              Center(child: Text(setsAsync.error.toString()))
            else if (!setsAsync.hasValue || !packsAsync.hasValue)
              Center(
                key: const Key('libraryLoading'),
                child: Text(l10n.libraryLoading),
              )
            else
              _buildLibrary(
                context,
                l10n,
                packsAsync.requireValue,
                setsAsync.requireValue,
              ),
            if (!_fabMenu.isDismissed)
              Positioned.fill(
                child: SpeedDialScrim(
                  key: const Key('newSetFabScrim'),
                  animation: _fabMenu,
                  onTap: _collapseFabMenu,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibrary(
    BuildContext context,
    AppLocalizations l10n,
    List<Pack> packs,
    List<QuestionSet> sets,
  ) {
    if (sets.isEmpty && packs.length <= 1) return _buildEmpty(context, l10n);
    final sections = groupSetsByPack(packs, sets);
    // One pack only: a plain list, no header and no collapse control.
    final showHeaders = sections.length > 1;
    final ownPacks = packs.where((p) => p.isOwn).toList();
    final rows = <Widget>[];
    for (final section in sections) {
      final pack = section.pack;
      if (showHeaders) {
        rows.add(
          PackSectionHeader(
            pack: pack,
            setCount: section.sets.length,
            onToggle: () => _togglePack(pack),
          ),
        );
      }
      if (showHeaders && pack.collapsed) continue;
      if (section.sets.isEmpty) {
        rows.add(
          _EmptyPackHint(
            onAddSet: pack.isOwn ? () => _openEditor(packId: pack.id) : null,
          ),
        );
        continue;
      }
      for (final set in section.sets) {
        final moveTargets = [
          for (final p in ownPacks)
            if (p.id != pack.id) p,
        ];
        rows.add(
          _SetCard(
            set: set,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SetDetailScreen(setId: set.id),
              ),
            ),
            onRename: () => _openEditor(existing: set),
            onDuplicate: () => _duplicateSet(set.id),
            onDelete: () => _confirmDeleteSet(set),
            onMove: pack.isOwn && moveTargets.isNotEmpty
                ? () => _moveSet(set, moveTargets)
                : null,
          ),
        );
      }
    }
    return ListView(padding: fabListBottomPadding(context), children: rows);
  }

  Widget _buildFabMenu(
    BuildContext context,
    AppLocalizations l10n,
    PreferredSizeWidget appBar,
  ) {
    final padding = MediaQuery.paddingOf(context);
    final options = [
      SpeedDialOption(
        key: const Key('marketplaceFab'),
        label: l10n.marketplace,
        icon: Icons.storefront,
        onPressed: _openMarketplace,
      ),
      SpeedDialOption(
        key: const Key('importSetFab'),
        label: l10n.importSet,
        icon: Icons.file_upload,
        onPressed: _importSet,
      ),
      SpeedDialOption(
        key: const Key('newSetMiniFab'),
        label: l10n.newSet,
        icon: Icons.edit,
        onPressed: _createNewSet,
      ),
    ];
    // Stagger length follows the option count.
    _fabMenu.duration = speedDialOpenDuration(options.length);
    return SpeedDial(
      animation: _fabMenu,
      mainKey: const Key('newSetFab'),
      label: l10n.newSet,
      icon: Icons.add,
      closeTooltip: l10n.newSetFabCollapseTooltip,
      onToggle: _toggleFabMenu,
      topClearance: padding.top + appBar.preferredSize.height,
      // Scaffold lifts the FAB by the larger of the two (e.g. keyboard up).
      bottomClearance:
          math.max(padding.bottom, MediaQuery.viewPaddingOf(context).bottom) +
          kFloatingActionButtonMargin,
      options: options,
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

/// One set row: title, mastery crowns or "New" badge (#134; nothing for a
/// set without items), play icon + three-dot menu.
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

  /// Null when the set cannot be moved (downloaded pack, or no other own
  /// pack to move to).
  final VoidCallback? onMove;

  const _SetCard({
    required this.set,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMove,
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
    final mastery = ref.watch(masteryForSetProvider(set.id)).value;
    return Card(
      child: ListTile(
        key: Key('setTile-${set.id}'),
        minVerticalPadding: 12,
        title: Text(set.title),
        subtitle: mastery == null || mastery.kind == MasteryKind.none
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: FoxSpacing.xs),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SetMasteryIndicator(
                    key: Key('setMastery-${set.id}'),
                    setId: set.id,
                    mastery: mastery,
                  ),
                ),
              ),
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
                  case 'move':
                    onMove?.call();
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
                if (onMove != null)
                  PopupMenuItem(
                    value: 'move',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.drive_file_move_outline),
                      title: Text(l10n.moveToPack),
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

/// Hint + "Add set" action shown inside an empty own pack.
class _EmptyPackHint extends StatelessWidget {
  /// Null for downloaded packs: own sets cannot be added to them.
  final VoidCallback? onAddSet;

  const _EmptyPackHint({required this.onAddSet});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FoxSpacing.lg,
        vertical: FoxSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.packEmptyHint, key: const Key('packEmptyHint')),
          if (onAddSet != null) ...[
            const SizedBox(height: FoxSpacing.sm),
            FoxSecondaryButton(
              key: const Key('packAddSetButton'),
              label: l10n.packAddSet,
              onPressed: onAddSet,
            ),
          ],
        ],
      ),
    );
  }
}
