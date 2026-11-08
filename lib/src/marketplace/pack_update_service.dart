// Pack-update detection and application outside the Marketplace screens
// (issue #125): the startup check and the Home banner's "Update" both go
// through here. Uses exactly the #121 rules — `outdatedSetIds` decides what
// counts as an update, `updatePack` applies it all-or-nothing.

import '../data/database.dart';
import '../data/marketplace_repository.dart';
import '../data/packs_repository.dart';
import 'marketplace_client.dart';

/// A downloaded pack whose Marketplace source offers new or changed sets.
class PackUpdate {
  final Pack pack;
  final Uri manifestUrl;
  final Uri packUrl;
  final MarketplacePackListing listing;

  /// Ids (Marketplace set ids) of new/changed sets, in listing order.
  final List<String> outdatedSetIds;

  const PackUpdate({
    required this.pack,
    required this.manifestUrl,
    required this.packUrl,
    required this.listing,
    required this.outdatedSetIds,
  });

  String get sourceUrl => pack.sourceUrl!;
  String get sourcePackId => pack.sourcePackId!;
}

/// Tracks packs that are being downloaded/updated right now, so the same
/// pack is never written twice concurrently (Home banner vs. Marketplace
/// pack screen). Keyed by (source, Marketplace pack id).
class PackUpdateLocks {
  final Set<String> _held = {};

  static String keyFor(String sourceUrl, String packId) => '$sourceUrl|$packId';

  bool isHeld(String sourceUrl, String packId) =>
      _held.contains(keyFor(sourceUrl, packId));

  /// True when the lock was free and is now held by the caller.
  bool tryAcquire(String sourceUrl, String packId) =>
      _held.add(keyFor(sourceUrl, packId));

  void release(String sourceUrl, String packId) =>
      _held.remove(keyFor(sourceUrl, packId));
}

class PackUpdateService {
  final MarketplaceClient _client;
  final MarketplaceRepository _marketplace;
  final PacksRepository _packs;

  PackUpdateService(this._client, this._marketplace, this._packs);

  /// Checks every downloaded pack against its source. Sources or packs that
  /// cannot be reached/parsed are skipped silently — a failed check is never
  /// an error for the learner.
  Future<List<PackUpdate>> findUpdates() async {
    final downloaded = [
      for (final pack in await _packs.getAllPacks())
        if (pack.sourceUrl != null && pack.sourcePackId != null) pack,
    ];
    final updates = <PackUpdate>[];
    final manifests = <String, MarketplaceManifest?>{};
    for (final pack in downloaded) {
      final sourceUrl = pack.sourceUrl!;
      final manifestUrl = Uri.parse(sourceUrl);
      if (!manifests.containsKey(sourceUrl)) {
        manifests[sourceUrl] = await _tryFetchManifest(manifestUrl);
      }
      final manifest = manifests[sourceUrl];
      final ref = manifest?.packs
          .where((p) => p.id == pack.sourcePackId)
          .firstOrNull;
      if (ref == null) continue;
      try {
        final listing = await _client.fetchPack(manifestUrl, ref.url);
        final outdated = await _marketplace.outdatedSetIds(
          sourceUrl: sourceUrl,
          packId: ref.id,
          listedSets: {for (final s in listing.sets) s.id: s.updatedAt},
        );
        if (outdated.isEmpty) continue;
        updates.add(
          PackUpdate(
            pack: pack,
            manifestUrl: manifestUrl,
            packUrl: manifestUrl.resolveUri(Uri.parse(ref.url)),
            listing: listing,
            outdatedSetIds: outdated,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return updates;
  }

  Future<MarketplaceManifest?> _tryFetchManifest(Uri url) async {
    try {
      return await _client.fetchManifest(url);
    } catch (_) {
      return null;
    }
  }

  /// Local sets of [update] that applying it would overwrite although the
  /// learner edited them since the last sync.
  Future<List<({String setId, QuestionSet set})>> editedSets(
    PackUpdate update,
  ) => _marketplace.locallyEditedSets(
    sourceUrl: update.sourceUrl,
    packId: update.sourcePackId,
    setIds: update.outdatedSetIds,
  );

  /// Whether the local pack of [update] still exists (it may have been
  /// deleted since the check).
  Future<bool> stillDownloaded(PackUpdate update) async =>
      await _marketplace.findPack(update.sourceUrl, update.sourcePackId) !=
      null;

  /// Fetches the sets of [update] except [skipSetIds] and writes them in one
  /// transaction (all-or-nothing). [onSetFetched] reports each fetched set.
  Future<void> apply(
    PackUpdate update, {
    Set<String> skipSetIds = const {},
    void Function()? onSetFetched,
  }) async {
    final fetched = <FetchedMarketplaceSet>[];
    for (final setRef in update.listing.sets) {
      if (!update.outdatedSetIds.contains(setRef.id) ||
          skipSetIds.contains(setRef.id)) {
        continue;
      }
      fetched.add(
        FetchedMarketplaceSet(
          setId: setRef.id,
          listingUpdatedAt: setRef.updatedAt,
          json: await _client.fetchSetJson(update.packUrl, setRef.url),
        ),
      );
      onSetFetched?.call();
    }
    if (fetched.isEmpty) return;
    await _marketplace.updatePack(
      sourceUrl: update.sourceUrl,
      packId: update.sourcePackId,
      title: update.listing.title,
      description: update.listing.description,
      sets: fetched,
    );
  }
}
