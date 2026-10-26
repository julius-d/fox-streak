// Pet collection/equip screen (issue #059).
//
// Reached by tapping the pet on Home. Shows the *entire* catalog as a
// grid: owned pets are tappable to equip; not-yet-owned ones render
// locked/greyed (visible but inert) so the user can see there's more to
// collect.
//
// v#069: tiles are ordered by `PetEntry.sortOrder` ascending (not
// alphabetical by id), each shows its rarity/seasonal label under the pet
// (owned and locked alike, no percentage shown), and an owned-more-than-
// once tile shows a "×N" badge in its top-right corner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../stats/pet_service.dart';
import '../stats/stats_providers.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'pet_catalog.dart';
import 'pet_providers.dart';

class PetCollectionScreen extends ConsumerWidget {
  const PetCollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final AsyncValue<List<PetEntry>> catalogAsync = ref.watch(
      petCatalogProvider,
    );
    final AsyncValue<Map<String, int>> ownedAsync = ref.watch(
      ownedPetCountsProvider,
    );
    final String equippedId =
        ref.watch(profileProvider).asData?.value.equippedPetId ??
        PetCatalog.defaultEntry.id;

    return Scaffold(
      key: const Key('petCollectionScreen'),
      appBar: AppBar(title: Text(l10n.petCollectionTitle)),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text(e.toString())),
        data: (List<PetEntry> catalog) => ownedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace _) => Center(child: Text(e.toString())),
          data: (Map<String, int> ownedCounts) {
            final List<PetEntry> sorted = [...catalog]
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            return GridView.builder(
              key: const Key('petCollectionGrid'),
              padding: const EdgeInsets.all(FoxSpacing.lg),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: FoxSpacing.md,
                crossAxisSpacing: FoxSpacing.md,
              ),
              itemCount: sorted.length,
              itemBuilder: (BuildContext context, int index) {
                final PetEntry entry = sorted[index];
                final int ownedCount = ownedCounts[entry.id] ?? 0;
                return _PetTile(
                  entry: entry,
                  ownedCount: ownedCount,
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

/// One grid cell: an owned pet (tappable to equip, highlighted if
/// currently equipped) or a locked placeholder for a not-yet-owned one —
/// either way, labelled underneath with its rarity (or "Seasonal" for
/// spider/snowman), and badged "×N" if [ownedCount] is more than 1.
///
/// Design reason for not reusing a kit button here: the kit's buttons are
/// all label-driven (text + optional icon), not a square image tile with a
/// lock overlay or an equipped-highlight border — this stays a one-off.
class _PetTile extends ConsumerWidget {
  final PetEntry entry;
  final int ownedCount;
  final bool isEquipped;
  final AppLocalizations l10n;

  const _PetTile({
    required this.entry,
    required this.ownedCount,
    required this.isEquipped,
    required this.l10n,
  });

  bool get _isOwned => ownedCount > 0;

  String get _rarityLabel => l10n.petRarityLabel(entry.rarityKey);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget rarityLabel = Text(
      _rarityLabel,
      key: Key('petRarityLabel-${entry.id}'),
      style: Theme.of(context).textTheme.labelSmall,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (!_isOwned) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Semantics(
              key: Key('petTile-${entry.id}'),
              label: l10n.petLockedSemanticLabel,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(FoxRadius.md),
                  ),
                ),
                child: Center(
                  child: Icon(Icons.lock_outline, color: scheme.outlineVariant),
                ),
              ),
            ),
          ),
          const SizedBox(height: FoxSpacing.xs),
          rarityLabel,
        ],
      );
    }

    final Widget tile = InkWell(
      key: Key('petTile-${entry.id}'),
      borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.md)),
      onTap: () => ref.read(petServiceProvider).equip(entry.id),
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
              ? l10n.petEquippedSemanticLabel(entry.emoji)
              : l10n.petSemanticLabel(entry.emoji),
          child: FoxPet(pet: entry, size: 72),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: tile),
              if (ownedCount > 1)
                Positioned(
                  key: Key('petOwnedCount-${entry.id}'),
                  right: 4,
                  top: 4,
                  child: _OwnedCountBadge(count: ownedCount),
                ),
            ],
          ),
        ),
        const SizedBox(height: FoxSpacing.xs),
        rarityLabel,
      ],
    );
  }
}

/// The "×N" owned-count badge (issue #069) shown top-right on a tile for a
/// pet owned more than once — surfaces `OwnedPets.count` (written since
/// #064, never read by the UI until now).
class _OwnedCountBadge extends StatelessWidget {
  final int count;

  const _OwnedCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.sm)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          '×$count',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
