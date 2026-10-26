// Pet collection/equip screen (issue #059).
//
// Reached by tapping the pet on Home. Shows the *entire* catalog as a
// grid: owned pets are tappable to equip; not-yet-owned ones render
// locked/greyed (visible but inert) so the user can see there's more to
// collect.
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
    final AsyncValue<List<String>> ownedAsync = ref.watch(ownedPetIdsProvider);
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
          data: (List<String> ownedIds) {
            final Set<String> owned = ownedIds.toSet();
            return GridView.builder(
              key: const Key('petCollectionGrid'),
              padding: const EdgeInsets.all(FoxSpacing.lg),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: FoxSpacing.md,
                crossAxisSpacing: FoxSpacing.md,
              ),
              itemCount: catalog.length,
              itemBuilder: (BuildContext context, int index) {
                final PetEntry entry = catalog[index];
                return _PetTile(
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

/// One grid cell: an owned pet (tappable to equip, highlighted if
/// currently equipped) or a locked placeholder for a not-yet-owned one.
///
/// Design reason for not reusing a kit button here: the kit's buttons are
/// all label-driven (text + optional icon), not a square image tile with a
/// lock overlay or an equipped-highlight border — this stays a one-off.
class _PetTile extends ConsumerWidget {
  final PetEntry entry;
  final bool isOwned;
  final bool isEquipped;
  final AppLocalizations l10n;

  const _PetTile({
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
        key: Key('petTile-${entry.id}'),
        label: l10n.petLockedSemanticLabel,
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
  }
}
