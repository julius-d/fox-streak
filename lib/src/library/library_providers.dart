// Riverpod streams for the set library (issue #003).
//
// Thin wrappers over `SetsRepository` (#002). Screens watch these; all data
// access goes through `setsRepositoryProvider` — no direct DB use in widgets.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../data/set_mastery.dart';

/// All sets, ordered by id (repository order).
final allSetsProvider = StreamProvider<List<QuestionSet>>((ref) {
  return ref.watch(setsRepositoryProvider).watchAllSets();
});

/// Items of one set, ordered by position.
final itemsForSetProvider = StreamProvider.family<List<Item>, int>((
  ref,
  setId,
) {
  return ref.watch(setsRepositoryProvider).watchItemsForSet(setId);
});

/// Mastery of every set with items, by set id (issue #134); a set missing
/// from the map has no items ([SetMastery.empty]).
final setMasteryProvider = StreamProvider<Map<int, SetMastery>>((ref) {
  return ref.watch(statsRepositoryProvider).watchSetMastery();
});

/// One set's mastery, derived from [setMasteryProvider].
final masteryForSetProvider = Provider.family<AsyncValue<SetMastery>, int>((
  ref,
  setId,
) {
  return ref
      .watch(setMasteryProvider)
      .whenData((bySet) => bySet[setId] ?? SetMastery.empty);
});

/// All packs in library order: own first (by creation), then downloaded (by
/// download time) — issue #121.
final allPacksProvider = StreamProvider<List<Pack>>((ref) {
  return ref.watch(packsRepositoryProvider).watchAllPacks();
});

/// Own packs only: the valid targets when adding or importing a set.
final ownPacksProvider = StreamProvider<List<Pack>>((ref) {
  return ref.watch(packsRepositoryProvider).watchOwnPacks();
});
