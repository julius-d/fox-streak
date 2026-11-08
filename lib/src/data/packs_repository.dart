// Packs: grouping of sets (issue #121).
//
// Every set lives in exactly one pack. *Own* packs are created by the learner
// (title only); *downloaded* packs come from the Marketplace and are
// identified by `(sourceUrl, sourcePackId)`. Own sets can only live in own
// packs.

import 'package:drift/drift.dart';

import 'clock.dart';
import 'database.dart';
import 'pack_defaults.dart';

/// Whether the pack was downloaded from a Marketplace source.
extension PackOrigin on Pack {
  bool get isDownloaded => sourceUrl != null;
  bool get isOwn => sourceUrl == null;
}

/// Returns the id of the first own pack (by creation), creating the default
/// "My sets" pack when the learner has none (e.g. only downloaded packs).
Future<int> ensureDefaultOwnPack(AppDatabase db, Clock clock) async {
  final existing =
      await (db.select(db.packs)
            ..where((t) => t.sourceUrl.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ])
            ..limit(1))
          .getSingleOrNull();
  if (existing != null) return existing.id;
  return db
      .into(db.packs)
      .insert(
        PacksCompanion.insert(
          title: defaultPackTitle(),
          createdAt: clock.now().millisecondsSinceEpoch,
        ),
      );
}

class PacksRepository {
  final AppDatabase _db;
  final Clock _clock;

  PacksRepository(AppDatabase db, [Clock? clock])
    : _db = db,
      _clock = clock ?? SystemClock();

  /// Library order: own packs first (by creation), then downloaded packs (by
  /// download time). Stable — never reordered by usage.
  static final List<OrderingTerm Function(Packs)> _libraryOrder = [
    (t) => OrderingTerm.asc(t.sourceUrl.isNotNull()),
    (t) => OrderingTerm.asc(t.createdAt),
    (t) => OrderingTerm.asc(t.downloadedAt),
    (t) => OrderingTerm.asc(t.id),
  ];

  Future<List<Pack>> getAllPacks() =>
      (_db.select(_db.packs)..orderBy(_libraryOrder)).get();

  Stream<List<Pack>> watchAllPacks() =>
      (_db.select(_db.packs)..orderBy(_libraryOrder)).watch();

  Stream<List<Pack>> watchOwnPacks() =>
      (_db.select(_db.packs)
            ..where((t) => t.sourceUrl.isNull())
            ..orderBy(_libraryOrder))
          .watch();

  Future<Pack?> getPackById(int id) =>
      (_db.select(_db.packs)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Creates an own pack (title only); returns its id.
  Future<int> createPack(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError('title must be non-empty');
    return _db
        .into(_db.packs)
        .insert(
          PacksCompanion.insert(
            title: trimmed,
            createdAt: _clock.now().millisecondsSinceEpoch,
          ),
        );
  }

  /// Renames an own pack; downloaded packs cannot be renamed.
  Future<void> renamePack(int id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError('title must be non-empty');
    final pack = await getPackById(id);
    if (pack == null) throw ArgumentError('unknown pack id $id');
    if (pack.isDownloaded) {
      throw ArgumentError('downloaded packs cannot be renamed');
    }
    await (_db.update(_db.packs)..where((t) => t.id.equals(id))).write(
      PacksCompanion(title: Value(trimmed)),
    );
  }

  /// Number of sets in the pack (what a delete would take with it).
  Future<int> countSets(int packId) async {
    final count = _db.questionSets.id.count();
    final row =
        await (_db.selectOnly(_db.questionSets)
              ..addColumns([count])
              ..where(_db.questionSets.packId.equals(packId)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Deletes the pack together with its sets (items/attempts cascade). When
  /// that leaves no pack at all, an empty default own pack is recreated.
  Future<void> deletePack(int id) => _db.transaction(() async {
    await (_db.delete(_db.packs)..where((t) => t.id.equals(id))).go();
    final remaining = await getAllPacks();
    if (remaining.isEmpty) await ensureDefaultOwnPack(_db, _clock);
  });

  Future<void> setCollapsed(int id, {required bool collapsed}) =>
      (_db.update(_db.packs)..where((t) => t.id.equals(id))).write(
        PacksCompanion(collapsed: Value(collapsed)),
      );

  /// The own pack to preselect when adding a set: the one holding the most
  /// recently created set, else the first own pack (created when missing).
  Future<int> defaultOwnPackId() async {
    final last =
        await (_db.select(_db.questionSets).join([
                innerJoin(
                  _db.packs,
                  _db.packs.id.equalsExp(_db.questionSets.packId),
                ),
              ])
              ..where(_db.packs.sourceUrl.isNull())
              ..orderBy([
                OrderingTerm.desc(_db.questionSets.createdAt),
                OrderingTerm.desc(_db.questionSets.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (last != null) return last.read(_db.packs.id)!;
    return ensureDefaultOwnPack(_db, _clock);
  }
}
