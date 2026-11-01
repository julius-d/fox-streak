// Marketplace sources + imported-set-tracking repository (issue #101).
//
// Owns the `marketplace_sources`/`imported_marketplace_sets` tables and the
// import/update orchestration on top of `SetsRepository`'s existing item
// CRUD — no low-level DB writes are duplicated here. Import/update always
// go through the Set JSON codec's validation (#002/#094/#101), same as a
// plain file import.

import 'package:drift/drift.dart';

import 'database.dart';
import 'set_json_codec.dart';
import 'sets_repository.dart';

/// Whether a marketplace Set has ever been imported locally, and if so
/// whether the marketplace's current copy differs from what was last
/// imported/updated.
enum MarketplaceSetStatus { notImported, upToDate, updateAvailable }

/// [MarketplaceRepository.importStateFor]'s result: the [status] plus the
/// local set id when one exists (`notImported` always has a null
/// [localSetId]).
class MarketplaceImportState {
  final MarketplaceSetStatus status;
  final int? localSetId;

  const MarketplaceImportState(this.status, this.localSetId);
}

/// Repository for `marketplace_sources` + `imported_marketplace_sets`, and
/// the import/update flows that bridge a fetched marketplace Set into
/// `SetsRepository`'s local tables.
class MarketplaceRepository {
  final AppDatabase _db;
  final SetsRepository _setsRepository;

  MarketplaceRepository(AppDatabase db, SetsRepository setsRepository)
    : _db = db,
      _setsRepository = setsRepository;

  // -- Sources --------------------------------------------------------------

  Stream<List<MarketplaceSource>> watchSources() => (_db.select(
    _db.marketplaceSources,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  /// Adds a source; throws [ArgumentError] when [url] was already added.
  Future<int> addSource({required String url, required String name}) async {
    final existing = await (_db.select(
      _db.marketplaceSources,
    )..where((t) => t.url.equals(url))).getSingleOrNull();
    if (existing != null) {
      throw ArgumentError('marketplace source "$url" was already added');
    }
    return _db
        .into(_db.marketplaceSources)
        .insert(MarketplaceSourcesCompanion.insert(url: url, name: name));
  }

  Future<void> removeSource(int id) =>
      (_db.delete(_db.marketplaceSources)..where((t) => t.id.equals(id))).go();

  // -- Import status ----------------------------------------------------

  /// Looks up whether the Set identified by `(sourceUrl, packId, setId)`
  /// was ever imported, and if so whether [listingUpdatedAt] (the pack
  /// listing's current value for it) matches what was stored at the last
  /// import/update.
  Future<MarketplaceImportState> importStateFor({
    required String sourceUrl,
    required String packId,
    required String setId,
    required String listingUpdatedAt,
  }) async {
    final row = await _findMapping(sourceUrl, packId, setId);
    if (row == null) {
      return const MarketplaceImportState(
        MarketplaceSetStatus.notImported,
        null,
      );
    }
    final status = row.listingUpdatedAt == listingUpdatedAt
        ? MarketplaceSetStatus.upToDate
        : MarketplaceSetStatus.updateAvailable;
    return MarketplaceImportState(status, row.localSetId);
  }

  /// True when the local set's content changed since its last
  /// marketplace import/update (detected via `QuestionSets.updatedAt`,
  /// which every `SetsRepository` write already bumps) — gates the
  /// "Update" flow's overwrite-local-edits warning.
  Future<bool> isLocallyEdited(int localSetId) async {
    final mapping = await (_db.select(
      _db.importedMarketplaceSets,
    )..where((t) => t.localSetId.equals(localSetId))).getSingleOrNull();
    if (mapping == null) return false;
    final set = await _setsRepository.getSetById(localSetId);
    if (set == null) return false;
    return set.updatedAt != mapping.localUpdatedAtAtSync;
  }

  Future<ImportedMarketplaceSet?> _findMapping(
    String sourceUrl,
    String packId,
    String setId,
  ) =>
      (_db.select(_db.importedMarketplaceSets)..where(
            (t) =>
                t.sourceUrl.equals(sourceUrl) &
                t.packId.equals(packId) &
                t.setId.equals(setId),
          ))
          .getSingleOrNull();

  // -- Import / update ----------------------------------------------------

  /// Imports a never-before-imported marketplace Set as a new local set;
  /// returns the new local set id. Throws [SetImportException] on bad
  /// Set JSON (same validation as a plain file import, #008).
  Future<int> importSet({
    required String sourceUrl,
    required String packId,
    required String setId,
    required String listingUpdatedAt,
    required Map<String, dynamic> setJson,
    DateTime? today,
  }) {
    return _db.transaction(() async {
      final localSetId = await _setsRepository.importSetFromJson(
        setJson,
        today: today,
      );
      final imported = await _setsRepository.getSetById(localSetId);
      await _db
          .into(_db.importedMarketplaceSets)
          .insert(
            ImportedMarketplaceSetsCompanion.insert(
              localSetId: Value(localSetId),
              sourceUrl: sourceUrl,
              packId: packId,
              setId: setId,
              listingUpdatedAt: listingUpdatedAt,
              localUpdatedAtAtSync: imported!.updatedAt,
            ),
          );
      return localSetId;
    });
  }

  /// Updates a previously-imported local set ([localSetId]) with a newer
  /// marketplace copy: items are matched by their share-format `id`
  /// (#101) — matched items are updated in place (keeping their DB id, so
  /// attempt history keyed on it survives), unmatched new items are
  /// inserted fresh, and local items with no match in the new version are
  /// removed. Throws [SetImportException] on bad Set JSON.
  Future<void> updateSet({
    required int localSetId,
    required String sourceUrl,
    required String packId,
    required String setId,
    required String listingUpdatedAt,
    required Map<String, dynamic> setJson,
    DateTime? today,
  }) {
    final share = decodeSetFromJson(setJson, today: today);
    return _db.transaction(
      () => _applyUpdate(
        localSetId: localSetId,
        listingUpdatedAt: listingUpdatedAt,
        share: share,
      ),
    );
  }

  Future<void> _applyUpdate({
    required int localSetId,
    required String listingUpdatedAt,
    required ShareSet share,
  }) async {
    final existingItems = await _setsRepository.getItemsForSet(localSetId);
    final existingByMarketplaceId = <String, Item>{
      for (final item in existingItems)
        if (item.marketplaceItemId != null) item.marketplaceItemId!: item,
    };

    final keptLocalItemIds = <int>{};
    final orderedLocalItemIds = <int>[];
    for (final newItem in share.items) {
      final matched = newItem.id == null
          ? null
          : existingByMarketplaceId[newItem.id];
      if (matched != null) {
        await _setsRepository.updateItem(
          id: matched.id,
          type: newItem.type,
          prompt: newItem.prompt,
          answer: newItem.answer,
          languagePairUpdate: () =>
              (promptLang: newItem.promptLang, answerLang: newItem.answerLang),
          choicesUpdate: () => newItem.choices,
          hint: newItem.hint,
          imageUpdate: () => newItem.imageType == null
              ? null
              : (
                  imageType: newItem.imageType,
                  imageContent: newItem.imageContent,
                  imageCopyright: newItem.imageCopyright,
                ),
        );
        keptLocalItemIds.add(matched.id);
        orderedLocalItemIds.add(matched.id);
      } else {
        final newLocalId = await _setsRepository.addItem(
          setId: localSetId,
          type: newItem.type,
          prompt: newItem.prompt,
          answer: newItem.answer,
          promptLang: newItem.promptLang,
          answerLang: newItem.answerLang,
          choices: newItem.choices,
          hint: newItem.hint,
          imageType: newItem.imageType,
          imageContent: newItem.imageContent,
          imageCopyright: newItem.imageCopyright,
          marketplaceItemId: newItem.id,
        );
        keptLocalItemIds.add(newLocalId);
        orderedLocalItemIds.add(newLocalId);
      }
    }
    for (final existing in existingItems) {
      if (!keptLocalItemIds.contains(existing.id)) {
        await _setsRepository.deleteItem(existing.id);
      }
    }
    await _setsRepository.reorderItems(localSetId, orderedLocalItemIds);
    await _setsRepository.updateSet(
      id: localSetId,
      title: share.title,
      description: share.description,
      createdBy: share.createdBy,
      category: share.category,
    );

    final updated = await _setsRepository.getSetById(localSetId);
    await (_db.update(
      _db.importedMarketplaceSets,
    )..where((t) => t.localSetId.equals(localSetId))).write(
      ImportedMarketplaceSetsCompanion(
        listingUpdatedAt: Value(listingUpdatedAt),
        localUpdatedAtAtSync: Value(updated!.updatedAt),
      ),
    );
  }
}
