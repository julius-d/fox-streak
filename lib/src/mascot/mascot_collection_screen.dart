// Mascot collection/equip screen (issue #059).
//
// Reached by tapping the mascot on Home. Shows the *entire* catalog as a
// grid: owned mascots are tappable to equip; not-yet-owned ones render
// locked/greyed (visible but inert) so the user can see there's more to
// collect.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../stats/mascot_service.dart';
import '../stats/stats_providers.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'mascot_catalog.dart';
import 'mascot_providers.dart';

class MascotCollectionScreen extends ConsumerWidget {
  const MascotCollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final AsyncValue<List<MascotEntry>> catalogAsync = ref.watch(
      mascotCatalogProvider,
    );
    final AsyncValue<List<String>> ownedAsync = ref.watch(
      ownedMascotIdsProvider,
    );
    final String equippedId =
        ref.watch(profileProvider).asData?.value.equippedMascotId ??
        MascotCatalog.defaultEntry.id;

    return Scaffold(
      key: const Key('mascotCollectionScreen'),
      appBar: AppBar(title: Text(l10n.mascotCollectionTitle)),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text(e.toString())),
        data: (List<MascotEntry> catalog) => ownedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace _) => Center(child: Text(e.toString())),
          data: (List<String> ownedIds) {
            final Set<String> owned = ownedIds.toSet();
            return GridView.builder(
              key: const Key('mascotCollectionGrid'),
              padding: const EdgeInsets.all(FoxSpacing.lg),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: FoxSpacing.md,
                crossAxisSpacing: FoxSpacing.md,
              ),
              itemCount: catalog.length,
              itemBuilder: (BuildContext context, int index) {
                final MascotEntry entry = catalog[index];
                return _MascotTile(
                  entry: entry,
                  isOwned: owned.contains(entry.id),
                  isEquipped: entry.id == equippedId,
                  l10n: l10n,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// One grid cell: an owned mascot (tappable to equip, highlighted if
/// currently equipped) or a locked placeholder for a not-yet-owned one.
///
/// Design reason for not reusing a kit button here: the kit's buttons are
/// all label-driven (text + optional icon), not a square image tile with a
/// lock overlay or an equipped-highlight border — this stays a one-off.
class _MascotTile extends ConsumerWidget {
  final MascotEntry entry;
  final bool isOwned;
  final bool isEquipped;
  final AppLocalizations l10n;

  const _MascotTile({
    required this.entry,
    required this.isOwned,
    required this.isEquipped,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (!isOwned) {
      return Semantics(
        key: Key('mascotTile-${entry.id}'),
        label: l10n.mascotLockedSemanticLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.md)),
          ),
          child: Center(
            child: Icon(Icons.lock_outline, color: scheme.outlineVariant),
          ),
        ),
      );
    }

    return InkWell(
      key: Key('mascotTile-${entry.id}'),
      borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.md)),
      onTap: () => ref.read(mascotServiceProvider).equip(entry.id),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isEquipped ? scheme.primaryContainer : null,
          border: isEquipped
              ? Border.all(color: scheme.primary, width: 2)
              : null,
          borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.md)),
        ),
        child: Semantics(
          button: true,
          label: isEquipped
              ? l10n.mascotEquippedSemanticLabel(entry.emoji)
              : l10n.mascotSemanticLabel(entry.emoji),
          child: FoxMascot(mascot: entry, size: 72),
        ),
      ),
    );
  }
}
