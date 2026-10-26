// Riverpod wiring for pet reads (issue #059).
//
// Thin wrappers over `PetCatalog`/`PetRepository`/`StatsRepository` —
// Home, the lesson result screen, onboarding, `FoxEmptyState`, and the
// collection screen all watch these; no direct DB/asset-bundle use in
// widgets.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../stats/pet_service.dart';
import '../stats/stats_providers.dart';
import 'pet_catalog.dart';

/// The full pet catalog, discovered once from the asset manifest.
///
/// Goes through [petCatalogLoaderProvider] (not `PetCatalog.load`
/// directly) so overriding that one seam in a test genuinely keeps every
/// catalog read — this provider included — off the real asset bundle, not
/// just `PetService`'s own lootbox-trigger check.
final petCatalogProvider = FutureProvider<List<PetEntry>>((ref) {
  return ref.watch(petCatalogLoaderProvider)();
});

/// Live view of every pet ID this profile has unlocked, for the
/// collection screen.
final ownedPetIdsProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(petRepositoryProvider).watchOwnedPetIds();
});

/// Resolves the equipped pet as a full catalog entry (ID + asset path +
/// decoded emoji), falling back to the default fox while the profile or
/// catalog is still loading (or if the equipped ID is somehow absent from
/// the catalog) — every screen that renders the equipped pet goes
/// through this one provider so there's a single place reconciling
/// `profileStats.equippedPetId` against the catalog.
final equippedPetProvider = Provider<PetEntry>((ref) {
  final ProfileStat? profile = ref.watch(profileProvider).asData?.value;
  final List<PetEntry>? catalog = ref.watch(petCatalogProvider).asData?.value;
  if (profile == null || catalog == null) return PetCatalog.defaultEntry;
  return catalog.firstWhere(
    (entry) => entry.id == profile.equippedPetId,
    orElse: () => PetCatalog.defaultEntry,
  );
});
