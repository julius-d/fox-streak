// Riverpod wiring for mascot reads (issue #059).
//
// Thin wrappers over `MascotCatalog`/`MascotRepository`/`StatsRepository` —
// Home, the lesson result screen, onboarding, `FoxEmptyState`, and the
// collection screen all watch these; no direct DB/asset-bundle use in
// widgets.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../stats/mascot_service.dart';
import '../stats/stats_providers.dart';
import 'mascot_catalog.dart';

/// The full mascot catalog, discovered once from the asset manifest.
///
/// Goes through [mascotCatalogLoaderProvider] (not `MascotCatalog.load`
/// directly) so overriding that one seam in a test genuinely keeps every
/// catalog read — this provider included — off the real asset bundle, not
/// just `MascotService`'s own lootbox-trigger check.
final mascotCatalogProvider = FutureProvider<List<MascotEntry>>((ref) {
  return ref.watch(mascotCatalogLoaderProvider)();
});

/// Live view of every mascot ID this profile has unlocked, for the
/// collection screen.
final ownedMascotIdsProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(mascotRepositoryProvider).watchOwnedMascotIds();
});

/// Resolves the equipped mascot as a full catalog entry (ID + asset path +
/// decoded emoji), falling back to the default fox while the profile or
/// catalog is still loading (or if the equipped ID is somehow absent from
/// the catalog) — every screen that renders the equipped mascot goes
/// through this one provider so there's a single place reconciling
/// `profileStats.equippedMascotId` against the catalog.
final equippedMascotProvider = Provider<MascotEntry>((ref) {
  final ProfileStat? profile = ref.watch(profileProvider).asData?.value;
  final List<MascotEntry>? catalog = ref
      .watch(mascotCatalogProvider)
      .asData
      ?.value;
  if (profile == null || catalog == null) return MascotCatalog.defaultEntry;
  return catalog.firstWhere(
    (entry) => entry.id == profile.equippedMascotId,
    orElse: () => MascotCatalog.defaultEntry,
  );
});
